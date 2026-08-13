# 05 · Agent A2A 桥接：静默超时的 deadline 语义修复与产物完整性保障

> **作者**：司棋 · **场景**：文档 Agent 通过 A2A 协议异步交付产物

---

## 一句话摘要

面对 A2A 协议下**"lastChunk=true 后仍有 artifactUpdate"**造成的产物丢失问题，我通过**deadline 语义重写（收到 lastChunk 不缩短、收到任意进度消息重置）**从根源修复；同时 07-27 完成 A2A 静默超时三 bug 修复，让 Doc Agent 从"能跑"稳定到"上线可用"。

---

## 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"你做过 Agent 系统吗？"** | A2A（Agent to Agent）协议、异步流控、产物完整性 |
| **"分布式协议怎么设计？"** | deadline / heartbeat / lastChunk 语义的深度理解 |
| **"讲一个你踩过最深的时序 bug"** | lastChunk 缩短 deadline 导致后续 artifact 丢失 |
| **"稳定性怎么保障？"** | 从"偶发故障"到"日志驱动的批量修复"（07-21 六连修） |

**可回答的经典面试题**：
- 异步流协议的完整性怎么保证？
- Agent 编排如何解决超时问题？
- 分布式系统的可观测性怎么做？
- Agent 生态（A2A / MCP / OpenAgent）的技术选型？

---

## 背景与问题定义

### 业务场景

Interview Agent 主链需要生成文档产物（简历、复盘报告），通过 **A2A 协议**调用独立部署的 **Doc Agent**：

```
主 Agent  ──A2A──▶  Doc Agent
   │                    │
   │                    │  1. 接收请求
   │◀── 进度消息 ───────│  2. 流式返回进度
   │◀── artifact ──────│  3. 上传产物到 VFS
   │◀── lastChunk ─────│  4. 结束标记
```

### 关键问题：产物"看似完整实则丢失"

**协议原设计**：
- 收到 `lastChunk=true` 表示"主流程结束"
- 客户端**缩短 deadline**（以为快结束了）

**实际情况**：
- Doc Agent 内部：`lastChunk` 是"文本生成结束"
- 之后还要：文件上传 → VFS 签发 → 返回最终 URL（可能 1-3 秒）

**故障链**：
```
lastChunk=true → 缩短 deadline → deadline 到期 → 关闭连接
     ↓
    但此时 URL 还没到，用户拿到空产物
```

**表现**：产物"偶尔丢失"，且用户无任何提示。

---

## 方案演进与关键决策

### 方案 A（原始设计，淘汰）：lastChunk 缩短 deadline

**假设**：lastChunk 之后无重要消息
**实际**：错误假设

### 方案 B（第一次修，07-21 #1）：移除缩短逻辑

```diff
- if last_chunk:
-     deadline = min(deadline, now() + SHORT_TIMEOUT)
```

**改进**：不再主动缩短
**遗留**：如果长时间无消息，仍会到期

### 方案 C（第二次修，07-21 #2）：进度消息重置 deadline

```python
def on_message(msg):
    # 收到任何进度消息 → 重置 deadline
    deadline = now() + FULL_TIMEOUT
    ...
```

**改进**：只要 Doc Agent 在活跃返回进度/artifact，就不断续期
**效果**：产物丢失率从"偶发"降为 0

### 关键决策：为什么不用心跳协议

**心跳方案**：Doc Agent 定期发 `heartbeat` 消息
- 优点：主动通知
- 缺点：（1）需要协议升级；（2）跨服务时序更复杂

**权衡**：本场景每个真实进度消息就是天然心跳，无需引入新语义。

---

## 07-27 A2A 静默超时三 bug（第二次深度攻坚）

### 三个 bug 是什么

`fix(doc_agent_client): 修复 A2A 静默超时导致产物丢失的三个 bug`

三个隐蔽的静默超时问题：
1. **socket 层 timeout 未透传**：底层 aiohttp 用了默认 timeout，覆盖了应用层 deadline
2. **stream reader 空读循环**：某些情况下 stream 返回 0 字节但不触发 EOF → 死循环等待
3. **cancel 后未清理 task_store**：客户端超时 cancel 后，服务端 task 状态未同步 → 幽灵 task

### 修复思路

- **对齐超时层次**：应用层 deadline 是唯一真理源，底层超时改为无限或极大值
- **空读检测**：连续 3 次 0 字节 → 主动关闭 stream
- **cancel 传播**：cancel 时通过 A2A 反向消息通知服务端清理

---

## 与 07-21 六连修的关系

同一天 07-21 六个 fix 提交（chenqian 05 号文档也提到）：

| # | 主题 | 与本文关联 |
|:---:|:---|:---|
| 1 | 移除 lastChunk 缩短 deadline | **本文重点** |
| 2 | 进度消息重置 deadline | **本文重点** |
| 3 | 进度文本保留换行 | UX 相关 |
| 4 | 原文件名日期不重复追加 | 与命名相关 |
| 5 | ctx_log 绑定 session_id/user_id | 与文档 06 关联 |
| 6 | 复合任务 file_url 参数路由 | 状态污染 |

**方法论**：**"同域集中攻坚 + 修 bug 顺手加可观测"**——修 #1/#2 时顺手加了 #5 的日志能力，为下次调试铺路。

---

## 算法/工程实现细节

### deadline 语义（核心 diff）

```python
class DocAgentStream:
    def __init__(self, timeout=180):
        self.deadline = time.time() + timeout
        self.timeout = timeout

    async def on_message(self, msg):
        # 关键：收到任何消息（包括 lastChunk 后的 artifactUpdate）→ 重置
        self.deadline = time.time() + self.timeout

        if msg.type == "progress":
            ...
        elif msg.type == "artifact":
            self.artifacts.append(msg)
        elif msg.type == "last_chunk":
            # 【关键】不再缩短 deadline
            self.text_done = True

    async def wait_until_all_artifacts(self):
        while True:
            if time.time() > self.deadline:
                break
            if self._all_expected_artifacts_arrived():
                break
            await asyncio.sleep(0.1)
```

### 静默检测

```python
async def read_stream(reader):
    empty_count = 0
    while True:
        chunk = await reader.read(4096)
        if not chunk:
            empty_count += 1
            if empty_count >= 3:
                raise ConnectionClosed("stream silent")
            continue
        empty_count = 0
        yield chunk
```

---

## 量化验证与效果

| 指标 | 治理前 | 治理后 |
|:---|:---|:---|
| 文档产物丢失率 | 偶发（周多起） | **0** |
| A2A 静默超时故障 | 每周 3-5 起 | **0** |
| 幽灵 task 数 | 累积 | **0**（cancel 传播后） |
| 上线可用性 | 需人工重试 | **稳定** |

---

## 方法论抽象与迁移

### 分布式协议设计三原则

1. **语义边界要明确**：`lastChunk` 是"文本结束"还是"整体结束"？必须写死
2. **超时要有唯一真理源**：应用层 deadline vs 底层 socket timeout，只能一个说了算
3. **cancel 要传播**：客户端超时不能只关自己，要通知对端清理

### 可迁移场景

| 场景 | 迁移点 |
|:---|:---|
| gRPC 流式接口 | deadline 传播（gRPC context） |
| SSE / WebSocket | 静默检测 + heartbeat |
| 微服务编排 | 上下游超时对齐（下游 timeout < 上游 timeout） |
| Agent 编排 | 产物完整性判据 |

### 反例警示

- **反例 1**：底层 socket timeout 用默认值 → 覆盖应用层 deadline
- **反例 2**：cancel 只在本地生效 → 服务端幽灵 task 堆积
- **反例 3**：把"文本结束"当"整体结束" → 产物丢失

---

## 关联提交

| 日期 | Commit |
|:---:|:---|
| 07-21 | fix(doc_agent): 移除 lastChunk 缩短 deadline 逻辑 |
| 07-21 | fix(doc_agent): 收到进度消息时重置 deadline |
| 07-27 | fix(doc_agent_client): 修复 A2A 静默超时导致产物丢失的三个 bug |

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |
