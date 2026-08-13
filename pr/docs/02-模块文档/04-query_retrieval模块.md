# Query Retrieval 模块详细文档

## 1. 模块概述

### 1.1 模块职责
Query Retrieval 模块负责向量检索相关功能，包括：
- **向量搜索**：调用VSearch服务进行语义相似度检索
- **结果匹配**：根据相似度阈值筛选匹配结果
- **数据转换**：将VSearch返回格式转换为标准格式
- **重试机制**：失败时自动重试，提高可用性

### 1.2 文件结构
```
query_retrieval/
├── query_recall.py      # 向量检索核心逻辑
├── query_write.py       # 向量数据写入（未使用）
├── query_delete.py      # 向量数据删除（未使用）
├── excel_to_json.py     # Excel转JSON工具
├── atom_intents.txt     # 原子意图列表
├── output.json          # 输出结果
└── recall_test.xlsx     # 测试数据
```

## 2. 核心组件详解

### 2.1 query_recall.py - 向量检索核心

#### 2.1.1 超时配置

```python
import os

if os.getenv('APP_ENV', 'dev') == "prd":
    CONNECT_TIMEOUT = 1
    RETRIEVE_TIMEOUT = 1
else:
    CONNECT_TIMEOUT = 5
    RETRIEVE_TIMEOUT = 5
```

**环境适配**：
- **生产环境**：连接超时1秒，检索超时1秒（快速失败）
- **其他环境**：连接超时5秒，检索超时5秒（容错性更好）

**设计考量**：
- 生产环境追求低延迟，快速失败后降级
- 开发/测试环境允许更长等待时间

#### 2.1.2 数据转换 transform_data

```python
def transform_data(original_data):
    """将VSearch返回格式转换为标准格式"""
    ids = []
    distances = []
    metadatas = []
    documents = []
    
    try:
        for entry in original_data:
            ids.append(entry['id'])
            distances.append(entry['score'])
            metadatas.append(parse_metadata(entry['metadata']))
            documents.append(entry['sentence'])
        
        # 构建标准格式
        transformed_data = {
            'ids': [ids],
            'distances': [distances],
            'metadatas': [metadatas],
            'documents': [documents],
            'data': None,
            'uris': None,
            'embeddings': None
        }
        
        return transformed_data
    except:
        return []
```

**转换逻辑**：
1. 遍历VSearch返回的每条结果
2. 提取id、score、metadata、sentence
3. 解析metadata JSON字符串
4. 构建符合ChromaDB格式的标准结构

**标准格式**：
```python
{
    'ids': [['id1', 'id2', ...]],
    'distances': [[0.95, 0.87, ...]],
    'metadatas': [[{...}, {...}, ...]],
    'documents': [['doc1', 'doc2', ...]],
    'data': None,
    'uris': None,
    'embeddings': None
}
```

#### 2.1.3 Metadata解析

```python
def parse_metadata(meta_str):
    """解析metadata JSON字符串"""
    try:
        return json.loads(meta_str)
    except json.JSONDecodeError:
        return {}
```

**容错处理**：
- JSON解析失败时返回空字典
- 避免因单条数据格式错误导致整体失败

#### 2.1.4 分数匹配 score_match

```python
def score_match(recall_results, max_score, min_score):
    """根据分数阈值筛选匹配结果"""
    try:
        score_list = recall_results['distances'][0]
        metadatas = recall_results['metadatas'][0]
        
        # 获取大于 max_score 的下标
        greater_indices = [i for i, num in enumerate(score_list) if num > max_score]
        # 获取大于 min_score 的下标
        less_indices = [i for i, num in enumerate(score_list) if num > min_score]
        
        max_score_result = [metadatas[i]['type'] for i in greater_indices]
        min_score_result = [metadatas[i]['type'] for i in less_indices]
        
        special_threshold = metadatas[0]["threshold"]
        
        # 如果没有设置特殊阈值，直接返回原结果
        if special_threshold == 0:
            return max_score_result, min_score_result
        
        # 特殊阈值小于最大分数阈值时，使用特殊阈值重新筛选
        if special_threshold < max_score:
            greater_special_indices = [i for i, num in enumerate(score_list) if num > special_threshold]
            max_score_result = [metadatas[i]['type'] for i in greater_special_indices]
            return max_score_result, min_score_result
        
        # 特殊阈值大于等于最大分数阈值，且存在max_score_result时
        if max_score_result:
            if max(score_list) > special_threshold:
                return [max_score_result[0]], min_score_result
            else:
                return [], min_score_result
        
        return max_score_result, min_score_result
    except:
        return [], []
```

**匹配策略**：
1. **双阈值筛选**：
   - `max_score` (默认0.95)：高分命中，直接返回
   - `min_score` (默认0.8)：低分命中，作为参考
2. **特殊阈值处理**：
   - 从metadata中读取 `threshold` 字段
   - 如果 `threshold > 0`，使用特殊阈值替代 `max_score`
3. **返回结果**：
   - `max_score_result`: 高分命中的任务类型列表
   - `min_score_result`: 低分命中的任务类型列表

**阈值优先级**：
```
特殊阈值 (threshold) > max_score > min_score
```

#### 2.1.5 向量搜索 gen_llm_vsearch_res

```python
def gen_llm_vsearch_res(text, n_results, trace_id):
    """生成向量搜索结果"""
    trace_id_ctx_var.set(trace_id)
    max_retries = 1
    retry_count = 0
    
    while retry_count <= max_retries:
        try:
            start1 = int(time.time() * 1000)
            if not text or not n_results:
                return None
            
            # 构建请求Payload
            payload = {
                "app_key": vsearch_config['app_key'],
                "scene_code": vsearch_config['scene_code'],
                "collection_id": vsearch_config['collection_id'],
                "query_sentence": text,
                "top_k": n_results,
                "tune": 1,
                "rerankModel": 3,
                "searchType": 1
            }
            headers = {"Content-Type": "application/json"}
            
            # 发送请求
            response = get_session().post(
                url=f"{vsearch_config['url']}/doc/search/v1",
                headers=headers,
                json=payload,
                timeout=(CONNECT_TIMEOUT, RETRIEVE_TIMEOUT),
            )
            
            if response.status_code == 200 and response.json().get("data"):
                response = response.json().get("data")
                response_1 = transform_data(response)
                show_result(response_1)
                return response_1
            
            # 请求失败，准备重试
            retry_count += 1
            if retry_count <= max_retries:
                logger.bind(traceId=trace_id_ctx_var.get()).warning(
                    f"向量服务调用失败，正在重试 ({retry_count}/{max_retries})，状态码: {response.status_code}"
                )
        
        except Exception as ex:
            retry_count += 1
            if retry_count <= max_retries:
                logger.bind(traceId=trace_id_ctx_var.get()).warning(
                    f"向量服务调用异常，正在重试 ({retry_count}/{max_retries}), 异常信息 {ex}"
                )
            else:
                logger.bind(traceId=trace_id_ctx_var.get()).error(
                    "向量服务调用异常{}: {}".format(text, ex)
                )
    
    return None
```

**核心流程**：
1. **参数校验**：检查text和n_results是否为空
2. **构建请求**：组装VSearch API请求参数
3. **发送请求**：使用HTTP会话发送POST请求
4. **结果转换**：调用 `transform_data` 转换格式
5. **重试机制**：失败时最多重试1次
6. **日志记录**：记录成功/失败/重试信息

**请求参数说明**：
```python
{
    "app_key": "xxx",           # 应用密钥
    "scene_code": "xxx",        # 场景代码
    "collection_id": "router",  # 集合ID
    "query_sentence": text,     # 查询文本
    "top_k": n_results,         # 返回结果数
    "tune": 1,                  # 调优参数
    "rerankModel": 3,           # 重排序模型
    "searchType": 1             # 搜索类型
}
```

#### 2.1.6 结果展示 show_result

```python
def show_result(response_1):
    """展示检索结果"""
    documents = response_1['documents'][0]
    distances = response_1['distances'][0]
    
    results = []
    for document, distance in zip(documents, distances):
        results.append({
            'document': document,
            'distance': distance
        })
    
    logger.bind(traceId=trace_id_ctx_var.get()).info(
        f"query_query检索结果: {results}"
    )
```

**用途**：
- 记录检索结果到日志
- 便于调试和问题排查

## 3. 向量检索流程

### 3.1 完整流程

```
用户Query
    ↓
[1] 调用 gen_llm_vsearch_res
    - 构建VSearch请求
    - 发送HTTP请求
    - 重试机制（最多1次）
    ↓
[2] 数据转换 transform_data
    - 解析VSearch返回
    - 转换为标准格式
    ↓
[3] 分数匹配 score_match
    - 应用双阈值筛选
    - 处理特殊阈值
    - 返回匹配结果
    ↓
[4] 结果返回
    - max_score_result: 高分命中
    - min_score_result: 低分命中
```

### 3.2 在Router中的使用

```python
async def _vector_search_task(self, query, trace_id, top_k, max_score, min_score, timeout=2.0):
    """执行向量搜索"""
    try:
        # 在线程池中执行同步的向量搜索
        query_results = await asyncio.wait_for(
            asyncio.to_thread(
                gen_llm_vsearch_res, query, trace_id=trace_id, n_results=top_k
            ),
            timeout=timeout,
        )
        max_score_result, min_score_result = score_match(query_results, max_score, min_score)
    except asyncio.TimeoutError:
        # 超时降级
        return [], False
    except Exception as e:
        # 异常降级
        return [], False
    
    if max_score_result:
        return max_score_result, True
    return min_score_result, False
```

**异步包装**：
- 使用 `asyncio.to_thread` 将同步调用转为异步
- 设置2秒超时，避免阻塞主流程
- 超时或异常时降级返回空结果

## 4. VSearch服务集成

### 4.1 服务配置

```python
# config/config.py
LLM_VSEARCH_SERVER = {
    'local': {
        'url': 'http://llm-content-search-pre.vivo.lan:8080',
        'app_key': "cc0649228086490cbabd138645f4f86f",
        'scene_code': "jovi-console-tool-search",
        'collection_id': "router"
    },
    'dev': {...},
    'test': {...},
    'pre': {...},
    'prd': {
        'url': 'http://vsearch-intent.vivo.lan:8080',
        'app_key': "76d4fa186f714e4d8cfeb389a498996d",
        'scene_code': "jovi-console-tool-search",
        'collection_id': "router"
    }
}

vsearch_config = LLM_VSEARCH_SERVER[os.getenv('APP_ENV', 'dev')]
```

**环境适配**：
- 不同环境使用不同的VSearch服务地址
- 生产环境使用独立的app_key
- 统一使用 `router` 集合

### 4.2 API接口

**请求**：
```
POST {url}/doc/search/v1
Content-Type: application/json

{
    "app_key": "xxx",
    "scene_code": "xxx",
    "collection_id": "router",
    "query_sentence": "用户query文本",
    "top_k": 10,
    "tune": 1,
    "rerankModel": 3,
    "searchType": 1
}
```

**响应**：
```json
{
    "retcode": 0,
    "data": [
        {
            "id": "doc_001",
            "score": 0.95,
            "metadata": "{\"type\": \"简单任务\", \"threshold\": 0.9}",
            "sentence": "帮我定一个明天早上8点的闹钟"
        },
        {
            "id": "doc_002",
            "score": 0.87,
            "metadata": "{\"type\": \"复杂任务\", \"threshold\": 0.0}",
            "sentence": "帮我查下屏幕上这首诗是谁写的，然后画一幅这个作者的肖像图"
        }
    ]
}
```

**Metadata字段**：
- `type`: 任务类型（简单任务/复杂任务）
- `threshold`: 特殊阈值（0表示不使用）

## 5. 匹配策略详解

### 5.1 双阈值机制

```python
max_score = 0.95  # 高分阈值
min_score = 0.8   # 低分阈值
```

**匹配逻辑**：
1. **高分命中** (`score > 0.95`)：
   - 直接返回结果
   - 设置 `post_type = "hit_vector"`
   - 跳过模型推理结果
2. **低分命中** (`0.8 < score < 0.95`)：
   - 作为参考结果
   - 不直接返回，使用模型推理结果
3. **未命中** (`score < 0.8`)：
   - 无向量匹配结果
   - 完全依赖模型推理

### 5.2 特殊阈值处理

```python
special_threshold = metadatas[0]["threshold"]

if special_threshold == 0:
    # 不使用特殊阈值
    return max_score_result, min_score_result

if special_threshold < max_score:
    # 特殊阈值更低，放宽匹配条件
    greater_special_indices = [i for i, num in enumerate(score_list) if num > special_threshold]
    max_score_result = [metadatas[i]['type'] for i in greater_special_indices]
    return max_score_result, min_score_result

if max_score_result:
    # 特殊阈值更高，收紧匹配条件
    if max(score_list) > special_threshold:
        return [max_score_result[0]], min_score_result
    else:
        return [], min_score_result
```

**应用场景**：
- 某些特定query需要更高的匹配精度
- 通过metadata中的threshold字段动态调整
- 支持细粒度的匹配控制

### 5.3 结果融合

```python
# 在 router_v2.py 中
if is_high_score:
    logger.info(f"命中向量库大于指定阈值的向量，直接返回结果: {q_q_result[0]}")
    task = 'easy' if q_q_result[0] == '简单任务' else 'complex'
    result_dict['post_type'] = 'hit_vector'
    result_dict['task_type'] = task
```

**融合策略**：
- 向量高分命中 → 直接返回，标记 `post_type = "hit_vector"`
- 向量低分命中 → 使用模型结果
- 向量未命中 → 使用模型结果

## 6. 性能优化

### 6.1 超时控制

```python
# 生产环境：快速失败
CONNECT_TIMEOUT = 1
RETRIEVE_TIMEOUT = 1

# 其他环境：容错性更好
CONNECT_TIMEOUT = 5
RETRIEVE_TIMEOUT = 5
```

**优化效果**：
- 生产环境：1秒超时，快速降级
- 避免向量服务慢导致整体延迟增加

### 6.2 异步执行

```python
query_results = await asyncio.wait_for(
    asyncio.to_thread(gen_llm_vsearch_res, ...),
    timeout=2.0,
)
```

**优化效果**：
- 向量搜索与模型推理并行执行
- 总耗时取两者最大值而非累加
- 2秒超时保护

### 6.3 重试机制

```python
max_retries = 1
retry_count = 0

while retry_count <= max_retries:
    try:
        # 发送请求
        ...
    except Exception as ex:
        retry_count += 1
        if retry_count <= max_retries:
            logger.warning(f"正在重试 ({retry_count}/{max_retries})")
```

**优化效果**：
- 网络抖动时自动重试
- 提高服务可用性
- 最多重试1次，避免过度重试

### 6.4 连接池复用

```python
from utils.requests_session import get_session

session = get_session()
response = session.post(url, json=payload, timeout=...)
```

**优化效果**：
- 复用HTTP连接
- 减少连接建立开销
- 提高并发性能

## 7. 错误处理

### 7.1 异常分类

```python
try:
    response = get_session().post(...)
    
    if response.status_code == 200 and response.json().get("data"):
        # 成功
        return transform_data(response.json().get("data"))
    
    # HTTP错误
    retry_count += 1
    logger.warning(f"向量服务调用失败，状态码: {response.status_code}")

except Exception as ex:
    # 网络异常、超时等
    retry_count += 1
    logger.warning(f"向量服务调用异常: {ex}")
```

**异常类型**：
1. **HTTP错误**：状态码非200
2. **网络异常**：连接失败、超时
3. **数据异常**：JSON解析失败、格式错误

### 7.2 降级策略

```python
# 在 router_v2.py 中
if isinstance(results[0], Exception):
    logger.warning(f"向量搜索失败，降级使用路由模型结果: {results[0]}")
    q_q_result, is_high_score = [], False
```

**降级逻辑**：
- 向量搜索失败 → 返回空结果
- 不阻塞模型推理
- 使用模型结果作为兜底

## 8. 数据管理工具

### 8.1 excel_to_json.py

```python
"""将Excel工具定义转换为JSON格式"""
import pandas as pd
import json

def excel_to_json(excel_path, output_path):
    df = pd.read_excel(excel_path)
    data = df.to_dict(orient='records')
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
```

**用途**：
- 将Excel工具定义转换为JSON
- 便于版本管理和代码审查

### 8.2 query_write.py / query_delete.py

```python
"""向量数据写入和删除（未使用）"""
# 预留接口，用于向量库数据管理
```

**状态**：
- 代码存在但未使用
- 预留用于未来向量库数据管理

## 9. 设计理念总结

### 9.1 快速失败
- 生产环境1秒超时
- 失败后快速降级
- 不阻塞主流程

### 9.2 双阈值匹配
- 高分直接返回
- 低分作为参考
- 支持特殊阈值

### 9.3 容错设计
- 自动重试1次
- 异常降级处理
- 详细日志记录

### 9.4 性能优化
- 异步并行执行
- 连接池复用
- 超时保护

## 10. 使用示例

### 10.1 基本调用

```python
from query_retrieval.query_recall import gen_llm_vsearch_res, score_match

# 执行向量搜索
results = gen_llm_vsearch_res(
    text="帮我定一个明天早上8点的闹钟",
    n_results=10,
    trace_id="trace-123"
)

# 分数匹配
max_score_result, min_score_result = score_match(
    results,
    max_score=0.95,
    min_score=0.8
)

print(f"高分命中: {max_score_result}")
print(f"低分命中: {min_score_result}")
```

### 10.2 在Router中使用

```python
# 在 router_v2.py 中
async def _vector_search_task(self, query, trace_id, top_k, max_score, min_score):
    query_results = await asyncio.wait_for(
        asyncio.to_thread(
            gen_llm_vsearch_res, query, trace_id=trace_id, n_results=top_k
        ),
        timeout=2.0,
    )
    max_score_result, min_score_result = score_match(query_results, max_score, min_score)
    
    if max_score_result:
        return max_score_result, True
    return min_score_result, False
```

## 11. 常见问题

### 11.1 向量搜索超时
**现象**：日志显示 "向量库搜索超时"

**原因**：
1. VSearch服务响应慢
2. 网络延迟高
3. 查询文本过长

**解决方案**：
1. 检查VSearch服务状态
2. 优化网络配置
3. 截断查询文本

### 11.2 匹配结果不准确
**现象**：高分命中的结果与query不相关

**原因**：
1. 向量库数据质量问题
2. 相似度阈值设置不当
3. 重排序模型效果差

**解决方案**：
1. 清洗向量库数据
2. 调整阈值参数
3. 优化重排序模型

### 11.3 重试失败
**现象**：重试后仍然失败

**原因**：
1. VSearch服务宕机
2. 网络持续不可用
3. 请求参数错误

**排查方法**：
1. 检查VSearch服务健康状态
2. 检查网络连通性
3. 验证请求参数格式

## 12. 最佳实践

1. **合理设置超时**：生产环境1秒，其他环境5秒
2. **监控命中率**：统计高分/低分命中比例
3. **定期更新向量库**：保持数据时效性
4. **日志追踪**：使用trace_id关联完整链路
5. **阈值调优**：根据业务场景调整max_score和min_score
6. **性能监控**：记录向量搜索耗时
7. **降级预案**：确保向量服务不可用时能正常降级
