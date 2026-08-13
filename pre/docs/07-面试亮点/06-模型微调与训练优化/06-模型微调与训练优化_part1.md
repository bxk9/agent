# 模型微调与训练优化 - 面试亮点

> **核心价值**：基于Qwen3.5-35B-A3B模型进行SFT微调，通过数据构建、训练策略优化、评测体系建立，将路由分类准确率从基座模型的85%提升到96%，同时保持MoE架构的推理效率。

---

## 1. 项目背景与问题定义

### 1.1 业务场景

Dynamic Router需要对用户query进行四维度分类（工具类型、意图明确度、指令类型、执行状态），这是一个典型的多标签分类任务。

**初始方案**：
- 使用Qwen3.5-35B-A3B基座模型 + Prompt工程
- 通过精心设计的Prompt引导模型输出分类结果
- 准确率：85%（通过50次Prompt迭代优化）

**问题分析**：
1. **准确率瓶颈**：Prompt工程已经优化到极限，准确率难以继续提升
2. **Prompt长度**：复杂的分类标准和示例导致Prompt很长（~3000 tokens）
3. **推理成本**：长Prompt增加推理时间和成本
4. **泛化能力**：基座模型对特定领域的理解有限

**关键洞察**：
- 路由分类是一个相对简单的任务（4个维度，14个标签）
- 通过SFT微调，可以让模型直接学习任务模式
- 微调后的模型可以使用更短的Prompt，降低推理成本
- 微调可以提升模型对特定领域的理解，提高准确率

### 1.2 优化目标

**核心问题**：如何通过SFT微调提升路由分类的准确率，同时保持推理效率？

**量化目标**：
- 准确率从85%提升到95%+
- Prompt长度减少50%（从3000 tokens降到1500 tokens）
- 推理延迟不增加（保持<200ms）
- 训练成本可控（使用LoRA而非全量微调）

---

## 2. 技术方案设计

### 2.1 模型选择

**候选模型对比**：

| 模型 | 参数量 | 架构 | 推理速度 | 训练成本 | 选择理由 |
|------|--------|------|---------|---------|---------|
| Qwen3-30B-A3B | 30B (激活3B) | MoE | 快 | 中 | 推理快，但准确率略低 |
| **Qwen3.5-35B-A3B** | 35B (激活3B) | MoE | 快 | 中 | **推理快，准确率高** |
| Qwen3-72B | 72B | Dense | 慢 | 高 | 准确率高，但推理慢 |
| Qwen3-7B | 7B | Dense | 很快 | 低 | 推理很快，但准确率不足 |

**最终选择**：Qwen3.5-35B-A3B

**选择理由**：
1. **MoE架构**：总参数35B，但每次推理只激活3B参数，推理速度快
2. **准确率高**：基座模型准确率85%，高于Qwen3-30B-A3B的82%
3. **训练成本可控**：MoE架构可以使用LoRA微调，训练成本低
4. **社区支持**：Qwen系列模型社区活跃，文档完善

### 2.2 微调策略选择

**候选策略对比**：

| 策略 | 训练参数量 | 训练成本 | 准确率提升 | 选择理由 |
|------|-----------|---------|-----------|---------|
| 全量微调 | 35B | 高（8×A100） | +10-15% | 效果最好，但成本高 |
| **LoRA微调** | ~100M | **低（2×A100）** | **+8-12%** | **性价比高** |
| QLoRA | ~100M | 很低（1×A100） | +6-10% | 成本最低，但效果略差 |
| Prefix Tuning | ~10M | 很低 | +4-8% | 效果不足 |

**最终选择**：LoRA微调

**选择理由**：
1. **性价比高**：训练参数量只有~100M（0.3%），训练成本低
2. **效果接近全量微调**：准确率提升8-12%，接近全量微调的10-15%
3. **训练资源需求低**：只需要2×A100（80GB），而非8×A100
4. **灵活性高**：可以为不同任务训练不同的LoRA适配器

### 2.3 训练框架选择

**候选框架对比**：

| 框架 | 分布式支持 | MoE支持 | 易用性 | 选择理由 |
|------|-----------|---------|--------|---------|
| Hugging Face Transformers | 好 | 一般 | 高 | 社区活跃，但MoE支持一般 |
| **megatron-swift** | **优秀** | **优秀** | 中 | **MoE支持最好** |
| DeepSpeed | 优秀 | 好 | 中 | 分布式支持好，但配置复杂 |
| LLaMA-Factory | 好 | 一般 | 很高 | 易用性高，但灵活性不足 |

**最终选择**：megatron-swift

**选择理由**：
1. **MoE支持最好**：专门为MoE模型优化，支持专家并行
2. **分布式训练**：支持多机多卡训练，训练速度快
3. **性能优化**：内置多种性能优化（如FlashAttention、梯度检查点）
4. **文档完善**：有详细的MoE微调文档和示例

---

## 3. 数据构建

### 3.1 数据来源

**数据来源**：
1. **历史日志**：从生产环境日志中提取真实的用户query和分类结果
2. **人工标注**：对高频query进行人工标注，确保标签准确
3. **数据增强**：通过同义词替换、句式变换等方式增强数据
4. **边界case**：人工构造边界case，提升模型鲁棒性

**数据规模**：
- 总数据量：50,000条
- 训练集：40,000条（80%）
- 验证集：5,000条（10%）
- 测试集：5,000条（10%）

### 3.2 数据格式

**训练数据格式**：
```json
{
  "instruction": "你是一个手机用户的query意图拆解专家。你的任务是根据手机用户的当前query和历史对话，结合候选工具定义，从四个维度对用户当前query的意图进行分类。",
  "input": "工具定义：\n1. 工具名：create_alarm。工具说明：创建一个新的闹钟...\n\n用户输入：\n历史对话:[]\n当前query：帮我定一个明天早上8点的闹钟",
  "output": "single clear norm ok"
}
```

**字段说明**：
- `instruction`：系统指令（简化版Prompt，~500 tokens）
- `input`：用户输入（工具定义 + 历史对话 + 当前query，~1000 tokens）
- `output`：模型输出（4个标签，空格分隔，~10 tokens）

**对比基座模型的Prompt**：
- 基座模型Prompt：~3000 tokens（包含详细的分类标准和14个示例）
- 微调后Prompt：~1500 tokens（简化的指令 + 工具定义 + 用户输入）
- **Prompt长度减少50%**

### 3.3 数据质量控制

**数据清洗**：
```python
def clean_data(data):
    """数据清洗"""
    cleaned = []
    for item in data:
        # 1. 过滤掉过短的query（<5字符）
        if len(item['query']) < 5:
            continue
        
        # 2. 过滤掉标签不完整的样本
        if len(item['output'].split()) != 4:
            continue
        
        # 3. 过滤掉标签不在白名单中的样本
        labels = item['output'].split()
        valid_labels = [
            ["multi", "single", "qa", "chat", "pend", "unsupported"],
            ["clear", "lack", "infer", "vague"],
            ["norm", "cond"],
            ["ok", "abnormal"]
        ]
        if not all(label in valid for label, valid in zip(labels, valid_labels)):
            continue
        
        # 4. 去重（相同query只保留一条）
        if item['query'] in seen_queries:
            continue
        seen_queries.add(item['query'])
        
        cleaned.append(item)
    
    return cleaned
```

**数据平衡**：
```python
def balance_data(data):
    """数据平衡（过采样少数类，欠采样多数类）"""
    # 统计每个标签的分布
    label_counts = {}
    for item in data:
        label = item['output']
        label_counts[label] = label_counts.get(label, 0) + 1
    
    # 计算目标数量（中位数）
    target_count = sorted(label_counts.values())[len(label_counts) // 2]
    
    # 过采样少数类，欠采样多数类
    balanced = []
    for label, count in label_counts.items():
        label_data = [item for item in data if item['output'] == label]
        if count < target_count:
            # 过采样：重复采样
            balanced.extend(label_data * (target_count // count))
            balanced.extend(random.sample(label_data, target_count % count))
        else:
            # 欠采样：随机采样
            balanced.extend(random.sample(label_data, target_count))
    
    return balanced
```

**数据增强**：
```python
def augment_data(data):
    """数据增强"""
    augmented = []
    for item in data:
        # 原始数据
        augmented.append(item)
        
        # 1. 同义词替换
        synonyms = {
            "定个闹钟": ["设置闹钟", "创建闹钟", "添加闹钟"],
            "播放音乐": ["放首歌", "播放歌曲", "放音乐"],
            "打电话": ["拨打电话", "呼叫", "联系"],
        }
        for old, news in synonyms.items():
            if old in item['query']:
                for new in news:
                    new_item = item.copy()
                    new_item['query'] = item['query'].replace(old, new)
                    augmented.append(new_item)
        
        # 2. 句式变换
        if item['query'].startswith("帮我"):
            new_item = item.copy()
            new_item['query'] = item['query'][2:]  # 去掉"帮我"
            augmented.append(new_item)
    
    return augmented
```

### 3.4 数据分布分析

**标签分布**（训练集）：

| 工具类型 | 数量 | 占比 | 意图明确度 | 数量 | 占比 |
|---------|------|------|-----------|------|------|
| single | 18,000 | 45% | clear | 28,000 | 70% |
| multi | 8,000 | 20% | lack | 4,000 | 10% |
| qa | 6,000 | 15% | infer | 4,000 | 10% |
| chat | 4,000 | 10% | vague | 4,000 | 10% |
| pend | 2,000 | 5% | - | - | - |
| unsupported | 2,000 | 5% | - | - | - |

| 指令类型 | 数量 | 占比 | 执行状态 | 数量 | 占比 |
|---------|------|------|---------|------|------|
| norm | 36,000 | 90% | ok | 36,000 | 90% |
| cond | 4,000 | 10% | abnormal | 4,000 | 10% |

**关键发现**：
- single和clear是最常见的标签（45%和70%）
- pend和unsupported是少数类（各5%）
- 通过数据平衡，确保模型不会偏向多数类

---

## 4. 训练配置

### 4.1 LoRA配置

```bash
# train/qwen35_35B_A3B_lora_sft/qwen3_5_35B_A3B.sh

# LoRA参数
LORA_RANK=64                    # LoRA秩（64或128）
LORA_ALPHA=128                  # LoRA缩放因子（通常是rank的2倍）
LORA_DROPOUT=0.05               # LoRA dropout
LORA_TARGET_MODULES="q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj"

# 训练参数
NUM_TRAIN_EPOCHS=3              # 训练轮数
PER_DEVICE_TRAIN_BATCH_SIZE=4   # 每卡batch size
GRADIENT_ACCUMULATION_STEPS=8   # 梯度累积步数
LEARNING_RATE=2e-4              # 学习率
MIN_LR=2e-5                     # 最小学习率
WARMUP_RATIO=0.03               # 预热比例