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