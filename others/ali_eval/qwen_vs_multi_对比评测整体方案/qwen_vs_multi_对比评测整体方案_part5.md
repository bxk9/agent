| `references` | str | `[{"Title":"...","Url":"...","AttributionScore":0.85}]` | JSON 字符串（仅 multi 有值） |
| `success` | bool | `TRUE` | 调用是否成功 |
| `error` | str | （空） | 错误信息 |
| `elapsed_ms` | int | `8523` | 端到端耗时（ms） |
| `server_ms` | int | `7200` | 服务端耗时（qwen 为空） |
| `network_ms` | int | `1323` | 网络耗时（qwen 为空） |
| `ttft_ms` | int | `3200` | 首字节耗时 |
| `timestamp` | str | `2026-07-30T14:30:00` | 采集时间戳 |
| `overall` | int | `2` | 综合评分 0/1/2（Phase 1b 填充） |
| `accuracy` | int | `2` | 事实准确性 0/1/2（Phase 1b 填充） |
| `completeness` | int | `1` | 覆盖完整度 0/1/2（Phase 1b 填充） |
| `relevance` | int | `2` | 相关性 0/1/2（Phase 1b 填充） |
| `remark` | str | `答案准确且相关，但遗漏了薪资范围` | 评分备注（Phase 1b 填充） |
| `scored_at` | str | `2026-07-30T15:00:00` | 评分时间戳（Phase 1b 填充） |

#### P2_metrics.xlsx Sheet 结构

**Sheet「总览」**：

| 指标 | 多引擎路由 | qwen3.6-agent | 差异 | p 值 | 显著性 |
|------|:---:|:---:|:---:|:---:|:---:|
| 满意率 | 0.65 | 0.58 | +0.07 | 0.03 | * |
| 不满意率 | 0.10 | 0.12 | -0.02 | — | — |
| 加权平均分 | 1.55 | 1.46 | +0.09 | 0.04 | * |
| 胜率 | 52% | 35% | +17% | — | * |
| 事实准确率 | 0.82 | 0.70 | +0.12 | 0.01 | * |
| 完整度得分 | 0.75 | 0.78 | -0.03 | 0.30 | — |
| 相关性得分 | 0.88 | 0.85 | +0.03 | 0.25 | — |
| 溯源覆盖率 | 0.72 | N/A | — | — | — |
| 单轮可用率 | 0.98 | 0.92 | +0.06 | — | — |
| 成功率 | 0.99 | 0.97 | +0.02 | — | — |
| P50 耗时 | 3420ms | 2800ms | -620ms | 0.01 | * |
| P95 耗时 | 8900ms | 6500ms | -2400ms | 0.01 | * |
| **判定结论** | **各有优劣** | | | | |
| **结论说明** | 多引擎路由在准确率和溯源上领先，qwen3.6-agent 在完整度和延迟上领先 | | | | |

**Sheet「D5_质量对比」**：同上 D5 部分指标

**Sheet「D6_性能对比」**：同上 D6 部分指标

**Sheet「分场景」**：按 category 分组，每行一个场景

**Sheet「分行业」**：按 industry 分组，每行一个行业

**Sheet「分复杂度」**：按 search_complexity 分组，每行一个复杂度级别

---

## 五、统计分析与结论输出

### 5.1 全局对比

| 分析项 | 方法 | 输出 |
|--------|------|------|
| D5 质量对比 | 满意率 / 加权平均分 / 胜率 / 准确率 / 完整度 / 相关性 | 柱状图 + 表格 |
| D6 性能对比 | 成功率 / P50 / P95 / 标准差 | 柱状图 + 箱线图 |
| 统计检验 | Mann-Whitney U + 效应量 | p 值 + 显著性标注 |

### 5.2 分场景对比

| 分析项 | 分组维度 | 输出 |
|--------|---------|------|
| 业务场景 | `category`（resume_opt / interview_prep） | 分组柱状图 |
| 行业 | `industry`（10 个行业） | 热力图 |
| 搜索复杂度 | `search_complexity`（single / multi / incremental） | 分组柱状图 |
| 公司 | `company`（高频公司） | 热力图 |
| 岗位 | `position`（高频岗位） | 热力图 |

### 5.3 差异分析

| 分析项 | 说明 |
|--------|------|
| 一致率 | 两方案同时满意 / 同时不满意 / 一方满意一方不满意的 query 占比 |
| 分歧 case | 列出两方案评分差异 ≥1 分的 query，做 case study |
| 优劣势总结 | 每个方案在哪些场景/行业/复杂度下占优，哪些场景吃亏 |

### 5.4 结论模板

```
┌─────────────────────────────────────────────────────────────┐
│                    qwen3.6-agent vs 多引擎路由                │
│                        对比评测结论                           │
├──────────────┬──────────────────┬──────────────────────────┤
│ 方案          │ 判定             │ 说明                      │
├──────────────┼──────────────────┼──────────────────────────┤
│ 多引擎路由    │ [胜出/各有优劣]   │ [核心优势简述]             │
│ qwen3.6-agent │ [胜出/各有优劣]   │ [核心优势简述]             │
├──────────────┴──────────────────┴──────────────────────────┤
│                                                            │
│ 核心发现：                                                  │
│ 1. [质量结论] 在答案质量方面，...                            │
│ 2. [性能结论] 在性能方面，...                                │
│ 3. [场景差异] 在简历优化场景下，...；在面试准备场景下，...    │
│ 4. [行业差异] 在互联网/金融等行业，...                       │
│ 5. [溯源能力] 多引擎路由的溯源覆盖率为 XX%，qwen3.6-agent 无  │
│                                                            │
│ 建议：                                                      │
│ - 如果追求答案质量和可追溯性，推荐多引擎路由                   │
│ - 如果追求部署简单和低延迟，推荐 qwen3.6-agent                │
│ - 可以在简历优化场景优先使用多引擎路由，面试准备场景使用 agent │
└─────────────────────────────────────────────────────────────┘
```

---

## 六、可视化清单

| 维度 | 图表类型 | 内容 | 文件名 |
|------|---------|------|--------|
| D5 质量 | 分组柱状图 | 两方案满意率/瑕疵率/不满意率对比 | `D5_satisfaction_bar.png` |
| D5 质量 | 分组柱状图 | 两方案加权平均分对比 | `D5_weighted_avg_bar.png` |
| D5 质量 | 热力图 | X=场景, Y=方案, 值=加权平均分 | `D5_category_heatmap.png` |
| D5 质量 | 热力图 | X=行业, Y=方案, 值=加权平均分 | `D5_industry_heatmap.png` |
| D5 质量 | 分组柱状图 | 分复杂度（single/multi/incremental）的加权平均分 | `D5_complexity_bar.png` |
| D6 性能 | 分组柱状图 | 成功率/超时率对比 | `D6_reliability_bar.png` |
| D6 性能 | 分组柱状图 | P50/P95/P99 耗时对比 | `D6_latency_bar.png` |
| D6 性能 | 箱线图 | 两方案耗时分布 | `D6_latency_boxplot.png` |
| D6 性能 | 堆叠柱状图 | 网络耗时 vs 服务端耗时拆分 | `D6_latency_split.png` |
| 综合 | 雷达图 | 两方案 D5+D6 子指标雷达 | `CS_radar.png` |
| 综合 | 分组柱状图 | 多维度对比概览 | `CS_summary_bar.png` |

---

## 七、报告 xlsx Sheet 结构

Phase 3 生成的 `report/eval_report.xlsx` 包含以下 Sheet：

| Sheet | 来源 | 内容 | 说明 |
|-------|------|------|------|
| `总览` | P2_metrics.xlsx | 多维度对比表 + 判定结论 + 统计检验结果 | 一页看全貌 |
| `D5_质量对比` | P2_metrics.xlsx | 满意率/不满意率/加权平均分/胜率/准确率/完整度/相关性/溯源覆盖率 | 原始值对比 |
| `D6_性能对比` | P2_metrics.xlsx | 成功率/超时率/P50/P95/标准差 | 原始值对比 |
| `分场景` | P2_metrics.xlsx | 按 category 分组的 D5 指标 | 简历优化 vs 面试准备 |
| `分行业` | P2_metrics.xlsx | 按 industry 分组的 D5 指标 | 10 个行业 |
| `分复杂度` | P2_metrics.xlsx | 按 search_complexity 分组的 D5 指标 | single/multi/incremental |
| `明细_multi` | P1a_multi.xlsx | 多引擎路由每条 query 的 answer + scores + timing | 逐条追溯 |
| `明细_qwen` | P1a_qwen.xlsx | qwen3.6-agent 每条 query 的 answer + scores + timing | 逐条追溯 |
| `分歧Case` | 对比计算 | 两方案 overall 差异 ≥1 分的 query | 差异分析 |

> **设计说明**：`P2_metrics.xlsx` 是 Phase 2 的纯指标输出，`report/eval_report.xlsx` 是 Phase 3 合并了指标 + 明细的最终交付物。两个文件均可直接用于人工检查和汇报。

---

## 八、实现文件清单

| 文件 | 职责 | 预估行数 |
|------|------|:---:|
| `eval/qwen_vs_multi/cli.py` | 评测主入口 + 流水线编排 + 断点续跑 | ~300 |
| `eval/qwen_vs_multi/phase0_dataset.py` | 数据集加载 + 校验 | ~80 |
| `eval/qwen_vs_multi/phase1a_collect.py` | 方案调用 + 答案采集（不含评分） | ~300 |
| `eval/qwen_vs_multi/phase1b_score.py` | LLM Judge 评分（独立阶段，可重跑） | ~150 |
| `eval/qwen_vs_multi/phase2_metrics.py` | 指标计算 + 统计检验 | ~250 |
| `eval/qwen_vs_multi/phase3_report.py` | 可视化报告生成（PNG + xlsx + HTML） | ~350 |
| `eval/qwen_vs_multi/judge.py` | LLM Judge 打分模块（调用主项目 LLM 做 0/1/2 多维度评分） | ~120 |
| `eval/qwen_vs_multi/callers/multi_engine_caller.py` | 多引擎路由方案调用封装 | ~100 |
| `eval/qwen_vs_multi/callers/qwen_agent_caller.py` | qwen3.6-agent 方案调用封装 | ~100 |
| `eval/qwen_vs_multi/common.py` | 通用工具（日志/xlsx 读写/目录管理） | ~80 |

---

## 九、运行方式

```bash
# 完整流水线（Phase 0 → 1a → 1b → 2 → 3 全跑）
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_300.xlsx \
    --limit 300 \
    --concurrency 4

# 小规模验证（50 条冒烟测试）
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_50.xlsx \
    --limit 50 \
    --concurrency 2

# 中规模验证（100 条）
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_100.xlsx \
    --limit 100 \
    --concurrency 2

# 只跑 Phase 1a（答案采集，最昂贵阶段）
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_300.xlsx \
    --phase 1a \
    --concurrency 4

# 只跑 Phase 1b（LLM 评分，基于已有 P1a 数据）
python -m eval.qwen_vs_multi.cli \
    --input datasets/search_eval_queries_300.xlsx \
    --phase 1b
