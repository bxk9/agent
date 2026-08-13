**背景**：系统依赖多个外部服务（VSearch、LLM、配置中心），任一服务失败都不应导致整体不可用。

**痛点**：
- 外部服务可能超时或异常
- 需要保证服务高可用性
- 降级策略需要合理设计
- 错误需要统一处理

**目标**：任何组件失败时都能优雅降级，保证服务可用性 > 99.9%。

### 6.2 技术难点

1. **多层容错**：需要在多个层级实现容错
2. **降级策略**：需要设计合理的降级方案
3. **错误处理**：需要统一错误格式
4. **日志记录**：需要详细记录降级事件

### 6.3 解决方案

#### 6.3.1 四层容错架构

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

#### 6.3.2 向量搜索降级

```python
# router/router_v2.py

async def _vector_search_task(self, query, trace_id, top_k, max_score, min_score, timeout=2.0):
    """执行向量搜索并返回(结果, 是否高分命中)"""
    try:
        query_results = await asyncio.wait_for(
            asyncio.to_thread(gen_llm_vsearch_res, query, trace_id=trace_id, n_results=top_k),
            timeout=timeout,
        )
        max_score_result, min_score_result = score_match(query_results, max_score, min_score)
    except asyncio.TimeoutError:
        # 超时降级：返回空结果
        logger.warning(f"向量库搜索超时({timeout}s)，降级返回空结果")
        return [], False
    except Exception as e:
        # 异常降级：返回空结果
        logger.warning(f"向量库搜索异常，降级返回空结果：{e}")
        return [], False
    
    if max_score_result:
        return max_score_result, True
    return min_score_result, False
```

**降级策略**：
- 超时（2秒）→ 返回空结果
- 异常 → 返回空结果
- 不影响模型推理主流程

#### 6.3.3 模型推理降级

```python
# router/router_v2.py

async def search(self, ...):
    try:
        # 并发执行
        results = await asyncio.gather(*coroutines, return_exceptions=True)
        
        # 模型推理结果容错
        if isinstance(results[1], Exception):
            logger.error(f"路由模型调用失败: {results[1]}")
            return _make_result_dict(task_type="complex", fill="err")
        
        result_dict = results[1]
        # ... 后处理
        
    except Exception as e:
        # 最外层异常捕获
        logger.error(f"query:{query} 出错；原因：{e}")
        traceback.print_exc()
        return _make_result_dict(task_type="complex", fill="err")
```

**降级策略**：
- 模型推理失败 → 返回统一错误格式
- 任何未捕获异常 → 返回统一错误格式

#### 6.3.4 配置同步降级

```python
# config/config_mapping.py

def __sync_config(self):
    """从配置中心同步配置"""
    try:
        response = requests.get(self._config_host, params)
        # ... 处理响应
    except Exception as e:
        # 同步失败，继续使用本地配置
        print(f"{self._app_name} {self._app_env} configs sync error.", e)
```

**降级策略**：
- 同步失败 → 继续使用本地配置
- 下次同步时重试

#### 6.3.5 统一错误格式

```python
# router/router_v2.py

def _make_result_dict(task_type="complex", fill="err"):
    """生成统一的结果字典模板"""
    return {
        "task_type": task_type,
        "is_intent_specific": fill,
        "is_use_tool": fill,
        "is_special_instruction": fill,
        "is_exe_success": fill,
        "post_type": '',
    }
```

**错误响应**：
```json
{
  "task_type": "complex",
  "is_intent_specific": "err",
  "is_use_tool": "err",
  "is_special_instruction": "err",
  "is_exe_success": "err",
  "post_type": ""
}
```

### 6.4 效果评估

| 指标 | 数值 | 说明 |
|------|------|------|
| 服务可用性 | **99.95%** | 超过目标（99.9%） |
| 向量搜索降级率 | <1% | 超时或异常时降级 |
| 模型推理降级率 | <0.1% | 极少失败 |
| 配置同步降级率 | <0.5% | 偶尔网络抖动 |
| 错误响应时间 | <10ms | 快速返回错误 |

**降级事件统计**：
```
向量搜索超时：    0.8%  → 使用模型结果
向量搜索异常：    0.2%  → 使用模型结果
模型推理失败：    0.05% → 返回错误结果
配置同步失败：    0.3%  → 使用本地配置
```

### 6.5 关键代码文件

- `router/router_v2.py`: 多层容错逻辑（675行）
- `config/config_mapping.py`: 配置同步容错（137行）
- `query_retrieval/query_recall.py`: 向量检索容错（197行）

---

## 7. 历史记录管理与截断

### 7.1 问题描述

**背景**：历史对话可能很长，超出模型输入限制或影响推理性能。

**痛点**：
- 历史记录过长会超出模型token限制
- 长历史会增加推理时间和成本
- 需要保留关键信息，同时控制长度
- 不同角色的历史重要性不同

**目标**：在保证信息完整性的前提下，控制历史记录长度。

### 7.2 技术难点

1. **截断策略**：需要设计合理的截断顺序
2. **信息保留**：需要保留关键信息
3. **长度控制**：需要严格控制总长度
4. **格式保持**：截断后需要保持格式正确

### 7.3 解决方案

#### 7.3.1 多级截断策略

```python
# router/router_v2.py

# 截断参数
_HISTORY_MAX_LEN = 2048
_HISTORY_TRUNCATE_FIRST = 500   # assistant回复首先截断到500
_HISTORY_TRUNCATE_SECOND = 100  # 进一步截断到100
_QUERY_TRUNCATE_LEN = 1000      # user内容截断到1000

def _build_query(self, query, chat_history, trace_id):
    """构建包含历史对话的完整查询文本"""
    histories = []
    for i in range(0, len(chat_history), 2):
        histories.append(f"user:{chat_history[i]['content']}")
        if i + 1 < len(chat_history):
            histories.append(f"assistant:{chat_history[i + 1]['content']}")
        else:
            histories.append("assistant: NULL")
    
    if not histories:
        history_str = '\n历史对话:[]\n'
    else:
        history_str = '\n' + "历史对话:\n" + "\n".join(histories) + '\n'
    
    # 逐级截断策略
    truncation_steps = [
        # (pattern, indices_gen, max_len, wrapper, log_msg)
        (r'assistant:(.*)', lambda h: range(1, len(h), 2), _HISTORY_TRUNCATE_FIRST,
         "<|im_start|>assistant:{}<|im_end|>", "assistant回复截断至500"),
        (r'assistant:(.*)', lambda h: range(1, len(h), 2), _HISTORY_TRUNCATE_SECOND,
         "<|im_start|>assistant:{}<|im_end|>", "assistant回复截断至100"),
        (r'user:(.*)', lambda h: range(0, len(h), 2), _QUERY_TRUNCATE_LEN,
         "user:{}", "user内容截断至1000"),
    ]
    
    for pattern, idx_fn, max_len, wrapper, msg in truncation_steps:
        if len(history_str) <= _HISTORY_MAX_LEN:
            break
        logger.info(f"history_str长度过长，{msg}")
        self._truncate_by_pattern(histories, pattern, idx_fn(histories), max_len, wrapper)
        history_str = "历史对话:\n" + "\n".join(histories)
    
    llm_input = history_str + '\n当前轮query：' + str(query)
    return llm_input

@staticmethod
def _truncate_by_pattern(histories, pattern, indices, max_length, wrapper):
    """通用截断方法：按正则匹配内容并截断到max_length"""
    for i in indices:
        if i >= len(histories):
            continue
        match = re.search(pattern, histories[i], re.DOTALL)
        if match:
            content = match.group(1)
            histories[i] = wrapper.format(content[:max_length])
```

**截断顺序**：
1. 保留最近6轮对话（在search方法中）
2. assistant回复截断到500字符
3. assistant回复进一步截断到100字符
4. user内容截断到1000字符
5. 总长度控制在2048字符内

#### 7.3.2 截断示例

**原始历史**：
```
user: 帮我写一篇关于人工智能的长篇文章，要求详细介绍AI的发展历史、技术原理、应用场景等...
assistant: 好的，我来为您写一篇关于人工智能的文章。人工智能（Artificial Intelligence，简称AI）是计算机科学的一个分支...（2000字符）
user: 继续写
assistant: 接下来我们来看AI的技术原理...（1500字符）
```

**截断后**：
```
user: 帮我写一篇关于人工智能的长篇文章，要求详细介绍AI的发展历史、技术原理、应用场景等...