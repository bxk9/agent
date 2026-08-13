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
