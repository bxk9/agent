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