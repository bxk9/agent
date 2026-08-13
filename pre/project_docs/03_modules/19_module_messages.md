# 19 · 模块 · 消息协议 `messages/`

## 1. 模块定位

`messages/` 是**协议数据结构定义与编解码库**：包含 FlatBuffers 生成产物、Pydantic/自定义 Protocol 类、以及分析器。它被 `app/claw_protocol/` 底层消费，用来定义 Envelope 内 payload 的具体形态。

一句话：**协议层的"数据字典"**。

## 2. 文件清单

| 文件 / 目录 | 职责 |
|-----------|------|
| `protocol.py` | 通用消息协议定义（跨业务的基础消息类型） |
| `botchat_protocol.py` | BotChat 协议实现（对话消息、附件、引用） |
| `workflow_protocol.py` | 工作流协议实现（多步任务编排） |
| `msg_analyzer.py` | 消息分析器：类型识别 / 校验 / 转换 |
| `flat/` | FlatBuffers 生成产物子包 |
| `flat/ASR/` | 语音识别相关消息（若走 flatbuffers 通路） |
| `flat/AST/` | 抽象语法/结构类消息 |
| `flat/BATCH/` | 批量消息 |
| `flat/UPDATE/` | 增量更新消息（Task.update） |
| `flat/workflow/` | 工作流消息 |
| `flat/utils/` | FlatBuffers 通用工具 |
| `flatbuffers-25.2.10-*.whl` | FlatBuffers Python 运行时（wheel 打包，锁版本） |
| `pydantic-2.10.6-*.whl` | Pydantic wheel（锁版本，供部分离线场景） |

## 3. 对外契约

主要供 `app/claw_protocol/` 调用：

```python
from messages.protocol import BaseMessage
from messages.botchat_protocol import BotChatRequest, BotChatEvent
from messages.flat.UPDATE import TaskUpdate  # FlatBuffers 生成类
from messages.msg_analyzer import analyze

msg = analyze(raw_bytes)   # 返回结构化对象或错误
```

## 4. 核心设计理念（模块级）

1. **FlatBuffers 用于二进制热路径**  
   高频、需要零拷贝解析的消息（ASR 音频事件、批量更新）走 FlatBuffers；JSON 承载低频/复杂结构。

2. **Pydantic 用于业务语义层**  
   `botchat_protocol.py` / `workflow_protocol.py` 用 Pydantic 定义业务侧数据类，享受校验与序列化便利。

3. **`msg_analyzer` 是入口分派**  
   拿到未知字节流时先过 analyzer；由它决定"这是 FlatBuffers 还是 JSON、什么类型、是否合法"，避免 `claw_protocol/server.py` 里堆 if-else。

4. **wheel 锁定运行时**  
   FlatBuffers / Pydantic 用 wheel 内置，避免不同环境 pip 装出不同版本导致协议不兼容。

## 5. 典型调用链

```
ws.receive_bytes()  → envelope.decode()
  → payload_bytes
    → messages.msg_analyzer.analyze(payload_bytes)
        · 头字节判断格式
        · JSON → messages.botchat_protocol.BotChatRequest.parse_raw()
        · FlatBuffers → messages.flat.XXX.getRootAs...
    → 结构化对象
  → dispatch 到 agent_executor
```

回推方向：

```
agent_executor.emit(Task.update)
  → messages.flat.UPDATE.TaskUpdate.build(...)  # 或 JSON
  → envelope.encode()
  → ws.send_bytes()
```

## 6. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增业务消息类型 | 优先 Pydantic 版本（`xxx_protocol.py`）；只有热路径才生成 FlatBuffers |
| 修改 FlatBuffers schema | 修改 `.fbs`（外部维护）→ 重新生成 → 覆盖 `flat/` 目录；**保证向后兼容**（只加字段，不改 tag） |
| 前后端协议对齐 | 前端 SDK 需与后端使用**同版本 fbs**；建议在 CI 里生成两端 |
| 消息校验失败 | analyzer 返回 error，`claw_protocol.jsonrpc.send` 回 `-32600 Invalid Request` |

**易踩坑**：
- FlatBuffers 生成产物**不要手改**——下次 `flatc` 重新生成会覆盖。
- Pydantic v2 与 v1 的 `parse_obj` / `model_validate` API 不同；本项目统一用 v2。
- 前端 SDK 拿到未知 update 类型时应**优雅忽略**，不 crash（协议前向兼容原则）。

## 7. 与其他模块的关系

| 模块 | 使用方式 |
|------|--------|
| `app/claw_protocol/` | 直接依赖：解 envelope 后调 analyzer；发送前调消息类的 build/encode |
| `app/agent_executor.py` | 中层依赖：接收结构化消息、生成 Task.update |
| `app/voice/` | 语音链路目前**未**走此协议库（走独立 JSON schema） |
| `app/tools/doc_agent_client.py` | 复用 envelope 编解码调用远端 Doc Agent |
