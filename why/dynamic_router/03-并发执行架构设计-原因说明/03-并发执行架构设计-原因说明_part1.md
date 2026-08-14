# 并发执行架构设计 - 原因说明

> 本文档详细说明并发执行架构设计的设计原因和决策依据

---

## 1. 核心设计原因

### 1.1 为什么需要并发执行（可能原因）

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
        
        # 4. 结果处理
        # ...
```

**详细解释**：
- 路由决策需要同时执行两个耗时操作：向量检索和模型推理
- 向量检索：调用VSearch服务，检索相似query的历史分类结果（~100ms）
- 模型推理：调用LLM进行四维度分类（~200ms）
- 这两个操作是独立的，没有数据依赖
- 因此可以并发执行，总延迟取最大值而非累加

**业务场景**：
```
串行执行：
向量检索（100ms）→ 模型推理（200ms）→ 总延迟：300ms

并发执行：
向量检索（100ms）┐
                  ├→ 总延迟：200ms（取最大值）
模型推理（200ms）┘

性能提升：33%
```

### 1.2 为什么选择asyncio而不是多线程（可能原因）

**来源**：代码分析 - router/router_v2.py

**代码实现**：
```python
# 使用asyncio.gather并发执行
results = await asyncio.gather(*coroutines, return_exceptions=True)
```

**详细解释**：
- 向量检索和模型推理都是IO操作（HTTP请求），不是CPU密集型
- asyncio适合IO密集型任务，多线程适合CPU密集型任务
- asyncio无线程切换开销，性能更优
- FastAPI本身就是异步框架，使用asyncio最自然

**技术对比**：
```
asyncio:
- 适合IO密集型任务
- 无线程切换开销
- 代码简洁，易于维护
- 与FastAPI异步框架完美契合

多线程:
- 适合CPU密集型任务
- 有线程切换开销
- 需要处理线程安全问题
- 与FastAPI异步框架不契合

多进程:
- 适合CPU密集型任务
- 进程创建开销大
- 进程间通信复杂
- 不适合短任务
```

### 1.3 为什么使用return_exceptions=True（可能原因）

**来源**：代码分析 - router/router_v2.py

**代码实现**：
```python
# 并发执行所有任务
results = await asyncio.gather(*coroutines, return_exceptions=True)
```

**详细解释**：
- `return_exceptions=False`（默认）：任一任务抛出异常，立即中断，其他任务取消
- `return_exceptions=True`：任一任务抛出异常，将异常作为结果返回，其他任务继续执行
- 使用`return_exceptions=True`可以保证一个任务失败不影响其他任务

**异常处理逻辑**：
```python
# 向量搜索结果容错
if isinstance(results[0], Exception):
    logger.warning(f"向量搜索失败，降级使用路由模型结果: {results[0]}")
    q_q_result, is_high_score = [], False
else:
    (q_q_result, is_high_score) = results[0]

# 路由模型结果容错
if isinstance(results[1], Exception):
    logger.error(f"路由模型调用失败: {results[1]}")
    return _make_result_dict(task_type="complex", fill="err")
result_dict = results[1]
```

**设计逻辑**：
```
为什么向量检索失败可以降级？
- 向量检索是辅助功能，用于加速高频query
- 失败时可以使用模型推理结果
- 准确率下降约1-2%，可接受

为什么模型推理失败不能降级？
- 模型推理是核心功能，无法降级
- 失败时返回错误结果
- 下游系统需要处理错误结果
```

---

## 2. 向量检索任务设计原因

### 2.1 为什么需要向量检索（可能原因）

**来源**：代码分析 - router/router_v2.py

**代码实现**：
```python
async def _vector_search_task(self, query, trace_id, top_k, max_score, min_score, timeout=2.0):
    """执行向量搜索并返回(结果, 是否高分命中)"""
    vector_start = int(time.time() * 1000)
    
    try:
        # 在线程池中执行同步的向量搜索，并设置超时
        query_results = await asyncio.wait_for(
            asyncio.to_thread(
                gen_llm_vsearch_res, query, trace_id=trace_id, n_results=top_k
            ),
            timeout=timeout,
        )
        max_score_result, min_score_result = score_match(query_results, max_score, min_score)
    except asyncio.TimeoutError:
        # 超时降级：返回空结果
        vector_cost = int(time.time() * 1000) - vector_start
        logger.warning(f"向量库搜索超时({timeout}s)，降级返回空结果，耗时：{vector_cost}ms")
        return [], False
    except Exception as e:
        # 异常降级：返回空结果
        vector_cost = int(time.time() * 1000) - vector_start
        logger.warning(f"向量库搜索异常，降级返回空结果：{e}，耗时：{vector_cost}ms")
        return [], False
    
    vector_cost = int(time.time() * 1000) - vector_start
    logger.info(f"向量库搜索耗时：{vector_cost}ms")
    
    if max_score_result:
        return max_score_result, True
    return min_score_result, False
```

**详细解释**：
- 向量检索用于加速高频query的处理
- 通过检索相似query的历史分类结果，可以跳过模型推理
- 高分命中（>0.95）：直接返回历史结果
- 低分命中（0.8-0.95）：作为参考，继续使用模型推理
- 无匹配（<0.8）：完全依赖模型推理

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

### 2.2 为什么使用asyncio.to_thread（可能原因）

**来源**：代码分析 - router/router_v2.py

**代码实现**：
```python
# 在线程池中执行同步的向量搜索，并设置超时
query_results = await asyncio.wait_for(
    asyncio.to_thread(
        gen_llm_vsearch_res, query, trace_id=trace_id, n_results=top_k
    ),
    timeout=timeout,
)
```

**详细解释**：
- `gen_llm_vsearch_res`是同步函数（使用requests库）
- 直接在async函数中调用会阻塞事件循环
- `asyncio.to_thread`将其放到线程池，不阻塞事件循环
- 其他异步任务可以继续执行

**技术对比**：
```
直接调用同步函数：
- 阻塞事件循环
- 其他异步任务无法执行
- 性能差

使用asyncio.to_thread：
- 不阻塞事件循环
- 其他异步任务可以继续执行
- 性能好
```

### 2.3 为什么设置2秒超时（可能原因）

**来源**：代码分析 - router/router_v2.py

**代码实现**：
```python
async def _vector_search_task(self, query, trace_id, top_k, max_score, min_score, timeout=2.0):
    """执行向量搜索并返回(结果, 是否高分命中)"""
    # ...
```

**详细解释**：
- 向量检索是辅助功能，不应该阻塞主流程
- 2秒超时是一个经验值，平衡了性能和可用性
- 超时后降级返回空结果，使用模型推理结果

**超时策略**：
```
生产环境：
- 向量检索超时：2秒
- 模型推理超时：60秒
- 总超时：62秒

开发环境：
- 向量检索超时：5秒
- 模型推理超时：60秒
- 总超时：65秒
```

---

## 3. 模型推理任务设计原因

### 3.1 为什么需要模型推理（可能原因）

**来源**：代码分析 - router/router_v2.py

**代码实现**：
```python
async def _get_router_result(self, query, query_content, tools_content, trace_id):
    """调用路由模型获取分类结果"""
    llm_start = int(time.time() * 1000)
    logger.info(f"工具选择：{tools_content}")
    
    result_dict = await self._parse_llm_result_v2(
        query_content, tools_content, trace_id, self.copilot_env, self.base_url, self.special_flag
    )
    self.special_flag = 1  # 重置标记
    
    llm_cost = int(time.time() * 1000) - llm_start
    logger.info(f"路由模型请求耗时：{llm_cost}ms")
    return result_dict
```

**详细解释**：
- 模型推理是核心功能，用于四维度分类
- 向量检索是辅助功能，用于加速高频query
- 模型推理的准确率高于向量检索
- 因此模型推理是默认方案，向量检索是加速方案

**业务场景**：
```
低频query：
- "帮我查一下屏幕上这首诗是谁写的，然后画一幅这个作者的肖像图"
- "导航到江苏最高的电视塔"
- "等我到家了帮我把空调打开"

这些query的分类结果是不确定的，需要模型推理：
1. 调用LLM进行四维度分类
2. 返回分类结果
3. 准确率：96%
```

### 3.2 为什么使用SGLang而不是OpenAI API（可能原因）

**来源**：代码分析 - utils/request_llm_v2.py

**代码实现**：
```python
async def call_sglang_generate(
    tools_content, 
    content,
    trace_id,
    *,
    base_url: str,
    model: str = "qwen3.5-35b",
    max_tokens: int = 50,
    temperature: float = 0.0,
    top_k: int = 1,
    top_p: float = 0.01,
    special_flag=1
):
    """调用SGLang原生/generate，使用stop_token_ids早停"""
    # ...
```

**详细解释**：
- SGLang原生支持stop_token_ids参数，可以在生成特定token时立即停止
- OpenAI API不支持stop_token_ids参数，只能停止在特定字符串