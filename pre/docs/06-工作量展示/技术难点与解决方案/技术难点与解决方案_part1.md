# Dynamic Router 技术难点与解决方案

> 记录项目开发过程中遇到的核心技术挑战及解决方案

---

## 目录

1. [SGLang早停优化](#1-sglang早停优化)
2. [并发执行与性能优化](#2-并发执行与性能优化)
3. [Prompt工程与分类准确性](#3-prompt工程与分类准确性)
4. [动态配置热更新](#4-动态配置热更新)
5. [向量检索与结果融合](#5-向量检索与结果融合)
6. [多层容错与降级策略](#6-多层容错与降级策略)
7. [历史记录管理与截断](#7-历史记录管理与截断)
8. [工具定义管理与映射](#8-工具定义管理与映射)

---

## 1. SGLang早停优化

### 1.1 问题描述

**背景**：路由分类需要输出4个维度的标签（工具类型、意图明确度、指令类型、执行状态），完整输出需要生成7个token（4个标签 + 3个分隔符），耗时约100ms。

**痛点**：
- 某些标签（如`multi`、`chat`）一旦确定，后续字段对决策无用
- 完整生成浪费计算资源和时间
- 高并发场景下延迟累积明显

**目标**：在模型生成到特定标签时提前终止，减少不必要的token生成。

### 1.2 技术难点

1. **Token ID映射**：需要准确获取每个早停标签对应的token ID
2. **字段位置推断**：根据已生成的token数量推断当前处于哪个字段
3. **字段补全逻辑**：早停后需要正确补全剩余字段为空字符串
4. **SGLang API适配**：需要正确使用`stop_token_ids`参数

### 1.3 解决方案

#### 1.3.1 早停标签定义

```python
# utils/request_llm_v2.py

# 定义8个早停标签及其token ID
EARLY_STOP_LABELS = [
    "multi", "chat", "pend", "qa",      # 字段1：工具类型
    "infer", "vague",                    # 字段2：意图明确度
    "cond",                              # 字段3：指令类型
    "abnormal"                           # 字段4：执行状态
]

STOP_TOKEN_IDS = [
    25429,  # multi
    9398,   # chat
    3613,   # pend
    14992,  # qa
    22846,  # infer
    37753,  # vague
    9464,   # cond
    33418   # abnormal
]

# 建立ID到标签的反向映射
STOP_ID_TO_LABEL = {v: k for k, v in zip(EARLY_STOP_LABELS, STOP_TOKEN_IDS)}
```

**Token ID获取方法**：
```python
# 通过tokenizer获取token ID
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen3.5-35B-A3B")
for label in EARLY_STOP_LABELS:
    token_id = tokenizer.convert_tokens_to_ids(label)
    print(f"{label}: {token_id}")
```

#### 1.3.2 字段跳过规则

```python
# 定义每个早停标签需要跳过的后续字段数
TASK1_SKIP_MAP = {
    "qa": 3,      # qa后跳过3个字段（意图、指令、执行）
    "multi": 2,   # multi后跳过2个字段（指令、执行）
    "chat": 2,
    "pend": 2,
}

TASKN_SKIP_MAP = {
    "task2": {"infer": 2, "vague": 2},
    "task3": {"cond": 1},
    "task4": {"abnormal": 0},
}
```

**设计逻辑**：
- `qa`/`multi`/`chat`/`pend` → 可直接判定为complex，跳过后续字段
- `infer`/`vague` → 意图不明确，跳过指令和执行字段
- `cond` → 条件指令必为complex，跳过执行字段
- `abnormal` → 已是最后一个字段，无需跳过

#### 1.3.3 SGLang调用实现

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
    
    # 构建Prompt
    prompt = system_prompt_compressed_space if special_flag else system_prompt_no_reason_special
    content = user_prompt.replace("{{TOOLS}}", tools_content or ' ').replace('{{USER_QUERY}}', content)
    prompt = f"""<|im_start|>system
{prompt}<|im_end|>
<|im_start|>user
{content}<|im_end|>
<|im_start|>assistant
<think>

</think>

"""
    
    # 构建请求payload
    payload = {
        "text": prompt,
        "sampling_params": {
            "temperature": temperature,
            "top_k": top_k,
            "top_p": top_p,
            "max_new_tokens": max_tokens,
            "repetition_penalty": 1.0,
            "stop_token_ids": STOP_TOKEN_IDS,  # 关键：早停token列表
        },
    }
    
    # 发送请求
    resp = await client.post(
        f'{router_router_config}/generate',
        json=payload,
    )
    resp.raise_for_status()
    data = resp.json()
    
    # 解析结果
    output_text = data.get("text", "")
    output_ids = data.get("output_ids", [])
    
    # 从output_ids反查命中的早停标签
    matched_token_id = None
    matched_label = None
    if output_ids:
        last_token_id = output_ids[-1]
        if last_token_id in STOP_ID_TO_LABEL:
            matched_token_id = last_token_id
            matched_label = STOP_ID_TO_LABEL[last_token_id]
    
    return {
        "output_text": output_text,
        "output_ids": output_ids,
        "matched_token_id": matched_token_id,
        "matched_label": matched_label,
        "completion_tokens": data.get("meta_info", {}).get("completion_tokens", 0),
        "finish_reason": data.get("meta_info", {}).get("finish_reason", {}).get("type", ""),
    }
```

#### 1.3.4 字段推断与补全

```python
# router/router_v2.py

@staticmethod
def _infer_skip_count(task_index: int, matched_label: str | None) -> int:
    """根据命中的字段位置和标签，推断需要跳过的字段数"""
    if matched_label is None:
        return 0
    
    if task_index == 0:
        return TASK1_SKIP_MAP.get(matched_label, 0)
    
    task_name = f"task{task_index + 1}"
    return TASKN_SKIP_MAP.get(task_name, {}).get(matched_label, 0)

@staticmethod
def _parse_partial_output(parts: list, skip_count: int) -> list:
    """将早停后的不完整输出补全为4个字段"""
    # 补全到4个字段
    while len(parts) < 4:
        parts.append("")
    
    # 从末尾开始跳过skip_count个字段
    for i in range(skip_count):
        idx = 3 - i
        parts[idx] = ""
    
    return parts
```

**解析流程**：
```python
# 1. 分割输出文本
text_parts = [p.strip().lower() for p in llm_raw_result.strip().split() if p.strip()]

# 2. 添加命中的早停标签
if matched_label:
    parts = text_parts + [matched_label]
else:
    parts = text_parts

# 3. 推断早停位置
task_index = len(parts) - 1 if len(parts) > 0 else 0
skip_count = Router._infer_skip_count(task_index, matched_label)

# 4. 补全字段
parts = Router._parse_partial_output(parts, skip_count)

# 示例：
# 输入：text="single", matched_label="multi"
# parts = ["single", "multi"]
# task_index = 1
# skip_count = 2
# 输出：["single", "multi", "", ""]
```

### 1.4 效果评估

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 平均生成token数 | 7 | 1-3 | **减少57-85%** |
| 平均延迟 | 100ms | 20-40ms | **降低60-80%** |
| P99延迟 | 150ms | 50ms | **降低67%** |

**早停命中率统计**：
```
multi:  35%  → 跳过2个字段，节省60%时间
chat:   20%  → 跳过2个字段，节省60%时间
qa:     15%  → 跳过3个字段，节省75%时间
pend:   10%  → 跳过2个字段，节省60%时间
其他:   20%  → 完整生成
```

### 1.5 关键代码文件

- `utils/request_llm_v2.py`: SGLang调用实现（310行）
- `router/router_v2.py`: 字段推断与补全（675行）
- `config/prompt.py`: 空格分隔Prompt（139行）

---

## 2. 并发执行与性能优化

### 2.1 问题描述

**背景**：路由决策需要同时执行两个耗时操作：
1. 向量检索（VSearch服务调用）：~100ms
2. 模型推理（LLM调用）：~200ms

**痛点**：
- 串行执行总耗时 = 100ms + 200ms = 300ms
- 资源利用率低，CPU在等待IO时空闲
- 高并发场景下吞吐量受限

**目标**：通过并发执行将总耗时降低到max(100ms, 200ms) = 200ms。

### 2.2 技术难点

1. **异步编程模型**：需要正确使用asyncio进行并发控制
2. **异常处理**：并发任务中任一失败不应影响整体流程
3. **超时控制**：向量检索需要设置超时，避免阻塞主流程
4. **结果融合**：需要正确整合多路结果

### 2.3 解决方案

#### 2.3.1 并发执行架构

```python
# router/router_v2.py

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
        # ... (详见下文)
        
    except Exception as e:
        logger.error(f"query:{query} 出错；原因：{e}")
        return _make_result_dict(task_type="complex", fill="err")
```

#### 2.3.2 向量检索任务（带超时）

```python
async def _vector_search_task(self, query, trace_id, top_k, max_score, min_score, timeout=2.0):
    """执行向量搜索并返回(结果, 是否高分命中)"""
    vector_start = int(time.time() * 1000)
    
    try: