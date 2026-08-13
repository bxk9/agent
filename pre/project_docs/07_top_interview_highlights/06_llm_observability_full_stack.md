# 06 · LLM 全链路可观测：usage_tokens contextvar 修复 + trace_id 全链路

> **作者**：yitong × 司棋 · **场景**：LLM 调用与 Agent 长链路的成本 & 故障追溯

---

## 一句话摘要

面对**"日志散落多服务无法关联 + 异步流下 usage_tokens 丢失"**两大可观测性痛点，团队协作构建了 **"ctx_log 全链路上下文注入 + usage 显式挂载 stream 对象"** 的双管齐下方案，让 token 日志覆盖率从 ~30% 提升到 100%，故障定位时间从 30 分钟压缩到 2 分钟。

---

## 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"你有可观测性经验吗？"** | ctx_log + trace_id + usage_tokens 三件套 |
| **"LLM 服务怎么算成本？"** | usage_tokens 采集的具体实现和陷阱 |
| **"异步编程有哪些坑？"** | contextvar 跨 async task 传递问题 |
| **"故障排查怎么做？"** | 从"翻 20 服务日志"到"5 秒定位" |

**可回答的经典面试题**：
- LLM 服务的可观测性怎么建设？
- 分布式追踪（Tracing）有哪些方案？
- Python contextvar 和 threading.local 的区别？
- Token 成本监控怎么落地？

---

## 背景与问题定义

### 痛点 1：日志散落，跨服务无法关联

一次会话可能触达 5+ 微服务：
- 前端网关
- Agent Executor 主链
- LLM 网关（BlueClaw）
- VFS 文件服务
- Doc Agent（A2A）
- 复盘 Skill 后端

早期日志问题：
- 无统一 user_id / session_id / trace_id
- 时间戳附近 grep → 30+ 分钟才能定位
- 异步 stream 让顺序错乱

### 痛点 2：usage_tokens 静默丢失（司棋主修）

BlueClaw 网关流式返回 usage_tokens：
- 在 stream 的**最后一个 chunk** 才返回
- Python 用 `contextvars` 存储时——

```python
# 错误示范
usage_var.set(usage_from_chunk)  # 在 chunk handler 内（子协程）
...
# 主协程读取时
final_usage = usage_var.get()  # 拿不到！context 已切换
```

**结果**：token 日志覆盖率约 30%（大部分是 0），成本失去可观测。

---

## 方案演进与关键决策

### 方案 A（司棋主）：contextvar 修复 + 显式挂载

**根因**：contextvar 在 `asyncio.create_task()` 创建的子任务里独立复制，主任务修改子任务的 var 看不到。

**修复**：把 usage **显式挂载到 stream 对象**，而非 contextvar：

```python
class LLMStream:
    def __init__(self):
        self.usage = None  # 显式字段

    async def _read_chunks(self):
        async for chunk in self.raw:
            if chunk.usage:
                self.usage = chunk.usage  # 挂到 self
            yield chunk

# 主协程使用
async for c in stream:
    ...
# 流结束后，从 stream 对象直接读
final_usage = stream.usage  # 稳定可靠
```

**关键点**：不用共享变量，用**对象作为通信介质**。

### 方案 B（yitong 消费方）：token 数据的下游治理

作为 usage_tokens 的下游消费方，我做了 5 次相关迭代：
1. usage_tokens 上报字段命名统一
2. 缺失时的 fallback（避免下游 NPE）
3. 与 trace_id 绑定，串起"哪个用户/哪个会话/多少 token"
4. 分模型统计（BlueClaw 不同模型价格不同）
5. 与耗时数据关联，形成"成本 + 延迟"双维度

### 方案 C（ctx_log 全链路）

**核心机制**：基于 `contextvars` 的日志上下文自动注入

```python
# 请求入口
ctx_log.bind(user_id="A", session_id="S1", trace_id="T1")

# 全链路自动继承
logger.info("xxx")  # 自动加上 [user_id=A session_id=S1 trace_id=T1]
```

**三个绑定点**：

| 域 | 绑定字段 | 位置 |
|:---:|:---|:---|
| HTTP 入口 | user_id, session_id | web handler |
| A2A 调用 | trace_id | A2A executor |
| LLM stream | thread_id, request_id | blueclaw_chat._call_api |

### 关键决策：为什么 ctx_log 用 contextvars 而 usage 不用

- **ctx_log**：**读**多写少，请求入口 set 一次，全链路 get
- **usage_tokens**：**跨异步任务写**，contextvar 天然失败

这是"看似同样都是 contextvar 场景，但访问模式不同 → 方案不同"的经典案例。

---

## 算法/工程实现细节

### ctx_log 实现骨架

```python
from contextvars import ContextVar
from typing import Dict, Any

_ctx: ContextVar[Dict[str, Any]] = ContextVar("ctx", default={})

class CtxLog:
    def bind(self, **kwargs):
        current = _ctx.get().copy()
        current.update(kwargs)
        _ctx.set(current)

    def info(self, msg, **kwargs):
        merged = {**_ctx.get(), **kwargs}
        logger.info(f"{msg} | {merged}")

ctx_log = CtxLog()
```

**关键点**：
- `_ctx.get().copy()` 保护上层 dict 不被内层修改污染
- 每次 bind 产生新 dict → 异步 task 之间自然隔离

### usage 显式挂载 + trace_id 关联

```python
class BlueClawStream:
    def __init__(self, raw, trace_id):
        self.raw = raw
        self.trace_id = trace_id
        self.usage = None

    async def __aiter__(self):
        async for chunk in self.raw:
            if chunk.usage:
                self.usage = chunk.usage
                # 立即上报（同一协程内，可用 ctx_log）
                ctx_log.info("llm_usage",
                             trace_id=self.trace_id,
                             usage=chunk.usage)
            yield chunk.text
```

### 跨服务传递 trace_id

- HTTP 请求：`X-Trace-Id` header
- A2A 消息：`metadata.trace_id`
- Task Store：`task.trace_id` 字段

---

## 量化验证与效果

| 指标 | 治理前 | 治理后 |
|:---|---:|---:|
| Token 日志覆盖率 | ~30% | **100%** |
| 故障平均定位时间 | ~30 min | **~2 min** |
| 日志上下文完备率 | ~40% | **100%** |
| 跨服务串联能力 | 无 | **trace_id 全链** |
| 成本可观测粒度 | 服务级 | **用户/会话/请求级** |

### 典型排查案例

**故障**：用户 A 报"简历生成一半没了"

**治理前**：只知道时间 → 翻 5+ 服务日志 → 30 分钟定位

**治理后**：
1. 日志中心搜 `user_id=A` → 5 秒
2. 找到 trace_id → 关联全链路
3. 发现 doc_agent A2A 超时 → 5 秒定位根因
4. 已修复（参见 05 号文档）

---

## 方法论抽象与迁移

### 可观测性三件套

| 维度 | 关注点 |
|:---:|:---|
| **User 维度** | 定位到具体用户（user_id） |
| **Session 维度** | 定位到具体会话（session_id） |
| **Request 维度** | 定位到具体请求（trace_id / request_id） |

**原则**：**任何一行日志都能反向定位到用户 / 会话 / 请求**。

### contextvars vs 对象挂载：如何选择

| 特征 | 选 contextvars | 选对象挂载 |
|:---|:---:|:---:|
| 读多写少 | ✅ | ❌ |
| 跨异步 task 写 | ❌ | ✅ |
| 生命周期跨越协程 | ✅ | 依情况 |
| 需要 typed 字段 | ❌ | ✅ |

**血泪教训**：`contextvars.set()` 在子 task 修改，主 task 读**必然**拿不到——这是 Python 异步的隐藏陷阱。

### 可迁移场景

- **任何 LLM 应用**：usage_tokens 采集通用问题
- **任何微服务**：trace_id 传播是标配
- **异步流处理**：对象挂载模式适用于任何"生成器最后一个 chunk 才有关键信息"的场景

---

## 关联提交

| 日期 | 作者 | Commit |
|:---:|:---|:---|
| 07-21 | 司棋 | feat(doc_agent): 日志改用 ctx_log 绑定 session_id/user_id |
| 07-29 | 司棋 | fix(logging): 补全 Agent stream 结束日志的 thread_id |
| 08-05 | 司棋 | fix(token): usage_tokens contextvar 跨异步任务传递 |
| 08-05 | 司棋 | fix(logging): token 统计日志绑定 trace_id |
| 06-08 ~ 08-上旬 | yitong | usage_tokens 5 次下游迭代（详见 06_workload_showcase 06 号文档） |

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |
