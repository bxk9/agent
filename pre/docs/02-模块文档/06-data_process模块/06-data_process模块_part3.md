基于分类标准、工具定义、query 与 history，逐维度推导 reason 后再输出 label。

# 输出要求 (绝对死线约束)
1. 格式要求: 必须且仅输出一个单行的合法 JSON 字典，禁止换行格式化，首尾绝对禁止使用 ```json 这样的 Markdown 代码块包裹。格式参考：{"工具调用类型": {"reason": "简要中文理由", "label": "对应英文标签"}, ...}
2. 字段顺序约束: 在每个维度的字典内，必须先输出 "reason" 字段进行逻辑推导，然后再输出 "label" 字段给出结论。生成顺序错误判定为不及格。
3. key-value 定义:
   - reason: 用简短的中文解释为何得出该标签。
   - label: 必须严格对应这4个维度，并从以下白名单中精准提取英文值（仅限纯小写）：
     * 工具调用类型: multi, pend, unsupported, single, qa, chat
     * 意图明确度: clear, lack, infer, vague
     * 指令类型: cond, norm
     * 执行反馈状态: abnormal, ok
"""
```

#### 2.1.4 典型示例

```python
case_no_reason = """
# 典型示例
**Case 1 —— 闲聊招呼，无任务诉求**
历史对话:[]
当前query：你好呀，今天心情不错
Output: chat,clear,norm,ok

**Case 2 —— 知识问答，调用 knowledgeQA**
历史对话:[]
当前query：西红柿炒鸡蛋怎么做
Output: qa,clear,norm,ok

**Case 3 —— 意图清晰但工具不支持 → 跨维度绑定 clear**
历史对话:[]
当前query：帮我买一张去月球的票
Output: unsupported,clear,norm,ok

**Case 4 —— 修饰主体不明确，多工具歧义 → 跨维度绑定 vague**
历史对话:[]
当前query：到10%
Output: pend,vague,norm,ok

**Case 5 —— 异常反馈：用户否定上一轮生成结果**
历史对话:
user:帮我画一张漂亮女生的照片
assistant:好的，已经生成了漂亮女生的图片
当前query：不够好看，帮我换一张颜值很高的女生的照片
Output: single,clear,norm,abnormal

**Case 6 —— 正常推进：用户自行变更，非纠错，对照 Case 5→ ok**
历史对话:
user:帮我画一张漂亮女生的照片
assistant:好的，已经生成了漂亮女生的图片
当前query：想了下，还是换成帅气男生的照片吧
Output: single,clear,norm,ok

**Case 7 —— 单工具参数缺失（缺目的地，须问用户）→ lack**
历史对话:[]
当前query：帮我打个车
Output: single,lack,norm,ok

**Case 8 —— 参数需推理（江苏最高电视塔需检索具体名称）**
历史对话:[]
当前query：导航到江苏最高的电视塔
Output: single,infer,norm,ok

**Case 9 —— 多工具调用（先截屏识别再绘图）**
历史对话:[]
当前query：帮我查下屏幕上这首诗是谁写的，然后画一幅这个作者的肖像图
Output: multi,clear,norm,ok

**Case 10 —— 复合指令子任务缺参（定闹钟缺时间参数）→ 整体取最高档 lack**
历史对话:[]
当前query：打开网易云播放周杰伦，然后给我定个闹钟
Output: multi,lack,norm,ok

**Case 11 —— 多任务含 vague 子任务 → 整体取最高档 vague**
历史对话:[]
当前query：调到10%，再放首歌
Output: multi,vague,norm,ok

**Case 12 —— 条件指令（外部条件触发+待执行任务）→ cond**
历史对话:[]
当前query：等我到家了帮我把空调打开
Output: single,clear,cond,ok

**Case 13 —— 完整动宾但多相似候选工具，方向不明 → pend+vague**
历史对话:[]
当前query：帮我买张票
Output: pend,vague,norm,ok

**Case 14 —— 本轮的指令是对上一轮条件指令的补充，本轮视为cond → cond**
历史对话:
user:充电时帮我做点事
assistant:请问你想让我在充电时帮你执行什么操作呢？比如开启省电模式、调整屏幕亮度等，你可以具体说明一下~
当前query：帮我播放周杰伦的歌
Output: single,clear,cond,ok
"""
```

**示例覆盖场景**：
1. 闲聊招呼
2. 知识问答
3. 工具不支持
4. 意图模糊
5. 异常反馈
6. 正常推进
7. 参数缺失
8. 参数推理
9. 多工具调用
10. 复合指令缺参
11. 多任务含vague
12. 条件指令
13. 工具待确定
14. 条件指令补充

#### 2.1.5 Prompt组装

```python
# 不带推理过程的完整Prompt
system_prompt_no_reason = system_prompt_base + output_format_no_reason + case_no_reason

# 带推理过程的完整Prompt
system_prompt_use_reason = system_prompt_base + output_format_use_reason + case_use_reason
```

### 2.2 router_prompt_special.py - 特殊场景Prompt

```python
"""
特殊场景Prompt，用于处理美团、支付宝等特殊服务
"""

system_prompt_no_reason_special = """
你是一个手机用户的query意图拆解专家。你的任务是根据手机用户的当前query和历史对话，结合候选工具定义，从下面四个维度对用户当前query的意图进行分类。

# 特殊规则
当候选工具中包含 meituan_service、alipay_direct_service、alipay_execution_service 等特殊服务工具时，需要特别注意：
1. 这些工具通常涉及第三方服务调用
2. 需要更严格的参数验证
3. 可能涉及支付、订单等敏感操作

[其余分类标准与标准Prompt相同]
"""
```

**特殊处理**：
- 针对第三方服务工具的特殊规则
- 更严格的参数验证
- 敏感操作提示

### 2.3 router_prompt_4token.py - 4token优化Prompt

```python
"""
4token优化Prompt，用于SGLang早停优化
"""

system_prompt_no_reason_space = """
你是一个手机用户的query意图拆解专家。你的任务是根据手机用户的当前query和历史对话，结合候选工具定义，从下面四个维度对用户当前query的意图进行分类。

# 输出要求 (绝对死线约束)
1. 输出格式: 必须且只能输出由4个小写英文单词组成的字符串，标签之间仅用1个空格' '分隔。
2. 绝对禁止: 禁止输出任何冒号、前缀、逗号、换行符、中文字符或额外的解释说明。
3. 顺序必须固定: 位置永远对应 [工具调用类型] [意图明确度] [指令类型] [执行反馈状态]
4. 输出强制白名单(且仅限小写):
   - 位置1: multi, pend, unsupported, single, qa, chat
   - 位置2: clear, lack, infer, vague
   - 位置3: cond, norm
   - 位置4: abnormal, ok

[其余分类标准与标准Prompt相同]
"""
```

**优化点**：
- 使用空格分隔而非逗号
- 便于SGLang的token级别早停
- 减少分隔符token

## 3. 训练数据生成

### 3.1 run_router_data.py

```python
"""
生成路由训练数据
"""

def generate_training_data(excel_path, output_path):
    """从Excel生成训练数据"""
    df = pd.read_excel(excel_path)
    
    training_data = []
    for _, row in df.iterrows():
        query = row['query']
        history = row['history']
        label = row['label']
        
        # 构建训练样本
        sample = {
            "query": query,
            "history": history,
            "label": label
        }
        training_data.append(sample)
    
    # 保存为JSON
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(training_data, f, ensure_ascii=False, indent=2)
```

**用途**：
- 从标注数据生成训练集
- 支持批量处理
- 输出标准JSON格式

### 3.2 run_router_data_with_tool.py

```python
"""
生成带工具定义的训练数据
"""

def generate_training_data_with_tools(excel_path, output_path):
    """从Excel生成带工具定义的训练数据"""
    df = pd.read_excel(excel_path)
    
    training_data = []
    for _, row in df.iterrows():
        query = row['query']
        history = row['history']
        label = row['label']
        tools = row['tools']
        
        # 构建带工具的训练样本
        sample = {
            "query": query,
            "history": history,
            "tools": tools,
            "label": label
        }
        training_data.append(sample)
    
    # 保存为JSON
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(training_data, f, ensure_ascii=False, indent=2)
```

**用途**：
- 生成包含工具定义的训练数据
- 用于模型微调
- 提高模型对工具的理解

## 4. Prompt工程最佳实践

### 4.1 分类标准设计原则

1. **互斥性**：每个标签的定义应该互斥，避免歧义
2. **完备性**：覆盖所有可能的场景
3. **优先级明确**：当多个标签符合时，有明确的优先级规则
4. **扩展规则**：针对边界情况提供扩展规则
5. **排除规则**：明确哪些情况不属于该标签

### 4.2 示例设计原则

1. **典型性**：覆盖常见场景
2. **对比性**：提供对比示例（如Case 5 vs Case 6）
3. **边界性**：覆盖边界情况
4. **多样性**：覆盖不同维度的组合

### 4.3 输出格式设计

1. **简洁性**：输出格式尽可能简洁
2. **可解析性**：便于程序解析
3. **确定性**：输出格式严格约束
4. **兼容性**：支持多种���出格式（带/不带推理）

## 5. 设计理念总结

### 5.1 多维度分类
- 4个正交维度全面刻画用户意图
- 每个维度独立判断，互不干扰
- 支持跨维度绑定规则

### 5.2 规则驱动
- 明确的分类标准和规则
- 优先级规则解决冲突
- 扩展规则覆盖边界情况

### 5.3 示例引导
- 丰富的典型示例
- 对比示例帮助理解
- 覆盖常见和边界场景

### 5.4 灵活输出
- 支持带/不带推理过程
- 支持不同分隔符（逗号/空格）
- 适配不同推理引擎

## 6. 使用示例

### 6.1 使用标准Prompt

```python
from data_process.router_prompt import system_prompt_no_reason, user_prompt

# 填充模板
tools_content = "1. 工具名：create_alarm。工具说明：创建闹钟..."
user_query = "帮我定一个明天早上8点的闹钟"

content = user_prompt.replace("{{TOOLS}}", tools_content)
content = content.replace('{{USER_QUERY}}', user_query)

# 构建消息
messages = [
    {"role": "system", "content": system_prompt_no_reason},
    {"role": "user", "content": content}
]
```

### 6.2 使用带推理的Prompt

```python
from data_process.router_prompt import system_prompt_use_reason, user_prompt

# 使用带推理过程的Prompt
messages = [