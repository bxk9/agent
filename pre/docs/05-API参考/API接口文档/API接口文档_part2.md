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