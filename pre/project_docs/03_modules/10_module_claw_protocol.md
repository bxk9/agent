# 10 · 模块 · Claw 协议层 `app/claw_protocol/`

## 1. 模块定位

Claw 协议层是**唯一**知道"字节流长什么样"的模块。它把前端通过 WebSocket 发来的 **Protobuf Envelope + JSON-RPC 2.0** 报文，翻译为业务侧可以直接消费的 Python 事件/请求；反过来把 Agent 事件包装为 Envelope 回推。

一句话：**协议在此结束，业务在此开始**。

## 2. 文件清单

| 文件 | 职责 |
|------|------|
| `envelope.py` | Protobuf Envelope 的序列化 / 反序列化；把 `payload_bytes` 与元信息（type / correlation_id / timestamps）解耦 |
| `jsonrpc.py` | JSON-RPC 2.0 收发：`recv(request)` 解析、`send(response/notify)` 编码；错误码约定 |
| `server.py` | `_claw_ws_handler(websocket)` —— WebSocket 主循环：读 Envelope → 分派 method → 调 `agent_executor` → 回推事件 |
| `task_store.py` | 短时任务缓存 `TaskStore`（内存）：为异步长任务/取消/重放提供占位；`_startup_task_store_cleanup` 定期回收 |
| `task_updater.py` | 事件回推工具：把 Agent 六类事件翻译为 `Task.update` / `Message` 对应的 JSON-RPC 通知 |
| `__init__.py` | 对外仅导出 `_claw_ws_handler` 与常量 |

## 3. 对外契约

### 入站（前端 → 后端）
- WebSocket URL：`/blueclaw/core`
- 帧格式：二进制 Envelope；`payload` 内是 JSON-RPC Request
- 支持方法（示例）：
  - `SendMessage`：新一轮用户消息
  - `CancelTask`：取消进行中任务
  - `Ping`：心跳

### 出站（后端 → 前端）
- 单请求多通知模式：一个 `SendMessage` 会产出多个 `Task.update` 通知 + 一个最终响应
- 通知类型：由 `task_updater` 根据 Agent 事件生成
  - `token` → `Message.append`
  - `tool_use / tool_result / tool_error` → `Task.state_update`
  - `final` → `Task.completed` + JSON-RPC Response
  - `llm_usage` → `Task.metrics`

### 对内暴露
`server.py` 只依赖 `agent_executor.dispatch(method, params, task_updater)`；除此之外**不 import 任何 Agent 内部符号**。

## 4. 核心设计理念（模块级）

1. **Envelope 与 JSON-RPC 双层解耦**  
   Envelope 提供**传输元数据**（消息类型、幂等键、时间戳），JSON-RPC 提供**语义**。将来若需要在 Envelope 层加压缩/加密/多路复用，业务代码无感。

2. **任务表只存"活着"的任务**  
   `TaskStore` 是一个进程内 dict + TTL 回收，**不做**持久化。原因：Claw 前端已有自己的重连和任务追踪，后端只需保证"在线时可查、可取消"。

3. **协议错误不抛异常，落 JSON-RPC error**  
   所有协议层错误必须以 JSON-RPC 标准错误码回推（`-32600 Invalid Request` 等），业务错误则走 `tool_error` 事件。

4. **单文件 WebSocket 循环，避免过度框架化**  
   `_claw_ws_handler` 是一个显式的 `while True` 循环，容易读、容易加日志。故意不引入路由框架。

## 5. 典型调用链

```
浏览器 ws.send(envelope_bytes)
  → FastAPI /blueclaw/core WebSocketRoute
  → claw_protocol.server._claw_ws_handler
       loop:
         envelope = await ws.receive_bytes()
         req = envelope.decode(envelope)
         rpc = jsonrpc.recv(req.payload)
         match rpc.method:
           case "SendMessage":
             task = task_store.create(rpc.id, params)
             updater = task_updater.for_task(task, ws)
             await agent_executor.dispatch("SendMessage", rpc.params, updater)
             await task_store.finalize(task)
           case "CancelTask": ...
```

## 6. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增 JSON-RPC 方法 | 在 `agent_executor` 的 dispatch 表加入分支；`server.py` 无需改 |
| 新增事件类型 | 在 `task_updater` 加映射；同步在 `19_module_messages.md` 更新契约 |
| 修改 Envelope 结构 | **必须同时改前端 SDK**；建议以新字段可选的方式演进，不要重排字段 tag |
| 取消/中断 | 使用 `TaskStore.cancel(task_id)`，agent 循环通过检查 `updater.cancelled` 及时退出 |

**易踩坑**：
- 忘记 `await ws.close()` 会造成 fd 泄漏；`_shutdown_close_ws_connections` 已在 shutdown 钩子中收敛。
- `TaskStore` 是进程内，多副本部署时**不共享**——目前依赖前端做粘性会话（因为 A2A `context_id` 也需绑定同一进程的 MemorySaver）。

## 7. 与 `messages/` 的关系

Envelope / JSON-RPC 的**数据结构**由 `messages/*.fbs`（FlatBuffers）+ Protobuf 定义，见 `19_module_messages.md`。协议层 = 编解码实现；messages/ = 数据结构 Schema。
