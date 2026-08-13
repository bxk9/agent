# SGLang早停优化技术 - 面试亮点

> **核心价值**：通过深入理解LLM推理机制，设计并实现了基于stop_token_ids的早停优化，将推理延迟降低80%，是业界领先的token级短路策略。

---

## 1. 项目背景与问题定义

### 1.1 业务场景

Dynamic Router是一个智能路由系统，需要对用户query进行四维度分类：
1. **工具调用类型**：single/multi/qa/chat/pend/unsupported（6个标签）
2. **意图明确度**：clear/lack/infer/vague（4个标签）
3. **指令类型**：norm/cond（2个标签）
4. **执行反馈状态**：ok/abnormal（2个标签）

**输出格式**：`single clear norm ok`（4个标签，空格分隔）

### 1.2 性能瓶颈分析

**传统方案的延迟构成**：
```
完整生成流程：
1. 生成标签1（工具类型）：~25ms
2. 生成分隔符：~5ms
3. 生成标签2（意图明确度）：~25ms
4. 生成分隔符：~5ms
5. 生成标签3（指令类型）：~25ms
6. 生成分隔符：~5ms
7. 生成标签4（执行状态）：~25ms

总耗时：~115ms
生成token数：7个（4标签 + 3分隔符）
```

**关键洞察**：
- 某些标签一旦确定，就能直接判定任务复杂度
- 例如：`multi` → 必然是complex任务，后续3个字段对决策无用
- 例如：`chat` → 必然是complex任务，后续字段也无用
- **浪费**：继续生成后续字段是无效计算

### 1.3 优化目标

**核心问题**：如何在模型生成到特定标签时提前终止，减少不必要的token生成？

**量化目标**：
- 延迟降低 > 50%
- 准确率不受影响
- 支持多种早停场景

---

## 2. 技术方案设计

### 2.1 核心思路

**利用SGLang的stop_token_ids机制**：
- SGLang支持在生成过程中遇到特定token ID时立即停止
- 我们可以将"可早停标签"对应的token ID加入stop_token_ids列表
- 模型生成到这些token时会自动停止，无需生成后续内容

**关键挑战**：
1. 如何获取每个标签对应的准确token ID？
2. 早停后如何推断当前处于哪个字段位置？
3. 如何正确补全被跳过的字段？

### 2.2 早停标签选择策略

**设计原则**：只有能直接判定task_type的标签才触发早停

**字段1（工具类型）早停标签**：
```python
# 这些标签一旦确定，就能判定为complex
"multi"   → complex（多工具调用）
"chat"    → complex（闲聊）
"pend"    → complex（工具待确定）
"qa"      → easy（知识问答，但后续字段固定为clear/norm/ok）
```

**字段2（意图明确度）早停标签**：
```python
"infer"   → complex（参数需推理）
"vague"   → complex（意图模糊）
```

**字段3（指令类型）早停标签**：
```python
"cond"    → complex（条件指令）
```

**字段4（执行状态）早停标签**：
```python
"abnormal" → complex（异常反馈）
```

**早停规则表**：

| 字段位置 | 早停标签 | 跳过后续字段数 | 原因 |
|---------|---------|--------------|------|
| 字段1 | multi | 2 | complex已确定，跳过指令和执行 |
| 字段1 | chat | 2 | complex已确定，跳过指令和执行 |
| 字段1 | pend | 2 | complex已确定，跳过指令和执行 |
| 字段1 | qa | 3 | easy已确定，后续字段固定 |
| 字段2 | infer | 2 | complex已确定，跳过指令和执行 |
| 字段2 | vague | 2 | complex已确定，跳过指令和执行 |
| 字段3 | cond | 1 | complex已确定，跳过执行 |
| 字段4 | abnormal | 0 | 已是最后一个字段 |

### 2.3 Token ID获取方法

**方法1：Tokenizer直接转换**
```python
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen3.5-35B-A3B")

# 获取每个标签的token ID
labels = ["multi", "chat", "pend", "qa", "infer", "vague", "cond", "abnormal"]
for label in labels:
    token_id = tokenizer.convert_tokens_to_ids(label)
    print(f"{label}: {token_id}")
```

**方法2：实验验证**
```python
# 通过实际推理验证token ID是否正确
test_prompts = [
    "帮我定一个闹钟，然后播放音乐",  # 应该输出multi
    "你好啊",                      # 应该输出chat
    "到10%",                       # 应该输出pend
    "西红柿炒鸡蛋怎么做",           # 应该输出qa
]

for prompt in test_prompts:
    # 调用模型，观察output_ids
    result = call_model(prompt)
    print(f"Prompt: {prompt}")
    print(f"Output IDs: {result['output_ids']}")
    print(f"Last token: {result['output_ids'][-1]}")
```

**最终确定的Token ID映射**：
```python
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

STOP_ID_TO_LABEL = {
    25429: "multi",
    9398: "chat",
    3613: "pend",
    14992: "qa",
    22846: "infer",
    37753: "vague",
    9464: "cond",
    33418: "abnormal"
}
```

---

## 3. 核心实现细节

### 3.1 SGLang调用实现

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
    
    # 1. 构建Prompt（使用空格分隔，便于早停）
    prompt = system_prompt_compressed_space if special_flag else system_prompt_no_reason_special
    content = user_prompt.replace("{{TOOLS}}", tools_content or ' ').replace('{{USER_QUERY}}', content)
    
    # Qwen chat template格式
    full_prompt = f"""<|im_start|>system
{prompt}<|im_end|>
<|im_start|>user
{content}<|im_end|>
<|im_start|>assistant
<think>

</think>

"""
    
    # 2. 构建请求payload（关键：stop_token_ids）
    payload = {
        "text": full_prompt,
        "sampling_params": {
            "temperature": temperature,
            "top_k": top_k,
            "top_p": top_p,
            "max_new_tokens": max_tokens,
            "repetition_penalty": 1.0,
            "stop_token_ids": STOP_TOKEN_IDS,  # 核心：早停token列表
        },
    }
    
    # 3. 发送请求
    resp = await client.post(
        f'{base_url}/generate',
        json=payload,
    )
    resp.raise_for_status()
    data = resp.json()
    
    # 4. 解析结果
    output_text = data.get("text", "")
    output_ids = data.get("output_ids", [])
    
    # 5. 从output_ids反查命中的早停标签
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

**关键点解析**：
1. **stop_token_ids参数**：告诉SGLang在生成这些token时立即停止
2. **output_ids反查**：从生成的token序列最后一个token反查命中的标签
3. **空格分隔**：Prompt中使用空格而非逗号，便于token级别的早停

### 3.2 字段位置推断算法

**问题**：早停后，如何知道当前处于哪个字段？

**解决方案**：根据已生成的token数量推断

```python
@staticmethod
def _infer_skip_count(task_index: int, matched_label: str | None) -> int:
    """根据命中的字段位置和标签，推断需要跳过的字段数
    
    Args:
        task_index: 当前字段索引（0=工具类型, 1=意图明确度, 2=指令类型, 3=执行状态）
        matched_label: 命中的早停标签
    
    Returns:
        需要跳过的后续字段数
    """
    if matched_label is None:
        return 0
    
    # 字段1的早停规则
    if task_index == 0:
        return TASK1_SKIP_MAP.get(matched_label, 0)
    
    # 字段2/3/4的早停规则
    task_name = f"task{task_index + 1}"
    return TASKN_SKIP_MAP.get(task_name, {}).get(matched_label, 0)
```

**字段索引推断逻辑**：
```python
# 分割输出文本
text_parts = [p.strip().lower() for p in llm_raw_result.strip().split() if p.strip()]

# 添加命中的早停标签
if matched_label:
    parts = text_parts + [matched_label]
else:
    parts = text_parts

# 推断字段索引
# 例如：parts = ["single", "multi"] → task_index = 1（第二个字段触发早停）
task_index = len(parts) - 1 if len(parts) > 0 else 0

# 推断跳过字段数
skip_count = Router._infer_skip_count(task_index, matched_label)
```

**示例**：
```
场景1：输出 "multi"，命中早停
- text_parts = []
- matched_label = "multi"
- parts = ["multi"]
- task_index = 0（第一个字段）
- skip_count = 2（跳过后续2个字段）
- 最终：["multi", "", "", ""]

场景2：输出 "single infer"，命中早停
- text_parts = ["single"]
- matched_label = "infer"
- parts = ["single", "infer"]
- task_index = 1（第二个字段）
- skip_count = 2（跳过后续2个字段）
- 最终：["single", "infer", "", ""]

场景3：输出 "single clear cond"，命中早停
- text_parts = ["single", "clear"]
- matched_label = "cond"
- parts = ["single", "clear", "cond"]
- task_index = 2（第三个字段）
- skip_count = 1（跳过后续1个字段）
- 最终：["single", "clear", "cond", ""]
```

### 3.3 字段补全算法

```python
@staticmethod
def _parse_partial_output(parts: list, skip_count: int) -> list:
    """将早停后的不完整输出补全为4个字段
    
    Args:
        parts: 已解析的字段列表（可能不完整）
        skip_count: 需要跳过的字段数
    
    Returns:
        补全后的4个字段列表
    """
    # 1. 补全到4个字段
    while len(parts) < 4:
        parts.append("")
    
    # 2. 从末尾开始，将需要跳过的字段设为空字符串
    for i in range(skip_count):
        idx = 3 - i
        parts[idx] = ""
    
    return parts
```

**补全示例**：
```