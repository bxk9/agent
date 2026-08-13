# Utils 模块详细文档

## 1. 模块概述

### 1.1 模块职责
Utils 模块提供项目所需的各种工具函数和基础设施，包括：
- **LLM调用**：封装大模型API调用（OpenAI兼容、SGLang原生）
- **日志系统**：结构化日志记录与追踪
- **HTTP客户端**：连接池化的HTTP请求客户端
- **认证工具**：API签名生成
- **会话管理**：HTTP会话复用

### 1.2 文件结构
```
utils/
├── request_llm.py       # OpenAI兼容接口调用（旧版）
├── request_llm_v2.py    # SGLang原生接口调用（新版，支持早停）
├── logger.py            # 日志系统配置
├── auth_util.py         # API认证签名生成
├── misc.py              # 杂项工具函数
└── requests_session.py  # HTTP会话管理
```

## 2. LLM 调用模块

### 2.1 request_llm.py - OpenAI兼容接口

#### 2.1.1 HTTP客户端管理

```python
# 全局复用的 httpx.AsyncClient
_async_http_client: httpx.AsyncClient | None = None

def _get_async_http_client() -> httpx.AsyncClient:
    global _async_http_client
    if _async_http_client is None:
        _async_http_client = httpx.AsyncClient(
            timeout=httpx.Timeout(60.0, connect=5.0),
            limits=httpx.Limits(max_connections=200, max_keepalive_connections=100),
        )
    return _async_http_client

async def close_async_http_client():
    """在应用关闭时调用，优雅释放连接池"""
    global _async_http_client
    if _async_http_client is not None:
        await _async_http_client.aclose()
        _async_http_client = None
```

**连接池配置**：
- `max_connections=200`: 最大连接数
- `max_keepalive_connections=100`: 保持活动的连接数
- `timeout=60s`: 请求超时时间
- `connect=5s`: 连接超时时间

**设计要点**：
- 单例模式，全局复用同一个客户端
- 连接池化，避免频繁创建/销毁连接
- 提供优雅关闭方法

#### 2.1.2 OpenAI客户端缓存

```python
_client_cache = {}
def get_client(base_url):
    if base_url not in _client_cache:
        _client_cache[base_url] = OpenAI(api_key='', base_url=base_url)
    return _client_cache[base_url]

_async_client_cache = {}
def _get_async_openai_client(base_url):
    if base_url not in _async_client_cache:
        _async_client_cache[base_url] = AsyncOpenAI(api_key='EMPTY', base_url=base_url)
    return _async_client_cache[base_url]
```

**缓存策略**：
- 按 `base_url` 缓存客户端实例
- 避免重复创建客户端对象
- 支持同步和异步两种客户端

#### 2.1.3 OpenAI兼容调用

```python
async def call_openai_compatible_async(prompt, fill_end, base_url, model_name, temperature=0, extra_body=None):
    client = _get_async_openai_client(base_url)
    response = await client.chat.completions.create(
        model=model_name,
        messages=[
            {"role": "system", "content": prompt},
            {"role": "user", "content": fill_end}
        ],
        stream=False,
        temperature=temperature,
        seed=42,
        extra_body=extra_body or EXTRA_BODY_DEFAULT,
    )
    logger.bind(traceId=trace_id_ctx_var.get()).info(f"模型请求id:{response.id}")
    return response.choices[0].message.content
```

**参数说明**：
- `prompt`: 系统提示词
- `fill_end`: 用户输入（已填充工具定义和query）
- `base_url`: 模型服务地址
- `model_name`: 模型名称
- `temperature`: 温度参数（默认0，保证确定性）
- `seed`: 随机种子（固定为42，保证可复现）
- `extra_body`: 额外参数（如关闭思考模式）

#### 2.1.4 模型调用封装

```python
EXTRA_BODY_STRICT = {
    "chat_template_kwargs": {"enable_thinking": False},
    "top_k": 1,
    "top_p": 0.01,
    "repetition_penalty": 1.0,
    "max_new_tokens": 50,
}

async def call_30b(tools_content, content, trace_id_ctx_var, model_name="qwen3-moe-30b-pre", env='v1', special_flag=1):
    content = user_prompt.replace("{{TOOLS}}", tools_content or ' ').replace('{{USER_QUERY}}', content)
    return await call_openai_compatible_async(
        system_prompt_compressed if special_flag else system_prompt_no_reason_special,
        content,
        base_url=router_router_config + '/v1',
        model_name=model_name,
        temperature=0,
        extra_body=EXTRA_BODY_STRICT,
    )
```

**严格模式参数**：
- `enable_thinking=False`: 关闭思考模式，直接输出
- `top_k=1`: 只考虑概率最高的token
- `top_p=0.01`: 极小的采样范围
- `repetition_penalty=1.0`: 无重复惩罚
- `max_new_tokens=50`: 限制最大生成长度

### 2.2 request_llm_v2.py - SGLang原生接口（支持早停）

#### 2.2.1 早停标签定义

```python
# 触发早停的 8 个标签
EARLY_STOP_LABELS = [
    "multi", "chat", "pend", "qa",
    "infer", "vague", "cond", "abnormal",
]

# task1 所有合法标签 -> 命中后需要跳过的字段数
TASK1_SKIP_MAP = {
    "qa": 3,      # qa 后面三个字段全跳过
    "multi": 2,   # multi 后面两个字段跳过
    "chat": 2,
    "pend": 2,
}

# task2/task3/task4 触发早停的标签 -> 命中后需要跳过的字段数
TASKN_SKIP_MAP = {
    "task2": {"infer": 2, "vague": 2},
    "task3": {"cond": 1},
    "task4": {"abnormal": 0},
}
```

**早停策略**：
- 字段1（工具类型）：`multi`, `chat`, `pend`, `qa` 触发早停
- 字段2（意图明确度）：`infer`, `vague` 触发早停
- 字段3（指令类型）：`cond` 触发早停
- 字段4（执行状态）：`abnormal` 触发早停（但不跳过字段）

#### 2.2.2 Stop Token IDs

```python
# 硬编码 stop token ids（来自实验，字段位置相关）
STOP_TOKEN_IDS = [
    # field_1 早停标签
    25429,  # multi
    9398,   # chat
    3613,   # pend
    14992,  # qa
    # field_2 早停标签
    22846,  # infer
    37753,  # vague
    # field_3 早停标签
    9464,   # cond
    # field_4 早停标签
    33418,  # abnormal
]

# id -> label 反查表
STOP_ID_TO_LABEL = {v: k for k, v in zip(EARLY_STOP_LABELS, STOP_TOKEN_IDS)}
```

**Token ID来源**：
- 通过实验确定每个标签对应的token ID
- 与模型的tokenizer绑定
- 需要随模型版本更新

#### 2.2.3 SGLang /generate 调用

```python
async def call_sglang_generate(
    tools_content, 
    content,
    trace_id,
    *,
    base_url: str,
    model: str = "qwen3.5-35b",
    max_tokens: int = 50,
    temperature: float = 0.0,
    top_k: int = 1,
    top_p: float = 0.01,
    special_flag=1
):
    """调用 SGLang 原生 /generate，使用 stop_token_ids 早停"""
    start = time.perf_counter()
    
    client = _get_async_http_client()
    stop_token_ids = STOP_TOKEN_IDS
    id_to_label = STOP_ID_TO_LABEL
    
    # 构建 Qwen chat template 格式
    prompt = system_prompt_compressed_space if special_flag else system_prompt_no_reason_special
    content = user_prompt.replace("{{TOOLS}}", tools_content or ' ').replace('{{USER_QUERY}}', content)
    prompt = f"""<|im_start|>system\n{prompt}<|im_end|>
<|im_start|>user\n{content}<|im_end|>
<|im_start|>assistant\n<think>
</think>

"""
    
    payload = {
        "text": prompt,
        "sampling_params": {
            "temperature": temperature,
            "top_k": top_k,
            "top_p": top_p,
            "max_new_tokens": max_tokens,
            "repetition_penalty": 1.0,
            "stop_token_ids": stop_token_ids,
        },
    }
    
    resp = await client.post(
        f'{router_router_config}/generate',
        json=payload,
    )
    resp.raise_for_status()
    data = resp.json()
    
    # 解析返回结果
    output_text = data.get("text", "")
    meta_info = data.get("meta_info", {})
    finish_reason = meta_info.get("finish_reason", {}).get("type", "")
    completion_tokens = meta_info.get("completion_tokens", 0)
    
    # 从 output_ids 反查标签
    output_ids = data.get("output_ids", [])
    matched_token_id = None
    matched_label = None
    if output_ids:
        last_token_id = output_ids[-1]
        if last_token_id in id_to_label:
            matched_token_id = last_token_id
            matched_label = id_to_label[last_token_id]
    
    latency_ms = (time.perf_counter() - start) * 1000
    logger.info(
        f"[sglang_generate] trace_id={trace_id} model={model} latency={latency_ms:.1f}ms "
        f"completion_tokens={completion_tokens} finish={finish_reason} matched={matched_label} "
        f"output_ids={output_ids}"
    )
    
    return {
        "output_text": output_text,
        "output_ids": output_ids,
        "matched_token_id": matched_token_id,
        "matched_label": matched_label,
        "completion_tokens": completion_tokens,
        "finish_reason": finish_reason,
    }
```

**核心流程**：
1. **构建Prompt**：使用Qwen chat template格式
2. **设置采样参数**：包含 `stop_token_ids`
3. **调用/generate**：发送POST请求到SGLang
4. **解析结果**：提取生成文本和命中标签
5. **反查标签**：从output_ids最后一个token反查标签名
6. **记录日志**：记录耗时、token数、命中标签

**返回结构**：
```python
{
    "output_text": "single clear",           # 生成的文本（不含stop token）
    "output_ids": [12345, 67890, 25429],     # 生成的token ids
    "matched_token_id": 25429,               # 命中的stop token id
    "matched_label": "multi",                # 命中的标签名
    "completion_tokens": 3,                  # 生成的token数
    "finish_reason": "stop"                  # 完成原因
}
```

#### 2.2.4 早停优化效果

**传统方式**：
```
模型生成: "single clear norm ok"
Token数: 4个标签 + 3个分隔符 = 7 tokens
耗时: ~100ms
```

**早停方式**：
```
模型生成到 "multi" 时停止
Token数: 1个标签 = 1 token
耗时: ~20ms
```

**性能提升**：
- Token生成减少 85%
- 延迟降低 80%
- 对于可早停的场景效果显著

## 3. 日志系统

### 3.1 logger.py 配置

#### 3.1.1 追踪ID上下文

```python
from contextvars import ContextVar

# 定义全局 ContextVar 变量
trace_id_ctx_var: ContextVar[str] = ContextVar('trace_id', default='')
```

**用途**：
- 在异步环境中传递追踪ID
- 关联同一请求的所有日志
- 支持分布式追踪
