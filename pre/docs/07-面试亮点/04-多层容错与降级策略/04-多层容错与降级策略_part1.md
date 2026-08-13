# 多层容错与降级策略 - 面试亮点

> **核心价值**：设计并实现了四层容错架构，通过参数验证、异常捕获、降级策略、兜底返回四个层次，将系统可用性从99%提升到99.95%，保证了生产环境的高可用性。

---

## 1. 项目背景与问题定义

### 1.1 业务场景

Dynamic Router是一个在线服务，依赖多个外部系统：
1. **VSearch向量检索服务**：检索相似query的历史分类结果
2. **LLM推理服务**：调用大模型进行四维度分类
3. **配置中心**：动态更新MCP工具映射等业务规则

**生产环境的挑战**：
- 外部服务可能超时、异常、不可用
- 网络抖动、服务重启、资源不足等问题随时可能发生
- 任何一个依赖失败都不应该导致整个服务不可用
- 需要在保证可用性的同时，尽量保证准确性

### 1.2 初始方案的问题

**V1.0方案（无容错）**：
```python
async def search(self, query, tools, ...):
    # 1. 向量检索
    vector_result = await self._vector_search_task(query, ...)
    
    # 2. 模型推理
    model_result = await self._get_router_result(query, ...)
    
    # 3. 结果融合
    return self._merge_results(vector_result, model_result)
```

**问题分析**：
1. **向量检索失败**：抛出异常，整个请求失败
2. **模型推理失败**：抛出异常，整个请求失败
3. **配置同步失败**：使用旧配置，可能导致规则不一致
4. **参数验证失败**：FastAPI返回422错误，用户体验差

**实际生产数据**（V1.0版本）：
- 服务可用性：99%（每月约7小时不可用）
- 向量检索失败率：0.8%（超时或异常）
- 模型推理失败率：0.05%（极少失败）
- 配置同步失败率：0.3%（偶尔网络抖动）

**关键洞察**：
- 向量检索是辅助功能，失败时可以使用模型结果
- 模型推理是核心功能，失败时需要返回错误结果
- 配置同步失败时，可以继续使用旧配置
- 需要多层容错，保证任何组件失败都不影响整体服务

### 1.3 优化目标

**核心问题**：如何设计多层容错架构，在保证可用性的同时，尽量保证准确性？

**量化目标**：
- 服务可用性 > 99.9%（每月不可用时间 < 43分钟）
- 向量检索失败时，准确率下降 < 2%
- 模型推理失败时，返回统一的错误格式
- 配置同步失败时，不影响服务运行

---

## 2. 四层容错架构设计

### 2.1 架构概览

```
┌─────────────────────────────────────┐
│  Layer 1: 参数验证                   │
│  - Pydantic参数校验                  │
│  - 类型检查                          │
│  - 默认值填充                        │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Layer 2: 异常捕获                   │
│  - try-except包裹关键逻辑            │
│  - 详细错误日志                      │
│  - 统一错误格式                      │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Layer 3: 降级策略                   │
│  - 向量搜索失败 → 使用模型结果        │
│  - 模型推理失败 → 返回错误结果        │
│  - 配置同步失败 → 使用本地配置        │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Layer 4: 兜底返回                   │
│  - 统一错误格式                      │
│  - task_type = "complex"             │
│  - 所有字段 = "err"                  │
└─────────────────────────────────────┘
```

### 2.2 Layer 1: 参数验证

**目标**：在请求进入业务逻辑前，验证参数的合法性和完整性

**实现**：使用Pydantic进行参数验证

```python
# data/params.py

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
    copilot_env: Optional[str] = 'v1'
    base_url: Optional[str] = ''
    extra: Optional[Any] = None
```

**验证规则**：
1. **类型检查**：query可以是str/int/float，自动转换为str
2. **默认值填充**：可选参数提供默认值，避免None
3. **必填检查**：虽然都是Optional，但业务逻辑会检查关键字段

**FastAPI自动验证**：
```python
# main.py

@app.post('/router')
async def handle_router(params: Params):
    """主路由接口"""
    result = await router_instance.search(
        trace_id=params.trace_id,
        query=params.query,
        tools=params.tools,
        tools_history=params.tools_history,
        chat_history=params.chat_history,
        need_dispatch=params.need_dispatch,
        copilot_env=params.copilot_env,
        extra=params.extra
    )
    return result
```

**验证失败处理**：
- FastAPI自动返回422错误
- 包含详细的错误信息（哪个字段、什么错误）
- 客户端可以根据错误信息修正请求

**示例**：
```json
// 请求
{
  "query": 123,  // int类型，会自动转换为str
  "tools": "invalid"  // 应该是list，但传了str
}

// 响应（422错误）
{
  "detail": [
    {
      "loc": ["body", "tools"],
      "msg": "value is not a valid list",
      "type": "type_error.list"
    }
  ]
}
```

### 2.3 Layer 2: 异常捕获

**目标**：捕获业务逻辑中的异常，避免未捕获异常导致服务崩溃

**实现**：在关键逻辑外层包裹try-except

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
    
    # 3. 并发执行（最外层异常捕获）
    try:
        coroutines = [
            self._vector_search_task(query, trace_id, top_k, max_score, min_score),
            self._get_router_result(query, query_content, tools_content, trace_id),
        ]
        
        results = await asyncio.gather(*coroutines, return_exceptions=True)
        
        # 4. 结果处理
        # ... (详见下文)
        
    except Exception as e:
        # 最外层异常捕获：任何未预期的异常
        logger.error(f"query:{query} 出错；原因：{e}")
        traceback.print_exc()
        return _make_result_dict(task_type="complex", fill="err")
```

**异常捕获层次**：

**层次1：最外层（search方法）**
```python
try:
    # 整个业务逻辑
    ...
except Exception as e:
    logger.error(f"query:{query} 出错；原因：{e}")
    traceback.print_exc()
    return _make_result_dict(task_type="complex", fill="err")
```
- 捕获任何未预期的异常
- 记录详细错误日志（包含堆栈）
- 返回统一的错误格式

**层次2：并发任务层（asyncio.gather）**
```python
results = await asyncio.gather(*coroutines, return_exceptions=True)
```
- `return_exceptions=True`：即使某个任务抛出异常，也不会中断其他任务
- 异常作为结果返回，而不是抛出

**层次3：单个任务层（vector_search_task、get_router_result）**
```python
async def _vector_search_task(self, ...):
    try:
        query_results = await asyncio.wait_for(
            asyncio.to_thread(gen_llm_vsearch_res, ...),
            timeout=timeout,
        )
        # ...
    except asyncio.TimeoutError:
        logger.warning(f"向量库搜索超时({timeout}s)")
        return [], False
    except Exception as e:
        logger.warning(f"向量库搜索异常：{e}")
        return [], False
```
- 捕获特定异常（TimeoutError）和通用异常（Exception）
- 记录警告日志
- 返回降级结果（空列表）

### 2.4 Layer 3: 降级策略

**目标**：当某个组件失败时，使用备选方案，保证服务可用

**实现**：根据组件的重要性和失败原因，选择不同的降级策略

#### 2.4.1 向量检索降级

**策略**：向量检索失败时，使用模型推理结果

```python
# 向量搜索结果容错
if isinstance(results[0], Exception):
    logger.warning(f"向量搜索失败，降级使用路由模型结果: {results[0]}")
    q_q_result, is_high_score = [], False
else:
    (q_q_result, is_high_score) = results[0]
```

**降级逻辑**：
1. 检查向量检索结果是否是Exception
2. 如果是异常，记录警告日志
3. 将向量检索结果设为空列表，is_high_score设为False
4. 后续逻辑会使用模型推理结果

**影响分析**：
- 向量检索是辅助功能，用于加速高频query
- 失败时准确率下降约1-2%（可接受）
- 延迟增加约50ms（需要完全依赖模型推理）

#### 2.4.2 模型推理降级

**策略**：模型推理失败时，返回统一的错误格式

```python
# 路由模型结果容错
if isinstance(results[1], Exception):
    logger.error(f"路由模型调用失败: {results[1]}")
    return _make_result_dict(task_type="complex", fill="err")
result_dict = results[1]
```

**降级逻辑**：