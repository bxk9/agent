- 无法区分：从客户端视角，网络传输和 Prefill 都是"等待首字节"
- 与玄机 ttft 同源：玄机网关的 ttft 包含 Prefill，B_net 与其同源可比
- 优化方向明确：B_net 高时，可以通过 Responses API 缓存优化 Prefill

**处理逻辑**：
```
场景：B_net = 400ms
  → 网络传输耗时 100ms（正常）
  → 玄机网关 Prefill 耗时 300ms（KV Cache 未命中）
  → 优化方向：引入 Responses API 缓存，复用 KV Cache
  → B_net 降低到 120ms

如果 B_net 不包含 Prefill：
  → 无法区分网络传输和 Prefill
  → 无法确定优化方向
  → 可能错误地优化网络传输，但实际瓶颈在 Prefill
```

### 2.2.2 为什么区分 first_token_ts 和 first_delta_ts（真实原因）

**来源**：代码注释 - `agent/pro/stage_infer.py`

**代码注释原文**：
```python
# 修复：终点原为 first_delta_ts（消费端首个「可上屏内容」）。工具轮该时刻 = 工具调用参数
# 全部生成完毕并解析完成，紧接着即 break 结束流，使 ttft_ms 退化为 ≈ cost_ms，
# 与文本轮真首字混在同一列，统计口径不可比；现改用 model 层写入的 first_token_ts。
```

**详细解释**：
- first_token_ts：模型层写入的首个内容 token（包括工具调用）
- first_delta_ts：消费层收到的首个可上屏内容（仅文本）
- 工具轮和思考过程无上屏文本，first_delta_ts 无值，但 first_token_ts 有值
- 如果只用 first_delta_ts，工具轮的 TTFT 会退化为 cost_ms，与文本轮混在同一列，统计口径不可比

**量化示例**：
```
文本轮：
  first_token_ts = 100ms（模型生成首个文本 token）
  first_delta_ts = 110ms（消费层收到首个可上屏文本）
  D_onscreen = 10ms

工具轮：
  first_token_ts = 100ms（模型生成首个工具调用 token）
  first_delta_ts = None（无上屏文本）
  D_onscreen = None

如果只用 first_delta_ts：
  → 工具轮的 TTFT = cost_ms（如 500ms）
  → 文本轮的 TTFT = 110ms
  → 混在同一列，统计口径不可比
  → 无法区分"工具轮"和"文本轮慢"

使用 first_token_ts：
  → 工具轮的 TTFT = 100ms
  → 文本轮的 TTFT = 100ms
  → 统计口径可比
  → 可以区分"工具轮"和"文本轮"
```

### 2.2.3 为什么用 ContextVar 传递请求起始时间（真实原因）

**来源**：代码实现 - `main.py` 和 `agent/pro/stage_infer.py`

**代码实现原文**：
```python
# main.py
req_start_ctx_var = contextvars.ContextVar("req_start", default=0.0)

async def chat(body: dict):
    req_start_ctx_var.set(time.perf_counter())
    async for token in _do_chat(body):
        yield token

# agent/pro/stage_infer.py
async def _stage_infer(turn, session, body, context):
    _t0 = req_start_ctx_var.get()  # 获取请求到达时刻
```

**详细解释**：
- 避免函数签名污染：`_t0` 需要在多个函数间传递，用参数会导致签名冗长
- 跨协程安全：ContextVar 是协程安全的，每个请求独立
- 与 trace_id 一致：trace_id 也用 ContextVar 传递，保持一致性

**处理逻辑**：
```
函数参数传递（未采用）：
  async def chat(body: dict, _t0: float):
      async for token in _do_chat(body, _t0):
          yield token
  async def _do_chat(body: dict, _t0: float):
      async for token in agent.process(body, _t0):
          yield token
  async def process(self, body, _t0: float):
      async for sse in _stage_infer(turn, session, body, context, _t0):
          yield sse
  → 函数签名冗长
  → 每个函数都需要传递 _t0

ContextVar 传递（当前实现）：
  req_start_ctx_var = contextvars.ContextVar("req_start", default=0.0)
  async def chat(body: dict):
      req_start_ctx_var.set(time.perf_counter())
      async for token in _do_chat(body):
          yield token
  async def _stage_infer(turn, session, body, context):
      _t0 = req_start_ctx_var.get()
  → 函数签名简洁
  → 无需在每个函数间传递 _t0
```

### 2.2.4 为什么不用全局变量传递 _t0（真实原因）

**来源**：代码实现 - `main.py`

**详细解释**：
- 并发安全：全局变量在并发环境下不安全
- 请求隔离：每个请求有独立的 `_t0`，互不影响
- 生命周期管理：ContextVar 随协程结束自动清理

**业务场景**：
```
场景：并发请求
  请求 A：_t0 = 1000.0
  请求 B：_t0 = 1000.5

全局变量（未采用）：
  global _t0
  _t0 = 1000.0  # 请求 A 设置
  _t0 = 1000.5  # 请求 B 覆盖
  → 请求 A 读到 1000.5（错误）
  → 并发不安全

ContextVar（当前实现）：
  req_start_ctx_var.set(1000.0)  # 请求 A 设置
  req_start_ctx_var.set(1000.5)  # 请求 B 设置
  → 请求 A 读到 1000.0（正确）
  → 请求 B 读到 1000.5（正确）
  → 并发安全
```

## 2.3 性能与质量原因

### 2.3.1 为什么工具轮不计算 D_onscreen（真实原因）

**来源**：代码注释 - `agent/pro/stage_infer.py`

**代码注释原文**：
```python
# 注：工具轮无上屏文本，D 与 total 恒为 None（区别于"测量缺失"，二者都用 None，靠 path 判读）
```

**详细解释**：
- 工具轮：模型输出工具调用，客户端执行工具后回调
- 无上屏文本：工具轮不需要向用户展示文本，只需要下发工具调用请求
- D_onscreen 无意义：没有上屏文本，D_onscreen 无法计算
- 用 None 表示"无上屏文本"，区别于"测量缺失"（二者都用 None，靠 path 判读）

**业务场景**：
```
文本轮：
  模型输出: "今天北京晴天，气温 25°C"
  → 上屏显示文本
  → D_onscreen = 10ms
  → total = A + B + C + D = 50 + 200 + 100 + 10 = 360ms

工具轮：
  模型输出: create_alarm(time="08:00")
  → 下发工具调用请求
  → 无上屏文本
  → D_onscreen = None
  → total = None（无法计算）
  → 靠 path 判读：path=A/B/C 表示缓存路径，retry 表示重试次数
```

### 2.3.2 为什么日志格式包含 path 和 retry（真实原因）

**来源**：代码实现 - `agent/pro/stage_infer.py`

**代码实现原文**：
```python
logger.info(
    f"[perf-bucket] path={_responses_path or 'C'} retry={ctrl.retry_count} "
    f"A_preproc={_s.ttft_a_preproc_ms}ms "
    f"B_net_firstbyte={_s.ttft_b_net_ms}ms(≈玄机ttft同源) "
    f"C_decode={_s.ttft_c_decode_ms}ms "
    f"D_onscreen={_s.ttft_d_onscreen_ms}ms "
    f"total_to_onscreen={_s.ttft_total_ms}ms "
    f"ttft={_s.ttft_ms}ms(=B+C) "
    f"req_id={_req_id}"
)
```

**详细解释**：
- path：区分 Responses API 缓存路径（A/B/C），分析缓存效果
- retry：区分首次推理和重试，分析重试对性能的影响
- B_net 标注"≈玄机ttft同源"：说明与玄机网关的 ttft 可比
- ttft 标注"=B+C"：说明模型层 TTFT 只包括网络和模型解码

**业务场景**：
```
场景 1：缓存命中，首次推理
  → path=A, retry=0
  → B_net=30ms（缓存命中，Prefill 快）
  → 分析：缓存效果好

场景 2：缓存不可用，首次推理
  → path=C, retry=0
  → B_net=200ms（无缓存，Prefill 慢）
  → 分析：需要优化缓存策略

场景 3：缓存不可用，重试
  → path=C, retry=1
  → B_net=200ms（无缓存，Prefill 慢）
  → 分析：重试时强制降级，无法使用缓存

场景 4：缓存命中，重试（不应该出现）
  → path=A, retry=1
  → 分析：重试时应该强制降级到路径C，如果出现 path=A，说明有 bug
```

## 2.4 工程实现原因

### 2.4.1 为什么数据写入 turn.stat（真实原因）

**来源**：代码实现 - `agent/pro/stage_infer.py`

**代码实现原文**：
```python
_s = turn.stat
_s.ttft_a_preproc_ms = _bucket_ms(_t0, _stream_meta.send_ts)
_s.ttft_b_net_ms = _bucket_ms(_stream_meta.send_ts, _stream_meta.first_byte_ts)
_s.ttft_c_decode_ms = _bucket_ms(_stream_meta.first_byte_ts, _stream_meta.first_token_ts)
_s.ttft_d_onscreen_ms = _bucket_ms(_stream_meta.first_delta_ts, emitter.first_emit_ts)
_s.ttft_total_ms = _bucket_ms(_t0, emitter.first_emit_ts)
```

**详细解释**：
- 统一收集：turn.stat 已经收集了其他埋点数据（如 model_name、input_tokens）
- 统一落盘：stage_finalize 统一将 turn.stat 写入日志
- 简化实现：无需引入独立的埋点系统

**数据流向**：
```
StreamMeta 收集时间戳
  → stage_infer 计算分桶耗时，写入 turn.stat
  → stage_finalize 将 turn.stat 写入日志
  → 日志系统聚合分析（如 ELK）
```

**处理逻辑**：
```
独立埋点系统（未采用）：
  → 引入独立的埋点系统（如 Prometheus）
  → 需要额外的依赖和配置
  → 需要额外的落盘逻辑
  → 复杂度高

turn.stat（当前实现）：
  → turn.stat 已经收集了其他埋点数据
  → stage_finalize 统一将 turn.stat 写入日志
  → 无需额外的依赖和配置
  → 复杂度低
```

### 2.4.2 为什么需要 _bucket_ms 辅助函数（真实原因）

**来源**：代码实现 - `agent/pro/stage_infer.py`

**代码实现原文**：
```python
def _bucket_ms(a: float, b: float) -> float | None:
    """两个 perf_counter 时刻的毫秒差，任一为 0 或逆序则返回 None（数据缺失）"""
    if a and b and b >= a:
        return round((b - a) * 1000, 1)
    return None
```

**详细解释**：
- 返回 None 表示数据缺失（如工具轮无 first_delta_ts）
- 区分"测量缺失"和"测量为 0"，二者都用 None，靠 path 判读
- 避免负数：如果 b < a（时间逆序），返回 None

**处理逻辑**：
```
场景 1：正常测量
  → a = 1000.0, b = 1000.1
  → _bucket_ms(a, b) = 100.0ms

场景 2：数据缺失（如工具轮无 first_delta_ts）
  → a = 1000.0, b = 0.0
  → _bucket_ms(a, b) = None

场景 3：时间逆序（异常情况）
  → a = 1000.1, b = 1000.0
  → _bucket_ms(a, b) = None
  → 避免负数
```

## 2.5 业务价值原因

### 2.5.1 为什么 TTFT 分桶埋点值得体系化投入（真实原因）

**来源**：性能数据统计

**数据**：
```
优化前（无分桶埋点）：
  → TTFT = 800ms，无法定位瓶颈
  → 团队盲目优化，事倍功半
  → 优化效率低
