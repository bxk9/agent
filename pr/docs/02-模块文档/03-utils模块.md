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

#### 3.1.2 结构化日志格式

```python
def custom_format(record):
    """适配平台的日志格式"""
    # 限制 message 和 stacktrace 长度
    message = record["message"][:10 * 1024]  # 限制 10KB
    exception = record.get("exception")
    stacktrace = (
        "".join(traceback.format_exception(*exception))[:10 * 1024]
        if exception
        else None
    )
    
    # 转换为 UTC 时间
    tm = time.time()
    msc = int(tm * 1000) % 1000
    nowtime = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(int(tm)))
    nowtime += ".{}Z".format(msc)
    
    # 构造 JSON 格式日志
    log_json = {
        "thread_name": record["thread"].name,
        "message": message,
        "@timestamp": nowtime,
        "level": record["level"].name,
        "mdc": {"traceId": record["extra"].get("traceId", "")},
        "file": os.path.basename(record["file"].name) if record["file"] else None,
        "class": record["name"],
        "line_number": record["line"],
        "logger_name": record["name"],
        "method": record["function"],
        "@version": 1,
        "source_host": local_host,
        "stacktrace": stacktrace,
    }
    return json.dumps(log_json, ensure_ascii=False)
```

**日志字段**：
- `thread_name`: 线程名称
- `message`: 日志消息（限制10KB）
- `@timestamp`: UTC时间戳（毫秒精度）
- `level`: 日志级别
- `mdc.traceId`: 追踪ID
- `file`: 源文件名
- `line_number`: 行号
- `method`: 方法名
- `source_host`: 主机名
- `stacktrace`: 异常堆栈（限制10KB）

#### 3.1.3 日志输出配置

```python
if check_online():
    # 线上环境：输出到文件
    LOG_DIR = os.environ.get('LOG_DIR', '/data/intent-tool-retrieval/logs/biz/')
    os.makedirs(LOG_DIR, exist_ok=True)
    log_file_template = os.path.join(LOG_DIR, f"vivo_biz_{APP_NAME}.log.{{time:YYYYMMDDHH}}")
    logger.add(
        sink=log_file_template,
        rotation='1 hour',           # 每小时轮转
        format="{message}",
        serialize=False,
        retention='10 days',         # 保留10天
        encoding="utf-8",
    )
    logger = logger.patch(lambda record: record.update(message=custom_format(record)))
else:
    # 本地环境：输出到控制台和文件
    logger.add(
        "log/app.log", 
        rotation='10 MB', 
        retention='10 days', 
        compression='zip', 
        level="INFO", 
        format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {file} | {function} | Line: {line} | Thread: {thread.name} | {message}"
    )
```

**环境适配**：
- **线上环境**：JSON格式，按小时轮转，便于日志收集
- **本地环境**：可读格式，按大小轮转，便于调试

### 3.2 日志使用示例

```python
from utils.logger import logger, trace_id_ctx_var

# 设置追踪ID
trace_id_ctx_var.set("trace-123")

# 绑定追踪ID记录日志
logger.bind(traceId=trace_id_ctx_var.get()).info(
    f"query: {query}, history: {chat_history}"
)

# 记录错误
logger.bind(traceId=trace_id_ctx_var.get()).error(
    f"处理失败: {error_message}"
)

# 记录警告
logger.bind(traceId=trace_id_ctx_var.get()).warning(
    f"向量搜索超时，降级处理"
)
```

## 4. 认证工具

### 4.1 auth_util.py

#### 4.1.1 签名生成

```python
def gen_sign_headers(app_id, app_key, method, uri, query):
    """生成API签名头"""
    method = str(method).upper()
    timestamp = str(int(time.time()))
    nonce = gen_nonce()
    
    # 构建规范化的查询字符串
    canonical_query_string = gen_canonical_query_string(query)
    
    # 构建签名字符串
    signed_headers_string = 'x-ai-gateway-app-id:{}\nx-ai-gateway-timestamp:{}\n' \
                            'x-ai-gateway-nonce:{}'.format(app_id, timestamp, nonce)
    signing_string = '{}\n{}\n{}\n{}\n{}\n{}'.format(
        method,
        uri,
        canonical_query_string,
        app_id,
        timestamp,
        signed_headers_string
    )
    
    # 生成签名
    signing_string = signing_string.encode('utf-8')
    signature = gen_signature(app_key, signing_string)
    
    return {
        'Content-Type': 'text/event-stream',
        'X-AI-GATEWAY-APP-ID': app_id,
        'X-AI-GATEWAY-TIMESTAMP': timestamp,
        'X-AI-GATEWAY-NONCE': nonce,
        'X-AI-GATEWAY-SIGNED-HEADERS': "x-ai-gateway-app-id;x-ai-gateway-timestamp;x-ai-gateway-nonce",
        'X-AI-GATEWAY-SIGNATURE': signature
    }
```

**签名流程**：
1. 生成时间戳和随机数
2. 构建规范化的查询字符串
3. 拼接签名字符串
4. 使用HMAC-SHA256生成签名
5. 返回认证头

#### 4.1.2 辅助函数

```python
def gen_nonce(length=8):
    """生成随机字符串"""
    chars = string.ascii_lowercase + string.digits
    return ''.join([random.choice(chars) for _ in range(length)])

def gen_canonical_query_string(params):
    """构建规范化的查询字符串"""
    if params:
        escape_uri = urllib.parse.quote
        raw = []
        for k in sorted(params.keys()):
            tmp_tuple = (escape_uri(k), escape_uri(str(params[k])))
            raw.append(tmp_tuple)
        s = "&".join("=".join(kv) for kv in raw)
        return s
    else:
        return ''

def gen_signature(app_secret, signing_string):
    """生成HMAC-SHA256签名"""
    bytes_secret = app_secret.encode('utf-8')
    hash_obj = hmac.new(bytes_secret, signing_string, hashlib.sha256)
    bytes_sig = base64.b64encode(hash_obj.digest())
    signature = str(bytes_sig, encoding='utf-8')
    return signature
```

## 5. 杂项工具

### 5.1 misc.py

```python
import os, ast

ENV = os.environ.get("APP_ENV", "dev").lower()

def check_online():
    """检查是否为线上环境"""
    return ENV == "prd" or ENV == 'pre' or ENV == 'test'

def safe_eval(text):
    """安全的 eval 解析，解析失败返回原文本或空字典"""
    if not isinstance(text, str):
        return text
    try:
        return ast.literal_eval(text)
    except:
        return text
```

**函数说明**：
- `check_online()`: 判断是否为线上环境（prd/pre/test）
- `safe_eval()`: 安全地解析字符串为Python对象，避免使用危险的 `eval()`

## 6. HTTP会话管理

### 6.1 requests_session.py

```python
import contextvars
import requests
from requests.adapters import HTTPAdapter

session_var = contextvars.ContextVar('session')

# 全局共享的adapter
_shared_adapter = HTTPAdapter(
    pool_connections=10,
    pool_maxsize=500,
    pool_block=True
)

def get_session():
    """获取HTTP会话（线程安全）"""
    try:
        return session_var.get()
    except LookupError:
        s = requests.Session()
        s.mount('http://', _shared_adapter)
        s.mount('https://', _shared_adapter)
        session_var.set(s)
        return s
```

**设计要点**：
- 使用 `ContextVar` 实现线程安全的会话管理
- 全局共享 `HTTPAdapter`，复用连接池
- 连接池配置：10个连接池，每个池最大500连接

**使用示例**：
```python
from utils.requests_session import get_session

session = get_session()
response = session.post(url, json=payload, timeout=10)
```

## 7. 设计理念总结

### 7.1 连接池化
- HTTP客户端全局复用
- OpenAI客户端按base_url缓存
- HTTPAdapter共享连接池
- 避免频繁创建/销毁连接

### 7.2 早停优化
- 使用SGLang原生 `/generate` 接口
- 通过 `stop_token_ids` 实现早停
- 减少不必要的token生成
- 显著降低延迟

### 7.3 结构化日志
- JSON格式，便于日志收集
- 追踪ID关联完整请求链路
- 限制日志大小，避免磁盘爆满
- 环境适配，线上/本地不同格式

### 7.4 安全认证
- HMAC-SHA256签名
- 时间戳防重放攻击
- 随机数保证唯一性
- 规范化查询字符串

### 7.5 线程安全
- ContextVar传递上下文
- 会话管理线程安全
- 连接池并发安全

## 8. 性能优化建议

### 8.1 连接池调优
```python
# 根据并发量调整连接池大小
limits=httpx.Limits(
    max_connections=200,              # 总连接数
    max_keepalive_connections=100,    # 保持活动连接数
)
```

### 8.2 超时设置
```python
# 根据服务响应时间调整超时
timeout=httpx.Timeout(
    60.0,        # 总超时
    connect=5.0  # 连接超时
)
```

### 8.3 早停标签优化
- 定期统计早停命中率
- 调整早停标签集合
- 更新token ID映射

### 8.4 日志优化
- 限制日志大小（10KB）
- 异步写入日志
- 定期清理旧日志

## 9. 常见问题

### 9.1 连接池耗尽
**现象**：请求超时，日志显示连接池满

**解决方案**：
```python
# 增加连接池大小
limits=httpx.Limits(max_connections=500, max_keepalive_connections=200)
```

### 9.2 早停未生效
**现象**：模型生成了完整的4个字段

**排查方法**：
1. 检查 `stop_token_ids` 是否正确
2. 检查模型是否支持该token ID
3. 查看 `output_ids` 最后一个token

### 9.3 日志丢失
**现象**：部分日志未写入文件

**可能原因**：
1. 日志轮转时丢失
2. 磁盘空间不足
3. 权限问题

**解决方案**：
1. 检查日志目录权限
2. 监控磁盘空间
3. 调整轮转策略

## 10. 最佳实践

1. **客户端复用**：始终使用缓存的客户端，避免重复创建
2. **优雅关闭**：应用关闭时调用 `close_async_http_client()`
3. **追踪ID**：每个请求设置唯一的trace_id
4. **日志级别**：合理使用INFO/WARNING/ERROR
5. **异常处理**：捕获异常并记录完整堆栈
6. **性能监控**：记录关键操作的耗时
7. **定期更新**：随模型版本更新token ID映射
