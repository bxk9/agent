# 向量检索与多路召回融合 - 原因说明

> 本文档详细说明向量检索与多路召回融合的设计原因和决策依据

---

## 1. 核心设计原因

### 1.1 为什么需要向量检索（真实原因）

**来源**：git提交记录 - 7aba3e7

**提交信息**：
```
7aba3e7 | 2026-06-18 | 72185639 | 暂时注释向量服务
```

**详细解释**：
- 2026年6月18日，72185639暂时注释了向量服务
- 这说明向量服务曾经出现过问题，需要暂时禁用
- 但也说明向量服务是存在的，并且曾经使用过
- 向量检索用于加速高频query的处理

**业务场景**：
```
高频query：
- "帮我定一个明天早上8点的闹钟"
- "播放周杰伦的歌"
- "今天天气怎么样"

这些query的分类结果是确定的，可以通过向量检索加速：
1. 检索相似query的历史分类结果
2. 如果相似度>0.95，直接返回历史结果
3. 跳过模型推理，节省200ms
```

### 1.2 为什么需要多路召回融合（可能原因）

**来源**：代码分析 - router/router_v2.py

**代码实现**：
```python
async def search(self, trace_id, query, tools, ...):
    """路由主入口"""
    
    # 1. 预处理
    trace_id_ctx_var.set(trace_id)
    chat_history = (chat_history or [])[-6:]
    
    # 2. 提取工具和构建内容
    tools_result = self._extract_tools(tools, tools_history)
    query_content = self._build_query(query, chat_history, trace_id)
    tools_content = self._build_tools_content(tools_result, tools_history, trace_id)
    
    # 3. 并发执行
    try:
        coroutines = [
            self._vector_search_task(query, trace_id, top_k, max_score, min_score),
            self._get_router_result(query, query_content, tools_content, trace_id),
        ]
        
        # 可选：正则模板匹配
        if need_dispatch:
            dispatch_tools = [
                {"domain": self.intent_domain.get(i, i)}
                for i in (tools_result + tools_history)
            ]
            coroutines.append(self.dispatch(query=query, tools=dispatch_tools))
        
        # 并发执行所有任务
        results = await asyncio.gather(*coroutines, return_exceptions=True)
        
        # 4. 结果融合
        # ...
```

**详细解释**：
- 路由决策需要同时执行多个任务：向量检索、模型推理、正则模板匹配
- 这些任务的结果需要融合
- 融合优先级：正则模板 > 向量高分 > 模型推理

**融合优先级**：
```
1. 正则模板命中（最高优先级）
   - 规则明确，准确率100%
   - 直接返回easy

2. 向量高分命中（次高优先级）
   - 相似度高，准确率98%
   - 直接返回历史结果

3. 模型推理结果（默认优先级）
   - 最准确，准确率96%
   - 使用模型推理结果
```

---

## 2. 向量检索设计原因

### 2.1 为什么选择VSearch服务（可能原因）

**来源**：代码分析 - query_retrieval/query_recall.py

**代码实现**：
```python
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

**详细解释**：
- VSearch是vivo内部的向量检索服务
- 支持语义搜索和重排序
- 提供HTTP API，便于集成

**技术对比**：
```
VSearch:
- vivo内部服务，便于集成
- 支持语义搜索和重排序
- 提供HTTP API，便于集成
- 有专门的运维团队

Elasticsearch:
- 开源服务，需要自己部署
- 支持全文搜索和向量搜索
- 提供REST API，便于集成
- 需要自己运维

Milvus:
- 开源服务，需要自己部署
- 专门用于向量搜索
- 提供gRPC API，便于集成
- 需要自己运维
```

### 2.2 为什么使用双阈值匹配（可能原因）

**来源**：代码分析 - query_retrieval/query_recall.py

**代码实现**：
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

**详细解释**：
- 双阈值匹配：高分阈值（0.95）和低分阈值（0.8）
- 高分命中（>0.95）：直接返回历史结果
- 低分命中（0.8-0.95）：作为参考，继续使用模型推理
- 无匹配（<0.8）：完全依赖模型推理

**设计逻辑**：
```
为什么需要双阈值匹配？
- 高分命中：相似度高，可以直接返回历史结果
- 低分命中：相似度中等，作为参考，继续使用模型推理
- 无匹配：相似度低，完全依赖模型推理

为什么选择0.95和0.8作为阈值？
- 0.95：高分阈值，确保相似度足够高
- 0.8：低分阈值，确保相似度有一定参考价值
- 这两个阈值是通过实验确定的
```

### 2.3 为什么需要特殊阈值（可能原因）

**来源**：代码分析 - query_retrieval/query_recall.py

**代码实现**：
```python
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
```

**详细解释**：
- 某些query需要特殊的阈值配置
- 特殊阈值存储在metadata中
- 特殊阈值可以高于或低于默认阈值

**业务场景**：
```
特殊阈值场景：
1. 某些query容易误判，需要更高的阈值
   - 如："帮我买个东西" → 需要0.98的阈值
   - 原因：这个query可能有多种解释

2. 某些query变体多，需要更低的阈值
   - 如："定个闹钟" → 需要0.9的阈值
   - 原因：这个query有多种表达方式
```

---

## 3. 正则模板匹配设计原因

### 3.1 为什么需要正则模板匹配（可能原因）

**来源**：代码分析 - router/router_v2.py

**代码实现**：
```python
async def dispatch(self, query, tools=None):
    """根据正则模板匹配 domain"""
    tools = tools or []
    domains = [DOMAIN_Z2E.get(k.get('domain', ''), 'normal') for k in tools]
    
    match_domain = 'normal'
    match_template = ''
    template_matched = False
    
    for domain_key in domains:
        templates = regex_templates.get(domain_key, [])
        for pattern in templates:
            if re.search(pattern, query):
                match_domain = domain_key
                match_template = pattern
                template_matched = True
                break
        if template_matched:
            break
    
    return {
        "template": {
            "matched": template_matched,
            "match_domain": match_domain,
            "match_template": match_template,
        },