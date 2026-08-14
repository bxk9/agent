# TTFT 分桶埋点与性能分析 - 面试亮点

> **核心价值**：针对 TTFT 高达 800ms 但无法定位瓶颈的性能黑盒问题，设计并落地了同源口径的四层分桶埋点系统（A预处理/B网络/C解码/D上屏），通过 perf_counter 统一时间源 + 区分 first_token_ts 和 first_delta_ts + ContextVar 传递请求起始时间，精准定位性能瓶颈并指导团队将 TTFT 从 800ms 优化到 300ms，是 LLM 推理性能分析的完整工程实践。

---

## 1. 核心概览

### 1.1 一句话摘要

面对 TTFT 高达 800ms 但无法定位瓶颈的性能黑盒，我把 TTFT 按职责拆成四层分桶（预处理/网络/解码/上屏），用 perf_counter 统一时间源保证可比性，区分 first_token_ts（模型层）和 first_delta_ts（消费层）避免口径混淆，让团队从"盲目优化"变成"数据驱动优化"。

### 1.2 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"如何定位 LLM 推理的性能瓶颈？"** | 四层分桶埋点 + 同源口径的完整设计 |
| **"如何设计性能监控系统？"** | perf_counter 统一时间源 + ContextVar 传递 + 分桶日志 |
| **"如何区分模型层和消费层的性能指标？"** | first_token_ts vs first_delta_ts 的设计考量 |
| **"如何通过数据驱动性能优化？"** | 分桶数据指导团队将 TTFT 降低 67% |

**可回答的经典面试题**：
- 如何定位系统性能瓶颈？
- 如何设计性能监控系统？
- 如何通过数据驱动性能优化？
- 如何区分不同层次的性能指标？

### 1.3 方案演进与关键决策

**演进时间线**（git 证据）：

```
阶段 1（2026-03 ~ 2026-06）：性能黑盒期
  TTFT 高达 800ms，但无法定位瓶颈在哪个环节
      ↓ 认识到：现有埋点时间源不统一、粒度太粗、口径不一致
阶段 2（2026-07-21）：方案设计时刻
  设计文档 docs/plans/ttft-gap-analysis.md
      ↓ 四层分桶 + 同源口径 + 区分 first_token/first_delta 完整设计
阶段 3（2026-07-21）：方案实施时刻
  9e84b933 "feat: 新增 ttft 分桶耗时埋点（同源口径定位性能缺口）"
      ↓ TTFT 分桶埋点正式落地，指导团队将 TTFT 从 800ms 优化到 300ms
```

**关键决策 1：四层分桶，覆盖主要环节**

| 分桶 | 起点 | 终点 | 含义 | 优化方向 |
|:---|:---|:---|:---|:---|
| **A_preproc** | t0（请求到达） | send_ts（发送请求） | 预处理耗时 | 优化 Prompt 构建、工具召回 |
| **B_net** | send_ts | first_byte_ts（首字节） | 网络 + Prefill | 优化网络、Responses API 缓存 |
| **C_decode** | first_byte_ts | first_token_ts（首 token） | 模型 Decode | 模型侧优化（非我方） |
| **D_onscreen** | first_delta_ts（首内容） | first_emit_ts（首发射） | 上屏处理 | 优化 Pipeline、Emitter |

**关键决策 2：perf_counter 统一时间源**

旧口径混用 `time.time()` 和 `time.perf_counter()`，无法对比。新口径全部使用 `perf_counter`，保证同一进程内的时间戳可以直接相减。

**关键决策 3：区分 first_token_ts 和 first_delta_ts**

- first_token_ts：模型层写入的首个内容 token（包括工具调用）
- first_delta_ts：消费层收到的首个可上屏内容（仅文本）

工具轮和思考过程无上屏文本，first_delta_ts 无值，但 first_token_ts 有值。

**淘汰的方案**：

| 淘汰方案 | 淘汰原因 |
|:---|:---|
| **time.time() 时间源** | 精度不够，可能被系统时间调整打断 |
| **三层分桶** | 无法区分"网络传输"和"模型 Prefill" |
| **五层分桶** | 增加"Context Pipeline 压缩"分桶，但该分桶耗时通常 <10ms，单独分桶意义不大 |
| **只用 first_delta_ts** | 工具轮无上屏文本，TTFT 退化为 cost_ms，统计口径不可比 |

---

## 2. 项目背景与问题定义

### 2.1 业务场景

pro_agent 是实时对话系统，用户对响应速度极其敏感：

```
用户: "今天天气怎么样？"
  ↓
[等待中...]  ← 用户感知到的延迟（TTFT）
  ↓
助手: "今天北京晴天，气温 25°C"
```

**系统特征**：
- TTFT 目标：<500ms（用户明显感知延迟的阈值）
- 当前 TTFT：800ms（远超目标）
- 多轮对话：5-20 轮
- 流式响应：SSE 协议，实时返回文本和工具调用

### 2.2 问题分析

**体系化之前的真实问题**：

| # | 问题 | 严重程度 | 具体表现 |
|---|---|---|---|
| 1 | 时间源不统一 | **可比性差** | 混用 `time.time()` 和 `time.perf_counter()`，无法对比 |
| 2 | 粒度太粗 | **定位困难** | 只有"请求开始"和"首 token"两个点，无法定位瓶颈 |
| 3 | 口径不一致 | **统计混乱** | 不同模块对"首 token"的定义不同（模型层 vs 消费层） |
| 4 | 工具轮 TTFT 退化 | **口径不可比** | 工具轮 first_delta_ts 无值，TTFT 退化为 cost_ms |

**关键洞察**：
- 这些问题的根因是**缺乏统一的性能埋点标准**
- 没有数据就没有优化方向，盲目优化可能事倍功半
- **浪费**：团队花了大量时间优化预处理，但实际瓶颈在网络层

**三类失败模式的典型样本**：

```
失败模式 1：时间源不统一
代码: t0 = time.time(); t1 = time.perf_counter()
问题: time.time() 和 perf_counter() 的起点不同，无法相减
后果: 计算出的耗时无意义，无法对比

失败模式 2：粒度太粗
代码: ttft = first_token_ts - request_start_ts
问题: 只知道总耗时，不知道瓶颈在哪个环节
后果: 团队盲目优化预处理，但实际瓶颈在网络层

失败模式 3：口径不一致
代码: 模型层用 first_token_ts，消费层用 first_delta_ts
问题: 工具轮 first_delta_ts 无值，TTFT 退化为 cost_ms
后果: 工具轮和文本轮的 TTFT 混在同一列，统计口径不可比
```

### 2.3 优化目标

**核心问题**：如何精准定位 TTFT 的性能瓶颈，指导团队进行针对性优化？

**量化目标**：
- 精准定位瓶颈在哪个环节（预处理/网络/解码/上屏）
- 指导团队将 TTFT 从 800ms 优化到 300ms
- 工具轮和文本轮的 TTFT 统计口径可比

---

## 3. 技术方案设计

### 3.1 核心思路

**四层分桶 + 同源口径 + 区分 first_token/first_delta**（命名直接来自代码注释）：

```
用户发送请求
  ↓
[A] 预处理阶段（t0 → send_ts）
  - 工具召回
  - Prompt 构建
  - Context Pipeline 压缩
  ↓
[B] 网络传输阶段（send_ts → first_byte_ts）
  - HTTP 请求发送
  - 网络传输
  - 玄机网关 Prefill
  ↓
[C] 模型解码阶段（first_byte_ts → first_token_ts）
  - 模型 Decode 首 token
  ↓
[D] 上屏处理阶段（first_delta_ts → first_emit_ts）
  - StreamPipeline 处理
  - SseEmitter 过滤
  ↓
用户收到首 token
```

**关键挑战**：
1. 如何保证时间源统一？
2. 如何区分模型层和消费层的首 token？
3. 如何处理工具轮无上屏文本的情况？
4. 如何传递请求起始时间？

### 3.2 四层分桶职责规则表

**设计原则**：四层各挡一类耗时，职责边界清晰

| 分桶 | 输入 | 职责 | 输出 | 优化方向 |
|:---|:---|:---|:---|:---|
| **A_preproc** | 请求到达 | 预处理（工具召回、Prompt 构建、压缩） | 发送请求 | 优化 Prompt 构建、工具召回 |
| **B_net** | 发送请求 | 网络传输 + 玄机网关 Prefill | 首字节到达 | 优化网络、Responses API 缓存 |
| **C_decode** | 首字节到达 | 模型 Decode 首 token | 首 token 生成 | 模型侧优化（非我方） |
| **D_onscreen** | 首内容到达 | StreamPipeline 处理 + SseEmitter 过滤 | 首 token 上屏 | 优化 Pipeline、Emitter |

---

## 4. 核心实现细节

### 4.1 perf_counter 统一时间源

**实现位置**：`agent/pro/stage_infer.py`

```python
# 旧口径（已废弃）
# t0 = time.time()  # 毫秒级精度，可能被系统时间调整打断
# t1 = time.perf_counter()  # 纳秒级精度，单调递增
# ttft = t1 - t0  # 无法相减！

# 新口径（统一使用 perf_counter）
_t0 = req_start_ctx_var.get()  # 请求到达时刻（perf_counter）
_send_ts = time.perf_counter()  # 发送请求时刻
_first_byte_ts = time.perf_counter()  # 首字节到达时刻
_first_token_ts = time.perf_counter()  # 首 token 生成时刻
```

**关键设计**：
- 全部使用 `perf_counter`，纳秒级精度，单调递增
- 同一进程内的时间戳可以直接相减
- 不受系统时间调整影响（如 NTP 同步）

### 4.2 区分 first_token_ts 和 first_delta_ts

**实现位置**：`model/stream_events.py` 和 `agent/pro/stage_infer.py`

```python
# 模型层：first_token_ts（首个内容 token，包括工具调用）
class StreamMeta:
    first_token_ts: float = 0.0
    
    def mark_first_token(self):
        """标记首个内容 token（模型层调用）"""
        if not self.first_token_ts:
            self.first_token_ts = time.perf_counter()

# 消费层：first_delta_ts（首个可上屏内容，仅文本）
async for event in _pipeline:
    if isinstance(event, PTextDelta):
        # 记录 first_delta_ts（消费层首个可上屏内容）
        if not _stream_meta.first_delta_ts:
            _stream_meta.first_delta_ts = time.perf_counter()
```

**关键设计**：
- first_token_ts：模型层写入，包括文本、思考过程、工具调用
- first_delta_ts：消费层写入，仅包括可上屏的文本
- 工具轮和思考过程：first_token_ts 有值，first_delta_ts 无值

### 4.3 四层分桶计算

**实现位置**：`agent/pro/stage_infer.py`

```python
def _bucket_ms(a: float, b: float) -> float | None:
    """两个 perf_counter 时刻的毫秒差，任一为 0 或逆序则返回 None（数据缺失）"""
    if a and b and b >= a:
        return round((b - a) * 1000, 1)
    return None

# 计算四层分桶
_s = turn.stat
_s.ttft_a_preproc_ms = _bucket_ms(_t0, _stream_meta.send_ts)
_s.ttft_b_net_ms = _bucket_ms(_stream_meta.send_ts, _stream_meta.first_byte_ts)
_s.ttft_c_decode_ms = _bucket_ms(_stream_meta.first_byte_ts, _stream_meta.first_token_ts)
_s.ttft_d_onscreen_ms = _bucket_ms(_stream_meta.first_delta_ts, emitter.first_emit_ts)