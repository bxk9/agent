            errors.append(error)
    
    # 统计错误分布
    error_stats = {
        'total_errors': len(errors),
        'error_rate': len(errors) / len(test_data),
        'dimension_errors': {
            'tool_type': 0,
            'intent_clarity': 0,
            'instruction_type': 0,
            'execution_status': 0
        },
        'multi_dimension_errors': 0
    }
    
    for error in errors:
        if len(error['error_dimensions']) > 1:
            error_stats['multi_dimension_errors'] += 1
        
        for dim_error in error['error_dimensions']:
            error_stats['dimension_errors'][dim_error['dimension']] += 1
    
    return {
        'errors': errors,
        'stats': error_stats
    }
```

#### 2.3.3 可视化报告

```python
def generate_report(metrics, error_analysis, output_dir):
    """生成评测报告"""
    
    # 1. 生成指标表格
    metrics_df = pd.DataFrame({
        'Dimension': ['Tool Type', 'Intent Clarity', 'Instruction Type', 'Execution Status', 'Overall'],
        'Accuracy': [
            metrics['tool_type']['accuracy'],
            metrics['intent_clarity']['accuracy'],
            metrics['instruction_type']['accuracy'],
            metrics['execution_status']['accuracy'],
            metrics['overall']['accuracy']
        ],
        'Macro F1': [
            metrics['tool_type']['macro_f1'],
            metrics['intent_clarity']['macro_f1'],
            metrics['instruction_type']['macro_f1'],
            metrics['execution_status']['macro_f1'],
            '-'
        ],
        'Weighted F1': [
            metrics['tool_type']['weighted_f1'],
            metrics['intent_clarity']['weighted_f1'],
            metrics['instruction_type']['weighted_f1'],
            metrics['execution_status']['weighted_f1'],
            '-'
        ]
    })
    
    metrics_df.to_csv(f"{output_dir}/metrics.csv", index=False)
    
    # 2. 生成混淆矩阵
    for dimension in ['tool_type', 'intent_clarity', 'instruction_type', 'execution_status']:
        plot_confusion_matrix(
            metrics[dimension]['per_class'],
            dimension,
            output_dir
        )
    
    # 3. 生成错误分析报告
    error_report = {
        'total_samples': len(error_analysis['errors']) + error_analysis['stats']['total_errors'],
        'total_errors': error_analysis['stats']['total_errors'],
        'error_rate': error_analysis['stats']['error_rate'],
        'dimension_errors': error_analysis['stats']['dimension_errors'],
        'multi_dimension_errors': error_analysis['stats']['multi_dimension_errors'],
        'sample_errors': error_analysis['errors'][:20]  # 前20个错误样本
    }
    
    with open(f"{output_dir}/error_analysis.json", 'w', encoding='utf-8') as f:
        json.dump(error_report, f, ensure_ascii=False, indent=2)
    
    # 4. 生成Markdown报告
    generate_markdown_report(metrics, error_analysis, output_dir)

def plot_confusion_matrix(report, dimension, output_dir):
    """绘制混淆矩阵"""
    
    # 提取混淆矩阵数据
    labels = [k for k in report.keys() if k not in ['accuracy', 'macro avg', 'weighted avg']]
    matrix = []
    
    for true_label in labels:
        row = []
        for pred_label in labels:
            # 这里需要实际的混淆矩阵数据
            # 简化处理：使用recall作为对角线值
            if true_label == pred_label:
                row.append(report[true_label]['recall'])
            else:
                row.append(0)
        matrix.append(row)
    
    # 绘制热力图
    plt.figure(figsize=(10, 8))
    sns.heatmap(
        matrix,
        annot=True,
        fmt='.2f',
        xticklabels=labels,
        yticklabels=labels,
        cmap='Blues'
    )
    plt.title(f'Confusion Matrix - {dimension}')
    plt.xlabel('Predicted')
    plt.ylabel('Actual')
    plt.tight_layout()
    plt.savefig(f"{output_dir}/confusion_matrix_{dimension}.png")
    plt.close()

def generate_markdown_report(metrics, error_analysis, output_dir):
    """生成Markdown报告"""
    
    report = f"""# 路由分类评测报告

## 1. 整体指标

| 指标 | 数值 |
|------|------|
| 整体准确率 | {metrics['overall']['accuracy']:.2%} |
| 任务复杂度准确率 | {metrics['task_complexity']['accuracy']:.2%} |
| 端到端准确率 | {metrics['overall']['end_to_end_accuracy']:.2%} |

## 2. 各维度指标

### 2.1 工具类型

| 指标 | 数值 |
|------|------|
| 准确率 | {metrics['tool_type']['accuracy']:.2%} |
| 宏平均F1 | {metrics['tool_type']['macro_f1']:.2%} |
| 加权平均F1 | {metrics['tool_type']['weighted_f1']:.2%} |

### 2.2 意图明确度

| 指标 | 数值 |
|------|------|
| 准确率 | {metrics['intent_clarity']['accuracy']:.2%} |
| 宏平均F1 | {metrics['intent_clarity']['macro_f1']:.2%} |
| 加权平均F1 | {metrics['intent_clarity']['weighted_f1']:.2%} |

### 2.3 指令类型

| 指标 | 数值 |
|------|------|
| 准确率 | {metrics['instruction_type']['accuracy']:.2%} |
| 宏平均F1 | {metrics['instruction_type']['macro_f1']:.2%} |
| 加权平均F1 | {metrics['instruction_type']['weighted_f1']:.2%} |

### 2.4 执行状态

| 指标 | 数值 |
|------|------|
| 准确率 | {metrics['execution_status']['accuracy']:.2%} |
| 宏平均F1 | {metrics['execution_status']['macro_f1']:.2%} |
| 加权平均F1 | {metrics['execution_status']['weighted_f1']:.2%} |

## 3. 错误分析

### 3.1 错误统计

| 指标 | 数值 |
|------|------|
| 总样本数 | {error_analysis['stats']['total_errors'] + len(error_analysis['errors'])} |
| 错误数 | {error_analysis['stats']['total_errors']} |
| 错误率 | {error_analysis['stats']['error_rate']:.2%} |
| 多维度错误数 | {error_analysis['stats']['multi_dimension_errors']} |

### 3.2 各维度错误分布

| 维度 | 错误数 | 占比 |
|------|--------|------|
| 工具类型 | {error_analysis['stats']['dimension_errors']['tool_type']} | {error_analysis['stats']['dimension_errors']['tool_type'] / error_analysis['stats']['total_errors']:.2%} |
| 意图明确度 | {error_analysis['stats']['dimension_errors']['intent_clarity']} | {error_analysis['stats']['dimension_errors']['intent_clarity'] / error_analysis['stats']['total_errors']:.2%} |
| 指令类型 | {error_analysis['stats']['dimension_errors']['instruction_type']} | {error_analysis['stats']['dimension_errors']['instruction_type'] / error_analysis['stats']['total_errors']:.2%} |
| 执行状态 | {error_analysis['stats']['dimension_errors']['execution_status']} | {error_analysis['stats']['dimension_errors']['execution_status'] / error_analysis['stats']['total_errors']:.2%} |

## 4. 典型错误案例

"""
    
    # 添加前10个错误案例
    for i, error in enumerate(error_analysis['errors'][:10], 1):
        report += f"""
### 案例 {i}

**Query**: {error['query']}

**预测**: {', '.join(error['prediction'])}

**真实**: {', '.join(error['ground_truth'])}

**错误维度**:
"""
        for dim_error in error['error_dimensions']:
            report += f"- {dim_error['dimension']}: 预测={dim_error['predicted']}, 实际={dim_error['actual']}\n"
        
        report += "\n---\n"
    
    with open(f"{output_dir}/evaluation_report.md", 'w', encoding='utf-8') as f:
        f.write(report)
```

---

## 3. A/B测试框架

### 3.1 A/B测试设计

**测试目标**：验证优化方案（如Prompt优化、模型微调）的效果

**测试设计**：
```
1. 流量分配：
   - 对照组（A组）：50%流量，使用旧版本
   - 实验组（B组）：50%流量，使用新版本

2. 测试周期：
   - 最少7天（覆盖工作日和周末）
   - 最少10,000个样本（保证统计显著性）

3. 评测指标：
   - 主要指标：准确率
   - 次要指标：延迟、吞吐量、用户满意度

4. 统计检验：
   - 使用卡方检验或t检验
   - 显著性水平：p < 0.05
```

### 3.2 A/B测试实现

```python
# utils/ab_test.py

import random
import hashlib
from scipy import stats

class ABTestManager:
    """A/B测试管理器"""
    
    def __init__(self, test_name, traffic_split=0.5):
        """
        初始化A/B测试
        
        Args:
            test_name: 测试名称
            traffic_split: 实验组流量比例（0-1）
        """
        self.test_name = test_name
        self.traffic_split = traffic_split
        
        # 统计数据
        self.stats = {
            'control': {'total': 0, 'correct': 0, 'latencies': []},
            'experiment': {'total': 0, 'correct': 0, 'latencies': []}
        }
    
    def assign_group(self, user_id):
        """
        分配��户到对照组或实验组
        
        使用一致性哈希，保证同一用户始终分配到同一组
        """
        # 计算哈希值
        hash_value = int(hashlib.md5(f"{self.test_name}:{user_id}".encode()).hexdigest(), 16)
        
        # 根据哈希值分配组
        if (hash_value % 100) / 100 < self.traffic_split:
            return 'experiment'
        else:
            return 'control'
    
    def record_result(self, group, is_correct, latency):
        """记录测试结果"""
        self.stats[group]['total'] += 1
        if is_correct:
            self.stats[group]['correct'] += 1
        self.stats[group]['latencies'].append(latency)
    
    def analyze_results(self):
        """分析测试结果"""
        
        control = self.stats['control']
        experiment = self.stats['experiment']
        
        # 计算准确率
        control_accuracy = control['correct'] / control['total'] if control['total'] > 0 else 0
        experiment_accuracy = experiment['correct'] / experiment['total'] if experiment['total'] > 0 else 0
        
        # 计算延迟
        control_latency_p50 = np.percentile(control['latencies'], 50) if control['latencies'] else 0
        experiment_latency_p50 = np.percentile(experiment['latencies'], 50) if experiment['latencies'] else 0
        
        # 统计检验（准确率）
        # 使用卡方检验
        contingency_table = [
            [control['correct'], control['total'] - control['correct']],
            [experiment['correct'], experiment['total'] - experiment['correct']]
        ]