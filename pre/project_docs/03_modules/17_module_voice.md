# 17 · 模块 · 语音面试 `app/voice/`

## 1. 模块定位

语音面试是主 Agent 的**旁路子系统**：走独立 WebSocket 端点 `/ws/interview`，采用二进制音频 + JSON 事件的低延迟协议，实时桥接 vivo `/chat/stream` 端点。它**共享**主 Agent 的记忆（MemorySaver）与素材库（VFS），但**不复用** LangGraph 主循环。

一句话：**语音要低延迟，所以另起一路，但读取主链路记忆**。

## 2. 文件清单

| 文件 | 职责 |
|------|------|
| `interview_ws.py` | `/ws/interview` 主处理器：接收音频、拼装事件、桥接 vivo、下推转写与回复 |
| `vivo_client.py` | vivo `/chat/stream` HTTP/WSS 客户端（专用，支持流式转写 + LLM 一体） |
| `session_events.py` | 语音会话事件：`session_started` / `stt_delta` / `llm_delta` / `error` / `end` |
| `context_builder.py` | 从主 Agent 记忆 + 简历 + 素材库构造语音面试上下文 |
| `interview_prompts.py` | 语音面试 prompt 模板（不同角色/风格） |
| `default_interviewer.md` | 默认面试官人格设定 |
| `mock_context.py` / `mock_resume.py` | 本地开发用的假上下文 |
| `test_voice_ws.py` | 端到端语音 ws 测试脚本 |
| `README.md` | 模块 README |

## 3. 对外契约

### 端点
- **WebSocket**：`/ws/interview?session_id=...&user_id=...`
- **H5 页面**：`/voice`（浏览器端 MediaRecorder + WebSocket 客户端）

### 帧类型（前 ↔ 后）

| 方向 | 类型 | 内容 |
|------|------|------|
| 前 → 后 | 二进制 | PCM/opus 音频分片 |
| 前 → 后 | JSON | `{type: "start"\|"end"\|"barge_in", ...}` |
| 后 → 前 | JSON | `{type: "stt_delta", text}` |
| 后 → 前 | JSON | `{type: "llm_delta", text}` |
| 后 → 前 | JSON | `{type: "session_started" \| "session_ended" \| "error", ...}` |

### Session 初始化数据

由 `app/main.py` 里的 `_build_voice_session_data` 装配：

```python
{
  "user_id": ...,
  "history": [...],        # 来自主 Agent MemorySaver（相同 context_id）
  "resume_summary": {...}, # 来自 memory.resume_index 最新版
  "master_profile": {...}, # 来自 memory.master_profile
  "interviewer": "default" # 或指定人格
}
```

## 4. 核心设计理念（模块级）

1. **独立协议 vs 共享数据**  
   数据面（PCM + 流式往返）与主 Agent 的控制面差异太大，强融合会牺牲延迟。选择：协议独立、**数据源共用**（记忆 + 简历 + 素材）。

2. **vivo 一体化 STT+LLM**  
   `vivo /chat/stream` 直接接受音频、输出 STT + LLM 双流。省掉单独 STT 服务的一跳，大幅降低 TTFT。

3. **`context_builder` 是唯一"记忆桥梁"**  
   语音端**只读**主 Agent 的记忆，不写回；写回走 `voice_record_tool` / `voice_error_book_judge` 等主链路工具，在语音结束后由主 Agent 触发。

4. **人格 md 化**  
   `default_interviewer.md` 与主 Agent 的 skills 一样：产品/运营改文件，不改代码。

5. **可注入 mock**  
   `mock_context.py` / `mock_resume.py` 让本地无网/无用户数据也能调；`test_voice_ws.py` 是端到端探针。

## 5. 典型调用链

```
浏览器 MediaRecorder
  ├─ (ws.send) start {session_id}
  ├─ (ws.send) audio_chunk × N (binary)
  └─ (ws.send) end
       ↓
interview_ws.handle(ws):
  1. session_data = _build_voice_session_data(session_id, user_id)
     · 读 MemorySaver[context_id]
     · 读 memory.resume_index.latest(uid)
     · 读 memory.master_profile.get_profile(uid)
  2. prompts = interview_prompts.build(session_data, interviewer_md)
  3. vivo = vivo_client.connect()
     · 发 system prompt
  4. loop:
       frame = await ws.receive()
       if binary: vivo.send_audio(frame)
       if json.end: vivo.finalize()
       async for delta in vivo.stream():
           if delta.stt: ws.send_json({"type": "stt_delta", ...})
           if delta.llm: ws.send_json({"type": "llm_delta", ...})
  5. on close: 落 voice_sessions/{sid}/record.txt (VFS)
```

## 6. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增面试官人格 | 新建 `xxx_interviewer.md`；前端选择时传 `interviewer=xxx` |
| 录音落盘 | 在 `interview_ws` 里累加 PCM，会话结束时 `vfs.put_bytes(voice_sessions/{sid}/audio.pcm)` |
| 支持打断（barge-in） | 前端发 `{type: "barge_in"}`；后端 `vivo_client.cancel_current_llm()` |
| 换 STT/LLM 供应商 | 复制 `vivo_client.py` 写 `xxx_client.py`；`interview_ws` 加分支或工厂 |

**易踩坑**：
- 语音 WS 断开时**必须**主动关闭 vivo 上游连接，否则 fd 泄漏。
- `context_builder` 若无法读到主 Agent 记忆（例如 context_id 不匹配），必须**优雅降级**为空历史 + 简历兜底，而不是抛错。
- 音频分片过小（<20ms）会增加往返开销；过大（>200ms）损伤感知延迟。默认 40-80ms。

## 7. 与主 Agent 的边界

| 维度 | 主 Agent | 语音链路 |
|------|---------|---------|
| 协议 | Claw / Envelope / JSON-RPC | 直接 WebSocket |
| 大脑 | LangGraph + `build_chat_model()` | vivo `/chat/stream` 单一供应 |
| 记忆读 | MemorySaver（自己写） | ← 只读 MemorySaver + memory/* |
| 记忆写 | MemorySaver + memory/* | 结束时落 VFS 记录，通过主 Agent 工具沉淀 |
| Prompt | `skills/*.md` | `default_interviewer.md` + `interview_prompts.py` |

## 8. 相关文档

- `31_data_flow_voice.md` — 数据流细节
- `50_debugging_guide.md` — 语音链路排错清单
