# 向量检索与多路召回融合 - 面试亮点

> **核心价值**：设计并实现了基于向量检索的多路召回融合策略，通过双阈值匹配（0.95/0.8）和多路结果融合，将高频query的响应时间从200ms降低到50ms，同时保持96%的准确率。

---

## 1. 项目背景与问题定义

### 1.1 业务场景

Dynamic Router需要对每个用户query进行四维度分类，主要依赖LLM推理：
- **输入**：用户query + 历史对话 + 候选工具列表
- **处理**：调用LLM进行四维度分类
- **输出**：任务复杂度（easy/complex）

**性能瓶颈**：
- LLM推理延迟：~200ms（即使使用SGLang早停优化）
- 高并发场景下，LLM服务压力大
- 很多query是重复或相似的，每次都调用LLM是浪费

**关键洞察**：
- 80%的query是高频query（如"定个闹钟"、"播放音乐"）
- 这些高频query的分类结果是确定的，不需要每次都调用LLM
- 可以通过向量检索，快速找到相似query的历史分类结果
- 对于高相似度的query，可以直接返回历史结果，跳过LLM推理

### 1.2 优化目标

**核心问题**：如何通过向量检索加速高频query的处理，同时保证准确率？

**量化目标**：
- 高频query响应时间 < 100ms（相比LLM推理的200ms）
- 向量检索命中率 > 30%（至少30%的query可以通过向量检索加速）
- 准确率下降 < 2%（向量检索的结果要可靠）
- 不影响低频query的处理（向量检索失败时降级到LLM推理）

---

## 2. 技术方案设计

### 2.1 整体架构

```
用户query
    ↓
[1] 向量检索（VSearch服务）
    ├─ 检索相似query的历史分类结果
    ├─ 返回相似度分数和分类结果
    └─ 耗时：~50ms
    ↓
[2] 双阈值匹配
    ├─ 高分匹配（>0.95）：直接返回历史结果
    ├─ 低分匹配（0.8-0.95）：作为参考，继续使用LLM推理
    └─ 无匹配（<0.8）：完全依赖LLM推理
    ↓
[3] LLM推理（并发执行）
    ├─ 调用LLM进行四维度分类
    └─ 耗时：~200ms
    ↓
[4] 结果融合
    ├─ 如果有高分匹配：使用向量检索结果
    ├─ 如果有低分匹配：优先使用LLM结果，向量结果作为参考
    └─ 如果无匹配：使用LLM结果
    ↓
返回最终结果
```

**关键设计**：
1. **并发执行**：向量检索和LLM推理并发执行，总延迟取最大值
2. **双阈值匹配**：高分直接返回，低分作为参考，平衡速度和准确性
3. **降级策略**：向量检索失败时，降级到LLM推理

### 2.2 向量检索实现

#### 2.2.1 VSearch服务集成

```python
# query_retrieval/query_recall.py

def gen_llm_vsearch_res(text, n_results, trace_id):
    """调用VSearch服务进行向量检索"""
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
                response_data = response.json().get("data")
                response_1 = transform_data(response_data)
                show_result(response_1)
                return response_1
            
            # 请求失败，准备重试
            retry_count += 1
            if retry_count <= max_retries:
                logger.warning(f"向量服务调用失败，正在重试 ({retry_count}/{max_retries})")
        
        except Exception as ex:
            retry_count += 1
            if retry_count <= max_retries:
                logger.warning(f"向量服务调用异常，正在重试 ({retry_count}/{max_retries})")
            else:
                logger.error(f"向量服务调用异常{text}: {ex}")
    
    return None
```

**关键参数**：
- `query_sentence`：用户query文本
- `top_k`：返回top-k个相似结果（默认10）
- `rerankModel`：重排序模型（3表示使用精排模型）
- `searchType`：搜索类型（1表示语义搜索）

**超时配置**：
```python
# 根据环境设置不同的超时时间
if os.getenv('APP_ENV', 'dev') == "prd":
    CONNECT_TIMEOUT = 1
    RETRIEVE_TIMEOUT = 1
else:
    CONNECT_TIMEOUT = 5
    RETRIEVE_TIMEOUT = 5
```

**设计理由**：
- 生产环境：1秒超时，快速失败，避免阻塞
- 开发环境：5秒超时，便于调试

#### 2.2.2 数据转换

```python
def transform_data(original_data):
    """将VSearch返回的数据转换为标准格式"""
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

**转换后的数据格式**：
```python
{
    'ids': [['id1', 'id2', 'id3', ...]],
    'distances': [[0.96, 0.87, 0.82, ...]],  # 相似度分数
    'metadatas': [[
        {'type': '简单任务', 'threshold': 0.9},
        {'type': '复杂任务', 'threshold': 0.0},
        ...
    ]],
    'documents': [['帮我定个闹钟', '播放音乐', ...]]
}
```

**关键字段**：
- `distances`：相似度分数（0-1，越高越相似）
- `metadatas`：历史分类结果（type字段）
- `documents`：历史query文本

### 2.3 双阈值匹配策略

#### 2.3.1 阈值设计

**问题**：如何判断向量检索的结果是否可靠？

**解决方案**：使用双阈值匹配策略

```python
# query_retrieval/query_recall.py

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
        
        # 处理特殊阈值
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

**阈值设置**：
```python
max_score = 0.95  # 高分阈值：直接返回
min_score = 0.8   # 低分阈值：作为参考
```

**设计理由**：
- **0.95高分阈值**：相似度>0.95的query几乎相同，可以直接返回历史结果
- **0.8低分阈值**：相似度0.8-0.95的query相似但不完全相同，作为参考
- **<0.8无匹配**：相似度<0.8的query差异较大，完全依赖LLM推理

**阈值选择依据**：
1. **数据分析**：分析历史数据，找到准确率和召回率的平衡点
2. **A/B测试**：测试不同阈值组合的效果
3. **业务需求**：根据业务对准确率和延迟的要求调整

#### 2.3.2 特殊阈值支持

**问题**：某些query需要特殊的阈值配置

**解决方案**：在metadata中存储特殊阈值

```python
# metadata示例
{
    'type': '简单任务',
    'threshold': 0.9  # 特殊阈值
}
```

**处理逻辑**：
1. 如果`threshold == 0`：使用默认阈值（0.95/0.8）
2. 如果`threshold < 0.95`：使用特殊阈值替代高分阈值
3. 如果`threshold >= 0.95`：只有最高分超过特殊阈值时才返回

**应用场景**：
- 某些query容易误判，需要更高的阈值（如0.98）
- 某些query变体多，需要更低的阈值（如0.9）

### 2.4 多路召回融合

#### 2.4.1 并发执行

```python
# router/router_v2.py

async def search(self, trace_id, query, tools, ...):
    """路由主入口"""
    
    # 1. 预处理
    trace_id_ctx_var.set(trace_id)
    chat_history = (chat_history or [])[-6:]
    
    # 2. 提取工具和构建内容
    tools_result = self._extract_tools(tools, tools_history)
    query_content = self._build_query(query, chat_history, trace_id)
    tools_content = self._build_tools_content(tools_result, tools_history, trace_id)
    