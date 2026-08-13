### 4.1 工具定义加载

```
┌─────────────────────────────────────────┐
│  Router.__init__()                      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  _load_tool_data()                      │
│  - 根据环境选择 Excel 文件               │
│  - 读取 "最新定义" Sheet                 │
│  - 加载 gui.json                        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  构建工具字典                            │
│  - intent_domain: 工具所属领域           │
│  - intent_def_dict: 工具定义             │
│  - intent_slot_dict: 工具槽位            │
└─────────────────────────────────────────┘
```

### 4.2 工具定义数据结构

#### 4.2.1 Excel 数据
```
| tool_name          | domain     | content          | slot              |
|--------------------|------------|------------------|-------------------|
| createAlarmClock   | 时间与日程 | 创建一个新的闹钟 | time: 闹钟时间... |
| queryAlarmClock    | 时间与日程 | 查询闹钟列表     | filter: 过滤条件  |
```

#### 4.2.2 加载后的字典
```python
intent_domain = {
    "createAlarmClock": "时间与日程",
    "queryAlarmClock": "时间与日程",
    # ...
}

intent_def_dict = {
    "createAlarmClock": "创建一个新的闹钟，支持设置时间、标签、重复等",
    "queryAlarmClock": "查询当前设备上的所有闹钟列表",
    # ...
}

intent_slot_dict = {
    "createAlarmClock": "time: 闹钟时间，格式为HH:MM\nlabel: 闹钟标签，可选",
    "queryAlarmClock": "filter: 过滤条件，可选",
    # ...
}
```

## 5. 正则模板匹配数据流

### 5.1 模板定义

```python
# template/time_schedule.py
regex_template = [
    r'(今天|明天)(早上|早晨|上午|中午|下午|晚上)(.{2}|.{3}|.{4}|.{5})?(叫|提醒|告诉|叫醒)',
    r'^(.+)(分钟|秒|小时)(倒计时|计时|定时)$',
    r'(定|设置|设|打开|整|调|开|上)(一个|个)?(今天|明天|明早|今早|明晚|今晚)(早上|早晨|上午|中午|下午|晚上)?(.+点)(钟|半)?(的)?(闹钟|闹铃)',
    # ... 更多模板
]

# template/__init__.py
regex_templates = {
    'timeAndSchedule': time_schedule.regex_template,
    'weather': weather.regex_template,
    'normal': []
}

DOMAIN_Z2E = {
    '时间与日程': 'timeAndSchedule',
    '天气': 'weather'
}
```

### 5.2 匹配流程

```python
# 输入
query = "定一个明天早上8点的闹钟"
tools = [
    {"domain": "时间与日程"},
    {"domain": "时间与日程"}
]

# 处理流程
# 1. 转换领域名称
domains = ["timeAndSchedule", "timeAndSchedule"]

# 2. 遍历模板
for domain_key in domains:
    templates = regex_templates.get(domain_key, [])
    for pattern in templates:
        if re.search(pattern, query):
            # 匹配成功
            match_domain = domain_key
            match_template = pattern
            template_matched = True
            break

# 输出
{
    "template": {
        "matched": True,
        "match_domain": "timeAndSchedule",
        "match_template": "(定|设置|设|打开|整|调|开|上)(一个|个)?(今天|明天|明早|今早|明晚|今晚)(早上|早晨|上午|中午|下午|晚上)?(.+点)(钟|半)?(的)?(闹钟|闹铃)"
    }
}
```

## 6. 错误处理数据流

### 6.1 向量搜索失败

```python
# 正常流程
try:
    query_results = await asyncio.wait_for(
        asyncio.to_thread(gen_llm_vsearch_res, ...),
        timeout=2.0
    )
except asyncio.TimeoutError:
    # 超时降级
    logger.warning("向量库搜索超时，降级返回空结果")
    return [], False
except Exception as e:
    # 异常降级
    logger.warning(f"向量库搜索异常，降级返回空结果：{e}")
    return [], False
```

### 6.2 模型推理失败

```python
# 正常流程
try:
    result_dict = await self._parse_llm_result_v2(...)
except Exception as e:
    # 异常处理
    logger.error(f"路由模型调用失败: {e}")
    return _make_result_dict(task_type="complex", fill="err")
```

### 6.3 统一错误格式

```python
def _make_result_dict(task_type="complex", fill="err"):
    return {
        "task_type": task_type,
        "is_intent_specific": fill,
        "is_use_tool": fill,
        "is_special_instruction": fill,
        "is_exe_success": fill,
        "post_type": ''
    }

# 错误响应
{
    "task_type": "complex",
    "is_intent_specific": "err",
    "is_use_tool": "err",
    "is_special_instruction": "err",
    "is_exe_success": "err",
    "post_type": ""
}
```

## 7. 日志数据流

### 7.1 追踪ID传递

```python
# 1. API Layer 设置
trace_id_ctx_var.set(trace_id)

# 2. Router Layer 使用
logger.bind(traceId=trace_id_ctx_var.get()).info(f"query: {query}")

# 3. Utils Layer 使用
logger.bind(traceId=trace_id_ctx_var.get()).info(f"模型请求id:{response.id}")

# 4. Query Retrieval Layer 使用
logger.bind(traceId=trace_id_ctx_var.get()).info(f"向量库搜索耗时：{vector_cost}ms")
```

### 7.2 关键事件日志

```python
# 请求入口
logger.info(f"[router-entry] params.extra type={type(params.extra).__name__}")

# 工具提取
logger.info(f"召回给路由的工具：{tools}")
logger.info(f"路由候选工具：{tools_list}")

# 向量检索
logger.info(f"向量库搜索耗时：{vector_cost}ms")
logger.info(f"query_query检索结果: {results}")

# 模型推理
logger.info(f"工具选择：{tools_content}")
logger.info(f"llm原始返回（sglang）: {llm_raw_result!r}, matched_label={matched_label}")
logger.info(f"路由模型请求耗时：{llm_cost}ms")

# 结果融合
logger.info(f"命中向量库大于指定阈值的向量，直接返回结果")
logger.info(f"解析后结果（sglang）: {result_dict}")

# 总耗时
print(f"路由总耗时：{time.time()-time1}")
```

## 8. 性能监控数据流

### 8.1 耗时统计

```python
# 向量搜索耗时
vector_start = int(time.time() * 1000)
# ... 执行向量搜索
vector_cost = int(time.time() * 1000) - vector_start
logger.info(f"向量库搜索耗时：{vector_cost}ms")

# 模型推理耗时
llm_start = int(time.time() * 1000)
# ... 执行模型推理
llm_cost = int(time.time() * 1000) - llm_start
logger.info(f"路由模型请求耗时：{llm_cost}ms")

# 总耗时
time1 = time.time()
# ... 执行完整流程
print(f"路由总耗时：{time.time()-time1}")
```

### 8.2 早停统计

```python
# SGLang 返回
{
    "completion_tokens": 3,
    "matched_label": "infer",
    "finish_reason": "stop"
}

# 日志记录
logger.info(
    f"[sglang_generate] trace_id={trace_id} model={model} latency={latency_ms:.1f}ms "
    f"completion_tokens={completion_tokens} finish={finish_reason} matched={matched_label}"
)
```

## 9. 数据流优化点

### 9.1 并发执行
```python
# 串行执行（旧）
vector_result = await vector_search()  # 100ms
model_result = await model_inference()  # 200ms
# 总耗时：300ms

# 并发执行（新）
results = await asyncio.gather(
    vector_search(),
    model_inference()
)
# 总耗时：200ms（取最大值）
```

### 9.2 短路优化
```python
# 完整生成（旧）
output = "single clear norm ok"  # 7 tokens, 100ms

# 早停生成（新）
output = "multi"  # 1 token, 20ms
# 性能提升：80%
```

### 9.3 连接池复用
```python
# 每次创建连接（旧）
client = httpx.AsyncClient()  # 150ms
response = await client.post(...)

# 连接池复用（新）
client = _get_async_http_client()  # 0ms（复用）
response = await client.post(...)
# 性能提升：150ms/请求
```

## 10. 数据流总结

### 10.1 核心数据流

1. **请求数据流**：客户端 → API → Router → 向量/模型 → 融合 → 响应
2. **配置数据流**：配置中心 → VivoConfigManager → 本地缓存 → 业务逻辑
3. **工具定义流**：Excel → Router → 字典 → Prompt构建
4. **日志数据流**：各模块 → Logger → 文件/控制台

### 10.2 关键转换点

1. **参数验证**：JSON → Pydantic Model
2. **工具提取**：工具列表 → MCP工具名列表
3. **Prompt构建**：工具定义 + Query → 完整Prompt
4. **结果解析**：模型输出 → 结构化字典
5. **结果融合**：多路结果 → 最终决策

### 10.3 性能关键点

1. **并发执行**：向量搜索 + 模型推理并行
2. **短路优化**：SGLang早停减少token生成
3. **连接池化**：HTTP客户端和OpenAI客户端复用
4. **超时降级**：向量搜索2秒超时，快速失败
5. **历史截断**：控制Prompt长度，减少推理时间

### 10.4 容错关键点

1. **向量搜索失败** → 使用模型结果
2. **模型推理失败** → 返回错误结果
3. **配置同步失败** → 使用本地配置
4. **字段校验失败** → 返回统一错误格式
5. **正则验证失败** → 跳过该配置项
