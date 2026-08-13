# Model 模块详解

> 本文档详细描述 model 模块的架构设计、多协议适配、流式推理、工具调用解析和 Responses API 缓存机制。

## 目录

1. [模块概述](#1-模块概述)
2. [设计理念](#2-设计理念)
3. [核心组件](#3-核心组件)
4. [XuanjiModel 详解](#4-xuanjamodel-详解)
5. [OpenAI 兼容模型](#5-openai-兼容模型)
6. [流式事件体系](#6-流式事件体系)
7. [工具调用解析](#7-工具调用解析)
8. [Responses API 缓存](#8-responses-api-缓存)
9. [接口说明](#9-接口说明)

---

## 1 模块概述

### 1.1 模块定位

model 模块是 pro_agent 的模型推理层，负责：

- **多协议适配**：统一封装玄机网关（vivo/openai 协议）和 OpenAI 兼容协议
- **流式推理**：异步生成器 yield 标准化流式事件
- **工具调用解析**：三层兜底解析模型输出的工具调用
- **Responses API**：支持 KV Cache 复用，降低首字时间
- **元数据采集**：TTFT、token 统计、provider_id 等

### 1.2 模块结构

```
model/
├── __init__.py
├── base.py              # Model 抽象基类
├── state.py             # ModelState / TokenType 枚举
├── stream_events.py     # 流式事件定义（TextDelta, ToolCallsDone 等）
├── xuanji/              # XuanjiModel：玄机网关客户端
│   ├── __init__.py      # 主入口（1123 行）
│   ├── _auth.py         # HMAC-SHA256 签名 / Bearer Token
│   ├── _protocol_openai.py  # OpenAI 协议行解析
│   ├── _protocol_vivo.py    # Vivo 协议行解析
│   ├── _tool_aggregator.py  # 工具调用增量聚合器
│   ├── _tool_text_parser.py # 文本中解析工具调用
│   ├── _transport.py        # HTTP SSE 传输层
│   ├── _types.py            # 内部数据类型
│   ├── profiles.json        # 模型档案配置
│   └── README.md
├── openai_model/        # OpenAI 兼容协议模型
│   └── __init__.py
└── utils/
    └── sse_util.py      # SSE 工具函数
```

### 1.3 核心职责

| 组件 | 职责 |
|---|---|
| `Model` (base) | 模型抽象基类，定义 stream/stream_responses 接口 |
| `XuanjiModel` | 玄机网关客户端，支持 openai/vivo 双协议 |
| `Model` (openai_model) | OpenAI 兼容协议模型客户端 |
| `StreamMeta` | 流式元数据（TTFT、token 统计、时间戳） |
| `profiles.json` | 模型档案配置（协议、工具模式、特殊 token） |

---

## 2 设计理念

### 2.1 薄壳入口 + 分层流水线

XuanjiModel 采用薄壳入口设计：`stream()` 根据 profile 选择协议分支，各分支内部是独立的流水线。

```
stream()
  ├─ _stream_openai()   # OpenAI 协议流水线
  └─ _stream_vivo()     # Vivo 协议流水线
```

每条流水线内部结构一致：
1. 构建请求体
2. 发起 SSE 流式请求
3. 逐行解析 → 标准化事件
4. 聚合工具调用
5. yield 终态事件

### 2.2 配置化而非硬编码

模型的行为（协议、工具模式、特殊 token）全部配置在 `profiles.json` 中，不硬编码在代码里。

```json
{
    "Doubao-Seed-2.0-pro": {
        "protocol": "openai",
        "provider": "bytedance",
        "tool_mode": "native",
        "supports_responses_api": true,
        "extra": {"temperature": 0.7, "max_new_tokens": 4096}
    },
    "BlueLM-Qwen3.5-35B-A3B-sft": {
        "protocol": "vivo",
        "provider": "vivo",
        "tool_mode": "text_parse",
        "tool_tokens": ["<tool_call>", "</tool_call>"]
    },
    "_default": {
        "protocol": "vivo",
        "tool_mode": "native"
    }
}
```

### 2.3 工具调用解析三层兜底

| 层级 | 路径 | 适用场景 |
|---|---|---|
| 标准路径 | `finish_reason=tool_calls` → `toolCalls` 字段 | OpenAI 协议原生支持 |
| 文本解析路径 | `TextToolParser` 从文本中提取 | BlueLM text_parse 模式 |
| Vivo 协议路径 | `tool_calls_done` 事件 | Vivo 自研协议 |

### 2.4 终态事件延迟 yield

**关键设计**：终态事件（ToolCallsDone/StreamDone）不在检测到终态时立即 yield，而是缓存到 `_pending_final_event`，在循环结束后统一 yield。

**原因**：终态后可能还有 usage 信息需要提取。如果立即 yield，消费方收到终态事件后 break，生成器永久停在 yield 处，后续 usage 提取代码不再执行。

```python
# 检测到终态
if chunk.type == "done":
    _meta.finish_seen = True
    _pending_final_event = StreamDone()  # 缓存，不立即 yield
    # 继续循环，提取 usage

# 循环结束后
_finalize_meta(_meta, _start)  # 写入终止里程碑
if _pending_final_event is not None:
    yield _pending_final_event  # 此时才 yield
```

---

## 3 核心组件

### 3.1 Model 抽象基类

**文件**：`model/base.py`（35 行）

```python
class Model(ABC):
    supports_responses_api: bool = False  # 是否支持 Responses API

    @abstractmethod
    def stream(self, messages, request_id, trace_id, tools=None, meta=None):
        """标准流式推理入口"""
        ...

    def stream_responses(self, input_messages, request_id, trace_id,
                         tools=None, meta=None, previous_response_id=""):
        """Responses API 流式推理（可选能力）"""
        raise NotImplementedError

    def get_model_name(self) -> str:
        return getattr(self, "model_name", "")
```

### 3.2 ModelState & TokenType

**文件**：`model/state.py`

```python
class ModelState(IntEnum):
    NORMAL = 0           # 正常输出中
    TOOL_CALL_FINISH = 1 # 工具调用解析完成
    FINISH = 2           # 流正常结束
    ERROR = -1           # 错误

class TokenType(IntEnum):
    TEXT = 0             # 文本 token
    COT = 1              # 思考过程 token
    TOOL_FUNC = 2        # 工具函数名
    TOOL_ARGS = 3        # 工具参数
    TOOL_FUNC_ARGS = 4   # 工具函数名+参数
    NONETYPE = -1        # 无类型
```

### 3.3 StreamMeta（流式元数据）

**文件**：`model/stream_events.py`

**核心字段**：

| 字段 | 类型 | 说明 |
|---|---|---|
| `send_ts` | float | 请求发送时刻（perf_counter） |
| `first_byte_ts` | float | 首字节到达时刻 |
| `first_token_ts` | float | 首个内容 token 时刻 |
| `first_text_token_ts` | float | 首个文本 token 时刻 |
| `tool_calls_ready_ts` | float | 工具调用就绪时刻 |
| `stream_end_ts` | float | 流结束时刻 |
| `ttft` | float | 首字时间（相对值，秒） |
| `total_cost` | float | 总耗时（秒） |
| `input_tokens` | int | 输入 token 数 |
| `output_tokens` | int | 输出 token 数 |
| `cached_tokens` | int | 缓存命中 token 数 |
| `response_id` | str | Responses API 缓存 ID |
| `provider_id` | str | 上游 provider 请求 ID |
| `lines` | int | 接收的 SSE 行数 |
| `text_chunks` | int | 文本 chunk 数 |
| `finish_seen` | bool | 是否收到 finish 信号 |
| `tool_call_yielded` | bool | 是否产出了工具调用 |
| `had_thinking` | bool | 是否有思考过程 |

### 3.4 流式事件类型

**文件**：`model/stream_events.py`

| 事件 | 字段 | 说明 |
|---|---|---|
| `TextDelta` | content | 文本增量 |
| `CotDelta` | content | 思考过程增量 |
| `ToolCallInfo` | id, name, arguments, thought_signature | 单个工具调用信息 |
| `ToolCallsDone` | tool_calls, thought_signature | 工具调用完成（含列表） |
| `StreamDone` | - | 流正常结束 |
| `StreamError` | code, message, error_class | 流错误 |

---

## 4 XuanjiModel 详解

### 4.1 构造参数

```python
class XuanjiModel(Model):
    def __init__(self, domain, app_id, app_key, model_name,
                 thinking_type="disabled", uri="", protocol="",
                 provider="", extra=None):
```

| 参数 | 说明 |
|---|---|
| `domain` | 玄机网关域名 |
| `app_id` / `app_key` | HMAC 签名凭据 |
| `model_name` | 模型名称（用于查找 profile） |
| `thinking_type` | 思考模式（disabled/enabled） |
| `protocol` | 协议类型（覆盖 profile 默认值） |
| `provider` | 上游 provider（覆盖 profile 默认值） |
| `extra` | 额外参数（与 profile.extra 合并） |

### 4.2 Profile 加载机制

```python
def _load_profile(model_name: str) -> dict:
    """按模型名查找 profile，支持前缀匹配，兜底 _default"""
    if model_name in _PROFILES:
        return _PROFILES[model_name]
    for key in sorted(_PROFILES.keys(), key=len, reverse=True):
        if model_name.startswith(key):
            return _PROFILES[key]
    return _PROFILES.get("_default", {})
```

**匹配优先级**：精确匹配 → 最长前缀匹配 → `_default` 兜底

### 4.3 OpenAI 协议流水线

```
_build_openai_body()
    ↓
stream_sse_lines()  # HTTP SSE 传输
    ↓
parse_openai_line()  # 逐行解析
    ↓
ToolAggregator.feed_delta()  # 工具调用增量聚合
    ↓
yield TextDelta / CotDelta / ToolCallsDone / StreamDone / StreamError
```

**请求体结构**：
```json
{
    "model": "Doubao-Seed-2.0-pro",
    "messages": [...],
    "stream": true,
    "tools": [...],
    "temperature": 0.7
}
```

### 4.4 Vivo 协议流水线

```
build_sign_headers()  # HMAC-SHA256 签名
    ↓
_build_vivo_body()
    ↓
stream_sse_lines()
    ↓
parse_vivo_line()  # 逐行解析
    ↓
TextToolParser.feed()  # 文本中解析工具调用（text_parse 模式）
    ↓
yield TextDelta / CotDelta / ToolCallsDone / StreamDone / StreamError
```

**请求体结构**：
```json
{
    "messages": [...],
    "task_type": "chatgpt",
    "sessionId": "...",
    "model": "BlueLM-Qwen3.5-35B-A3B-sft",
    "provider": "vivo",
    "extra": {"tools": [...], "max_length": 65536, "incremental": true}
}
```

### 4.5 消息标准化

`_normalize_messages()` 统一处理以下问题：

1. **arguments 序列化**：将 dict 类型的 arguments 序列化为 JSON 字符串
2. **��立 tool 消息修复**：为缺少对应 assistant tool_use 的 tool 消息补充占位 assistant
3. **thought_signature 处理**：Gemini 要求 camelCase → snake_case 转换

### 4.6 Gemini 特殊处理

`_sanitize_tools_for_gemini()` 清洗工具 schema：
- `enum` 仅允许 `type=string` 节点