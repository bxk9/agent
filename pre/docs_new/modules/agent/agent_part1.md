# Agent 模块详解

> 本文档详细描述 agent 模块的架构设计、核心组件、三阶段流水线和推理干预层。

## 目录

1. [模块概述](#1-模块概述)
2. [设计理念](#2-设计理念)
3. [核心组件](#3-核心组件)
4. [三阶段流水线详解](#4-三阶段流水线详解)
5. [推理干预层](#5-推理干预层)
6. [流式处理管道](#6-流式处理管道)
7. [接口说明](#7-接口说明)

---

## 1 模块概述

### 1.1 模块定位

agent 模块是 pro_agent 的核心编排层，负责：

- **单轮编排**：协调 prepare → infer → finalize 三阶段流水线
- **状态管理**：维护 TurnState（单轮状态）和 ModelSession（模型会话）
- **推理干预**：通过 hooks 机制在推理前后进行定点干预
- **流式处理**：处理模型流式输出，解析工具调用和特殊 token

### 1.2 模块结构

```
agent/
├── __init__.py
├── context.py              # AgentContext：请求级上下文
├── smart_route.py          # SmartRouteInfo：智能路由信息
├── flash/                  # Flash 模型专用 Agent
│   ├── __init__.py
│   └── system_prompt.md
└── pro/
    ├── agent.py            # HostAgent：薄壳编排器
    ├─��� turn_state.py       # TurnState：单轮唯一真值
    ├── model_session.py    # ModelSession：模型会话
    ├── retry_controller.py # RetryController：重试控制器
    ├── stage_prepare.py    # 准备阶段
    ├── stage_infer.py      # 推理阶段
    ├── stage_finalize.py   # 收尾阶段
    ├── agent_helpers.py    # 辅助函数
    ├── emit_context.py     # SSE 下发上下文
    ├── reminder.py         # 系统提醒
    ├── system.py           # 系统提示词加载
    ├── system_prompt.md    # 系统提示词模板
    ├── datatypes.py        # 共享数据类型
    ├── hooks/              # 推理干预层
    │   ├── base.py         # Hook 基类和 Context
    │   ├── registry.py     # Hook 注册表
    │   ├── panel_stale.py  # 面板过期清理
    │   └── composite_output_instruct.py
    └── stream/             # 流式处理管道
        ├── pipeline.py     # StreamPipeline
        ├── processor.py    # StreamProcessor 基类
        ├── assembler.py    # ResultAssembler
        ├── emitter.py      # SseEmitter
        ├── events.py       # 流式事件定义
        └── processors/     # 处理器实现
```

### 1.3 核心职责

| 组件 | 职责 |
|---|---|
| `HostAgent` | 薄壳编排器，串联三阶段流水线 |
| `TurnState` | 单轮唯一真值，收敛所有状态 |
| `ModelSession` | 持有当前模型实例 + 切换能力 |
| `RetryController` | 管理推理-校验循环的重试策略 |
| `hooks/` | 推理干预层，定点干预推理前后 |
| `stream/` | 流式处理管道，处理模型输出 |

---

## 2 设计理念

### 2.1 薄壳编排器模式

`HostAgent` 只是一个"薄壳"，负责串联三阶段流水线，自身不承载业务逻辑。各阶段（prepare/infer/finalize）是独立模块的**纯函数**，依赖通过显式参数传入。

```python
class HostAgent:
    def __init__(self, model: Model):
        self.session = ModelSession(model)

    async def process(self, body, context):
        turn = TurnState()
        try:
            await _stage_prepare(turn, self.session, body, context)
            if not turn.should_stop:
                async for sse in _stage_infer(turn, self.session, body, context):
                    yield sse
            if turn.error:
                yield "event:error\ndata:" + json.dumps(turn.error) + "\n\n"
            async for sse in _stage_finalize(turn, body, context):
                yield sse
        finally:
            write_stat_log(build_trace_data(turn, body, context))
```

### 2.2 单一真值来源

单轮编排的所有状态收敛到 `TurnState` 对象，避免"多处赋值 + 兜底覆盖"的来源不唯一问题。所有阶段只写入 `TurnState`，finalize 只读取 `TurnState`。

### 2.3 纯函数阶段

各阶段是独立模块的纯函数，依赖通过显式参数传入（turn, session, body, context），不依赖 HostAgent 实例。这使得各阶段可独立测试和替换。

---

## 3 核心组件

### 3.1 HostAgent（薄壳编排器）

**文件**：`agent/pro/agent.py`（108 行）

**职责**：
- 持有 `ModelSession`（当前模型 + 切换能力）
- 串联三阶段流水线（prepare → infer → finalize）
- 统一异常处理和埋点

**异常处理策略**：

| 异常类型 | 处理方式 |
|---|---|
| `asyncio.CancelledError` | 客户端断连，标记 cancelled 状态后 re-raise |
| `Exception` | 记录错误到 `turn.error`，由 finalize 下发 error 事件 |
| `finally` | 统一写埋点日志，保证所有退出路径落盘 |

### 3.2 TurnState（单轮唯一真值）

**文件**：`agent/pro/turn_state.py`（81 行）

**字段分类**：

| 分类 | 字段 | 写入阶段 |
|---|---|---|
| 请求上下文 | query, chat_history, request_id, trace_id, smart_route_info | prepare |
| 工具集 | tools, tool_list, patch_prompt_snippets | prepare |
| 推理产出 | assist_content, tool_call_requests, session_finished | infer |
| 控制信号 | should_stop, stop_reason, error | 任意阶段 |
| 埋点数据 | stat (StatCollector) | 各阶段 |
| 缓存回传 | new_geocode_cache | prepare |

**状态方法**：

```python
def stop(self, reason: str, **overrides) -> None:
    """标记本轮提前结束；overrides 就地写入终态字段"""
    self.should_stop = True
    self.stop_reason = reason
    for k, v in overrides.items():
        setattr(self, k, v)

def set_error(self, payload: dict) -> None:
    """记录未预期崩溃/业务错误载荷"""
    self.error = payload
    self.session_finished = True
```

### 3.3 ModelSession（模型会话）

**文件**：`agent/pro/model_session.py`（48 行）

**职责**：持有当前模型实例并提供切换能力。引用共享，切换后各阶段读到即新模型，无需回传。

**切换场景**：

| 场景 | 触发条件 | 切换方向 |
|---|---|---|
| Flash→Pro 降级 | 验证器检测到 Flash 模型幻觉 | flash → pro |
| Mock query 升级 | mock query 场景 | flash → pro |
| Patch 触发 | patch 声明式指定 target_model | 任意方向 |
| 空响应兜底 | Flash 静默退出 | flash → pro |

### 3.4 RetryController（重试控制器）

**文件**：`agent/pro/retry_controller.py`

**三套重试机制**：

| 机制 | 触发条件 | 行为 | 防护 |
|---|---|---|---|
| 验证器 RETRY | 验证器返回 RETRY + RetryHint | 回滚并重新推理 | tag 去重 + 全局闸门 + per-tag 闸门 |
| 空响应兜底 | Flash 静默退出 | 切换到 Pro 重推 | 独立计数器（最多 1 次） |
| 流式安全约束 | 已 yield 文本 token | 禁止回退 | 保护流式体验 |

**RetryHint 字段**：

| 字段 | 说明 |
|---|---|
| `drop_tools` | 排除工具列表 |
| `boost_tools` | 提升工具列表 |
| `extra_system_prompt` | 追加提示词 |
| `feedback_message` | 反馈消息 |
| `tag` | 去重标签 |
| `target_model` | 目标模型类型 |
| `include_violation_context` | 是否注入违例事实 |

### 3.5 AgentContext（请求级上下文）

**文件**：`agent/context.py`

请求级上下文，在多轮对话中通过 `end` 事件下发给客户端，下一轮请求中原样带回。

**核心字段**：

| 字段 | 说明 |
|---|---|
| `history` | MCP 对话历史（tool call + tool result） |
| `tools` | 本轮召回的工具键列表 |
| `model` | 使用的模型名 |
| `model_type` | 模型类型（pro / flash） |
| `tool_count` | 本 session 请求轮次数 |
| `mcp_tools` | 本 session 已调用的工具名列表 |
| `extra_for_experiment` | 实验性字段（geocode_cache, response_id, prefix_hash） |

### 3.6 SmartRouteInfo（智能路由信息）

**文件**：`agent/smart_route.py`

封装上游中控传递的路由信息，由上游模型预测。

| 字段 | 枚举类型 | 值域 | 说明 |
|---|---|---|---|
| `is_intent_specific` | `IntentSpecific` | clear/infer/lack/vague/err | 意图明确度 |
| `is_use_tool` | `UseTool` | single/para/seq/qa/chat/unsupported/pend | 工具调用类型 |
| `is_special_instruction` | `SpecialInstruction` | norm/short/cond | 指令类型 |
| `is_exe_success` | `ExeSuccess` | ok/abnormal | 执行反馈状态 |
| `post_type` | `PostType` | hit_unsupported/hit_multi_slot/hit_modify_task/hit_vector | 后处理触发类型 |

**关键业务逻辑**：
- `is_use_tool=CHAT`：清空工具请求，直接闲聊
- `is_use_tool=UNSUPPORTED/PEND`：系统提示词追加拒识引导
- `need_on_screen + is_use_tool=SINGLE`：强制中断推理，不再总结

---

## 4 三阶段流水线详解

### 4.1 阶段 1：准备阶段（_stage_prepare）

**文件**：`agent/pro/stage_prepare.py`（353 行）

**执行流程**：

```
1. 输入解析（query, chat_history, tool_exec_results）
2. 面板态首轮强制升级（末尾 user 消息 + 面板态非首轮 → 改写为首轮）
3. 处理 chat_history（清理、压缩）
4. 构建 SmartRouteInfo
5. 工具集构建（_resolve_tools → _build_tool_list）
6. Patch 注入（工具注入/剔除/设置注入/系统提示词/模型切换）
7. 彩蛋匹配与注入
8. 逆地理编码（缓存命中 / 异步反查）
9. 工具结果后处理（PostInfer hooks）
10. 推理前干预（PreInfer hooks）
11. 写入 TurnState
12. 早退判断（need_exit → stop）
13. 日程快捷方式（extra.schedules 命中 → 跳过推理）
```

**关键设计**：

- **面板态首轮强制升级**：面板态首轮被用户中断后未退出面板态、又重新提问时，改写 `action.type` 为首轮信号
- **Patch 注入**：支持工具注入、工具剔除、设置注入、系统提示词注入、模型切换、禁用 prompt 模块、豁免 batch validator
- **彩蛋注入**：将 `trigger_easter_egg` 工具注入候选池，让模型自主决策