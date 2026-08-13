# 专题 05｜Agent 执行层重构

> 主战场：`app/agent_executor.py`（**45 次修改**）+ `app/main.py`（47 次）+ `app/agent.py`（8 次）
> 版本：v1.0

---

## 一、模块定位

`agent_executor.py` 是本项目的**事件流枢纽**：
- 上游对接 `main.py` 的 WebSocket 端点（`/blueclaw/core`）
- 下游驱动 `LangGraph create_react_agent`
- 中间负责事件规范化、上下文注入、异常兜底、埋点

它是主 Agent 和外部世界之间**唯一**的事件流适配层。任何"上下文丢失 / 事件类型错乱 / recursion 爆炸 / 埋点缺字段"问题，都会命中这一层。

---

## 二、我的贡献主线

### 2.1 事件流规范化

将 LangGraph 内部纷杂事件映射为对外统一的六类：

| 事件类型 | 来源 | 用途 |
|---------|------|------|
| `token` | on_chat_model_stream | 前端流式渲染 |
| `tool_use` | on_tool_start | UI 展示"正在调用 XX 工具" |
| `tool_result` | on_tool_end（成功） | 展示工具产出 |
| `tool_error` | on_tool_end（异常） | 用户可见错误 |
| `final` | on_chain_end | 结束标志 |
| `llm_usage` | on_chat_model_end | 埋点上报 |

**改造前**：前端要处理十几种 LangGraph 原生事件，代码脆弱。
**改造后**：前端只关心六种，`agent_executor.py` 承担所有翻译工作。

### 2.2 上下文注入（scope 检测下沉）

最近的一次典型重构：

```
提交：refactor(scope): 拒绝渲染改为降级全量渲染 + basicInfo 嵌套容错 + 英文关键字中文化
提交：refactor: scope检测逻辑迁移到工具层，修复agent_executor层注入无效问题
```

**问题**：原本 scope 检测放在 `agent_executor` 层，但此时 tool_call 参数已经被 LangGraph 序列化过一次，注入无效。

**改造**：把检测下沉到工具层（`app/tools/resume_sidebar/pipeline.py`），执行器只做透明转发。这是"分层职责"的一次深度校准。

### 2.3 上下文裁剪

```
提交：blueclaw_chat增加裁剪和日志
提交：语音上下文裁剪
```

引入 `_MAX_MEMORY_CHARS = 50000` 上限：
- 超限时按"最近优先"截断历史 message
- system prompt 永远不被截断
- 截断前后打日志，便于诊断

### 2.4 recursion 与兜底

- `_RECURSION_LIMIT = 25` 硬上限，防止工具循环调用
- 兜底 v4 pro 模型：主模型报错时自动降级：
  ```
  提交：增加兜底v4 pro模型
  ```
- `_TOOL_RESULT_PREVIEW = 4000` 字符：工具返回过长时前端仅展示摘要，全量落日志

### 2.5 埋点闭环

- usage_tokens 上报（见 [`06_observability_and_telemetry.md`](./06_observability_and_telemetry.md)）
- deeplink 与主 Agent task_id 同步
- LLM 调用工具展示（新特性）：
  ```
  提交：增加llm调用工具展示
  ```

### 2.6 断连策略

```
提交：增加断开时长
提交：blueclaw infra增加header
```

- 空闲超时从 60s 提升到合理值
- BlueClaw 基础设施层增加 header 透传，便于云端路由

---

## 三、`main.py` 47 次改动的语义分布

| 类别 | 次数 | 代表提交 |
|------|-----|---------|
| WebSocket 事件流 | ~15 | `voice-session接口增加日志` |
| 字段兼容与容错 | ~10 | `简化上传分析url校验`、`fix(scope): basicInfo 嵌套容错` |
| 埋点 | ~8 | `增加语音埋点上报` |
| 新端点 | ~6 | `feat(voice-session): 主 Agent session_id 透传` |
| 稳定性 | ~8 | `修复乱码`、`规范自创名称` |

---

## 四、量化成果

| 指标 | 数值 |
|------|------|
| `agent_executor.py` 修改次数 | 45 |
| `main.py` 修改次数 | 47 |
| `agent.py` 修改次数 | 8 |
| 事件类型统一化 | 十几种 → 6 种 |
| recursion 保护 | 无 → limit=25 |
| 上下文裁剪 | 无 → 50k 上限 + 日志 |
| 模型兜底 | 无 → v4 pro 兜底 |

---

## 五、相关文档

- `../03_modules/12_module_agent_core.md` - Agent 核心模块
- `06_observability_and_telemetry.md` - 埋点细节
- `09_reliability_fallback.md` - 兜底策略

---

## 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|---------|
| v1.0 | 2026-08-10 | 初版 |
