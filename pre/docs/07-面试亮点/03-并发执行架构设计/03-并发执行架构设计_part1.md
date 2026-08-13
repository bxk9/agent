# 并发执行架构设计 - 面试亮点

> **核心价值**：设计并实现了向量检索与模型推理的并发执行架构，通过asyncio.gather将总延迟从300ms降低到200ms，性能提升33%，同时保证了系统的稳定性和可维护性。

---

## 1. 项目背景与问题定义

### 1.1 业务场景

Dynamic Router的路由决策需要同时执行两个耗时操作：
1. **向量检索**：调用VSearch服务，检索相似query的历史分类结果
2. **模型推理**：调用LLM进行四维度分类

**初始架构（串行执行）**：
```python
async def search(self, query, tools, ...):
    # 1. 向量检索（~100ms）
    vector_result = await self._vector_search_task(query, ...)
    
    # 2. 模型推理（~200ms）
    model_result = await self._get_router_result(query, ...)
    
    # 3. 结果融合
    final_result = self._merge_results(vector_result, model_result)
    
    return final_result
```

### 1.2 性能瓶颈分析

**串行执行的延迟构成**：
```
向量检索：100ms
模型推理：200ms
结果融合：<1ms
──────────────
总延迟：301ms
```

**关键洞察**：
- 向量检索和模型推理是**独立的**，没有数据依赖
- 向量检索的结果只用于辅助决策，不影响模型推理的输入
- 模型推理的输入（query、tools、history）在调用前就已经准备好
- **两个任务可以并发执行**，总延迟应该是max(100ms, 200ms) = 200ms，而不是100ms + 200ms = 300ms

### 1.3 优化目标

**核心问题**：如何将串行执行改为并发执行，同时保证系统的稳定性和可维护性？

**量化目标**：
- 总延迟降低 > 30%（从300ms降到200ms）
- 吞吐量提升 > 30%
- 不引入新的bug或稳定性问题
- 代码可维护性不降低

---

## 2. 技术方案设计

### 2.1 并发执行方案选择

**方案1：多线程（threading）**
```python
import threading

def search(self, query, tools, ...):
    results = {}
    
    def vector_task():
        results['vector'] = self._vector_search_sync(query, ...)
    
    def model_task():
        results['model'] = self._get_router_result_sync(query, ...)
    
    t1 = threading.Thread(target=vector_task)
    t2 = threading.Thread(target=model_task)
    
    t1.start()
    t2.start()
    
    t1.join()
    t2.join()
    
    return self._merge_results(results['vector'], results['model'])
```

**优点**：
- 实现简单，易于理解
- 可以利用多核CPU

**缺点**：
- 线程切换开销大
- 需要处理线程安全问题
- 不适合IO密集型任务（GIL限制）
- 异常处理复杂

**方案2：多进程（multiprocessing）**
```python
from multiprocessing import Process, Queue

def search(self, query, tools, ...):
    q1 = Queue()
    q2 = Queue()
    
    def vector_task(q):
        result = self._vector_search_sync(query, ...)
        q.put(result)
    
    def model_task(q):
        result = self._get_router_result_sync(query, ...)
        q.put(result)
    
    p1 = Process(target=vector_task, args=(q1,))
    p2 = Process(target=model_task, args=(q2,))
    
    p1.start()
    p2.start()
    
    p1.join()
    p2.join()
    
    vector_result = q1.get()
    model_result = q2.get()
    
    return self._merge_results(vector_result, model_result)
```

**优点**：
- 可以利用多核CPU
- 没有GIL限制

**缺点**：
- 进程创建开销大
- 进程间通信复杂
- 内存占用高
- 不适合短任务

**方案3：异步并发（asyncio）**
```python
import asyncio

async def search(self, query, tools, ...):
    # 并发执行两个异步任务
    vector_task = self._vector_search_task(query, ...)
    model_task = self._get_router_result(query, ...)
    
    # 等待两个任务完成
    vector_result, model_result = await asyncio.gather(
        vector_task,
        model_task
    )
    
    return self._merge_results(vector_result, model_result)
```

**优点**：
- 无线程/进程切换开销
- 适合IO密集型任务
- 代码简洁，易于维护
- 异常处理简单
- 与FastAPI异步框架完美契合

**缺点**：
- 需要所有任务都是异步的
- 不能利用多核CPU（但对于IO密集型任务不是问题）

**决策**：选择方案3（asyncio）

**理由**：
1. **IO密集型**：向量检索和模型推理都是IO操作（HTTP请求），不是CPU密集型
2. **异步框架**：FastAPI本身就是异步框架，使用asyncio最自然
3. **代码简洁**：asyncio.gather一行代码实现并发，易于维护
4. **性能优秀**：无线程切换开销，延迟最低
5. **异常处理**：asyncio.gather支持return_exceptions参数，便于异常处理

### 2.2 核心实现

```python
async def search(
    self,
    trace_id,
    query,
    tools,
    tools_history,
    chat_history=None,
    top_k=10,
    max_score=0.95,
    min_score=0.8,
    request_id='',
    session_id='',
    need_dispatch=False,
    copilot_env='v1',
    base_url='',
    extra={}
):
    """路由主入口"""
    
    # 1. 预处理
    trace_id_ctx_var.set(trace_id)
    chat_history = (chat_history or [])[-6:]  # 保留最近6轮
    
    # 2. 提取工具和构建内容
    tools_result = self._extract_tools(tools, tools_history)
    query_content = self._build_query(query, chat_history, trace_id)
    tools_content = self._build_tools_content(tools_result, tools_history, trace_id)
    
    # 3. 并发执行
    try:
        # 构建任务列表
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
        
        # 模板命中优先返回
        if need_dispatch:
            matched = results[2]
            if matched["template"]["matched"]:
                return _make_result_dict(task_type="easy", fill="template")
        
        # 高分向量命中直接返回
        if is_high_score:
            logger.info(f"命中向量库大于指定阈值的向量，直接返回结果: {q_q_result[0]}")
            task = 'easy' if q_q_result[0] == '简单任务' else 'complex'
            result_dict['post_type'] = 'hit_vector'
            result_dict['task_type'] = task
        
        return result_dict
        
    except Exception as e:
        logger.error(f"query:{query} 出错；原因：{e}")
        traceback.print_exc()
        return _make_result_dict(task_type="complex", fill="err")
```

**关键点解析**：

1. **任务列表构建**：
```python
coroutines = [
    self._vector_search_task(...),
    self._get_router_result(...),
]
```
- 将两个异步任务放入列表
- 任务此时还没有执行，只是创建了coroutine对象

2. **并发执行**：
```python
results = await asyncio.gather(*coroutines, return_exceptions=True)
```
- `*coroutines`：解包列表，传入多个coroutine
- `return_exceptions=True`：即使某个任务抛出异常，也不会中断其他任务
- `await`：等待所有任务完成

3. **结果处理**：
```python
if isinstance(results[0], Exception):
    # 向量搜索失败，降级处理
    q_q_result, is_high_score = [], False
else:
    (q_q_result, is_high_score) = results[0]
```
- 检查每个结果是否是Exception
- 如果是异常，进行降级处理
- 如果是正常结果，解包使用

---

## 3. 关键技术细节

### 3.1 异步任务封装

**问题**：向量检索是同步的（使用requests库），如何转为异步？

**解决方案**：使用`asyncio.to_thread`将同步任务放到线程池执行

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

**关键点**：
1. `asyncio.to_thread(func, *args)`：将同步函数放到线程池执行，返回awaitable对象
2. `asyncio.wait_for(awaitable, timeout)`：设置超时时间
3. 超时或异常时返回空结果，不阻塞主流程

**为什么要用to_thread？**