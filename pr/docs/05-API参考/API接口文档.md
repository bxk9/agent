# Dynamic Router API 接口文档

> 版本：v2.0.0  
> 最后更新：2024-01-XX

## 📋 目录

- [概述](#概述)
- [基础信息](#基础信息)
- [认证方式](#认证方式)
- [接口列表](#接口列表)
  - [POST /router - 主路由接口](#post-router---主路由接口)
  - [POST /completion - 补全接口](#post-completion---补全接口)
  - [POST /router_test - 测试接口](#post-router_test---测试接口)
  - [GET /check.do - 健康检查](#get-checkdo---健康检查)
- [数据模型](#数据模型)
- [错误码说明](#错误码说明)
- [使用示例](#使用示例)
- [SDK 示例](#sdk-示例)
- [常见问题](#常见问题)

---

## 概述

Dynamic Router 提供 RESTful API 接口，用于对用户 query 进行智能路由分类。系统基于大语言模型，从四个维度对用户意图进行分类：

1. **工具调用类型** (is_use_tool)：single/multi/qa/chat/pend/unsupported/specific
2. **意图明确度** (is_intent_specific)：clear/lack/infer/vague
3. **指令类型** (is_special_instruction)：norm/cond
4. **执行反馈状态** (is_exe_success)：ok/abnormal

最终输出任务复杂度判定：`easy`（简单任务）或 `complex`（复杂任务）。

---

## 基础信息

### 服务地址

| 环境 | 地址 | 说明 |
|------|------|------|
| 开发环境 | `http://localhost:19777` | 本地开发 |
| 测试环境 | `http://intent-tool-router-test.example.com` | 测试验证 |
| 预发环境 | `http://intent-tool-router-pre.example.com` | 预发布验证 |
| 生产环境 | `http://intent-tool-router.example.com` | 生产服务 |

### 请求格式

- **Content-Type**: `application/json`
- **字符编码**: UTF-8
- **请求方法**: POST / GET

### 响应格式

所有接口统一返回 JSON 格式：

```json
{
  "task_type": "easy",
  "is_intent_specific": "clear",
  "is_use_tool": "single",
  "is_special_instruction": "norm",
  "is_exe_success": "ok",
  "post_type": ""
}
```

---

## 认证方式

### API 签名认证

对于生产环境，需要在请求头中添加签名信息：

```http
X-AI-GATEWAY-APP-ID: your_app_id
X-AI-GATEWAY-TIMESTAMP: 1234567890
X-AI-GATEWAY-NONCE: random_string
X-AI-GATEWAY-SIGNED-HEADERS: x-ai-gateway-app-id;x-ai-gateway-timestamp;x-ai-gateway-nonce
X-AI-GATEWAY-SIGNATURE: hmac_sha256_signature
```

**签名生成算法：**

```python
import hmac
import hashlib
import base64
import time
import random
import string

def generate_signature(app_id, app_key, method, uri, params):
    """生成 API 签名"""
    timestamp = str(int(time.time()))
    nonce = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    
    # 构建规范化的查询字符串
    canonical_query = '&'.join([
        f"{k}={v}" for k, v in sorted(params.items())
    ])
    
    # 构建签名头字符串
    signed_headers = f"x-ai-gateway-app-id:{app_id}\nx-ai-gateway-timestamp:{timestamp}\nx-ai-gateway-nonce:{nonce}"
    
    # 构建签名字符串
    signing_string = f"{method}\n{uri}\n{canonical_query}\n{app_id}\n{timestamp}\n{signed_headers}"
    
    # 生成签名
    signature = base64.b64encode(
        hmac.new(
            app_key.encode('utf-8'),
            signing_string.encode('utf-8'),
            hashlib.sha256
        ).digest()
    ).decode('utf-8')
    
    return {
        'X-AI-GATEWAY-APP-ID': app_id,
        'X-AI-GATEWAY-TIMESTAMP': timestamp,
        'X-AI-GATEWAY-NONCE': nonce,
        'X-AI-GATEWAY-SIGNED-HEADERS': 'x-ai-gateway-app-id;x-ai-gateway-timestamp;x-ai-gateway-nonce',
        'X-AI-GATEWAY-SIGNATURE': signature
    }
```

---

## 接口列表

### POST /router - 主路由接口

对用户 query 进行智能路由分类。

#### 请求参数

**Request Body** (JSON):

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| query | string | 是 | - | 用户当前输入的 query |
| tools | array | 是 | - | 候选工具列表 |
| chat_history | array | 否 | [] | 历史对话列表 |
| trace_id | string | 否 | "" | 追踪 ID，用于日志追踪 |
| need_dispatch | boolean | 否 | false | 是否启用正则模板匹配 |
| copilot_env | string | 否 | "v1" | Copilot 环境标识 |
| base_url | string | 否 | "" | 自定义模型服务地址 |
| extra | object | 否 | null | 扩展参数 |

**tools 数组元素结构**：

```json
{
  "key": "create_alarm",
  "function_name": ["timeAndSchedule.createAlarmClock"]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| key | string | 工具意图名称 |
| function_name | array | MCP 工具全限定名列表 |

**chat_history 数组元素结构**：

```json
{
  "role": "user",
  "content": "帮我定一个明天早上8点的闹钟"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| role | string | 角色：user / assistant |
| content | string | 对话内容 |

#### 请求示例

```bash
curl -X POST http://localhost:19777/router \
  -H "Content-Type: application/json" \
  -d '{
    "query": "帮我定一个明天早上8点的闹钟",
    "tools": [
      {
        "key": "create_alarm",
        "function_name": ["timeAndSchedule.createAlarmClock"]
      },
      {
        "key": "search_alarm",
        "function_name": ["timeAndSchedule.queryAlarmClock"]
      }
    ],
    "chat_history": [],
    "trace_id": "trace-123",
    "need_dispatch": true,
    "copilot_env": "v1"
  }'
```

#### 响应参数

**Response Body** (JSON):

| 参数名 | 类型 | 说明 |
|--------|------|------|
| task_type | string | 任务复杂度：easy / complex |
| is_use_tool | string | 工具调用类型 |
| is_intent_specific | string | 意图明确度 |
| is_special_instruction | string | 指令类型 |
| is_exe_success | string | 执行反馈状态 |
| post_type | string | 后处理类型 |

**is_use_tool 可选值**：

| 值 | 说明 | 复杂度 |
|----|------|--------|
| single | 单工具调用 | easy |
| multi | 多工具调用 | complex |
| qa | 知识问答 | easy |
| chat | 闲聊 | complex |
| pend | 工具待确定 | complex |
| unsupported | 工具不支持 | easy |
| specific | 特殊工具 | complex |

**is_intent_specific 可选值**：

| 值 | 说明 | 复杂度 |
|----|------|--------|
| clear | 意图清晰 | easy |
| lack | 参数不足 | easy |
| infer | 参数需推理 | complex |
| vague | 意图模糊 | complex |

**is_special_instruction 可选值**：

| 值 | 说明 | 复杂度 |
|----|------|--------|
| norm | 普通指令 | easy |
| cond | 条件指令 | complex |

**is_exe_success 可选值**：

| 值 | 说明 | 复杂度 |
|----|------|--------|
| ok | 正常推进 | easy |
| abnormal | 异常反馈 | complex |

**post_type 可选值**：

| 值 | 说明 |
|----|------|
| "" | 无后处理 |
| hit_vector | 命中向量库 |
| hit_unsupported | 命中不支持工具 |
| hit_multi_slot | 命中多槽位工具 |
| hit_modify_task | 命中修改类任务 |

#### 响应示例

**简单任务**：

```json
{
  "task_type": "easy",
  "is_intent_specific": "clear",
  "is_use_tool": "single",
  "is_special_instruction": "norm",
  "is_exe_success": "ok",
  "post_type": ""
}
```

**复杂任务**：

```json
{
  "task_type": "complex",
  "is_intent_specific": "vague",
  "is_use_tool": "multi",
  "is_special_instruction": "cond",
  "is_exe_success": "ok",
  "post_type": ""
}
```

**命中向量库**：

```json
{
  "task_type": "easy",
  "is_intent_specific": "clear",
  "is_use_tool": "single",
  "is_special_instruction": "norm",
  "is_exe_success": "ok",
  "post_type": "hit_vector"
}
```

---

### POST /completion - 补全接口

用于正则模板匹配。

#### 请求参数

**Request Body** (JSON):

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| query | string | 是 | 用户 query |
| tools | array | 否 | 工具列表 |

#### 请求示例

```bash
curl -X POST http://localhost:19777/completion \
  -H "Content-Type: application/json" \
  -d '{
    "query": "定一个明天早上8点的闹钟",
    "tools": [
      {
        "domain": "时间与日程"
      }
    ]
  }'
```

#### 响应参数

**Response Body** (JSON):

```json
{
  "template": {
    "matched": true,
    "match_domain": "timeAndSchedule",
    "match_template": "(定|设置|设|打开|整|调|开|上)(一个|个)?(今天|明天|明早|今早|明晚|今晚)(早上|早晨|上午|中午|下午|晚上)?(.+点)(钟|半)?(的)?(闹钟|闹铃)"
  },
  "entropy": {
    "matched": false
  }
}
```

| 参数名 | 类型 | 说明 |
|--------|------|------|
| template.matched | boolean | 是否匹配成功 |
| template.match_domain | string | 匹配的领域 |
| template.match_template | string | 匹配的正则模板 |
| entropy.matched | boolean | 是否命中熵阈值 |

---

### POST /router_test - 测试接口

用于测试和调试，支持自定义模型地址。

#### 请求参数

与 `/router` 接口相同，额外支持：

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| base_url | string | 否 | 自定义模型服务地址 |

#### 请求示例

```bash
curl -X POST http://localhost:19777/router_test \
  -H "Content-Type: application/json" \
  -d '{
    "query": "帮我定一个明天早上8点的闹钟",
    "tools": [
      {
        "key": "create_alarm",
        "function_name": ["timeAndSchedule.createAlarmClock"]
      }
    ],
    "base_url": "http://custom-model-server:8080"
  }'
```

#### 响应参数

与 `/router` 接口相同。

---

### GET /check.do - 健康检查

检查服务健康状态。

#### 请求示例

```bash
curl http://localhost:19777/check.do
```

#### 响应示例

```html
<html>
  <head><title>heartbeat</title></head>
  <body><h1>hello world</h1></body>
</html>
```

**状态码**：200 OK

---

## 数据模型

### Params 模型

```python
from pydantic import BaseModel
from typing import Optional, Union, Any

class Params(BaseModel):
    query: Optional[Union[str, int, float]] = ''
    chat_history: Optional[list] = []
    scene: Optional[dict] = {}
    session_id: Optional[str] = ''
    request_id: Optional[str] = ''
    tools: Optional[list] = []
    tools_history: Optional[list] = []
    trace_id: Optional[str] = ''
    need_dispatch: Optional[bool] = False
    copilot_env: Optional[str] = 'v1'
    base_url: Optional[str] = ''
    extra: Optional[Any] = None
```

### RouterResult 模型

```python
from pydantic import BaseModel

class RouterResult(BaseModel):
    task_type: str  # easy / complex
    is_intent_specific: str  # clear / lack / infer / vague
    is_use_tool: str  # single / multi / qa / chat / pend / unsupported / specific
    is_special_instruction: str  # norm / cond
    is_exe_success: str  # ok / abnormal
    post_type: str  # "" / hit_vector / hit_unsupported / ...
```

---

## 错误码说明

### HTTP 状态码

| 状态码 | 说明 | 处理建议 |
|--------|------|----------|
| 200 | 成功 | 正常处理响应 |
| 400 | 请求参数错误 | 检查请求参数格式 |
| 401 | 认证失败 | 检查签名信息 |
| 422 | 参数验证失败 | 检查必填参数 |
| 500 | 服务器内部错误 | 联系技术支持 |
| 503 | 服务不可用 | 稍后重试 |

### 业务错误码

当发生错误时，返回统一的错误格式：

```json
{
  "task_type": "complex",
  "is_intent_specific": "err",
  "is_use_tool": "err",
  "is_special_instruction": "err",
  "is_exe_success": "err",
  "post_type": ""
}
```

**错误场景**：

| 场景 | 说明 |
|------|------|
| 模型推理失败 | LLM 服务异常或超时 |
| 字段校验失败 | 模型输出不符合预期格式 |
| 向量检索失败 | VSearch 服务异常（降级处理） |
| 配置加载失败 | 配置中心不可用（降级处理） |

---

## 使用示例

### cURL 示例

#### 基本调用

```bash
curl -X POST http://localhost:19777/router \
  -H "Content-Type: application/json" \
  -d '{
    "query": "帮我定一个明天早上8点的闹钟",
    "tools": [
      {
        "key": "create_alarm",
        "function_name": ["timeAndSchedule.createAlarmClock"]
      }
    ],
    "chat_history": [],
    "trace_id": "test-001"
  }'
```

#### 带历史对话

```bash
curl -X POST http://localhost:19777/router \
  -H "Content-Type: application/json" \
  -d '{
    "query": "改成9点",
    "tools": [
      {
        "key": "create_alarm",
        "function_name": ["timeAndSchedule.createAlarmClock"]
      }
    ],
    "chat_history": [
      {
        "role": "user",
        "content": "帮我定一个明天早上8点的闹钟"
      },
      {
        "role": "assistant",
        "content": "好的，已为您设置明天早上8点的闹钟"
      }
    ],
    "trace_id": "test-002"
  }'
```

#### 启用正则匹配

```bash
curl -X POST http://localhost:19777/router \
  -H "Content-Type: application/json" \
  -d '{
    "query": "定一个明天早上8点的闹钟",
    "tools": [
      {
        "key": "create_alarm",
        "function_name": ["timeAndSchedule.createAlarmClock"]
      }
    ],
    "need_dispatch": true,
    "trace_id": "test-003"
  }'
```

### Python 示例

#### 基本调用

```python
import requests

url = "http://localhost:19777/router"
payload = {
    "query": "帮我定一个明天早上8点的闹钟",
    "tools": [
        {
            "key": "create_alarm",
            "function_name": ["timeAndSchedule.createAlarmClock"]
        }
    ],
    "chat_history": [],
    "trace_id": "test-001"
}

response = requests.post(url, json=payload)
result = response.json()

print(f"任务类型: {result['task_type']}")
print(f"工具类型: {result['is_use_tool']}")
print(f"意图明确度: {result['is_intent_specific']}")
```

#### 带认证签名

```python
import requests
from utils.auth_util import generate_signature

url = "http://intent-tool-router.example.com/router"
app_id = "your_app_id"
app_key = "your_app_key"

payload = {
    "query": "帮我定一个明天早上8点的闹钟",
    "tools": [
        {
            "key": "create_alarm",
            "function_name": ["timeAndSchedule.createAlarmClock"]
        }
    ],
    "chat_history": [],
    "trace_id": "test-001"
}

# 生成签名
headers = generate_signature(
    app_id=app_id,
    app_key=app_key,
    method="POST",
    uri="/router",
    params={}
)
headers["Content-Type"] = "application/json"

response = requests.post(url, json=payload, headers=headers)
result = response.json()

print(result)
```

#### 异步调用

```python
import httpx
import asyncio

async def call_router():
    url = "http://localhost:19777/router"
    payload = {
        "query": "帮我定一个明天早上8点的闹钟",
        "tools": [
            {
                "key": "create_alarm",
                "function_name": ["timeAndSchedule.createAlarmClock"]
            }
        ],
        "chat_history": [],
        "trace_id": "test-001"
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(url, json=payload)
        return response.json()

# 运行异步调用
result = asyncio.run(call_router())
print(result)
```

#### 批量调用

```python
import requests
from concurrent.futures import ThreadPoolExecutor

url = "http://localhost:19777/router"

queries = [
    "帮我定一个明天早上8点的闹钟",
    "播放周杰伦的歌",
    "今天天气怎么样",
    "帮我打个车去机场"
]

def call_router(query):
    payload = {
        "query": query,
        "tools": [
            {
                "key": "create_alarm",
                "function_name": ["timeAndSchedule.createAlarmClock"]
            }
        ],
        "chat_history": [],
        "trace_id": f"batch-{query[:10]}"
    }
    
    response = requests.post(url, json=payload)
    return query, response.json()

# 并发调用
with ThreadPoolExecutor(max_workers=10) as executor:
    results = list(executor.map(call_router, queries))

for query, result in results:
    print(f"Query: {query}")
    print(f"Result: {result}")
    print()
```

### JavaScript 示例

#### Fetch API

```javascript
const url = 'http://localhost:19777/router';
const payload = {
  query: '帮我定一个明天早上8点的闹钟',
  tools: [
    {
      key: 'create_alarm',
      function_name: ['timeAndSchedule.createAlarmClock']
    }
  ],
  chat_history: [],
  trace_id: 'test-001'
};

fetch(url, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(payload)
})
  .then(response => response.json())
  .then(result => {
    console.log('任务类型:', result.task_type);
    console.log('工具类型:', result.is_use_tool);
    console.log('意图明确度:', result.is_intent_specific);
  })
  .catch(error => console.error('Error:', error));
```

#### Axios

```javascript
const axios = require('axios');

const url = 'http://localhost:19777/router';
const payload = {
  query: '帮我定一个明天早上8点的闹钟',
  tools: [
    {
      key: 'create_alarm',
      function_name: ['timeAndSchedule.createAlarmClock']
    }
  ],
  chat_history: [],
  trace_id: 'test-001'
};

axios.post(url, payload)
  .then(response => {
    const result = response.data;
    console.log('任务类型:', result.task_type);
    console.log('工具类型:', result.is_use_tool);
    console.log('意图明确度:', result.is_intent_specific);
  })
  .catch(error => console.error('Error:', error));
```

---

## SDK 示例

### Python SDK

```python
class DynamicRouterClient:
    """Dynamic Router Python SDK"""
    
    def __init__(self, base_url, app_id=None, app_key=None):
        self.base_url = base_url
        self.app_id = app_id
        self.app_key = app_key
    
    def route(self, query, tools, chat_history=None, trace_id=None, **kwargs):
        """调用路由接口"""
        url = f"{self.base_url}/router"
        
        payload = {
            "query": query,
            "tools": tools,
            "chat_history": chat_history or [],
            "trace_id": trace_id or ""
        }
        payload.update(kwargs)
        
        # 生成签名（如果需要）
        headers = {"Content-Type": "application/json"}
        if self.app_id and self.app_key:
            from utils.auth_util import generate_signature
            headers.update(generate_signature(
                self.app_id, self.app_key, "POST", "/router", {}
            ))
        
        response = requests.post(url, json=payload, headers=headers)
        response.raise_for_status()
        
        return response.json()
    
    def health_check(self):
        """健康检查"""
        url = f"{self.base_url}/check.do"
        response = requests.get(url)
        return response.status_code == 200


# 使用示例
client = DynamicRouterClient(
    base_url="http://localhost:19777",
    app_id="your_app_id",
    app_key="your_app_key"
)

result = client.route(
    query="帮我定一个明天早上8点的闹钟",
    tools=[
        {
            "key": "create_alarm",
            "function_name": ["timeAndSchedule.createAlarmClock"]
        }
    ],
    trace_id="sdk-test-001"
)

print(result)
```

---

## 常见问题

### Q1: 如何判断任务是简单还是复杂？

**A**: 查看 `task_type` 字段：
- `easy`: 简单任务，可以直接执行
- `complex`: 复杂任务，需要进一步处理

**判定规则**：
```python
is_complex = (
    is_intent_specific in ["infer", "vague"]
    or is_use_tool in ["multi", "chat", "pend", "specific"]
    or is_special_instruction in ["cond"]
    or is_exe_success in ["abnormal"]
)
```

### Q2: post_type 字段有什么用？

**A**: `post_type` 表示是否触发了后处理逻辑：
- `""`: 无后处理，使用模型原始结果
- `hit_vector`: 命中向量库高分结果，直接返回
- `hit_unsupported`: 命中不支持工具的后处理
- `hit_multi_slot`: 命中多槽位工具的后处理
- `hit_modify_task`: 命中修改类任务的后处理

### Q3: 如何处理错误响应？

**A**: 当所有字段都为 `"err"` 时，表示发生了错误：

```python
result = call_router(query, tools)

if all(v == "err" for k, v in result.items() if k != "post_type"):
    print("路由失败，使用默认策略")
    # 降级处理逻辑
else:
    print(f"路由成功: {result['task_type']}")
```

### Q4: 如何优化调用性能？

**A**: 
1. **启用正则匹配**：设置 `need_dispatch=true`，对于规则明确的 query 可以快速返回
2. **减少历史对话**：只传递最近 3-6 轮对话
3. **使用异步调用**：对于批量请求，使用异步或并发调用
4. **启用连接池**：复用 HTTP 连接，减少连接建立开销

### Q5: 如何调试和排查问题？

**A**:
1. **使用 trace_id**：为每个请求设置唯一的 trace_id，便于日志追踪
2. **查看日志**：通过 trace_id 在服务端日志中查找完整调用链路
3. **使用测试接口**：`/router_test` 支持自定义模型地址，便于调试
4. **检查健康状态**：定期调用 `/check.do` 检查服务健康状态

### Q6: 如何处理超时？

**A**:
```python
import requests
from requests.exceptions import Timeout

try:
    response = requests.post(url, json=payload, timeout=2.0)
    result = response.json()
except Timeout:
    print("请求超时，使用降级策略")
    result = {
        "task_type": "complex",
        "is_intent_specific": "err",
        "is_use_tool": "err",
        "is_special_instruction": "err",
        "is_exe_success": "err",
        "post_type": ""
    }
```

### Q7: 如何监控 API 调用？

**A**:
```python
import time
import requests

def call_router_with_metrics(url, payload):
    """带监控的 API 调用"""
    start_time = time.time()
    
    try:
        response = requests.post(url, json=payload, timeout=2.0)
        latency = time.time() - start_time
        
        # 记录指标
        print(f"Latency: {latency * 1000:.2f} ms")
        print(f"Status: {response.status_code}")
        
        result = response.json()
        print(f"Task Type: {result['task_type']}")
        print(f"Post Type: {result['post_type']}")
        
        return result
    except Exception as e:
        latency = time.time() - start_time
        print(f"Error: {e}, Latency: {latency * 1000:.2f} ms")
        raise
```

---

## 附录

### A. 完整工具列表

详见 [Data 模块文档](../02-模块文档/05-data模块.md) 中的工具意图映射表。

### B. 分类标准详解

详见 [Data Process 模块文档](../02-模块文档/06-data_process模块.md) 中的分类标准定义。

### C. 性能基准

| 指标 | 目标值 | 实际值 |
|------|--------|--------|
| P50 延迟 | < 200ms | ~150ms |
| P99 延迟 | < 500ms | ~350ms |
| 准确率 | > 95% | ~96% |
| 可用性 | > 99.9% | ~99.95% |

### D. 版本历史

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| v2.0.0 | 2024-01 | 支持 SGLang 早停优化，新增多维度分类 |
| v1.0.0 | 2023-12 | 首次发布，基础路由功能 |

---

**文档版本**：v2.0.0  
**最后更新**：2024-01-XX  
**维护团队**：Dynamic Router Team

---

<div align="center">

[📚 返回文档首页](../README.md) | [🏗️ 项目架构](../01-项目概览/项目架构文档.md) | [🔄 数据流程](../03-数据流程/数据流程详解.md)

</div>
