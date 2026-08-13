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

### 4.2 降级策略详解

#### 4.2.1 向量搜索降级
```python
# 向量搜索失败
if isinstance(results[0], Exception):
    logger.warning(f"向量搜索失败，降级使用路由模型结果")
    q_q_result, is_high_score = [], False
```

**降级效果**：
- 向量搜索不可用时，完全依赖模型推理
- 准确性略有下降，但服务可用

#### 4.2.2 模型推理降级
```python
# 模型推理失败
if isinstance(results[1], Exception):
    logger.error(f"路由模型调用失败")
    return _make_result_dict(task_type="complex", fill="err")
```

**降级效果**：
- 返回统一的错误结果
- 下游系统按complex任务处理

#### 4.2.3 配置同步降级
```python
# 配置同步失败
def __sync_config(self):
    try:
        response = requests.get(self._config_host, params)
        # ...
    except Exception as e:
        print(f"配置同步失败: {e}")
        # 继续使用本地配置
```

**降级效果**：
- 使用本地配置或上次成功的配置
- 下次同步时重试

### 4.3 重试机制

```python
def gen_llm_vsearch_res(text, n_results, trace_id):
    max_retries = 1
    retry_count = 0
    
    while retry_count <= max_retries:
        try:
            # 发送请求
            response = get_session().post(...)
            if response.status_code == 200:
                return transform_data(response.json())
            
            # 准备重试
            retry_count += 1
            logger.warning(f"正在重试 ({retry_count}/{max_retries})")
        except Exception as ex:
            retry_count += 1
            logger.warning(f"异常，正在重试 ({retry_count}/{max_retries})")
    
    return None
```

**设计原则**：
1. **有限重试**：最多重试1次，避免过度重试
2. **指数退避**：重试间隔逐渐增加（未实现）
3. **日志记录**：记录每次重试的原因

## 5. 可扩展性设计理念

### 5.1 模块化设计

#### 5.1.1 高内聚低耦合
```
config/          # 配置管理（独立模块）
data/            # 数据定义（独立模块）
router/          # 路由逻辑（核心模块）
utils/           # 工具函数（支撑模块）
query_retrieval/ # 向量检索（独立模块）
data_process/    # Prompt工程（独立模块）
template/        # 正则模板（独立模块）
```

**设计原则**：
1. **职责单一**：每个模块只负责特定职责
2. **接口清���**：模块间通过明确的接口交互
3. **依赖最小化**：减少模块间的依赖

#### 5.1.2 插件化扩展

```python
# 工具融合规则（可扩展）
TOOL_FUSION_RULES = [
    ({"mage_text_translate", "general_image_qa"}, "general_image_qa"),
    # 可以添加更多融合规则
]

# 正则模板（可扩展）
regex_templates = {
    'timeAndSchedule': time_schedule.regex_template,
    'weather': weather.regex_template,
    'normal': []
    # 可以添加更多领域模板
}
```

**扩展方式**：
1. 添加新的融合规则
2. 添加新的正则模板
3. 添加新的Prompt版本

### 5.2 配置驱动

#### 5.2.1 动态配置
```python
class VivoConfigManager:
    def register_on_change(self, key: str, callback):
        """注册配置变更回调"""
        with self._lock:
            self._on_change_callbacks.append((key, callback))
```

**支持的动态配置**：
- MCP工具映射
- 模型参数
- 业务规则

#### 5.2.2 环境适配
```python
ROUTER_MODEL_URL = {
    "dev": "http://...",
    "pre": "http://...",
    "prd": "http://...",
}

vsearch_config = LLM_VSEARCH_SERVER[os.getenv('APP_ENV', 'dev')]
```

**环境隔离**：
- 不同环境使用不同配置
- 支持环境级别的定制

### 5.3 接口扩展

#### 5.3.1 API版本化
```python
@app.post('/router')
async def handle_router(params: Params):
    # v1版本接口
    ...

# 未来可以添加v2版本
# @app.post('/v2/router')
# async def handle_router_v2(params: ParamsV2):
#     ...
```

#### 5.3.2 参数扩展
```python
class Params(BaseModel):
    # 基础参数
    query: str
    tools: list
    
    # 扩展参数（可选）
    extra: Optional[Any] = None
```

**扩展方式**：
- 添加可选参数
- 使用extra字段传递额外信息
- 保持向后兼容

## 6. 可观测性设计理念

### 6.1 结构化日志

#### 6.1.1 日志格式
```python
log_json = {
    "thread_name": record["thread"].name,
    "message": message,
    "@timestamp": nowtime,
    "level": record["level"].name,
    "mdc": {"traceId": record["extra"].get("traceId", "")},
    "file": os.path.basename(record["file"].name),
    "line_number": record["line"],
    "method": record["function"],
    "source_host": local_host,
    "stacktrace": stacktrace,
}
```

**设计要点**：
1. **JSON格式**：便于日志收集和分析
2. **追踪ID**：关联同一请求的所有日志
3. **上下文信息**：包含文件、行号、方法等

#### 6.1.2 日志级别
```python
logger.info(...)    # 正常流程
logger.warning(...) # 降级处理
logger.error(...)   # 异常情况
```

**使用原则**：
- INFO：正常业务流程
- WARNING：降级、重试等非致命问题
- ERROR：异常、失败等需要关注的问题

### 6.2 性能监控

#### 6.2.1 耗时统计
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
total_start = time.time()
# ... 执行完整流程
logger.info(f"路由总耗时：{time.time() - total_start}")
```

**监控指标**：
- 向量搜索耗时
- 模型推理耗时
- 总路由耗时
- 早停命中率

#### 6.2.2 关键事件记录
```python
logger.info(f"命中向量库大于指定阈值的向量，直接返回结果")
logger.info(f"special prompt注入")
logger.info(f"非历史对话场景，将 abnormal 状态改写为 ok")
```

**记录内容**：
- 关键决策点
- 特殊处理逻辑
- 降级和短路事件

### 6.3 追踪链路

#### 6.3.1 Trace ID传递
```python
# 设置追踪ID
trace_id_ctx_var.set(trace_id)

# 在日志中使用
logger.bind(traceId=trace_id_ctx_var.get()).info(...)
```

**追踪能力**：
- 关联同一请求的所有日志
- 跨服务追踪（配合其他系统）
- 问题定位和排查

## 7. 安全性设计理念

### 7.1 参数验证

```python
class Params(BaseModel):
    query: Optional[Union[str, int, float]] = ''
    tools: Optional[list] = []
    # Pydantic自动进行类型验证
```

**验证内容**：
- 类型检查
- 必填字段检查
- 格式验证

### 7.2 输入过滤

```python
# 过滤特殊工具
EXCLUDED_TOOLS = {
    "confirm_close_alarm",
    "file_agent_allow_upload",
    "show_alarm_card",
    # ...
}
result = [fn for fn in tools if fn not in EXCLUDED_TOOLS]
```

**过滤策略**：
- 移除不需要路由的工具
- 防止恶意工具注入

### 7.3 认证签名

```python
def gen_sign_headers(app_id, app_key, method, uri, query):
    """生成API签名头"""
    timestamp = str(int(time.time()))
    nonce = gen_nonce()
    
    # 构建签名字符串
    signing_string = f"{method}\n{uri}\n{canonical_query}\n..."
    
    # HMAC-SHA256签名
    signature = gen_signature(app_key, signing_string)
    
    return {
        'X-AI-GATEWAY-SIGNATURE': signature,
        'X-AI-GATEWAY-TIMESTAMP': timestamp,
        'X-AI-GATEWAY-NONCE': nonce,
    }
```

**安全措施**：
- HMAC-SHA256签名
- 时间戳防重放攻击
- 随机数保证唯一性

## 8. 设计理念总结

### 8.1 核心原则

1. **性能优先**：并发执行、短路优化、连接池化
2. **容错降级**：多层容错、优雅降级、重试机制
3. **模块化设计**：高内聚低耦合、插件化扩展
4. **可观测性**：结构化日志、性能监控、追踪链路
5. **配置驱动**：动态配置、环境适配、热更新

### 8.2 设计权衡

| 维度 | 选择 | 原因 |
|------|------|------|
| 准确性 vs 性能 | 性能优先（短路优化） | 业务场景对延迟敏感 |
| 复杂性 vs 可维护性 | 模块化设计 | 便于长期维护 |
| 功能完整 vs 快速交付 | 渐进式迭代 | 快速验证核心价值 |
| 强一致性 vs 可用性 | 可用性优先（降级策略） | 服务可用性更重要 |

### 8.3 未来演进方向

1. **更智能的短路**：基于历史数据动态调整早停标签
2. **模型轻量化**：使用更小的模型，进一步降低延迟
3. **缓存优化**：对高频query进行结果缓存
4. **A/B测试框架**：支持Prompt和策略的A/B测试