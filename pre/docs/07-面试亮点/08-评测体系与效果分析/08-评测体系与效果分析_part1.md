# 评测体系与效果分析 - 面试亮点

> **核心价值**：设计并实现了完整的路由分类评测体系，包括多维度指标计算、错误分析、A/B测试框架，通过数据驱动的方法将系统准确率从85%提升到96%，为持续优化提供了科学依据。

---

## 1. 项目背景与问题定义

### 1.1 业务场景

Dynamic Router是一个四维度分类系统，需要对用户query进行分类：
- **工具类型**：single/multi/qa/chat/pend/unsupported
- **意图明确度**：clear/lack/infer/vague
- **指令类型**：norm/cond
- **执行状态**：ok/abnormal

**评测挑战**：
1. **多维度评估**：需要同时评估4个维度的准确率
2. **类别不平衡**：某些标签（如single、clear）占比很高，某些标签（如pend、unsupported）占比很低
3. **错误分析**：需要深入分析错误原因，指导优化方向
4. **A/B测试**：需要在生产环境验证优化效果

### 1.2 优化目标

**核心问题**：如何建立科学的评测体系，准确评估系统性能，并指导持续优化？

**量化目标**：
- 建立多维度评测指标（准确率、召回率、F1分数）
- 实现自动化评测流程（一键评测）
- 支持错误分析和可视化
- 支持A/B测试和统计显著性检验

---

## 2. 评测体系设计

### 2.1 评测指标体系

#### 2.1.1 基础指标

**准确率（Accuracy）**：
```python
accuracy = (TP + TN) / (TP + TN + FP + FN)
```

**精确率（Precision）**：
```python
precision = TP / (TP + FP)
```

**召回率（Recall）**：
```python
recall = TP / (TP + FN)
```

**F1分数（F1-Score）**：
```python
f1 = 2 * precision * recall / (precision + recall)
```

#### 2.1.2 多分类指标

**宏平均（Macro Average）**：
```python
macro_precision = sum(precision_i) / n_classes
macro_recall = sum(recall_i) / n_classes
macro_f1 = sum(f1_i) / n_classes
```

**加权平均（Weighted Average）**：
```python
weighted_precision = sum(precision_i * support_i) / sum(support_i)
weighted_recall = sum(recall_i * support_i) / sum(support_i)
weighted_f1 = sum(f1_i * support_i) / sum(support_i)
```

**选择理由**：
- **宏平均**：对所有类别一视同仁，适合类别平衡的场景
- **加权平均**：考虑类别不平衡，适合实际业务场景
- **本项目选择加权平均**：因为标签分布不平衡（single占45%，pend占5%）

#### 2.1.3 业务指标

**任务复杂度准确率**：
```python
task_complexity_accuracy = correct_task_type / total_samples
```

**端到端准确率**：
```python
end_to_end_accuracy = all_4_dimensions_correct / total_samples
```

**关键指标**：
```python
key_metrics = {
    "overall_accuracy": 0.96,           # 整体准确率
    "task_complexity_accuracy": 0.98,   # 任务复杂度准确率
    "end_to_end_accuracy": 0.89,        # 端到端准确率
    "latency_p50": 140,                 # P50延迟（ms）
    "latency_p99": 280,                 # P99延迟（ms）
    "throughput": 70                    # 吞吐量（QPS）
}
```

### 2.2 评测数据集构建

#### 2.2.1 数据集设计

**数据集规模**：
- 总样本数：10,000条
- 训练集：不参与评测
- 验证集：5,000条（用于超参数调优）
- 测试集：5,000条（用于最终评测）

**数据集分布**：

| 工具类型 | 数量 | 占比 | 意图明确度 | 数量 | 占比 |
|---------|------|------|-----------|------|------|
| single | 2,250 | 45% | clear | 3,500 | 70% |
| multi | 1,000 | 20% | lack | 500 | 10% |
| qa | 750 | 15% | infer | 500 | 10% |
| chat | 500 | 10% | vague | 500 | 10% |
| pend | 250 | 5% | - | - | - |
| unsupported | 250 | 5% | - | - | - |

| 指令类型 | 数量 | 占比 | 执行状态 | 数量 | 占比 |
|---------|------|------|---------|------|------|
| norm | 4,500 | 90% | ok | 4,500 | 90% |
| cond | 500 | 10% | abnormal | 500 | 10% |

#### 2.2.2 数据质量保证

**标注流程**：
```
1. 初始标注：由2名标注员独立标注
   ↓
2. 一致性检查：计算Cohen's Kappa系数
   ↓
3. 分歧解决：第3名资深标注员仲裁
   ↓
4. 质量审核：随机抽查10%样本
```

**标注一致性**：
```python
from sklearn.metrics import cohen_kappa_score

# 计算两名标注员的一致性
kappa = cohen_kappa_score(annotator1_labels, annotator2_labels)
print(f"Cohen's Kappa: {kappa:.3f}")

# 结果：0.92（几乎完美一致）
```

**数据清洗**：
```python
def clean_test_data(data):
    """清洗测试数据"""
    cleaned = []
    for item in data:
        # 1. 过滤掉模糊样本（标注员分歧大）
        if item['agreement_score'] < 0.8:
            continue
        
        # 2. 过滤掉过短或无意义的query
        if len(item['query']) < 5:
            continue
        
        # 3. 验证标签完整性
        if len(item['labels']) != 4:
            continue
        
        cleaned.append(item)
    
    return cleaned
```

### 2.3 评测脚本实现

#### 2.3.1 核心评测函数

```python
# train_deploy_eval/eval/eval.py

import json
import pandas as pd
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt
import seaborn as sns

def evaluate_model(model, test_data, output_dir):
    """评测模型性能"""
    
    # 1. 预测
    predictions = []
    ground_truths = []
    
    for item in test_data:
        query = item['query']
        tools = item['tools']
        history = item['history']
        
        # 调用模型
        result = model.predict(query, tools, history)
        
        predictions.append(result)
        ground_truths.append(item['labels'])
    
    # 2. 计算指标
    metrics = calculate_metrics(predictions, ground_truths)
    
    # 3. 错误分析
    error_analysis = analyze_errors(test_data, predictions, ground_truths)
    
    # 4. 生成报告
    generate_report(metrics, error_analysis, output_dir)
    
    return metrics

def calculate_metrics(predictions, ground_truths):
    """计算评测指标"""
    
    # 分离4个维度
    pred_tool = [p[0] for p in predictions]
    pred_intent = [p[1] for p in predictions]
    pred_instruction = [p[2] for p in predictions]
    pred_execution = [p[3] for p in predictions]
    
    true_tool = [g[0] for g in ground_truths]
    true_intent = [g[1] for g in ground_truths]
    true_instruction = [g[2] for g in ground_truths]
    true_execution = [g[3] for g in ground_truths]
    
    # 计算每个维度的指标
    metrics = {}
    
    # 工具类型
    tool_report = classification_report(
        true_tool, pred_tool,
        output_dict=True,
        zero_division=0
    )
    metrics['tool_type'] = {
        'accuracy': tool_report['accuracy'],
        'macro_f1': tool_report['macro avg']['f1-score'],
        'weighted_f1': tool_report['weighted avg']['f1-score'],
        'per_class': tool_report
    }
    
    # 意图明确度
    intent_report = classification_report(
        true_intent, pred_intent,
        output_dict=True,
        zero_division=0
    )
    metrics['intent_clarity'] = {
        'accuracy': intent_report['accuracy'],
        'macro_f1': intent_report['macro avg']['f1-score'],
        'weighted_f1': intent_report['weighted avg']['f1-score'],
        'per_class': intent_report
    }
    
    # 指令类型
    instruction_report = classification_report(
        true_instruction, pred_instruction,
        output_dict=True,
        zero_division=0
    )
    metrics['instruction_type'] = {
        'accuracy': instruction_report['accuracy'],
        'macro_f1': instruction_report['macro avg']['f1-score'],
        'weighted_f1': instruction_report['weighted avg']['f1-score'],
        'per_class': instruction_report
    }
    
    # 执行状态
    execution_report = classification_report(
        true_execution, pred_execution,
        output_dict=True,
        zero_division=0
    )
    metrics['execution_status'] = {
        'accuracy': execution_report['accuracy'],
        'macro_f1': execution_report['macro avg']['f1-score'],
        'weighted_f1': execution_report['weighted avg']['f1-score'],
        'per_class': execution_report
    }
    
    # 整体指标
    all_correct = sum(
        1 for p, g in zip(predictions, ground_truths)
        if p == g
    )
    metrics['overall'] = {
        'accuracy': all_correct / len(predictions),
        'end_to_end_accuracy': all_correct / len(predictions)
    }
    
    # 任务复杂度准确率
    task_complexity_correct = sum(
        1 for p, g in zip(predictions, ground_truths)
        if determine_task_type(p) == determine_task_type(g)
    )
    metrics['task_complexity'] = {
        'accuracy': task_complexity_correct / len(predictions)
    }
    
    return metrics

def determine_task_type(labels):
    """根据4个维度确定任务复杂度"""
    tool_type, intent_clarity, instruction_type, execution_status = labels
    
    # complex条件
    is_complex = (
        intent_clarity in ['infer', 'vague'] or
        tool_type in ['multi', 'chat', 'pend', 'specific'] or
        instruction_type == 'cond' or
        execution_status == 'abnormal'
    )
    
    return 'complex' if is_complex else 'easy'
```

#### 2.3.2 错误分析

```python
def analyze_errors(test_data, predictions, ground_truths):
    """错误分析"""
    
    errors = []
    
    for i, (item, pred, truth) in enumerate(zip(test_data, predictions, ground_truths)):
        if pred != truth:
            error = {
                'index': i,
                'query': item['query'],
                'tools': item['tools'],
                'history': item['history'],
                'prediction': pred,
                'ground_truth': truth,
                'error_dimensions': []
            }
            
            # 分析哪些维度出错
            for j, (p, t) in enumerate(zip(pred, truth)):
                if p != t:
                    dimension = ['tool_type', 'intent_clarity', 'instruction_type', 'execution_status'][j]
                    error['error_dimensions'].append({
                        'dimension': dimension,
                        'predicted': p,
                        'actual': t
                    })
            