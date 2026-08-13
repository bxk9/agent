# Responses API 缓存优化

> 面试价值：⭐⭐⭐⭐⭐ | 技术深度：⭐⭐⭐⭐⭐ | 业务影响：⭐⭐⭐⭐⭐

## 一句话总结

设计并实现基于 Responses API 的 KV Cache 复用机制，通过三条路径（缓存命中/首次缓存/降级）和前缀一致性校验，在多轮对话场景中复用 system_prompt + chat_history 的 KV Cache，将首字时间（TTFT）降低 30-50%。

---

## 1. 问题背景

### 1.1 业务场景

pro_agent 是语音助手的中控服务，典型的多轮对话场景如下：

```
用户: "定一个早上八点的闹钟"
  → 第1次推理: system_prompt(2000 tokens) + chat_history(0) + user_query(20)
  → 模型返回: create_alarm 工具调用
  
用户: (客户端执行工具后回调)
  → 第2次推理: system_prompt(2000 tokens) + chat_history(0) + tool_result(100) + user_query(20)
  → 模型返回: "闹钟已设好"
```

### 1.2 技术痛点

**核心问题**：多轮对话中，system_prompt 和 chat_history 往往不变，但每次推理都要重新计算 KV Cache。

| 指标 | 数值 | 说明 |
|---|---|---|
| system_prompt 长度 | ~2000 tokens | 系统提示词 + 工具定义 |
| chat_history 长度 | 0~5000 tokens | 多轮对话历史 |
| 单次推理 prefill 耗时 | 200-500ms | 取决于 prompt 长度 |
| 多轮对话轮次 | 2-5 轮 | 工具调用 + 总结 |

**性能浪费**：
- 第2次推理时，system_prompt + chat_history 的 KV Cache 已在第1次计算过
- 但标准 Chat Completions API 无法复用，每次都要重新 prefill
- 多轮对话中，重复计算占比可达 60-80%

### 1.3 核心矛盾

**"KV Cache 应该跨推理复用"** —— 但标准 Chat Completions API 是无状态的，每次推理独立计算 KV Cache，无法复用前缀。

---

## 2. 技术方案

### 2.1 设计思路

利用 Responses API 的 `previous_response_id` 机制，实现 KV Cache 跨推理复用：

1. **第1次推理（路径B）**：使用 Responses API，获取 `response_id`
2. **第2次推理（路径A）**：传入 `previous_response_id` + 仅传 tool_results 增量
3. **降级路径（路径C）**：缓存不可用时走标准 Chat Completions API

### 2.2 三条路径

```
检查 Responses API 可用性
    ├─ 不可用 → 路径C（标准 stream）
    └─ 可用
        ├─ 有 response_id + 前缀一致 + 有 tool 增量
        │   → 路径A（缓存命中，只传增量）
        ├─ 无 response_id + 缓存启用
        │   → 路径B（首次缓存，获取 response_id）
        └─ 其他
            → 路径C（降级）
```

### 2.3 前缀一致性校验

```python
def _prefix_hash(system_prompt: str, chat_history: list) -> str:
    """前缀一致性校验哈希。
    
    覆盖 system_prompt + chat_history（历史对话，也是 Context Pipeline 的压缩目标），
    任一变化即视为服务端缓存的前缀已失效（如触发了历史压缩/淡化/丢弃），须降级路径C。
    """
    h = hashlib.sha256()
    h.update(system_prompt.encode())
    h.update(json.dumps(chat_history, ensure_ascii=False, default=str).encode())
    return h.hexdigest()
```

**为什么需要前缀校验**：
- Context Pipeline 可能在两次推理之间压缩了 chat_history
- 压缩后的 chat_history 与服务端缓存的前缀不一致
- 如果不校验，会向错误的 session 追加增量，导致模型输入错误

### 2.4 降级条件

| 条件 | 原因 | 降级路径 |
|---|---|---|
| 前缀哈希不匹配 | 历史压缩导致前缀变化 | C |
| 无 tool 增量 | 非工具回调续推 | C |
| 模型切换后 | 新模型的 KV Cache 不兼容 | C |
| 重试循环中 | retry_count > 0，避免缓存污染 | C |
| 路径A/B 流失败 | 服务端错误 | C（仅在未产出文本时） |

---

## 3. 实现细节

### 3.1 核心代码：路径判断

```python
# stage_infer.py

# Responses API 可用性判定（静态条件，不随 retry 变化）
_can_use_responses = (
    common_config.get("responses_cache_enabled", False)
    and getattr(session.model, "supports_responses_api", False)
    and not _model_switched
)

while True:  # 推理-校验-重试循环
    messages = ctrl.build_messages(...)
    
    # 前缀一致性校验
    _current_prefix_hash = _prefix_hash(built_system_prompt, chat_history)
    
    if _can_use_responses and _extra_exp.response_id and ctrl.retry_count == 0:
        # 路径A候选：第2次推理（有 response_id 从中控透传回来）
        if _extra_exp.prefix_hash != _current_prefix_hash:
            _cache_fallback_reason = "prefix_changed"
        else:
            _delta_messages = _extract_tool_results_delta(messages)
            if not _delta_messages:
                _cache_fallback_reason = "no_tool_delta"
            else:
                _use_responses_cache = True
    elif not _can_use_responses and _extra_exp.response_id:
        # 不可用但有 response_id：记录原因
        if not common_config.get("responses_cache_enabled", False):
            _cache_fallback_reason = "switch_disabled"
        elif not getattr(session.model, "supports_responses_api", False):
            _cache_fallback_reason = "model_not_supported"
        elif ctrl.retry_count > 0:
            _cache_fallback_reason = "retry"
        elif _model_switched:
            _cache_fallback_reason = "model_switched"
```

### 3.2 核心代码：三条路径执行

```python
if _use_responses_cache and _can_use_cache_this_iteration:
    # 路径A：缓存命中，只传 tool_results 增量 + previous_response_id
    _source = session.model.stream_responses(
        input_messages=_delta_messages,
        request_id=_req_id,
        trace_id=trace_id,
        tools=ctrl.tool_list,
        meta=_stream_meta,
        previous_response_id=_extra_exp.response_id,
    )
    _responses_path = "A"
elif _can_use_cache_this_iteration:
    # 路径B：缓存启用但无 response_id（第1次推理），用 Responses API 获取 response_id
    _source = session.model.stream_responses(
        input_messages=messages,
        request_id=_req_id,
        trace_id=trace_id,
        tools=ctrl.tool_list,
        meta=_stream_meta,
    )
    _responses_path = "B"
else:
    # 路径C：缓存不可用，走原逻辑
    _source = session.model.stream(
        messages=messages,
        request_id=_req_id,
        trace_id=trace_id,
        tools=ctrl.tool_list,
        meta=_stream_meta,
    )
```

### 3.3 核心代码：降级处理

```python
# 路径A/B 失败时降级到路径C
if isinstance(event, PStreamError):
    if _responses_path and not assist_content and not func_tools:
        logger.warning(
            f"[ResponsesCache] 路径{_responses_path}失败，降级到路径C: "
            f"code={event.code} msg={event.message!r}"
        )
        _cache_fallback_reason = f"stream_error_{_responses_path}"
        _use_responses_cache = False
        _can_use_responses = False
        _extra_exp.response_id = None
        _responses_path = ""
        break  # 退出 async for，由外层触发 continue

# 循环结束后
if _cache_fallback_reason.startswith("stream_error") and not _should_stop:
    tool_call_requests = []
    assist_content = ""
    session_finished = False
    continue  # 重走路径C
```

### 3.4 核心代码：缓存保存

```python
# 推理结束后，保存 response_id + prefix_hash 用于下次推理
if _can_use_responses and _stream_meta.response_id:
    _extra_exp.response_id = _stream_meta.response_id
    _extra_exp.prefix_hash = _current_prefix_hash
```

**关键点**：
- `response_id` 和 `prefix_hash` 保存在 `context.extra_for_experiment` 中
- 通过 `end` 事件下发给客户端，下一轮请求中原样带回
- 客户端不感知缓存逻辑，只负责透传

### 3.5 Responses API 请求体构建

```python
def _build_responses_body(self, input_messages, tools=None, 
                          previous_response_id="", request_id="") -> dict:
    """构造 Responses API 请求体"""
    normalized = self._normalize_messages(input_messages)
    responses_input = self._convert_to_responses_input(normalized)
    
    body = {
        "model": self.model_name,
        "input": responses_input,
        "stream": True,
        "caching": {"type": "enabled"},
        "thinking": {"type": self.thinking_type},
    }
    
    if previous_response_id:
        body["previous_response_id"] = previous_response_id
        # 路径A：服务端已存 function_call，input 中只需 function_call_output
        body["input"] = [
            item for item in responses_input
            if item.get("type") == "function_call_output"
        ]
    
    # 带 previous_response_id 时不可重传 tools（API 约束）
    if tools and not previous_response_id:
        body["tools"] = self._wrap_tools_for_responses(tools)
    
    return body
```

**关键设计**：
- 路径A 时只传 `function_call_output`（tool_results 增量），不传 tools
- 路径B 时传完整 messages + tools
- `caching: {"type": "enabled"}` 启用服务端 KV Cache

### 3.6 消息格式转换

```python
@staticmethod
def _convert_to_responses_input(messages):
    """将 Chat Completions 格式转换为 Responses API 格式"""
    result = []
    for msg in messages:
        role = msg.get("role", "")
        if role == "assistant":
            tool_calls = msg.get("tool_calls")
            if tool_calls:
                # 展开为独立的 function_call items
                for tc in tool_calls:
                    func = tc.get("function", {})
                    result.append({
                        "type": "function_call",
                        "call_id": tc.get("id", ""),
                        "name": func.get("name", ""),
                        "arguments": func.get("arguments", "{}"),
                    })
            else:
                result.append({"role": "assistant", "content": msg.get("content", "")})
        elif role == "tool":
            result.append({
                "type": "function_call_output",
                "call_id": msg.get("tool_call_id", ""),
                "output": msg.get("content", ""),
            })
        else:
            result.append(msg)
    return result