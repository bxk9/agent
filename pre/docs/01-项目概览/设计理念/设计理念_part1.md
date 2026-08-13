# Dynamic Router 设计理念

## 1. 整体设计理念

### 1.1 核心设计哲学

Dynamic Router 的设计遵循以下核心哲学：

1. **性能优先**：在保证准确性的前提下，最大化降低延迟
2. **模块化设计**：高内聚低耦合，便于维护和扩展
3. **容错降级**：任何组件失败都不应导致整体服务不可用
4. **可观测性**：完善的日志和监控，便于问题定位
5. **配置驱动**：业务逻辑与配置分离，支持热更新

### 1.2 设计目标

#### 1.2.1 性能目标
- **响应时间**：P99 < 500ms
- **吞吐量**：支持高并发请求
- **资源利用**：最大化利用异步IO和并发能力

#### 1.2.2 准确性目标
- **分类准确率**：> 95%
- **误判率**：< 5%
- **边界case覆盖**：覆盖常见和边界场景

#### 1.2.3 可用性目标
- **服务可用性**：> 99.9%
- **降级成功率**：100%（任何失败都能降级）
- **恢复时间**：自动恢复，无需人工干预

## 2. 架构设计理念

### 2.1 分层架构

```
┌─────────────────────────────────────────┐
│         API Layer (接口层)               │
│  - 请求验证                              │
│  - 参数解析                              │
│  - 响应格式化                            │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│       Router Layer (路由层)              │
│  - 并发调度                              │
│  - 结果融合                              │
│  - 后处理逻辑                            │
└─────────────────────────────────────────┘
                  ↓
    ┌─────────────┴─────────────┐
    ↓                           ↓
┌──────────┐            ┌──────────┐
│ Vector   │            │   LLM    │
│ Search   │            │Inference │
└──────────┘            └──────────┘
                  ↓
┌─────────────────────────────────────────┐
│       Support Layer (支撑层)             │
│  - Config (配置管理)                     │
│  - Utils (工具函数)                      │
│  - Data (数据定义)                       │
└─────────────────────────────────────────┘
```

**设计原则**：
1. **职责单一**：每层只负责特定职责
2. **依赖倒置**：上层不依赖下层的具体实现
3. **接口隔离**：层与层之间通过清晰的接口交互

### 2.2 并发执行策略

#### 2.2.1 设计理念
```
传统串行执行：
向量搜索 (100ms) → 模型推理 (200ms) → 总耗时 300ms

并发执行：
向量搜索 (100ms) ┐
                  ├→ 总耗时 max(100, 200) = 200ms
模型推理 (200ms) ┘
```

**性能提升**：33%

#### 2.2.2 实现方式
```python
# 使用 asyncio.gather 并发执行
coroutines = [
    self._vector_search_task(...),
    self._get_router_result(...),
]
results = await asyncio.gather(*coroutines)
```

**设计优势**：
- 充分利用异步IO
- 总耗时取最大值而非累加
- 资源利用率最大化

### 2.3 短路优化策略

#### 2.3.1 问题背景
传统方式下，模型需要生成完整的4个字段：
```
输入：用户query
输出：single clear norm ok
Token数：4个标签 + 3个分隔符 = 7 tokens
耗时：~100ms
```

但很多时候，第一个字段就能确定任务复杂度：
```
如果 is_use_tool = "multi" → task_type = "complex"
无需生成后续字段
```

#### 2.3.2 解决方案
使用 SGLang 的 `stop_token_ids` 实现早停：

```python
STOP_TOKEN_IDS = [
    25429,  # multi
    9398,   # chat
    3613,   # pend
    14992,  # qa
    # ... 其他早停标签
]

payload = {
    "text": prompt,
    "sampling_params": {
        "stop_token_ids": stop_token_ids,
        # ...
    }
}
```

**优化效果**：
```
早停方式：
输入：用户query
输出：multi (生成到multi时停止)
Token数：1个标签 = 1 token
耗时：~20ms
```

**性能提升**：80%

#### 2.3.3 早停规则设计

**字段1（工具类型）早停**：
- `multi` → 跳过后续3个字段
- `chat` → 跳过后续2个字段
- `pend` → 跳过后续2个字段
- `qa` → 跳过后续3个字段

**字段2（意图明确度）早停**：
- `infer` → 跳过后续2个字段
- `vague` → 跳过后续2个字段

**字段3（指令类型）早停**：
- `cond` → 跳过后续1个字段

**字段4（执行状态）早停**：
- `abnormal` → 不跳过（已是最后一个字段）

**设计原则**：
1. **确定性优先**：只有能确定task_type的标签才触发早停
2. **信息完整**：早停后仍能正确计算task_type
3. **性能收益**：早停标签应该是高频出现的

### 2.4 多路融合策略

#### 2.4.1 设计理念
结合多种信息源，提高分类准确性：

```
┌──────────────┐
│  向量检索     │ → 语义相似度匹配
└──────────────┘
       ↓
┌──────────────┐
│  正则模板     │ → 规则匹配
└──────────────┘
       ↓
┌──────────────┐
│  模型推理     │ → 深度理解
└──────────────┘
       ↓
┌──────────────┐
│  结果融合     │ → 智能决策
└──────────────┘
```

#### 2.4.2 融合优先级

```python
# 1. 正则模板命中 → 直接返回
if template_matched:
    return easy_result

# 2. 向量高分命中 → 直接返回
if vector_score > 0.95:
    return vector_result

# 3. 模型推理结果 → 后处理
return model_result
```

**设计原则**：
1. **规则优先**：确定性高的规则优先
2. **快速路径**：高置信度结果快速返回
3. **模型兜底**：模型推理作为通用解决方案

## 3. 性能优化理念

### 3.1 连接池化

#### 3.1.1 问题背景
HTTP连接建立开销大：
- TCP三次握手：~50ms
- TLS握手：~100ms
- 连接建立：~150ms

频繁创建/销毁连接会导致：
- 延迟增加
- 资源浪费
- 端口耗尽

#### 3.1.2 解决方案

```python
# HTTP客户端连接池
_async_http_client = httpx.AsyncClient(
    timeout=httpx.Timeout(60.0, connect=5.0),
    limits=httpx.Limits(
        max_connections=200,
        max_keepalive_connections=100
    )
)

# OpenAI客户端缓存
_async_client_cache = {}
def _get_async_openai_client(base_url):
    if base_url not in _async_client_cache:
        _async_client_cache[base_url] = AsyncOpenAI(...)
    return _async_client_cache[base_url]
```

**设计要点**：
1. **单例模式**：全局复用同一个客户端
2. **连接池配置**：合理设置连接池大小
3. **超时控制**：避免连接长时间占用

**性能提升**：
- 连接建立开销：150ms → 0ms（复用连接）
- 吞吐量提升：3-5倍

### 3.2 历史记录截断

#### 3.2.1 ��题背景
历史对话过长会导致：
- Prompt超长，超出模型限制
- 推理时间增加
- Token成本增加

#### 3.2.2 截断策略

```python
_HISTORY_MAX_LEN = 2048
_HISTORY_TRUNCATE_FIRST = 500   # assistant回复首先截断到500
_HISTORY_TRUNCATE_SECOND = 100  # 进一步截断到100
_QUERY_TRUNCATE_LEN = 1000      # user内容截断到1000
```

**截断顺序**：
1. 保留最近6轮对话
2. assistant回复截断到500字符
3. assistant回复进一步截断到100字符
4. user内容截断到1000字符
5. 总长度控制在2048字符内

**设计原则**：
1. **渐进式截断**：先截断assistant，再截断user
2. **保留关键信息**：user内容比assistant更重要
3. **长度控制**：总长度不超过模型限制

### 3.3 超时降级

#### 3.3.1 设计理念
任何外部依赖都可能失败，必须有降级策略：

```python
async def _vector_search_task(..., timeout=2.0):
    try:
        query_results = await asyncio.wait_for(
            asyncio.to_thread(gen_llm_vsearch_res, ...),
            timeout=timeout,
        )
    except asyncio.TimeoutError:
        # 超时降级：返回空结果
        return [], False
    except Exception as e:
        # 异常降级：返回空结果
        return [], False
```

**降级策略**：
1. **向量搜索失败** → 使用模型结果
2. **模型推理失败** → 返回错误结果
3. **配置同步失败** → 使用本地配置

**设计原则**：
1. **快速失败**：设置合理超时时间
2. **优雅降级**：失败时返回可用结果
3. **不阻塞主流程**：降级不影响其他组件

### 3.4 缓存策略

#### 3.4.1 客户端缓存
```python
_client_cache = {}
def get_client(base_url):
    if base_url not in _client_cache:
        _client_cache[base_url] = OpenAI(...)
    return _client_cache[base_url]
```

#### 3.4.2 配置缓存
```python
class VivoConfigManager:
    _configs: dict = {}  # 本地配置缓存
    
    def get_config(self, key, default_value=None):
        with self._lock:
            return self._configs.get(key, default_value)
```

**设计原则**：
1. **按需缓存**：只缓存频繁访问的数据
2. **缓存失效**：支持缓存更新和失效
3. **线程安全**：使用锁保护缓存访问

## 4. 容错与降级理念

### 4.1 多层容错

```
┌─────────────────────────────────────┐
│  Layer 1: 参数验证                   │
│  - Pydantic参数校验                  │
│  - 类型检查                          │
│  - 默认值填充                        │