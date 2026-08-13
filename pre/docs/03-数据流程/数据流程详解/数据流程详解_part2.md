    'distances': [[0.96, 0.87, 0.82]],
    'metadatas': [[
        {'type': '简单任务', 'threshold': 0.9},
        {'type': '简单任务', 'threshold': 0.0},
        {'type': '简单任务', 'threshold': 0.0}
    ]],
    'documents': [[
        '帮我定一个明天早上8点的闹钟',
        '设置一个早上8点的闹钟',
        '定个闹钟明天早上'
    ]]
}
```

#### 2.2.4 分数匹配 (score_match)
```python
# 输入
recall_results = {...}  # 转换后的数据
max_score = 0.95
min_score = 0.8

# 处理流程
# 1. 筛选 score > 0.95 的结果
# 2. 筛选 score > 0.8 的结果
# 3. 处理特殊阈值

# 输出
max_score_result = ['简单任务']  # score > 0.95
min_score_result = ['简单任务', '简单任务', '简单任务']  # score > 0.8
is_high_score = True
```

### 2.3 模型推理数据流

#### 2.3.1 Prompt 构建
```python
# System Prompt
system_prompt = system_prompt_compressed_space  # 4token优化版本

# User Prompt
user_prompt_template = """
# 工具库
以下是当前可用的工具定义（请基于此范围判断）：
{{TOOLS}}

# 任务
分析以下用户输入（无历史对话时用[]表示）：
{{USER_QUERY}}
"""

# 填充模板
content = user_prompt_template.replace("{{TOOLS}}", tools_content)
content = content.replace('{{USER_QUERY}}', query_content)

# 构建完整 Prompt
prompt = f"""<|im_start|>system
{system_prompt}<|im_end|>
<|im_start|>user
{content}<|im_end|>
<|im_start|>assistant
<think>
</think>

"""
```

#### 2.3.2 SGLang 请求
```python
payload = {
    "text": prompt,
    "sampling_params": {
        "temperature": 0.0,
        "top_k": 1,
        "top_p": 0.01,
        "max_new_tokens": 50,
        "repetition_penalty": 1.0,
        "stop_token_ids": [25429, 9398, 3613, 14992, 22846, 37753, 9464, 33418]
    }
}
```

#### 2.3.3 SGLang 响应
```json
{
  "text": "single clear",
  "output_ids": [12345, 67890, 22846],
  "meta_info": {
    "finish_reason": {
      "type": "stop",
      "matched": 22846
    },
    "completion_tokens": 3
  }
}
```

#### 2.3.4 结果解析
```python
# 输入
sglang_result = {
    "output_text": "single clear",
    "matched_label": "infer"  # 从 output_ids 反查
}

# 处理流程
# 1. 分割输出文本
text_parts = ["single", "clear"]

# 2. 添加命中标签
parts = ["single", "clear", "infer"]

# 3. 推断早停位置
task_index = 2  # 第3个字段触发早停
skip_count = 2  # 跳过后续2个字段

# 4. 补全字段
parts = ["single", "clear", "infer", "", ""]

# 输出
result_dict = {
    "is_use_tool": "single",
    "is_intent_specific": "clear",
    "is_special_instruction": "infer",
    "is_exe_success": ""
}
```

### 2.4 结果融合数据流

#### 2.4.1 并发执行结果
```python
results = [
    # 向量搜索结果
    (['简单任务'], True),  # (q_q_result, is_high_score)
    
    # 模型推理结果
    {
        "is_use_tool": "single",
        "is_intent_specific": "clear",
        "is_special_instruction": "norm",
        "is_exe_success": "ok"
    },
    
    # 正则匹配结果（如果启用）
    {
        "template": {
            "matched": False,
            "match_domain": "normal",
            "match_template": ""
        }
    }
]
```

#### 2.4.2 融合决策
```python
# 决策流程
if template_matched:
    # 正则模板命中 → 返回 easy
    return {"task_type": "easy", ...}

if is_high_score:
    # 向量高分命中 → 直接返回
    task = 'easy' if q_q_result[0] == '简单任务' else 'complex'
    result_dict['task_type'] = task
    result_dict['post_type'] = 'hit_vector'
    return result_dict

# 使用模型结果
return result_dict
```

#### 2.4.3 后处理
```python
# 输入
result_dict = {
    "is_use_tool": "single",
    "is_intent_specific": "clear",
    "is_special_instruction": "norm",
    "is_exe_success": "ok"
}

# 处理流程
# 1. 字段校验（已在解析时完成）

# 2. 计算 task_type
is_complex = (
    result_dict["is_intent_specific"] in ["infer", "vague"]
    or result_dict["is_use_tool"] in ["multi", "chat", "pend", "special"]
    or result_dict["is_special_instruction"] in ["cond"]
    or result_dict["is_exe_success"] in ["abnormal"]
)
result_dict["task_type"] = "complex" if is_complex else "easy"

# 3. 标签映射
result_dict["is_use_tool"] = "specific" if result_dict["is_use_tool"] == "special" else result_dict["is_use_tool"]
result_dict["is_special_instruction"] = "norm" if result_dict["is_special_instruction"] == "normal" else result_dict["is_special_instruction"]

# 4. 特殊场景处理
if "历史对话:[]" in query_content and result_dict["is_exe_success"] == "abnormal":
    result_dict["is_exe_success"] = "ok"

# 输出
result_dict = {
    "task_type": "easy",
    "is_intent_specific": "clear",
    "is_use_tool": "single",
    "is_special_instruction": "norm",
    "is_exe_success": "ok",
    "post_type": ""
}
```

## 3. 配置数据流

### 3.1 配置加载流程

```
┌─────────────────────────────────────────┐
│  应用启动                                │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  VivoConfigManager.__init__()           │
│  - 读取环境变量                          │
│  - 加载本地默认配置                      │
│  - 首次同步配置中心                      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  __do_init_env_vars()                   │
│  - 设置 app_name, app_env               │
│  - 确定配置中心地址                      │
│  - 加载本地 tools_intent 作为默认值      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  __sync_config()                        │
│  - 请求配置中心                          │
│  - 解析配置列表                          │
│  - 更新本地缓存                          │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  启动后台同步线程                        │
│  - 每30秒同步一次                        │
│  - 检测配置变更                          │
│  - 触发变更回调                          │
└─────────────────────────────────────────┘
```

### 3.2 配置热更新流程

```
┌─────────────────────────────────────────┐
│  配置中心更新配置                        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  后台线程定时同步 (30秒)                 │
│  __sync_config()                        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  __parse_config()                       │
│  - 解析新配置                            │
│  - 检测变更的 key                        │
│  - 合并到本地缓存                        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  触发变更回调                            │
│  - 遍历 _on_change_callbacks            │
│  - 执行注册的回调函数                    │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  reload_mcp_mapping()                   │
│  - 重新构建 MCP 映射                     │
│  - 更新全局变量                          │
│  - global_mcp_intentions                │
│  - global_intention_mcps                │
└─────────────────────────────────────────┘
```

### 3.3 MCP 映射数据流

#### 3.3.1 原始映射 (tools_intent)
```python
tools_intent = {
    "create_alarm": ["timeAndSchedule.createAlarmClock"],
    "search_alarm": ["timeAndSchedule.queryAlarmClock"],
    "play_music": ["media.playSpecificMusic"],
    # ...
}
```

#### 3.3.2 构建正向映射
```python
# global_mcp_intentions
{
    "create_alarm": ["timeAndSchedule.createAlarmClock"],
    "search_alarm": ["timeAndSchedule.queryAlarmClock"],
    "play_music": ["media.playSpecificMusic"],
    # ...
}
```

#### 3.3.3 构建反向映射
```python
# global_intention_mcps
{
    "common_tools": ["knowledgeQA"],
    "createAlarmClock": ["create_alarm"],
    "queryAlarmClock": ["search_alarm"],
    "playSpecificMusic": ["play_music"],
    # ...
}
```

## 4. 工具定义数据流
