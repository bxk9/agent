u_stat, p_value = mannwhitneyu(multi_overall_scores, qwen_overall_scores, alternative='two-sided')
```

- `p_value < 0.05`：差异显著
- `p_value >= 0.05`：差异不显著，不能仅凭指标数值对比下结论

### 15.2 分场景配对检验

对每个 `category`（简历优化 / 面试准备）和每个 `industry`（10 个行业），分别做配对 Wilcoxon 检验：

```python
from scipy.stats import wilcoxon

# 同一 query 的两方案 overall 评分配对
w_stat, p_value = wilcoxon(multi_overall_scores, qwen_overall_scores)
```

### 15.3 效应量

除 p 值外，报告效应量（Cohen's d 或 Cliff's delta），判断差异的实际意义：

| 效应量 | 含义 |
|--------|------|
| `|d| < 0.2` | 可忽略 |
| `0.2 ≤ |d| < 0.5` | 小 |
| `0.5 ≤ |d| < 0.8` | 中 |
| `|d| ≥ 0.8` | 大 |

### 15.4 检验结果纳入报告

在 xlsx 报告的"总览"Sheet 中增加统计检验行：
- 全局 Mann-Whitney U 的 p 值 + 效应量
- 分场景/分行业的 Wilcoxon p 值（标注显著者）

> 依赖：`scipy`（需确认是否已在 requirements.txt 中）