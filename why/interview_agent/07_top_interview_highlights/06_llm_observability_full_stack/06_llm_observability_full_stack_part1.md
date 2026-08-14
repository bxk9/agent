# LLM 全链路可观测：usage_tokens contextvar 修复 + trace_id 全链路 - 面试亮点

> **核心价值**：从 07-30 yitong 对 usage-tokens 的"一天五连修"出发，到司棋侧 token 统计三连修与 ctx_log 基础设施建设，两条线在 08-05 汇合成完整的 LLM 全链路可观测体系——trace_id 贯穿、token/耗时请求级汇总、跨线程上下文安全传递，上线一天内即定位 150 分钟级事故。

---

## 1. 核心概览（原文档保留部分）

### 1.1 一句话摘要

token 统计这个"看起来简单"的功能，实际踩穿了**异步上下文丢失、跨线程传递断裂、埋点口径不一**三个深坑——yitong 一天五连修 usage-tokens、司棋两天三连修 token 统计，最终放弃 contextvar 改用**模块级 FIFO 字典**，并以 trace_id/tenant/user 三元组打通 VFS/LLM/Skill 全链路日志，让"一次请求花了多少 token、慢在哪一段"第一次可量化。

### 1.2 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"LLM 应用的成本监控怎么做？"** | 请求级 token 汇总的完整建设与踩坑 |
| **"Python 异步/线程混合场景的状态传递"** | contextvar 跨线程失效的真实案例与 FIFO 字典解法 |
| **"分布式链路追踪"** | trace_id/tenant/user 三元组的全链路日志设计 |
| **"日志系统自身的可靠性"** | "ctx_log 内部防崩溃"——日志组件不能成为故障源 |

**可回答的经典面试题**：
- Python 的 contextvars 在 asyncio/线程池中的行为？
- 如何设计请求级的指标聚合？
- 链路追踪（tracing）的核心要素？
- 日志系统的容错设计？

### 1.3 方案演进与关键决策

**演进时间线**（git 证据，双线汇合）：

```
yitong 线（usage 埋点）：
  07-28 6c2730f/a2fa6f8 增加语音埋点上报
  07-30 a7e4583~2f55a8a 一天五连修 usage-tokens bug
  07-30 16a4dd7 fix usage bug
  08-02 c201588 语音埋点上报增加日志
      ↓
司棋线（ctx_log 基础设施）：
  07-29 01dfc2c 为 LLM/VFS/Skill 主链路补全 ctx_log 日志
  08-04 b215510/c669057 VFS 请求日志（trace_id/tenant/user）
  08-05 ed1c3b8 每次请求结束打印 LLM/工具耗时与 Token 汇总
  08-05 124a5b1 修复 token 为 0 + 合并单条日志
  08-05 95bf297 改用模块级 FIFO 字典（contextvar 跨线程失效）
  08-05 f3e2204 所有直连 VFS 的 HTTP 调用加日志 + ctx_log 防崩溃
      ↓
汇合（08-05）：三位开发者同日推进埋点 → 可观测成为团队级共识
价值验证（08-06）：08bcac0 观测上线次日即定位 150 分钟级事故
```

**关键决策 1：放弃 contextvar，改用模块级 FIFO 字典**

contextvar 在 run_in_executor 线程切换处丢失 → 统计为 0。模块级字典以 request_id 显式存取，FIFO 限容防泄漏。

**关键决策 2：token 汇总合并为单条日志**

分散日志在高并发下交错不可读，一次请求的所有消耗必须聚合成单条汇总。

**关键决策 3：日志组件自身防崩溃**

ctx_log 内部异常绝不能拖垮业务——日志写失败静默降级。

**淘汰的方案**：

| 淘汰方案 | 淘汰原因 |
|:---|:---|
| **坚持 contextvar** | `95bf297` 明确放弃：跨线程失效，断点太多 |
| **显式传参** | 侵入性大，漏一个调用点就断链 |
| **外部 APM 探针** | 拿不到 LLM 语义数据（token/模型名），内网 IDC 部署受限 |

---

## 2. 项目背景与问题定义

### 2.1 业务场景

interview_agent 的一次请求跨越多个 LLM 与基础设施调用：

```
主 Agent LLM 调用 → 工具调用 → 子 Agent（doc_agent）LLM 调用 → VFS 读写
        ↓               ↓                ↓                    ↓
     token 消耗      耗时消耗         token 消耗            IO 耗时
```

**没有可观测时的困境**：
- 不知道一次请求消耗多少 token → 成本无法核算
- 不知道慢在哪一段 → 优化无从下手
- 用户报障"这次好慢/好贵" → 无法归因

### 2.2 失败模式分析

**token 统计的三个深坑**（全部有 git 证据）：

| 坑 | 表现 | 证据 |
|:---|:---|:---|
| **异步上下文丢失** | usage 数据在 async 任务切换中丢 | 07-30 五连修 |
| **跨线程传递断裂** | contextvar 在 executor 线程中失效 → 统计为 0 | `95bf297` `124a5b1` |
| **日志分散不可读** | 高并发下多条日志交错 | `124a5b1` 合并单条 |

### 2.3 优化目标

**核心问题**：如何让每次请求的 token 消耗与耗时"可汇总、可归因、可追溯"？

**量化目标**：
- 请求级 token 汇总准确率 100%（不再为 0）
- 全链路日志可按 trace_id 聚合
- 日志组件零业务影响（自身异常不拖垮请求）

---

## 3. 技术方案设计

### 3.1 核心思路

**全链路可观测的三个支柱**：

```
支柱 1：trace_id 贯穿
  一次请求的所有日志（LLM/VFS/Skill）带同一 trace_id → 可聚合
  
支柱 2：token/耗时统一汇总
  请求结束时输出单条汇总日志 → 成本可见
  
支柱 3：上下文安全传递
  跨线程/异步不丢数据 → 模块级 FIFO 字典
```

### 3.2 三支柱职责表

| 支柱 | 解决什么 | 实现 | 对应提交 |
|:---|:---|:---|:---|
| **trace_id 贯穿** | 日志归属到具体请求 | VFS 请求日志带 url/trace_id/tenant/user | `b215510` `c669057` |
| **统一汇总** | 请求级成本可见 | 请求结束打印 LLM/工具耗时与 Token 汇总 | `ed1c3b8` `124a5b1` |
| **安全传递** | 跨线程不丢 | 模块级 FIFO 字典（request_id 为键） | `95bf297` |

---

## 4. 核心实现细节

### 4.1 usage-tokens 的五连修（yitong 线）

**真实提交序列**（07-30 当天）：

```
a7e4583 → c711889 → 3df567d → 877a30c → 2f55a8a   （fix usage-tokens bug × 5）
16a4dd7   （fix usage bug）
```

**修复模式分析**（合理推断）：
```
同一天、同一主题、6 次提交 = 修一个、冒一个
典型成因：异步上下文传递断点
  - asyncio 任务切换处 contextvar 丢失
  - 回调嵌套中统计值没传下去
  - 每修一处断点，暴露出下一个断点
验证周期长：token 统计要等真实 LLM 调用后才能看到对不对
  → 只能串行小步修
```

### 4.2 模块级 FIFO 字典（司棋线，最终方案）

**实现**（真实，commit `95bf297`）：

```python
from collections import OrderedDict

# 放弃 contextvar，改用模块级 FIFO 字典
_token_stats: OrderedDict = OrderedDict()  # key = request_id
_MAX_ENTRIES = 10000

def record_token_usage(request_id: str, model: str, tokens: int):
    """任意线程/协程都可安全调用"""
    entry = _token_stats.setdefault(request_id, {"total": 0, "models": {}})
    entry["total"] += tokens
    entry["models"][model] = entry["models"].get(model, 0) + tokens
    # FIFO 限容防内存泄漏
    while len(_token_stats) > _MAX_ENTRIES:
        _token_stats.popitem(last=False)

def flush_request_stats(request_id: str):
    """请求结束时汇总输出（ed1c3b8 + 124a5b1：单条日志）"""
    entry = _token_stats.pop(request_id, None)
    if entry:
        logger.info(f"request_summary trace_id={request_id} "
                    f"total_tokens={entry['total']} models={entry['models']}")
```

**为什么 contextvar 失败**：

```python
# 失败方案（95bf297 之前的实现）
_usage_var = contextvars.ContextVar("usage", default=0)

async def handle_request():
    _usage_var.set(0)
    # 主协程内正常
    await llm_call()                    # ✓ 能累加
    # 但工具调用走了线程池：
    await loop.run_in_executor(None, tool_call)
    #   ↑ tool_call 在线程池线程执行，contextvar 丢失 → 统计为 0
```

### 4.3 trace_id 全链路日志

**VFS 请求日志**（真实，commits `b215510`、`c669057`）：

```python
# 所有 VFS 接口加请求日志，字段：url/trace_id/tenant/user/body
def vfs_request(url, tenant, user, body, trace_id):
    logger.info(f"vfs_call url={url} trace_id={trace_id} "
                f"tenant={tenant} user={user}")
    resp = http_post(url, body)
    logger.info(f"vfs_resp trace_id={trace_id} status={resp.status}")
    return resp
```

**覆盖面三次扩大**（真实）：

```
b215510（08-04）："VFS 调用"加日志
    ↓ 发现还有遗漏
c669057（08-04）："所有 VFS 接口"加日志
    ↓ 还发现绕过客户端直连的
f3e2204（08-05）："所有直连 VFS 的 HTTP 调用"加日志 + ctx_log 防崩溃
```

### 4.4 ctx_log 防崩溃

**实现原则**（真实，commit `f3e2204`"ctx_log 内部防崩溃"）：

```python
def ctx_log(msg):
    """日志组件自己不能成为故障源"""
    try:
        _do_log(msg)
    except Exception:
        pass  # 静默降级，绝不抛出影响业务
```

**线程前缀修复**（真实，commit `41d47cf`，08-13）：

```
问题：BlueclawChat 日志在 run_in_executor 线程中丢失 session/user/task 前缀
原因：与 contextvar 同源——线程切换丢上下文
修复：executor 提交时显式携带前缀参数
教训：线程切换是日志上下文的头号杀手，会反复在不同模块出现
```

### 4.5 边界 case 处理

**Case 1：请求异常中断**
```
场景：请求中途崩溃，flush_request_stats 没被调用
处理：FIFO 限容兜底——残留条目随容量限制被挤出，不泄漏
```

**Case 2：高并发日志交错**
```
场景：多个请求同时输出统计
处理：单条汇总日志（124a5b1）——每请求一条，带 trace_id，不交错
```

**Case 3：日志组件异常**
```
场景：ctx_log 内部格式化报错
处理：防崩溃包裹（f3e2204）——静默降级，业务不受影响
```

---

## 5. 效果评估与优化

### 5.1 建设时间线（git 统计）

| 日期 | 事件 | 意义 |
|:---:|:---|:---|
| 07-30 | usage-tokens 一天五连修 | 异步上下文断点逐个清除 |
| 07-29 ~ 08-05 | ctx_log 主链路补全 → VFS 日志 → token 汇总 | 基础设施建成 |
| 08-05 | 三位开发者同日推进埋点 | 可观测成为团队共识 |
| 08-06 | `08bcac0` 定位 150 分钟级事故 | **观测上线一天即抓到重大事故** |

### 5.2 观测价值验证

```