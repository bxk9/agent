# TTFT 分桶埋点与性能分析

> 面试价值：⭐⭐⭐⭐ | 技术深度：⭐⭐⭐⭐⭐ | 业务影响：⭐⭐⭐⭐⭐

## 一句话总结

设计并实现同源口径的 TTFT（Time To First Token）分桶埋点系统，将首字时间精确拆分为预处理、网络、解码、上屏四个阶段，通过 perf_counter 统一时间源，实现性能瓶颈的精准定位，指导团队将 TTFT 从 800ms 优化到 300ms。

---

## 1. 问题背景

### 1.1 业务场景

pro_agent 是实时对话系统，用户对响应速度极其敏感：

```
用户: "今天天气怎么样？"
  ↓
[等待中...]  ← 用户感知到的延迟
  ↓
助手: "今天北京晴天，气温 25°C"
```

**TTFT（Time To First Token）**：从用户发送请求到收到第一个响应 token 的时间，是用户体验的核心指标。

### 1.2 技术痛点

**核心问题**：TTFT 高达 800ms，但无法定位瓶颈在哪个环节。

| 环节 | 可能的问题 | 难以定位的原因 |
|---|---|---|
| 预处理 | 工具召回慢、Prompt 构建慢 | 没有细粒度埋点 |
| 网络传输 | 网络延迟、网关排队 | 时间源不统一 |
| 模型解码 | Prefill 慢、Decode 慢 | 无法区分 Prefill 和 Decode |
| 上屏处理 | Pipeline 处理慢、Emitter 过滤慢 | 没有端到端追踪 |

**现有埋点的问题**：
1. **时间源不统一**：混用 `time.time()` 和 `time.perf_counter()`，无法对比
2. **粒度太粗**：只有"请求开始"和"首 token"两个点，无法定位瓶颈
3. **口径不一致**：不同模块对"首 token"的定义不同（模型层 vs 消费层）

### 1.3 核心矛盾

**"需要精准定位性能瓶颈，但现有埋点系统无法提供足够细粒度的数据"** —— 没有数据就没有优化方向，盲目优化可能事倍功半。

---

## 2. 技术方案

### 2.1 设计思路

**同源口径分桶埋点**：使用 `perf_counter` 作为统一时间源，将 TTFT 拆分为四个阶段：

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

### 2.2 四个分桶定义

| 分桶 | 起点 | 终点 | 含义 | 优化方向 |
|---|---|---|---|---|
| **A_preproc** | t0（请求到达） | send_ts（发送请求） | 预处理耗时 | 优化 Prompt 构建、工具召回 |
| **B_net** | send_ts | first_byte_ts（首字节） | 网络 + Prefill | 优化网络、Responses API 缓存 |
| **C_decode** | first_byte_ts | first_token_ts（首 token） | 模型 Decode | 模型侧优化（非我方） |
| **D_onscreen** | first_delta_ts（首内容） | first_emit_ts（首发射） | 上屏处理 | 优化 Pipeline、Emitter |

**关键设计**：
- **统一时间源**：全部使用 `time.perf_counter()`，保证可比性
- **明确边界**：每个分桶的起点和终点都有明确定义
- **区分 first_token 和 first_delta**：
  - `first_token_ts`：模型层写入的首个内容 token（包括工具调用）
  - `first_delta_ts`：消费层收到的首个可上屏内容（仅文本）

### 2.3 StreamMeta 扩展

```python
# model/stream_events.py

@dataclass
class StreamMeta:
    """流式元数据，承载性能埋点"""
    # 时间戳（perf_counter 口径）
    send_ts: float = 0.0              # 请求发送时刻
    first_byte_ts: float = 0.0        # 首字节到达时刻
    first_token_ts: float = 0.0       # 首个内容 token 时刻（模型层）
    first_text_token_ts: float = 0.0  # 首个文本 token 时刻
    tool_calls_ready_ts: float = 0.0  # 工具调用就绪时刻
    stream_end_ts: float = 0.0        # 流结束时刻
    
    # 标记方法
    def mark_first_token(self):
        """标记首个内容 token（模型层调用）"""
        if not self.first_token_ts:
            self.first_token_ts = time.perf_counter()
    
    def mark_first_text_token(self):
        """标记首个文本 token（模型层调用）"""
        if not self.first_text_token_ts:
            self.first_text_token_ts = time.perf_counter()
    
    def mark_tool_calls_ready(self):
        """标记工具调用就绪（模型层调用）"""
        if not self.tool_calls_ready_ts:
            self.tool_calls_ready_ts = time.perf_counter()
```

### 2.4 埋点注入

#### 模型层埋点（XuanjiModel）

```python
# model/xuanji/__init__.py

async def _stream_openai(self, messages, request_id, trace_id, tools, meta):
    _start = time.perf_counter()
    _meta = meta or StreamMeta()
    
    # 发送请求时记录 send_ts
    async for line in stream_sse_lines(
        url, headers, body, params, request_id,
        on_send=lambda: setattr(_meta, "send_ts", _meta.send_ts or time.perf_counter()),
        on_first_byte=lambda: setattr(_meta, "first_byte_ts", _meta.first_byte_ts or time.perf_counter()),
    ):
        # 解析 chunk
        chunk = parse_openai_line(line)
        
        if not _first_token and chunk.type in ("text", "cot", "tool_delta"):
            _first_token = True
            _meta.mark_first_token()  # 记录 first_token_ts
            _meta.ttft = _meta.first_token_ts - _start
        
        if chunk.type == "text":
            _meta.mark_first_text_token()  # 记录 first_text_token_ts
            yield TextDelta(content=chunk.content)
```

#### Agent 层埋点（stage_infer）

```python
# agent/pro/stage_infer.py

async def _stage_infer(turn, session, body, context):
    _t0 = req_start_ctx_var.get()  # 请求到达时刻
    
    # ... 构建消息、压缩上下文
    
    _stream_meta = StreamMeta()
    _source = session.model.stream(messages=messages, meta=_stream_meta)
    
    # StreamPipeline 处理
    _pipeline = StreamPipeline(source=_source, processors=build_processors(session.model))
    emitter = SseEmitter()
    
    async for event in _pipeline:
        if isinstance(event, PTextDelta):
            # 记录 first_delta_ts（消费层首个可上屏内容）
            if not _stream_meta.first_delta_ts:
                _stream_meta.first_delta_ts = time.perf_counter()
            
            # SseEmitter 发射
            chunk = emitter.emit(event)
            if chunk:
                yield chunk
    
    # 计算分桶耗时
    _s = turn.stat
    _s.ttft_a_preproc_ms = _bucket_ms(_t0, _stream_meta.send_ts)
    _s.ttft_b_net_ms = _bucket_ms(_stream_meta.send_ts, _stream_meta.first_byte_ts)
    _s.ttft_c_decode_ms = _bucket_ms(_stream_meta.first_byte_ts, _stream_meta.first_token_ts)
    _s.ttft_d_onscreen_ms = _bucket_ms(_stream_meta.first_delta_ts, emitter.first_emit_ts)
    _s.ttft_total_ms = _bucket_ms(_t0, emitter.first_emit_ts)
    
    logger.info(
        f"[perf-bucket] path={_responses_path or 'C'} retry={ctrl.retry_count} "
        f"A_preproc={_s.ttft_a_preproc_ms}ms "
        f"B_net_firstbyte={_s.ttft_b_net_ms}ms "
        f"C_decode={_s.ttft_c_decode_ms}ms "
        f"D_onscreen={_s.ttft_d_onscreen_ms}ms "
        f"total_to_onscreen={_s.ttft_total_ms}ms"
    )
```

### 2.5 辅助函数

```python
def _bucket_ms(a: float, b: float) -> float | None:
    """两个 perf_counter 时刻的毫秒差，任一为 0 或逆序则返回 None（数据缺失）"""
    if a and b and b >= a:
        return round((b - a) * 1000, 1)
    return None
```

---

## 3. 实现细节

### 3.1 SseEmitter 埋点

```python
# agent/pro/stream/emitter.py

class SseEmitter:
    """SSE 发射器，记录首次发射时间"""
    
    def __init__(self):
        self.first_emit_ts: float = 0.0  # 首次发射时刻
        self.has_emitted: bool = False   # 是否已发射过
    
    def emit(self, event: TextDelta) -> str | None:
        """发射 SSE 事件"""
        # 记录首次发射时间
        if not self.first_emit_ts:
            self.first_emit_ts = time.perf_counter()
        
        self.has_emitted = True
        
        # 格式化为 SSE 格式
        return f"event: text\ndata:{json.dumps({'content': event.content})}\n\n"
```

### 3.2 请求起始时间传递

```python
# main.py

req_start_ctx_var = contextvars.ContextVar("req_start", default=0.0)

async def chat(body: dict):
    # 记录请求到达时刻
    req_start_ctx_var.set(time.perf_counter())
    async for token in _do_chat(body):
        yield token

# agent/pro/stage_infer.py

async def _stage_infer(turn, session, body, context):
    _t0 = req_start_ctx_var.get()  # 获取请求到达时刻
    # ... 后续计算 A_preproc = send_ts - _t0
```

**为什么用 ContextVar**：
- 避免在函数签名中传递 `_t0`
- 跨协程安全，每个请求独立
- 与 trace_id 的传递方式一致

### 3.3 日志格式

```
[perf-bucket] path=A retry=0 
A_preproc=45.2ms 
B_net_firstbyte=120.5ms(≈玄机ttft同源) 
C_decode=85.3ms 
D_onscreen=12.1ms 
total_to_onscreen=263.1ms 
ttft=205.8ms(=B+C) 
req_id=abc123
```

**日志解析**：
- `path=A`：使用了 Responses API 缓存路径A
- `retry=0`：首次推理，未重试
- `A_preproc=45.2ms`：预处理耗时 45.2ms
- `B_net_firstbyte=120.5ms`：网络 + Prefill 耗时 120.5ms
- `C_decode=85.3ms`：模型 Decode 耗时 85.3ms
- `D_onscreen=12.1ms`：上屏处理耗时 12.1ms
- `total_to_onscreen=263.1ms`：总耗时 263.1ms
- `ttft=205.8ms(=B+C)`：模型层 TTFT（不含预处理和上屏）

### 3.4 数据聚合

```python
# infra/stat_collector.py

@dataclass
class StatCollector:
    """统计数据收集器"""
    # TTFT 分桶（毫秒）
    ttft_a_preproc_ms: float | None = None
    ttft_b_net_ms: float | None = None
    ttft_c_decode_ms: float | None = None
    ttft_d_onscreen_ms: float | None = None
    ttft_total_ms: float | None = None
    ttft_ms: int = -1  # 模型层 TTFT（B+C）
    
    # 其他指标
    model_name: str = ""
    input_tokens: int = 0
    output_tokens: int = 0
    cached_tokens: int = 0
    cost_ms: int = 0
```

**数据流向**：
1. `StreamMeta` 收集时间戳