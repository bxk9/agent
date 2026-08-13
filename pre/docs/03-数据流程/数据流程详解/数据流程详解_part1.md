# Dynamic Router 数据流程详解

## 1. 整体数据流概览

### 1.1 请求处理完整流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        客户端请求                                │
│  POST /router                                                   │
│  Body: {query, tools, chat_history, trace_id, ...}             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  [1] API Layer (main.py)                                        │
│  - 参数验证 (Pydantic)                                           │
│  - 设置 trace_id                                                │
│  - 调用 router.search()                                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  [2] Router Layer (router_v2.py)                                │
│  - 提取工具列表 (_extract_tools)                                 │
│  - 构建查询内容 (_build_query)                                   │
│  - 构建工具定义 (_build_tools_content)                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────┴─────────┐
                    ↓                   ↓
        ┌──────────────────┐  ┌──────────────────┐
        │ [3a] 向量检索     │  │ [3b] 模型推理     │
        │ query_recall.py  │  │ request_llm_v2.py│
        └──────────────────┘  └──────────────────┘
                    ↓                   ↓
        ┌──────────────────┐  ┌──────────────────┐
        │ VSearch 服务      │  │ SGLang 服务       │
        │ (外部服务)        │  │ (外部服务)        │
        └──────────────────┘  └──────────────────┘
                    ↓                   ↓
        ┌──────────────────┐  ┌──────────────────┐
        │ 向量结果          │  │ 模型输出          │
        │ {score, type}    │  │ "multi chat ..." │
        └──────────────────┘  └──────────────────┘
                    ↓                   ↓
                    └─────────┬─────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  [4] 结果融合 (router_v2.py)                                    │
│  - 向量高分命中 → 直接返回                                       │
│  - 正则模板命中 → 返回 easy                                      │
│  - 模型结果 → 后处理                                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  [5] 后处理                                                     │
│  - 字段校验                                                      │
│  - 跨维度绑定规则                                                │
│  - task_type 计算                                                │
│  - 特殊场景处理                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  [6] 返回结果                                                   │
│  {                                                              │
│    "task_type": "complex",                                      │
│    "is_intent_specific": "clear",                               │
│    "is_use_tool": "multi",                                      │
│    "is_special_instruction": "norm",                            │
│    "is_exe_success": "ok",                                      │
│    "post_type": ""                                              │
│  }                                                              │
└─────────────────────────────────────────────────────────────────┘
```

## 2. 详细数据流分解

### 2.1 请求参数数据流

#### 2.1.1 原始请求
```json
{
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
}
```

#### 2.1.2 Pydantic 验证后
```python
Params(
    query="帮我定一个明天早上8点的闹钟",
    tools=[
        {"key": "create_alarm", "function_name": ["timeAndSchedule.createAlarmClock"]},
        {"key": "search_alarm", "function_name": ["timeAndSchedule.queryAlarmClock"]}
    ],
    chat_history=[],
    trace_id="trace-123",
    need_dispatch=True,
    copilot_env="v1",
    # 默认值
    tools_history=[],
    session_id="",
    request_id="",
    base_url="",
    extra=None
)
```

#### 2.1.3 工具提取 (_extract_tools)
```python
# 输入
tools = [
    {"key": "create_alarm", "function_name": ["timeAndSchedule.createAlarmClock"]},
    {"key": "search_alarm", "function_name": ["timeAndSchedule.queryAlarmClock"]}
]

# 处理流程
# 1. 过滤 EXCLUDED_KEYS (chattingAndQA, shortcut_condition)
# 2. 展开 function_name
# 3. 通过 global_intention_mcps 映射
# 4. 过滤 EXCLUDED_TOOLS

# 输出
tools_result = [
    "createAlarmClock",
    "queryAlarmClock"
]
```

#### 2.1.4 查询构建 (_build_query)
```python
# 输入
query = "帮我定一个明天早上8点的闹钟"
chat_history = []

# 处理流程
# 1. 格式化历史对话
# 2. 截断处理（如果需要）
# 3. 拼接当前query

# 输出
query_content = """
历史对话:[]

当前轮query：帮我定一个明天早上8点的闹钟
"""
```

#### 2.1.5 工具定义构建 (_build_tools_content)
```python
# 输入
tools = ["createAlarmClock", "queryAlarmClock"]

# 处理流程
# 1. 添加 knowledgeQA
# 2. 根据环境添加特殊工具
# 3. 从 intent_def_dict 获取工具定义
# 4. 从 intent_slot_dict 获取槽位定义
# 5. 格式化并编号

# 输出
tools_content = """
1. 工具名：createAlarmClock。工具说明：创建一个新的闹钟...
当前工具槽位说明：
- time: 闹钟时间
- label: 闹钟标签

2. 工具名：knowledgeQA。工具说明：知识问答工具...
当前工具槽位说明：
- query: 用户问题

3. 工具名：queryAlarmClock。工具说明：查询闹钟列表...
当前工具槽位说明：
- filter: 过滤条件
"""
```

### 2.2 向量检索数据流

#### 2.2.1 请求构建
```python
# 输入
query = "帮我定一个明天早上8点的闹钟"
trace_id = "trace-123"
top_k = 10

# 构建 VSearch 请求
payload = {
    "app_key": "cc0649228086490cbabd138645f4f86f",
    "scene_code": "jovi-console-tool-search",
    "collection_id": "router",
    "query_sentence": "帮我定一个明天早上8点的闹钟",
    "top_k": 10,
    "tune": 1,
    "rerankModel": 3,
    "searchType": 1
}
```

#### 2.2.2 VSearch 响应
```json
{
  "retcode": 0,
  "data": [
    {
      "id": "doc_001",
      "score": 0.96,
      "metadata": "{\"type\": \"简单任务\", \"threshold\": 0.9}",
      "sentence": "帮我定一个明天早上8点的闹钟"
    },
    {
      "id": "doc_002",
      "score": 0.87,
      "metadata": "{\"type\": \"简单任务\", \"threshold\": 0.0}",
      "sentence": "设置一个早上8点的闹钟"
    },
    {
      "id": "doc_003",
      "score": 0.82,
      "metadata": "{\"type\": \"简单任务\", \"threshold\": 0.0}",
      "sentence": "定个闹钟明天早上"
    }
  ]
}
```

#### 2.2.3 数据转换 (transform_data)
```python
# 输入：VSearch 响应
# 输出：标准格式
{
    'ids': [['doc_001', 'doc_002', 'doc_003']],