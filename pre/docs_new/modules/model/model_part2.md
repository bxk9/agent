- `array` 必须带 `items`
- 顶层 `parameters` 必须 `type=object`
- 清除空 enum 值

---

## 5 OpenAI 兼容模型

**文件**：`model/openai_model/__init__.py`

用于 BlueLM-Qwen3.5 系列等支持标准 OpenAI 协议的模型。

**与 XuanjiModel 的区别**：
- 使用 Bearer Token 认证（而非 HMAC 签名）
- 标准 function_calls 格式
- 不支持 Responses API

---

## 6 流式事件体系

### 6.1 事件流转

```
模型 SSE 行
    ↓ parse_openai_line / parse_vivo_line
ChunkResult（内部类型）
    ↓ 转换为标准化事件
StreamEvent（TextDelta / CotDelta / ToolCallsDone / ...）
    ↓ StreamPipeline 处理
最终 StreamEvent
    ↓ SseEmitter 格式化
SSE 字符串（"event:text\ndata:..."）
```

### 6.2 事件语义

| 事件 | 语义 | 消费方行为 |
|---|---|---|
| `TextDelta` | 模型输出文本增量 | 上屏显示 |
| `CotDelta` | 模型思考过程 | 不上屏，仅记录 |
| `ToolCallsDone` | 工具调用解析完成 | 进入工具验证/执行 |
| `Signal` | 特殊信号 | 按 label 处理 |
| `StreamDone` | 流正常结束 | 标记 session_finished |
| `StreamError` | 流错误 | 降级或报错 |

---

## 7 工具调用解析

### 7.1 ToolAggregator（增量聚合器）

**文件**：`model/xuanji/_tool_aggregator.py`

**职责**：聚合流式 tool_delta 增量，在流结束时输出完整的工具调用列表。

**核心接口**：
```python
class ToolAggregator:
    def feed_delta(self, index, id, name, arguments, thought_signature=""):
        """接收一个 tool_delta 增量"""

    def finish(self) -> list[ToolCall]:
        """输出聚合后的完整工具调用列表"""

    @property
    def has_data(self) -> bool:
        """是否有聚合数据"""

    @staticmethod
    def from_vivo_tool_calls(vivo_calls, thought_signature="") -> list[ToolCall]:
        """从 Vivo 协议的 tool_calls_done 事件构建"""
```

### 7.2 TextToolParser（文本解析器）

**文件**：`model/xuanji/_tool_text_parser.py`

**职责**：从文本流中解析工具调用（BlueLM text_parse 模式）。

**工作原理**：
1. 检测 `<tool_call>` 开始标记
2. 累积工具调用 JSON 内容
3. 检测 `</tool_call>` 结束标记
4. 解析 JSON → ToolCall 对象

**跨 token 拆分处理**：开始/结束标记可能被切分到多个 token，通过模糊前缀表检测未完成片段。

### 7.3 三层兜底策略

| 层级 | 触发条件 | 解析方式 |
|---|---|---|
| 标准路径 | `finish_reason=tool_calls` | 读取 `toolCalls` 字段 |
| 文本解析路径 | `tool_mode=text_parse` | TextToolParser 从文本提取 |
| Vivo 协议路径 | `tool_calls_done` 事件 | 直接解析 vivo 格式 |

---

## 8 Responses API 缓存

### 8.1 设计目标

通过 Responses API 复用 KV Cache，减少重复计算，降低首字时间（TTFT）。

### 8.2 三条路径

| 路径 | 条件 | 行为 |
|---|---|---|
| **A（缓存命中）** | 有 response_id + 前缀一致 + 有 tool 增量 | 只传 tool_results 增量 + previous_response_id |
| **B（首次缓存）** | 无 response_id + 缓存启用 | 用 Responses API 获取 response_id |
| **C（降级）** | 缓存不可用 | 走原始 stream 逻辑 |

### 8.3 缓存一致性校验

```python
def _prefix_hash(system_prompt, chat_history) -> str:
    """前缀一致性校验哈希"""
    h = hashlib.sha256()
    h.update(system_prompt.encode())
    h.update(json.dumps(chat_history, ensure_ascii=False).encode())
    return h.hexdigest()
```

**降级条件**：
- 前缀哈希不匹配（历史压缩导致前缀变化）
- 无 tool 增量（非工具回调续推）
- 模型切换后
- 重试循环中（retry_count > 0）

### 8.4 Responses API 请求体

```json
{
    "model": "Doubao-Seed-2.0-pro",
    "input": [
        {"type": "function_call_output", "call_id": "...", "output": "..."}
    ],
    "stream": true,
    "caching": {"type": "enabled"},
    "previous_response_id": "resp_xxx",
    "thinking": {"type": "disabled"}
}
```

### 8.5 消息格式转换

`_convert_to_responses_input()` 将 Chat Completions 格式转换为 Responses API 格式：

| Chat Completions | Responses API |
|---|---|
| `{"role": "assistant", "tool_calls": [...]}` | `{"type": "function_call", "call_id": "...", "name": "...", "arguments": "..."}` |
| `{"role": "tool", "content": "..."}` | `{"type": "function_call_output", "call_id": "...", "output": "..."}` |
| `{"role": "user/system", "content": "..."}` | 保持不变 |

---

## 9 接口说明

### 9.1 Model 基类接口

```python
class Model(ABC):
    supports_responses_api: bool = False

    @abstractmethod
    def stream(self, messages, request_id, trace_id,
               tools=None, meta=None) -> AsyncGenerator[StreamEvent, None]:
        """标准流式推理入口"""

    def stream_responses(self, input_messages, request_id, trace_id,
                         tools=None, meta=None,
                         previous_response_id="") -> AsyncGenerator[StreamEvent, None]:
        """Responses API 流式推理（可选）"""

    def get_model_name(self) -> str:
        """获取模型名称"""
```

### 9.2 XuanjiModel 构造

```python
model = XuanjiModel(
    domain="api.xuanji.example.com",
    app_id="your_app_id",
    app_key="your_app_key",
    model_name="Doubao-Seed-2.0-pro",
    thinking_type="disabled",
    protocol="openai",      # 可选，覆盖 profile
    provider="bytedance",   # 可选，覆盖 profile
    extra={"temperature": 0.7}
)
```

### 9.3 StreamMeta 使用

```python
meta = StreamMeta()
async for event in model.stream(messages, request_id, trace_id, tools, meta):
    if isinstance(event, TextDelta):
        print(event.content)
    elif isinstance(event, ToolCallsDone):
        for tc in event.tool_calls:
            print(f"Tool: {tc.name}, Args: {tc.arguments}")

# 流结束后读取元数据
print(f"TTFT: {meta.ttft}s")
print(f"Input tokens: {meta.input_tokens}")
print(f"Output tokens: {meta.output_tokens}")
print(f"Response ID: {meta.response_id}")
```

---

**相关文档**：
- [Agent 模块详解](./agent.md)
- [Tools 模块详解](./tools.md)
- [数据流文档](../dataflow/README.md)
