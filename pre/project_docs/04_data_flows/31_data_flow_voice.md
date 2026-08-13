# 31 · 数据流 · 语音面试

## 全景图

```
┌── 浏览器 ─────────────────────────────────────────────┐
│  MediaRecorder → 音频分片（40-80ms PCM/opus）          │
│  WebSocket 客户端 → /ws/interview?session_id&user_id   │
└────────────────────┬─────────────────────────────────┘
                     │ WSS
                     ▼
┌── FastAPI /ws/interview ────────────────────────────┐
│  app/voice/interview_ws.handle(ws)                   │
│    1. _build_voice_session_data                     │
│    2. 建立 vivo_client 上行                          │
│    3. 双向 forward + 事件下推                        │
└──────────┬──────────────────────────┬──────────────┘
           │ 读                        │ 上行音频 + 下行 stt/llm
           ▼                          ▼
  MemorySaver / memory/*        vivo /chat/stream (WSS)
  · 简历索引最新版                （STT + LLM 一体化）
  · 素材库
  · 主 Agent 历史（相同 context_id）
```

## Step 1 · 连接建立

**前端**：`new WebSocket("wss://.../ws/interview?session_id=s_xxx&user_id=u_yyy")`

**后端**：`app/main.py` 路由 → `app/voice/interview_ws.handle(ws)`

## Step 2 · Session 数据装配

**函数**：`app/main.py::_build_voice_session_data(session_id, user_id)`

**读取**：
- `MemorySaver[context_id]` — 主 Agent 已有对话（若 session_id 关联到某个 context_id）
- `memory.resume_index.latest(user_id)` — 最新简历（含 file_id）
- `memory.master_profile.get_profile(user_id)` — 素材库
- 默认人格 `default_interviewer.md`

**产物**：`SessionData` dict，供 `context_builder` 与 `interview_prompts` 消费。

## Step 3 · Prompt 构造

**模块**：`app/voice/context_builder.py` + `interview_prompts.py`

**输出**：
- 面试官人格（角色、语气、风格）
- 候选人画像（姓名、目标岗位、简历要点、经历亮点）
- 面试策略提示（问什么、追问深度、时间控制）

作为 `system` 消息发往 vivo `/chat/stream`。

## Step 4 · 建立 vivo 上行

**模块**：`app/voice/vivo_client.py`

**动作**：
1. WSS 连接到 vivo `/chat/stream`
2. 发送 `session.create`（含 system prompt）
3. 进入音频接收循环

vivo 端**一体**完成 STT + LLM，回传两路增量：
- `stt_delta`：识别文本
- `llm_delta`：面试官回复文本

## Step 5 · 双向转发主循环

```python
async for frame in ws.iter_bytes_or_json():
    if isinstance(frame, bytes):
        await vivo.send_audio(frame)          # 上行音频
    elif frame["type"] == "end":
        await vivo.finalize()                 # 用户停顿信号
    elif frame["type"] == "barge_in":
        await vivo.cancel_current_llm()       # 用户打断

async for delta in vivo.stream():
    if delta.stt:
        await ws.send_json({"type": "stt_delta", "text": delta.stt})
    if delta.llm:
        await ws.send_json({"type": "llm_delta", "text": delta.llm})
```

## Step 6 · 会话事件

`app/voice/session_events.py` 定义了下推给前端的事件类型：

| type | 时机 | 载荷 |
|------|------|------|
| `session_started` | 建立成功 | 面试官名字 / 场景 |
| `stt_delta` | 每段识别文本 | `{text}` |
| `llm_delta` | 每段面试官回复 | `{text}` |
| `error` | 任何异常 | `{code, message}` |
| `session_ended` | 会话结束 | `{summary_file_id?}` |

## Step 7 · 会话结束落盘

- **累积**：整个会话的 `stt` + `llm` 文本行拼装为逐题问答记录
- **落 VFS**：`users/{uid}/voice_sessions/{sid}/record.txt` + `.md`
- **可选**：`audio.pcm`（若开启录音）
- **索引**：不建独立索引；主 Agent 触发时通过 session_id 直接读

## Step 8 · 主 Agent 后处理（可选）

会话结束后，前端可发起 `SendMessage`（走主 Agent）请求：
- **场景 A**：错题本判定 → `tools.voice_error_book_judge` → `error_book`
- **场景 B**：面试复盘 → `tools.review_report_tool`（读 record → 生成 HTML）
- **场景 C**：素材沉淀 → `tools.master_profile_tool`（把新经历落库）

**关键**：语音链路本身**不写主链路记忆**，全部由用户在语音结束后的**下一条文字消息**中触发主 Agent 完成沉淀。

## 关键失败点与降级

| 失败点 | 降级 |
|--------|-----|
| vivo 上行 WSS 断开 | 下推 `error` 事件，前端可自动重连；已识别文本保留 |
| session_data 读不到主 Agent 记忆 | 用空历史 + 简历兜底，不阻塞 |
| 音频分片过大/过小 | 前端合流/切分，服务器不缓冲 |
| 打断（barge-in）竞态 | 后端 `cancel_current_llm` 幂等；若 vivo 已 flush，可能有轻微多余输出 |

## 与主 Agent 记忆的边界

| 维度 | 语音链路 | 主 Agent |
|------|--------|---------|
| 读记忆 | ✅（构造 prompt） | ✅ |
| 写记忆 | ❌（会话结束只落 VFS record） | ✅ |
| 触发工具 | ❌（无 tool_calls 概念） | ✅ |
| 事件契约 | `stt_delta / llm_delta / ...` | `token / tool_use / ...` |

## 相关文档

- `17_module_voice.md` — 模块定位与文件清单
- `12_module_agent_core.md` — 主 Agent 记忆模型
- `50_debugging_guide.md` — 语音链路排错清单
