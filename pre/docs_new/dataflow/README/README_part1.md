# 数据流与生命周期文档

> 本文档详细描述 pro_agent 的完整请求数据流、状态流转、生命周期管理和关键路径分析。

## 目录

1. [完整请求数据流](#1-完整请求数据流)
2. [状态流转图](#2-状态流转图)
3. [生命周期管理](#3-生命周期管理)
4. [关键路径分析](#4-关键路径分析)
5. [错误处理流程](#5-错误处理流程)
6. [性能优化路径](#6-性能优化路径)

---

## 1 完整请求数据流

### 1.1 请求入口

```
客户端 → HTTP POST /stream/chat (或 /mock/chat)
    ↓
main.py: chat() / mock_chat()
    ↓
_do_chat(body)
    ├─ 设置 trace_id
    ├─ 确定 model_type（flash/pro）
    ├─ 创建 AgentContext
    ├─ 创建 ModelSession
    └─ HostAgent.process(body, context)
```

### 1.2 三阶段流水线

```
HostAgent.process()
    │
    ├─ _stage_prepare(turn, session, body, context)
    │   ├─ 输入解析（query, chat_history, tool_exec_results）
    │   ├─ 面板态首轮强制升级
    │   ├─ 处理 chat_history
    │   ├─ 构建 SmartRouteInfo
    │   ├─ 工具集构建（_resolve_tools → _build_tool_list）
    │   ├─ Patch 注入（工具/设置/提示词/模型切换）
    │   ├─ 彩蛋匹配与注入
    │   ├─ 逆地理编码
    │   ├─ 工具结果后处理（PostInfer hooks）
    │   ├─ 推理前干预（PreInfer hooks）
    │   ├─ 写入 TurnState
    │   └─ 早退判断（need_exit / schedule_shortcut）
    │
    ├─ _stage_infer(turn, session, body, context)
    │   ├─ 从 TurnState 读取输入
    │   ├─ Mock query 场景切换到 pro
    │   ├─ 构建系统提示词（base + patch + arbitration）
    │   ├─ 工具列表排序（高频 → 长定义 → 普通）
    │   ├─ 初始化 RetryController
    │   ├─ Responses API 可用性判定
    │   ├─ 推理-校验-重试循环（while True）：
    │   │   ├─ 构建消息列表
    │   │   ├─ Responses API 缓存判断（路径A/B/C）
    │   │   ├─ StreamPipeline 消费循环
    │   │   │   ├─ 模型 SSE 流
    │   │   │   ├─ EosFilter → MarkerFilter → SpecialTokenExtractor
    │   │   │   ├─ yield TextDelta / ToolCallsDone / StreamDone
    │   │   │   └─ 重复上屏检测
    │   │   ├─ 流结束处理
    │   │   ├─ 空响应兜底（flash → pro）
    │   │   ├─ 工具验证（Phase 1 逐工具）
    │   │   │   ├─ tool_pre_process（参数预处理）
    │   │   │   ├─ tool_validate（验证器链）
    │   │   │   └─ RetryInferenceSignal → 重试或降级
    │   │   └─ 工具验证（Phase 2 批量）
    │   │       ├─ tool_validate_batch（全局验证器）
    │   │       └─ DROP → 清空工具调用
    │   ├─ 写入 TurnState
    │   ├─ Responses API 缓存保存
    │   └─ TTFT 分桶埋点
    │
    └─ _stage_finalize(turn, body, context)
        ├─ 从 TurnState 读取产出
        ├─ 上屏合并（STREAM_ON_USER → assist_content）
        ├─ Session 去重（mcp_history）
        ├─ 推荐位信号计算（图片/文档上传引导）
        ├─ 上下文更新（写回 AgentContext）
        └─ SSE 下发（event:tool / event:end）
```

### 1.3 响应返回

```
_stage_finalize yield SSE 事件
    ↓
"event:text\ndata:..."      # 文本增量
"event:tool\ndata:[...]"    # 工具调用请求
"event:end\ndata:{...}"     # 会话状态更新
    ↓
StreamingResponse 返回客户端
```

---

## 2 状态流转图

### 2.1 TurnState 状态流转

```
初始化 TurnState
    ↓
_stage_prepare 写入：
    - query, chat_history, tools, tool_list
    - patch_prompt_snippets, reminder_facts
    - tool_exec_post_processed
    - need_exit, need_interact
    ↓
检查 should_stop
    ├─ True → 跳过 infer，直接进入 finalize
    └─ False → 继续
    ↓
_stage_infer 写入：
    - assist_content, tool_call_requests
    - session_finished, enable_voice
    - mcp_tools, model_type
    ↓
检查 error
    ├─ 有错误 → yield error 事件
    └─ 无错误 → 继续
    ↓
_stage_finalize 读取：
    - 所有终态字段
    ↓
yield SSE 事件
    ↓
write_stat_log（埋点落盘）
```

### 2.2 重试状态流转

```
RetryController 初始化
    ↓
推理-校验循环（while True）
    ↓
模型推理 → 工具调用解析
    ↓
tool_validate（Phase 1）
    ├─ PASS → 继续
    ├─ FIX → 修复参数，继续下一个验证器
    └─ RETRY → 抛出 RetryInferenceSignal
        ↓
    RetryController.can_retry()
        ├─ False（已发射文本 / 超过次数 / tag 重复）
        │   └─ 降级为 PASS，继续执行
        └─ True
            ↓
        RetryController.accept()
            ├─ 应用 drop_tools
            ├─ 追加 extra_system_prompt
            ├─ retry_count += 1
            └─ continue（重新推理）
```

### 2.3 Responses API 路径流转

```
检查 Responses API 可用性
    ├─ 不可用 → 路径C（原始 stream）
    └─ 可用
        ↓
    检查 response_id
        ├─ 无 response_id → 路径B（首次缓存）
        │   ├─ 成功 → 保存 response_id + prefix_hash
        │   └─ 失败 → 降级路径C
        └─ 有 response_id
            ↓
        检查前缀一致性
            ├─ 不一致 → 降级路径C
            └─ 一致
                ↓
            检查 tool 增量
                ├─ 无增量 → 降级路径C
                └─ 有增量 → 路径A（缓存命中）
                    ├─ 成功 → 复用 KV Cache
                    └─ 失败 → 降级路径C
```

---

## 3 生命周期管理

### 3.1 应用生命周期

```
启动（init_app）
    ├─ config_registry.init_all()
    │   ├─ 按 priority 排序
    │   ├─ 逐个执行 init_load()
    │   └─ 注册 on_change 回调
    ├─ easter_egg_manager.start()
    │   ├─ 首次同步加载
    │   └─ 启动守护线程轮询
    └─ init_arbitration()
        └─ 加载仲裁规则

运行（lifespan）
    ├─ 处理请求
    ├─ 配置中心轮询（每 30s）
    │   └─ 触发 on_change 回调
    └─ 彩蛋规则轮询（每 30s）

关闭（destroy）
    └─ 清理资源（当前为空）
```

### 3.2 请求生命周期

```
请求到达
    ↓
设置 trace_id + req_start
    ↓
创建 AgentContext + ModelSession
    ↓
HostAgent.process()
    ├─ try: 三阶段流水线
    ├─ except CancelledError: 客户端断连
    ├─ except Exception: 记录错误
    └─ finally: write_stat_log + cleanup
    ↓
响应返回
    ↓
请求结束
```

### 3.3 工具生命周期

```
工具召回（意图检索）
    ↓
_resolve_tools（意图 → 工具名）
    ↓
_build_tool_list（构建工具定义列表）
    ↓
Patch 注入/剔除
    ↓
_sort_tool_list（排序：高频 → 长定义 → 普通）
    ↓
模型推理 → 工具调用
    ↓
tool_pre_process（参数预处理）
    ↓
tool_validate（验证器链）
    ├─ PASS → 继续
    ├─ FIX → 修复参数
    └─ RETRY → 重试推理
    ↓
tool_validate_batch（批量验证）
    ├─ PASS → 继续
    └─ DROP → 清空工具调用
    ↓
yield event:tool（下发工具调用请求）
    ↓
客户端执行工具
    ↓
tool_post_process（结果后处理）
    ↓
模型总结（如有需要）
```

---

## 4 关键路径分析

### 4.1 首字时间（TTFT）路径

```
请求到达（t0）
    ↓
准备阶段（A_preproc）
    ├─ 输入解析
    ├─ 工具集构建
    ├─ Patch/彩蛋注入
    └─ 系统提示词构建
    ↓
发送请求（send_ts）
    ↓
网络传输（B_net）
    ↓
首字节到达（first_byte_ts）
    ↓
模型解码（C_decode）
    ↓
首个内容 token（first_token_ts）
    ↓
Pipeline 处理（D_onscreen）
    ↓
首次发射（first_emit_ts）
```

**TTFT = first_token_ts - t0 = A_preproc + B_net + C_decode**

### 4.2 工具调用路径

```
模型推理
    ↓
解析工具调用（ToolCallsDone）
    ↓
tool_pre_process（参数预处理）
    ↓
tool_validate（Phase 1 逐工具验证）
    ├─ PASS → 继续
    ├─ FIX → 修复参数
    └─ RETRY → 回滚，重新推理
    ↓
tool_validate_batch（Phase 2 批量验证）
    ├─ PASS → 继续
    └─ DROP → 清空工具调用
    ↓
yield event:tool
    ↓
客户端执行工具
    ↓
返回 tool_exec_results
    ↓
tool_post_process（结果后处理）
    ↓
模型总结（如需要）
```

### 4.3 重试路径

```
模型推理 → 工具调用
    ↓
tool_validate → RETRY
    ↓
检查 can_retry()
    ├─ has_emitted（已发射文本）→ 禁止重试
    ├─ retry_count >= max → 禁止重试
    └─ tag 重复 → 禁止重试
    ↓
accept(signal)
    ├─ 应用 drop_tools
    ├─ 追加 extra_system_prompt
    └─ retry_count += 1
    ↓
清空产出（assist_content = ""）
    ↓
continue（重新推理）
```

---

## 5 错误处理流程

### 5.1 异常分类

| 异常类型 | 处理方式 | 错误码 |
|---|---|---|
| `CancelledError` | 客户端断连，标记 cancelled | ClientDisconnectError |
| `ModelServiceError` | 模型服务错误 | 2011 |
| `AgentProcessError` | Agent 内部异常 | 2012 |
| `RequestHandleError` | 请求入口层异常 | 2013 |

### 5.2 异常处理流程

```
异常发生
    ↓
捕获异常
    ├─ CancelledError → turn.set_error(ClientDisconnect)
    ├─ Exception → turn.set_error(AgentProcessError)
    └─ 记录日志（traceback）
    ↓
yield event:error
    ↓
_stage_finalize
    ├─ 设置 session_finished = True
    └─ yield event:end
    ↓
write_stat_log（埋点落盘）
```

### 5.3 安全降级策略

| 组件 | 异常策略 |
|---|---|
| 验证器 | 异常 → PASS（不阻塞主流程） |