# 评分标准变化后，重新评分（P1a 答案不变，只重跑评分）
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_300.xlsx \
    --phase 1b --force

# 只跑 Phase 2（指标计算，基于已有 P1a 数据）
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_300.xlsx \
    --phase 2

# 只跑 Phase 3（报告生成）
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_300.xlsx \
    --phase 3

# 只跑某个方案
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_300.xlsx \
    --phase 1a \
    --schemes multi

# 强制重跑
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_300.xlsx \
    --phase 1a \
    --force

# 断点续跑
python -m eval.qwen_vs_multi.cli \
    --resume latest
```

---

## 十、执行计划

### 10.1 阶段划分

| 阶段 | 内容 | 预计耗时 | 依赖 |
|------|------|:---:|------|
| 1. 数据集构造 | 完成 50/100/300 条数据集 xlsx | ✅ 已完成 | - |
| 2. 代码开发 | 实现 cli.py + 各 phase 模块 + caller 封装 | 3~5 天 | 阶段 1 |
| 3. 冒烟测试 | 50 条数据集跑通全流程，验证指标正确性 | 0.5 天 | 阶段 2 |
| 4. 中规模验证 | 100 条数据集，确认指标合理性，调整参数 | 0.5 天 | 阶段 3 |
| 5. 全量评测 | 300 条数据集，两方案并行采集 | 1~2 天 | 阶段 4 |
| 6. 报告输出 | 生成 PNG/xlsx/HTML 报告，撰写分析结论 | 0.5 天 | 阶段 5 |
| 7. 结论评审 | 与团队 review 结论，确认路由策略决策 | 0.5 天 | 阶段 6 |

### 10.2 小规模验证后检查项

- [ ] 两方案的 answer 是否都正常采集（非空、非错误）
- [ ] LLM Judge 打分是否合理（抽查 10 条，对比人工判断）
- [ ] timing 数据是否完整（elapsed_ms / server_ms）
- [ ] 指标计算是否正确（手工验算 3~5 个指标）
- [ ] 分场景/分行业统计是否正确
- [ ] 统计检验（Mann-Whitney U / 效应量）是否正常输出
- [ ] 报告图表是否正常生成

---

## 十一、风险与注意事项

### 11.1 原始值对比 + 统计检验

本方案已去掉 min-max 归一化，改用原始值对比 + 统计显著性检验。**报告中同时展示原始值差异和 p 值**，不做归一化排名。例如：

| 指标 | 多引擎路由 | qwen3.6-agent | 差异 | p 值 |
|------|:---:|:---:|:---:|:---:|
| 满意率 | 0.65 | 0.58 | +0.07 | 0.03* |
| P50 耗时 | 3420ms | 2800ms | -620ms | 0.01* |

### 11.2 qwen3.6-agent 无 references

qwen3.6-agent 的回答通常不返回结构化引用，因此：
- 5.6 溯源覆盖率为 0（或标记为 N/A）
- 报告中需标注此项差异

### 11.3 单轮评测约束

确保数据集中所有 query 的第一轮回复都产出可见的搜索内容，而非确认卡/追问。如果某条 query 在实际运行中触发了确认卡，应标记为"单轮不可用"并排除。

### 11.4 外部服务依赖

- 多引擎路由方案：直接调用内部函数（`search_engines.search` + `VivoCustomChat`），不走评测 HTTP 端点（LLM 调用仍走内部 API 网关）
- qwen3.6-agent 方案：依赖 vivo Agent API（`chatgpt-api-pre.vmic.xyz`）
- 打分模块：依赖主项目 LLM（`Doubao-Seed-2.0-lite`，通过同一 vivo API 网关调用）
- 评测前需确认 Agent API 和 LLM API 可用

### 11.5 LLM 作为裁判的偏差

自建打分模块使用 LLM prompt 做 0/1/2 评分，可能存在：
- 长度偏好（偏好更长的回答）
- 格式偏好（偏好有结构化格式的回答）
- 两方案输出风格差异造成的系统性偏差（多引擎路由 = 结构化 + 引用标注，qwen3.6-agent = 自然对话）
- 位置偏差（prompt 中的回答顺序可能影响评分）

**缓解措施**：
- 使用低温度（0.1）保证评分一致性
- 对分歧 case 进行人工抽检（至少 20 条），计算人工 vs LLM 打分的一致率
- 如果一致率 < 80%，考虑引入 V2 排序评测（权威模型横向对比），类似现有的 `eval/v2_rank/` 线路
- 在报告中标注"LLM 打分偏差风险"

---

## 十二、附录：与现有 8 引擎评测框架的差异

| 差异点 | 8 引擎评测 | 本对比评测 |
|--------|-----------|-----------|
| 参评对象 | 8 个搜索引擎 | 2 个方案（qwen3.6-agent vs 多引擎路由） |
| 适用维度 | D1~D6 全部 | 仅 D5 + D6 |
| 数据采集 | Phase 1 搜索采集 + Phase 2 端到端 | Phase 1a 答案采集 + Phase 1b LLM 评分 |
| 打分方式 | 外部评测服务 `normal_acc_tool` | 自建 LLM Judge（`Doubao-Seed-2.0-lite` prompt 多维度评分） |
| 指标数量 | ~50 个子指标 | ~12 个子指标 |
| 对比方式 | 8 个引擎间 min-max 归一化 | 2 方案原始值 + 统计检验（不做归一化） |
| 测试集 | 通用搜索 query（641 条） | 简历优化 + 面试准备场景 query（300 条） |
| 目录结构 | `eval/runs/eval_run_*` | `eval/runs/qwen_vs_multi_*` |
| 代码位置 | `eval/` 顶层 | `eval/qwen_vs_multi/` |

---

## 十三、成本考量

### 13.1 成本对比

| 维度 | 多引擎路由 | qwen3.6-agent |
|------|-----------|---------------|
| 搜索 API 调用 | 搜索引擎并发调用（每次搜索 N 次 HTTP 请求，取决于 intent 路由） | 模型内部搜索（API 调用次数不可控，取决于模型决策） |
| LLM 推理 | 1 次（Doubao-Seed-2.0-lite 总结） | 1 次（qwen3.6-agent 推理+搜索决策） |
| token 消耗 | 搜索结果文本 + LLM 总结 prompt | 模型内部处理，token 不可控 |
| 部署复杂度 | 需维护 FastAPI 服务 + 搜索引擎注册 | 仅需 Agent API 端点 |
| 可观测性 | 每次搜索可追踪（日志/耗时/结果） | 黑盒，无法追踪搜索细节 |

### 13.2 成本评估建议

- 在 Phase 1a 采集时，同时记录每次调用的 token 消耗（如果 API 返回）
- 报告中增加"性价比"维度：`答案质量 / 平均耗时` 或 `答案质量 / 预估 token 消耗`
- 注意：成本不纳入指标对比，但应在结论中作为决策参考

---

## 十四、批判性审查意见

以下是对本方案 v1.0 版本的批判性审查，以及对应修正。

### 审查点 1：打分工具不可用，需自建

**问题**：v1.0 中写 `从 tests.normal_acc_tool import get_auto_acc_score`，但实际验证发现：
- `normal_acc_tool.py` 位于 `/home/bxk/projects/vivo_deepagents/tests/`，不在当前项目
- 无法 import（缺少 `pandas`/`tqdm` 依赖）
- 即使能 import，底层服务 `rag-auto-eval-acc-v2` 是"知识问答自动化评测"场景，非面试/简历场景
- 响应慢（5~10 秒/条），不可控

**修正**：v1.2 已改为自建 LLM Judge 打分模块（`eval/qwen_vs_multi/judge.py`），调用主项目已有的 `Doubao-Seed-2.0-lite` 模型，通过 prompt 做 0/1/2 评分。优势：无外部依赖、可定制评分标准、响应快（~2-3 秒/条）、评分逻辑透明。

**风险**：LLM 裁判偏差（见 11.5 节）。

### 审查点 2：多引擎路由方案定义不清晰

**问题**：v1.0 中写"通过路由策略选择引擎"，但当前项目实际实现是 `parallel_web_search()` 并发调用 8 个引擎后 RRF 融合，不存在"路由策略选择"。

**修正**：已将方案描述改为"多引擎搜索 + RRF 融合 + LLM 总结"，并在 Phase 1a 调用方式中明确使用 `search(intent="通用", query)` 调用搜索引擎。

**开放问题**：是否需要测试"路由策略版"（按意图/场景选择引擎子集）？如需，可后续增加一个变体方案。

### 审查点 3：qwen3.6-agent 的 server_ms 无法精确采集

**问题**：v1.0 中假设 qwen3.6-agent 的 `server_ms` 可以从首字节到末字节计算，但 SSE 流式场景下这个值不等于服务端处理时间（流式传输本身有延迟），且 `ttfb`（首字节时间）往往比 `server_ms` 更有意义。

**修正**：
- qwen3.6-agent 的 `server_ms` 标记为 `null`（不可用）
- 在 D6 指标中，qwen3.6-agent 的 6.3c（服务端耗时）权重分配给其他 D6 指标
- 考虑增加 `ttfb`（首字节耗时）作为性能指标，替代 `server_ms`

### 审查点 4：缺少统计显著性检验

**问题**：方案中只有"综合得分"排名，没有回答"差异是否显著"的问题。例如满意率 0.65 vs 0.58，差异多大才算"显著"？

**修正**：新增统计检验章节（见下方）。

### 审查点 5：缺少成本维度

**问题**：方案只对比了质量和性能，但 qwen3.6-agent 的 token 消耗和 API 调用次数是黑盒，可能比多引擎路由高很多。

**修正**：新增"成本考量"章节（见上方第十三章）。

### 审查点 6：单轮评测约束不够严格

**问题**：方案中虽然提到"单轮评测"，但未明确如何处理 qwen3.6-agent 可能返回的"确认卡"或"追问"的情况。qwen3.6-agent 作为 Agent 模型，可能不会直接给出答案，而是先确认用户意图。

**修正**：
- 在数据集中增加 `single_round_output` 字段，Phase 1a 采集后逐条校验实际产出是否匹配预期
- 如果某条 query 在任一方案中产出"确认卡/追问"而非搜索内容，标记为"单轮不可用"并排除
- 报告中单独统计"单轮可用率"（两方案都能正常产出答案的 query 占比）

### 审查点 7：LLM 裁判偏差需持续监控

**问题**：自建 LLM Judge 使用 prompt 打分，存在长度偏好、格式偏好等偏差。两方案输出风格不同（多引擎路由 = 结构化 + 引用标注，qwen3.6-agent = 自然对话），可能造成系统性偏差。

**建议**：
- 对分歧 case 进行人工抽检（至少 20 条），计算人工 vs 自动打分的一致率
- 如果一致率 < 80%，考虑引入 V2 排序评测（权威模型横向对比），类似现有的 `eval/v2_rank/` 线路
- 在报告中标注"打分偏差风险"

---

## 十五、统计显著性检验

由于只有 2 个方案，简单的指标数值对比可能掩盖差异是否真实存在的问题。建议增加以下统计检验：

### 15.1 两方案 overall 评分的 Mann-Whitney U 检验

```python
from scipy.stats import mannwhitneyu

# 对 N 条 query 的两组 overall 评分做非参数检验