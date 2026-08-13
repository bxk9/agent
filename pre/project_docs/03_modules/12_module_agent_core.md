# 12 · 模块 · Agent 核心 `app/agent.py` + `app/agent_executor.py`

## 1. 模块定位

Agent 核心是整个系统的**大脑**：
- `agent_executor.py`：协议 ↔ Agent 事件流的**适配器**（外部形状 → 内部输入 / 内部事件 → 外部通知）；
- `agent.py`：LangGraph ReAct 主循环、记忆管理、上下文裁剪、事件发射、异常兜底。

## 2. 文件清单

| 文件 | 职责 |
|------|------|
| `agent.py` | `InterviewAgent` 类；`stream(...)` 主入口，产出六类事件；上下文裁剪、孤立 tool_calls 清理、幽灵回显防护、TTFT 诊断 |
| `agent_executor.py` | 把 JSON-RPC `SendMessage` 参数 → Agent 输入；把 Agent 事件 → `Task.update` / `Message`；处理 `CancelTask` |

## 3. 对外契约

### 3.1 `InterviewAgent.stream()`

```python
async for event in agent.stream(
    user_id: str,
    context_id: str,        # A2A 上下文 → LangGraph thread_id
    messages: list[BaseMessage],
    skill: str = "auto",    # 可选：强制某技能
    extra_context: dict = None,  # 简历附件、语音 session 信息
):
    # event = {"type": <one_of_six>, "payload": {...}}
```

### 3.2 六类事件（严格稳定契约）

| type | payload 核心字段 | 何时产出 |
|------|----------------|---------|
| `token` | `text: str` | LLM 每流出一段增量 |
| `tool_use` | `name`, `args`, `tool_call_id` | LLM 决定调用工具 |
| `tool_result` | `name`, `tool_call_id`, `content_preview`（≤4000 chars） | 工具正常返回 |
| `tool_error` | `name`, `tool_call_id`, `error` | 工具抛异常 |
| `final` | `text`, `finish_reason` | 本轮 LLM 决定不再调用工具 |
| `llm_usage` | `input_tokens`, `output_tokens`, `total_tokens`, `model` | 每次 LLM 调用完成 |

### 3.3 关键常量（可调）

```python
_MAX_MEMORY_CHARS   = 50000    # 历史消息裁剪阈值（按字符）
_RECURSION_LIMIT    = 25       # LangGraph 递归上限（工具轮次上限）
_TOOL_RESULT_PREVIEW = 4000    # tool_result 事件里回传前端的预览截断
```

## 4. 核心设计理念（模块级）

### 4.1 `thread_id = context_id` 是记忆的锚
- LangGraph `MemorySaver` 用 `thread_id` 索引 checkpoint；
- A2A 协议的 `context_id` 表示"同一会话"；
- 两者绑定，天然实现"同一会话共享记忆、不同会话隔离"。

### 4.2 上下文裁剪：按字符不按 token
- 每轮开始前统计历史消息总字符数，超过 `_MAX_MEMORY_CHARS` 从头截断（保留最新）；
- 选择**字符**而非**token**：
  - 快（不需要分词器）；
  - 稳（跨模型一致）；
  - 换来的精度损失可接受（因为阈值本就保守）。

### 4.3 孤立 tool_calls 清理
- LangGraph 状态回放时，可能出现 `AIMessage(tool_calls=[...])` 但对应 `ToolMessage` 缺失（上次执行中断）；
- 主循环开头会扫描历史，成对不完整的直接丢弃，防止 LLM 报错 "unmatched tool_call_id"。

### 4.4 幽灵回显防护
- 某些模型偶尔"回显"上一条 tool_result 内容当作新回复；
- 通过对比 `final.text` 与最近 tool_result 的哈希/前缀，命中则忽略并重发一次简短提示，避免用户看到重复内容。

### 4.5 TTFT 诊断
- 记录"用户消息进入 → 首个 token 事件"耗时（Time-To-First-Token）；
- 超阈值打日志，便于定位网关抖动 vs. 工具卡住。

### 4.6 Executor 是适配器，不是逻辑层
- `agent_executor` 不放业务判断，只做"翻译"；
- 未来若加 REST 接口，只需再写一个 executor，Agent 不动。

## 5. 典型调用链

```
Envelope (WS)
  → jsonrpc.recv → SendMessage(params)
    → agent_executor.SendMessage(params, updater)
        · extract user_id / context_id / attachments
        · build_messages()  # 把 A2A Message 拼成 LangChain BaseMessage
        · async for ev in InterviewAgent.stream(...):
              updater.emit(ev)  # → Task.update 通知
        · updater.finalize()    # → JSON-RPC response
```

Agent 内部循环（简化）：

```
stream():
  system_prompt = skills._loader.build(skill, extra_context)
  memory = memsaver.get(context_id) or []
  memory = trim_by_chars(memory, _MAX_MEMORY_CHARS)
  memory = drop_orphan_tool_calls(memory)

  graph = create_react_agent(llm, tools, checkpointer=memsaver)
  async for step in graph.astream(input, thread_id=context_id, recursion_limit=25):
      if step is LLM chunk:  emit(token)
      if step is tool_call:  emit(tool_use)
      if step is tool_msg:   emit(tool_result | tool_error)
      if step is final:      emit(final); emit(llm_usage)
```

## 6. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增技能 | 在 `app/skills/` 加 md；在 executor 或 skill_loader 中把它加入"可选技能表"；无需改 agent.py |
| 新增工具 | 在 `app/tools/` 写 `@tool` 函数；在 `_agent_tools_for(skill)` 白名单里注册即可 |
| 需要"计划模式" | 建议在 agent.py 加事件 `plan`，但**保持既有六类事件不变**（原则 6） |
| 换 checkpointer（如落 Redis） | 只改 `agent.py` 里的 `MemorySaver` 构造；其他文件不动 |
| 调试单条消息 | 直接 `await agent.stream(user_id, context_id, [HumanMessage("...")])` 打印事件；不需要拉 WebSocket |

**易踩坑**：
- **千万不要**在工具函数里再 `await agent.stream(...)` 造成递归；工具是叶子节点。
- 若历史中包含大文本（如粘贴了整段 JD），字符裁剪可能把关键系统前缀也截掉——建议把大文本落 VFS 换成 `file_id`。
- `MemorySaver` 是**内存**的，多副本部署时需要**粘性会话**（同一 context_id 落同一进程）。

## 7. 事件消费者速查

| 消费者 | 关心的事件 |
|--------|-----------|
| Claw 前端 | `token`（打字机）、`tool_use/result`（状态卡）、`final`（结束） |
| 埋点/监控 | `llm_usage`、`tool_error`、TTFT 日志 |
| 语音端 | 通常不复用 Agent 事件（走独立链路），但 `_extract_history_and_resume` 会**读取** MemorySaver 拿历史 |
