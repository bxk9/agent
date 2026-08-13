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
        logger.warning(f"���量库搜索异常，降级返回空结果：{e}，耗时：{vector_cost}ms")
        return [], False
    
    vector_cost = int(time.time() * 1000) - vector_start
    logger.info(f"向量库搜索耗时：{vector_cost}ms")
    
    if max_score_result:
        return max_score_result, True
    return min_score_result, False
```

**关键点**：
- 使用`asyncio.to_thread`将同步调用转为异步
- 使用`asyncio.wait_for`设置2秒超时
- 超时或异常时返回空结果，不阻塞主流程

#### 2.3.3 结果融合逻辑

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
```

**融合优先级**：
1. 正则模板命中 → 直接返回easy
2. 向量高分命中（>0.95）→ 直接返回
3. 模型推理结果 → 后处理返回

#### 2.3.4 HTTP连接池优化

```python
# utils/request_llm.py

# 全局复用的httpx.AsyncClient
_async_http_client: httpx.AsyncClient | None = None

def _get_async_http_client() -> httpx.AsyncClient:
    global _async_http_client
    if _async_http_client is None:
        _async_http_client = httpx.AsyncClient(
            timeout=httpx.Timeout(60.0, connect=5.0),
            limits=httpx.Limits(
                max_connections=200,
                max_keepalive_connections=100
            ),
        )
    return _async_http_client

# OpenAI客户端缓存
_async_client_cache = {}
def _get_async_openai_client(base_url):
    if base_url not in _async_client_cache:
        _async_client_cache[base_url] = AsyncOpenAI(api_key='EMPTY', base_url=base_url)
    return _async_client_cache[base_url]
```

**连接池配置**：
- `max_connections=200`: 最大连接数
- `max_keepalive_connections=100`: 保持活动的连接数
- `timeout=60s`: 请求超时时间
- `connect=5s`: 连接超时时间

### 2.4 效果评估

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 总耗时（串行） | 300ms | 200ms | **降低33%** |
| 连接建立开销 | 150ms/次 | 0ms（复用） | **降低100%** |
| 吞吐量 | ~30 QPS | ~50 QPS | **提升67%** |

**并发执行时序图**：
```
时间轴 (ms)
0    50   100   150   200   250   300
|----|----|----|----|----|----|----|

串行执行：
[向量检索 100ms][模型推理 200ms]
总耗时：300ms

并发执行：
[向量检索 100ms]
[模型推理      200ms]
总耗时：200ms（取最大值）
```

### 2.5 关键代码文件

- `router/router_v2.py`: 并发调度逻辑（675行）
- `utils/request_llm.py`: HTTP连接池（163行）
- `utils/request_llm_v2.py`: SGLang调用（310行）

---

## 3. Prompt工程与分类准确性

### 3.1 问题描述

**背景**：需要从4个维度对用户query进行分类，每个维度有多个标签，总计14个标签。

**痛点**：
- 分类边界模糊，容易误判
- 规则复杂，模型难以理解
- 需要覆盖大量边界case
- 输出格式必须严格符合预期

**目标**：分类准确率 > 95%，输出格式100%正确。

### 3.2 技术难点

1. **分类标准定义**：需要清晰、无歧义的分类标准
2. **规则体系构建**：需要处理优先级、绑定、排除等复杂规则
3. **示例设计**：需要覆盖常见和边界场景
4. **输出格式控制**：需要确保模型输出严格符合格式要求
5. **迭代优化**：需要根据实际case持续优化

### 3.3 解决方案

#### 3.3.1 四维度分类体系

```python
# data_process/router_prompt.py

system_prompt_core = """
# 分类标准

## 一、工具调用类型
1. multi：（多工具调用）用户任务包含多个子任务，需要调用多个不同工具才能完成任务。
   - 扩展规则：必须先调用额外的工具完成隐含的前置操作的情况，也属于multi。
   - 扩展规则：对于含single子任务+任意非single子任务的混合query，整体归为multi。

2. pend：（工具待确定）用户诉求方向本身不明确，或该指令有多个相似候选工具可以选择。
   - 排除规则：若能明确该调用哪个候选工具，只是参数问题，则不属于pend。
   - 排除规则（播放类默认锚定）：仅针对播放类任务，"播放XX"默认锚定播放类工具，判single而非pend。

3. unsupported：（工具不支持）用户query是明确的任务指令，但当前候选工具中没有能够支持该任务的工具。
   - 扩展规则：任务内容严重违反道德习俗、社会价值观或社会秩序，也属于unsupported。

4. single：（单工具调用）只需要调用单个候选工具，即可完成任务。
   - 扩展规则（常识消歧）：当query的动作+对象齐全，结合用户习惯与生活常识存在唯一高概率指向时，应按该高概率意图锁定对应候选工具。

5. qa：（知识问答）用户提出各领域的知识性问题，可使用knowledgeQA工具回答。
   - 扩展规则：以任务形式要求输出特定内容的场景，包括文本创作/邮件起草/文本翻译等，也属于qa。

6. chat：（闲聊）不包含任何明确的功能操作或执行类诉求、纯满足对话交互或情绪价值的场景。

## 二、意图明确度
1. clear：（意图清晰）用户诉求方向明确，所有关键参数都已具备。
2. lack：（参数信息不足）用户诉求方向明确，但缺少执行所需的关键参数。
3. infer：（参数需要推理）用户诉求方向明确，但给的关键参数需经过一次推理转换才能得到可用值。
4. vague：（意图模糊）用户诉求方向不明，或意图模糊，必须先跟用户澄清"要做什么"才能继续。

## 三、指令类型
1. cond：（条件指令）query中包含触发条件 + 条件满足时执行的任务，且该条件需由外部调度器/监听器在满足时才能触发执行。
2. norm：（普通指令）除条件指令外的所有情况都属于普通指令。

## 四、执行反馈状态
1. abnormal：（异常反馈）多轮对话中，用户对模型在历史对话中的理解、调用或执行表现出不满或纠正，本质是"错源在模型"。
2. ok：（正常推进）除异常反馈外的所有情况均属于正常推进。
"""
```

#### 3.3.2 优先级与绑定规则

```python
system_prompt_base = """
你是一个手机用户的query意图拆解专家。你的任务是根据手机用户的当前query和历史对话，结合候选工具定义，从下面四个维度对用户当前query的意图进行分类。

""" + system_prompt_core + """

# 处理规则
1. 默认值规则：若工具定义中注明了某参数有默认值，用户未提供该参数时，使用默认值，视为clear。
2. 工具调用类型优先级：multi > pend > unsupported > single > qa > chat
3. 意图明确度优先级：vague > infer > lack > clear
4. 意图明确度强绑定：
   - 工具调用类型 ∈ {chat, qa, unsupported} → 强绑定clear
   - 工具调用类型 = pend → 强绑定vague
"""
```

**规则设计逻辑**：
- **优先级规则**：当多个标签符合时，选择优先级最高的
- **强绑定规则**：某些工具类型必然对应特定的意图明确度
- **默认值规则**：工具定义的默认值视为已提供

#### 3.3.3 输出格式控制

```python
output_format_no_reason = """
# 推理步骤（强制执行，不得跳过）
在输出标签前，请在内心按顺序完成以下判断：
   - ① 基于分类标准、工具定义、query和history，确定[工具调用类型]
   - ② 基于①的结论、工具定义和分类标准，判断[意图明确度]
   - ③ 检查query中是否含"外部条件触发+待执行任务"结构，判断[指令类型]
   - ④ 判断当前query是否含异常反馈，判断[执行反馈状态]
然后再按顺序输出最终的4个标签。

# 输出要求 (绝对死线约束)
1. 输出格式: 必须且只能输出由4个小写英文单词组成的字符串，标签之间仅用1个空格' '分隔。
2. 绝对禁止: 禁止输出任何冒号、前缀、逗号、换行符、中文字符或额外的解释说明。
3. 顺序必须固定: 位置永远对应 [工具调用类型] [意图明确度] [指令类型] [执行反馈状态]
4. 输出强制白名单(且仅限小写):
   - 位置1: multi, pend, unsupported, single, qa, chat
   - 位置2: clear, lack, infer, vague
   - 位置3: cond, norm
   - 位置4: abnormal, ok
"""
```

**格式控制要点**：
- 使用空格分隔（便于SGLang早停）
- 严格禁止其他字符
- 固定输出顺序
- 白名单约束

#### 3.3.4 典型示例库

```python
case_no_reason = """