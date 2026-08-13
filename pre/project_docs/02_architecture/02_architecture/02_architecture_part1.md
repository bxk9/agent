# 02 · 整体架构

## 1. 分层视图（Big Picture）

```
┌───────────────────────────────────────────────────────────────────────┐
│  客户端                                                                │
│   ├─ Claw 前端 SDK（面试 App / Web）        ─┐                         │
│   └─ 浏览器 MediaRecorder（语音面试）        │                         │
└──────────────────┬──────────────────────────┬──────────────────────────┘
                   │ WebSocket                │ WebSocket
                   │ Envelope + JSON-RPC      │ 二进制音频 + JSON 事件
                   ▼                          ▼
┌───────────────────────────────────────────────────────────────────────┐
│  接入层  (app/main.py — FastAPI)                                       │
│   ├─ /blueclaw/core   → claw_protocol.server._claw_ws_handler          │
│   ├─ /ws/interview    → voice.interview_ws.handle                      │
│   ├─ /voice           → 静态 H5 页面                                    │
│   └─ /health          → 健康检查                                        │
└──────────────────┬──────────────────────────┬──────────────────────────┘
                   ▼                          ▼
┌───────────────────────────────────────┐  ┌─────────────────────────────┐
│  协议层 (app/claw_protocol)            │  │  语音链路 (app/voice)         │
│   ├─ envelope.py  Protobuf 编解码      │  │   ├─ 双向 WSS 桥接 vivo       │
│   ├─ jsonrpc.py   send / recv        │  │   ├─ session_events           │
│   ├─ task_store   Ephemeral 任务表     │  │   └─ context_builder          │
│   └─ task_updater 事件回推            │  └─────────────────────────────┘
└──────────────────┬────────────────────┘
                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│  Executor  (app/agent_executor.py)                                     │
│    A2A / Claw 协议 ↔ Agent 事件流 的适配器                              │
└──────────────────┬────────────────────────────────────────────────────┘
                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│  Agent 核心 (app/agent.py)                                             │
│    LangGraph create_react_agent + MemorySaver                          │
│    thread_id = context_id （同一 A2A 上下文共享记忆）                    │
│    事件：token / tool_use / tool_result / tool_error / final / llm_usage │
└─────┬─────────────────┬──────────────────┬────────────────────────────┘
      ▼                 ▼                  ▼
┌──────────┐   ┌────────────────┐   ┌──────────────────┐
│ Skills   │   │ Tools (30+)    │   │ LLM 工厂         │
│  *.md    │   │ @tool 函数     │   │ vivo/blueclaw/   │
│ _loader  │   │ resume/voice/  │   │ google/openai    │
│ 组装 SP   │   │ search/…       │   │                  │
└──────────┘   └────┬───────────┘   └──────────────────┘
                    ▼
        ┌───────────────────────────────────┐
        │ 存储 & 外部服务                    │
        │  ├─ BlueClaw VFS  (app/vfs)       │
        │  ├─ memory/*  索引 & 素材库        │
        │  ├─ 搜索：Volc / 通用引擎          │
        │  └─ 文档解析：doc_agent            │
        └───────────────────────────────────┘
```

## 2. 分层职责（自上而下）

| 层 | 位置 | 职责 | 关键设计 |
|----|------|------|---------|
| **接入层** | `app/main.py` | FastAPI 生命周期、路由分发、启动/关停钩子 | 单端口多路由，`_startup_task_store_cleanup` 定期清理，`_shutdown_close_ws_connections` 优雅退出 |
| **协议层** | `app/claw_protocol/` | Envelope 编解码、JSON-RPC 收发、任务表、事件回推 | JSON-RPC 承载于 Protobuf Envelope；`TaskStore` 是短时任务缓存 |
| **Executor** | `app/agent_executor.py` | 把 A2A `SendMessage` 请求翻译为 Agent 输入；把 Agent 事件翻译为 `Task.update` / `Message` 回推 | 屏蔽协议差异，让 Agent 层与协议无关 |
| **Agent 核心** | `app/agent.py` | 主循环：调 LLM → 触发工具 → 汇聚事件；记忆管理；上下文裁剪；异常兜底 | LangGraph + MemorySaver；`thread_id=context_id`；`_MAX_MEMORY_CHARS=50000` 裁剪；孤立 tool_calls 清理；幽灵回显防护 |
| **Skill 层** | `app/skills/*.md` | 决定"这是哪个技能"及系统提示词 | Markdown 即 Prompt；`_loader.py` 扫描组装 |
| **Tool 层** | `app/tools/*.py` | 每个业务能力一个 `@tool` 函数 | 输入 Pydantic 校验；输出结构化 JSON；副作用（写 VFS/索引）由工具自行完成 |
| **LLM 层** | `app/llm/` | 屏蔽模型差异，返回统一的 `BaseChatModel` | 工厂 `build_chat_model()`；vivo 走 HMAC；`test_max_tokens.py` 侧信道诊断 |
| **存储/资源层** | `app/vfs/`, `memory/` | VFS 抽象；索引/素材/AI 标记 JSON | 用户中心化路径 `users/{uid}/...`；`file_id` 为跨模块引用凭据 |
| **旁路能力** | `app/voice/`, `app/resume_pipeline/` | 语音双工链路 / 简历离线视觉解析 | 与主 Agent 解耦，独立生命周期 |

## 3. 一次典型请求的生命周期（文字面试）

```
① 前端 WebSocket 连 /blueclaw/core
      │ 发送 Envelope: Envelope{payload = JSON-RPC{method: SendMessage, params: {message, context_id}}}
      ▼
② claw_protocol.server._claw_ws_handler
      解包 Envelope → jsonrpc.recv → dispatch("SendMessage")
      ▼
③ agent_executor.SendMessage
      · 从 message 提取 user_id / context_id / 附件（如 file_id）
      · 构造 Agent 输入 {messages=[HumanMessage(...)], thread_id=context_id, user_id, ...}
      · 打开事件流管道
      ▼
④ agent.InterviewAgent.stream(...)
      LangGraph 主循环：
        (a) 加载/回放 MemorySaver 中 thread_id 的历史
        (b) 组装 system prompt（skills/_loader.py）
        (c) 调 build_chat_model() 的 LLM
        (d) 若 LLM 返回 tool_calls：
              · 发 tool_use 事件
              · 执行 @tool 函数（如 resume_scope / master_profile_tool / search）
              · 发 tool_result（预览截断 4000 chars）
              · 回喂给 LLM
        (e) 若产生 token 流：发 token 事件（前端逐字渲染）
        (f) 最终 final 事件 + llm_usage 事件（用量统计）
      ▼
⑤ agent_executor 把事件翻译为 Task.update / Message，通过 task_updater 回推
      ▼
⑥ claw_protocol.jsonrpc.send → Envelope 编码 → WebSocket 发回前端
```

## 4. 事件模型（前端能看到什么）

Agent 主循环产出的六类事件，是**整个系统对外承诺的稳定契约**：

| 事件 | 语义 | 前端典型渲染 |
|------|------|------------|
| `token` | LLM 流式吐字 | 逐字打印气泡 |
| `tool_use` | Agent 决定调用工具 | 显示 "正在检索…" / "正在生成简历…" 状态卡 |
| `tool_result` | 工具返回（预览截断 4000 chars） | 状态卡收起，落地卡片（附件/链接） |
| `tool_error` | 工具抛错 | 红色提示 + 建议 |
| `final` | 本轮响应完成 | 结束气泡，允许下一轮输入 |
| `llm_usage` | token 用量 | 通常仅埋点，不上屏 |

## 5. 关键调用链索引

以下调用链是排查线上问题最常用的"锚点"，详见根 `ARCHITECTURE.md` 与 `50_debugging_guide.md`。

1. **文字面试普通问答**：`ws → server → executor → agent.stream → LLM → token → ws`
2. **简历生成 10 步流水线**：`agent → resume_scope → resume_template_sidebar → resume_sidebar/pipeline → resume_export → vfs → resume_index`（细节见 `30_data_flow_resume.md`）
3. **AI 标记跨轮**：`agent → resume_generator.md prompt → LLM 输出 <<<...>>> → memory/ai_marks_store → 下一轮 fetch → prompt`
4. **错题本触发**：`agent → mock_interview_word.md → error_book tool → memory/error_book_index → VFS`
5. **语音链路**：`浏览器 → /ws/interview → interview_ws.handle → vivo_client → vivo /chat/stream → session_events → 前端`