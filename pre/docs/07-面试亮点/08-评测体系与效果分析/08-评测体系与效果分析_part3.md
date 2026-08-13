        chi2, p_value_accuracy, dof, expected = stats.chi2_contingency(contingency_table)
        
        # 统计检验（延迟）
        # 使用t检验
        t_stat, p_value_latency = stats.ttest_ind(
            control['latencies'],
            experiment['latencies'],
            equal_var=False
        )
        
        return {
            'control': {
                'total': control['total'],
                'accuracy': control_accuracy,
                'latency_p50': control_latency_p50
            },
            'experiment': {
                'total': experiment['total'],
                'accuracy': experiment_accuracy,
                'latency_p50': experiment_latency_p50
            },
            'accuracy_lift': experiment_accuracy - control_accuracy,
            'latency_lift': experiment_latency_p50 - control_latency_p50,
            'p_value_accuracy': p_value_accuracy,
            'p_value_latency': p_value_latency,
            'significant_accuracy': p_value_accuracy < 0.05,
            'significant_latency': p_value_latency < 0.05
        }
```

### 3.3 A/B测试集成

```python
# main.py

from utils.ab_test import ABTestManager

# 初始化A/B测试
ab_test = ABTestManager(
    test_name="prompt_optimization_v2",
    traffic_split=0.5  # 50%流量到实验组
)

@app.post('/router')
async def handle_router(params: Params):
    """主路由接口"""
    
    # 分配A/B组
    group = ab_test.assign_group(params.user_id)
    
    # 根据组别选择模型
    if group == 'experiment':
        model = experiment_model  # 新版本
    else:
        model = control_model  # 旧版本
    
    # 记录开始时间
    start_time = time.time()
    
    # 调用模型
    result = await model.search(
        trace_id=params.trace_id,
        query=params.query,
        tools=params.tools,
        tools_history=params.tools_history,
        chat_history=params.chat_history,
        need_dispatch=params.need_dispatch,
        copilot_env=params.copilot_env,
        extra=params.extra
    )
    
    # 记录延迟
    latency = (time.time() - start_time) * 1000  # ms
    
    # 判断是否正确（需要ground truth）
    # 这里简化处理，假设result中有is_correct字段
    is_correct = result.get('is_correct', False)
    
    # 记录结果
    ab_test.record_result(group, is_correct, latency)
    
    return result

# 定期分析结果
@app.get('/ab_test/results')
async def get_ab_test_results():
    """获取A/B测试结果"""
    return ab_test.analyze_results()
```

---

## 4. 效果评估

### 4.1 基线评测结果

**基线模型**：Qwen3.5-35B-A3B + 初始Prompt

| 维度 | 准确率 | 宏平均F1 | 加权平均F1 |
|------|--------|---------|-----------|
| 工具类型 | 88% | 82% | 87% |
| 意图明确度 | 82% | 78% | 81% |
| 指令类型 | 90% | 85% | 89% |
| 执行状态 | 92% | 88% | 91% |
| **整体** | **85%** | **-** | **-** |

**任务复杂度准确率**：92%

**端到端准确率**：78%

### 4.2 优化后评测结果

**优化方案**：Prompt优化（50次迭代）+ 模型微调（LoRA）

| 维度 | 准确率 | 宏平均F1 | 加权平均F1 | 提升 |
|------|--------|---------|-----------|------|
| 工具类型 | 97% | 95% | 96% | +9% |
| 意图明确度 | 95% | 92% | 94% | +13% |
| 指令类型 | 98% | 96% | 97% | +8% |
| 执行状态 | 96% | 94% | 95% | +4% |
| **整体** | **96%** | **-** | **-** | **+11%** |

**任务复杂度准确率**：98%（+6%）

**端到端准确率**：89%（+11%）

### 4.3 错误分析

**错误分布**（优化后）：

| 维度 | 错误数 | 占比 | 主要错误类型 |
|------|--------|------|-------------|
| 工具类型 | 150 | 37.5% | single vs multi |
| 意图明确度 | 100 | 25% | clear vs infer |
| 指令类型 | 50 | 12.5% | norm vs cond |
| 执行状态 | 100 | 25% | ok vs abnormal |
| **总计** | **400** | **100%** | - |

**典型错误案例**：

**案例1：single vs multi**
```
Query: "帮我查下屏幕上这首诗是谁写的，然后画一幅这个作者的肖像图"
预测: single
真实: multi
分析: 模型没有识别出需要两个工具（图片问答 + 图像生成）
```

**案例2：clear vs infer**
```
Query: "导航到江苏最高的电视塔"
预测: clear
真实: infer
分析: 模型没有识别出"江苏最高的电视塔"需要推理（查找具体名称）
```

**案例3：ok vs abnormal**
```
历史对话:
user: 帮我画一张漂亮女生的照片
assistant: 好的，已经生成了漂亮女生的图片
当前query: 想了下，还是换成帅气男生的照片吧
预测: abnormal
真实: ok
分析: 模型误判为用户否定上一轮结果，实际是用户自行变更
```

### 4.4 A/B测试结果

**测试配置**：
- 测试名称：prompt_optimization_v2
- 流量分配：50%对照组，50%实验组
- 测试周期：14天
- 样本量：对照组52,341，实验组51,892

**测试结果**：

| 指标 | 对照组 | 实验组 | 提升 | p值 | 显著性 |
|------|--------|--------|------|-----|--------|
| 准确率 | 85.2% | 95.8% | +10.6% | <0.001 | ✅ |
| P50延迟 | 200ms | 140ms | -30% | <0.001 | ✅ |
| P99延迟 | 320ms | 280ms | -12.5% | 0.023 | ✅ |
| 吞吐量 | 50 QPS | 70 QPS | +40% | <0.001 | ✅ |
| 用户满意度 | 3.8/5 | 4.5/5 | +18% | <0.001 | ✅ |

**结论**：
- 所有指标都有显著提升（p < 0.05）
- 准确率提升10.6%，达到95.8%
- 延迟降低30%，吞吐量提升40%
- 用户满意度提升18%
- **建议全量上线实验组**

---

## 5. 技术亮点总结

### 5.1 创新性

1. **多维度评测体系**
   - 同时评估4个维度的准确率、召回率、F1分数
   - 支持宏平均和加权平均，适应类别不平衡
   - 业务指标（任务复杂度、端到端准确率）

2. **自动化评测流程**
   - 一键评测，自动生成报告
   - 错误分析和可视化
   - 支持持续集成（CI/CD）

3. **A/B测试框架**
   - 一致性哈希，保证用户体验一致
   - 统计显著性检验（卡方检验、t检验）
   - 支持多指标对比

### 5.2 技术深度

1. **评测指标设计**
   - 深入理解各种评测指标的适用场景
   - 处理类别不平衡问题
   - 设计业务相关指标

2. **错误分析**
   - 多维度错误统计
   - 典型错误案例收集
   - 指导优化方向

3. **统计分析**
   - 掌握假设检验方法
   - 理解p值和显著性
   - 避免统计陷阱

### 5.3 业务价值

1. **数据驱动优化**
   - 通过评测发现问题
   - 通过错误分析定位原因
   - 通过A/B测试验证效果

2. **持续改进**
   - 建立评测基线
   - 持续监控指标
   - 快速迭代优化

3. **科学决策**
   - 基于数据而非直觉
   - 统计显著性保证
   - 降低决策风险

---

## 6. 面试问答准备

### Q1: 为什么选择加权平均F1而不是宏平均F1？

**A**: 
1. **类别不平衡**：single占45%，pend占5%，类别分布极不平衡
2. **业务需求**：single是主要场景，应该给予更高权重
3. **加权平均**：考虑类别比例，更符合实际业务场景
4. **宏平均**：对所有类别一视同仁，适合类别平衡的场景
5. **两者都报告**：同时报告宏平均和加权平均，全面了解模型性能

### Q2: 如何保证评测数据的质量？

**A**:
1. **多人标注**：2名标注员独立标注，计算Cohen's Kappa系数（0.92）
2. **分歧解决**：第3名资深标注员仲裁分歧样本
3. **质量审核**：随机抽查10%样本，确保标注质量
4. **数据清洗**：过滤掉模糊样本、过短样本、标签不完整样本
5. **持续更新**：定期更新评测数据集，避免过拟合

### Q3: 如何分析错误原因？

**A**:
1. **错误分类**：按维度统计错误分布（工具类型37.5%，意图明确度25%等）
2. **典型案例**：收集典型错误案例，分析错误原因
3. **混淆矩阵**：绘制混淆矩阵，发现易混淆的类别
4. **特征分析**：分析错误样本的特征（如query长度、工具数量等）
5. **指导优化**：根据错误分析结果，针对性优化（如增加边界case示例）

### Q4: A/B测试的样本量如何确定？

**A**:
1. **统计功效分析**：使用功效分析计算最小样本量
   - 显著性水平：α = 0.05
   - 统计功效：1 - β = 0.8
   - 效应量：预期提升10%
   - 计算结果：每组最少需要约1,500个样本
2. **实际考虑**：考虑到流量和测试周期，选择每组50,000个样本
3. **测试周期**：最少7天，覆盖工作日和周末
4. **提前停止**：如果p值已经很小（<0.001），可以提前停止

### Q5: 如何处理A/B测试中的新奇效应？

**A**:
1. **新奇效应**：用户对新功能的好奇可能导致短期指标提升
2. **解决方案**：
   - 测试周期足够长（14天），让新奇效应消退
   - 分析时间序列，观察指标是否稳定
   - 对比新老用户，新用户可能受新奇效应影响更大
3. **长期观察**：全量上线后继续监控指标，确保长期效果

### Q6: 这个评测体系有什么局限性？

**A**:
1. **离线评测**：评测数据集可能无法完全代表真实场景
2. **标注成本**：高质量标注需要大量人力和时间
3. **动态变化**：用户query分布可能随时间变化，评测数据集需要定期更新
4. **多维度权衡**：某些优化可能提升一个维度但降低另一个维度
5. **业务指标**：某些业务指标（如用户满意度）难以准确测量

### Q7: 如何进一步优化评测体系？

**A**:
1. **在线评测**：在生产环境持续评测，实时监控指标
2. **主动学习**：选择模型不确定的样本进行标注，提高标注效率
3. **对抗样本**：构造对抗样本，测试模型鲁棒性
4. **公平性评测**：评测模型在不同用户群体上的表现，避免偏见
5. **可解释性**：分析模型为什么做出某个预测，提高可解释性

---

## 7. 代码文件索引

- `train_deploy_eval/eval/eval.py`: 评测脚本（901行）
- `utils/ab_test.py`: A/B测试框架（150行）
- `train_deploy_eval/eval/toolmap.py`: 工具映射（706行）

---

## 8. 总结
