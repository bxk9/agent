# search_eval 交接文档

> 创建时间：2026-08-13
> 项目路径：`/home/bxk/projects/interview_agent/search_eval/`
> 上一负责人交接时的项目状态

---

## 一、项目一句话概述

对比评测 **qwen3.6-agent**（模型自主搜索）与 **多引擎路由**（项目现有搜索架构：多引擎搜索 + RRF 融合 + LLM 总结）两个方案在求职面试/简历优化场景下的端到端答案质量与性能差异，为技术选型提供数据支撑。

---

## 二、当前完成状态

### 已完成

| 项 | 状态 | 说明 |
|----|:----:|------|
| 评测方案设计 | ✅ | `qwen_vs_multi_对比评测整体方案.md`（v1.8，1268 行），`qwen_vs_multi_可复用指标详解.md`（302 行） |
| 数据集构造 | ✅ | 50/100/300 条三套 xlsx，位于 `datasets/` |
| 全部代码实现 | ✅ | Phase 0~3 + judge + callers + common，共 ~1800 行 |
| 单元/集成测试 | ✅ | `tests/` 下 7 个测试文件，覆盖全流程 mock 测试 |
| 多引擎路由方案采集 | ✅ | 最新 run（`20260730_164410`）中 `P1a_multi.xlsx` 已有 300 条数据 |
| 指标计算 + 报告生成 | ⚠️ 部分 | Phase 2/3 代码可跑，但仅基于 multi 单方案数据 |

### 未完成

| 项 | 状态 | 说明 |
|----|:----:|------|
| **qwen3.6-agent 方案采集** | ❌ | 最新 run 缺少 `P1a_qwen.xlsx`，说明 qwen 方案的 300 条采集未完成 |
| **双方案对比指标** | ❌ | Phase 2 胜率/Mann-Whitney U 检验需要两方案都有数据 |
| **完整对比报告** | ❌ | 需要双方案数据齐全后重跑 Phase 2 + 3 |
| **LLM Judge 人工校验** | ❌ | 方案要求"对分歧 case 进行人工抽检 ≥20 条，一致率 ≥80%"，尚未执行 |
| **最终结论评审** | ❌ | 需与团队 review 评测结论 |

---

## 三、代码架构速览

```
search_eval/
├── cli.py                     # 主入口 + 流水线编排 + 断点续跑
├── common.py                  # 通用工具：日志、xlsx 读写、目录管理
├── phase0_dataset.py          # 数据集加载 + 校验 + 列映射
├── phase1a_collect.py         # 方案调用 + 答案采集（不含评分）
├── phase1b_score.py           # LLM Judge 评分（独立可重跑）
├── phase2_metrics.py          # 指标计算 + 统计检验（Mann-Whitney U / Cliff's delta）
├── phase3_report.py           # 可视化报告（PNG + xlsx + HTML 仪表盘）
├── judge.py                   # LLM Judge 打分模块（调用 Doubao-Seed-2.0-pro）
├── callers/
│   ├── multi_engine_caller.py # 多引擎路由调用（search() + LLM 总结）
│   └── qwen_agent_caller.py   # qwen3.6-agent 调用（SSE 流式 API）
├── datasets/                  # 三套评测数据集 xlsx
├── runs/                      # 历次运行产物
├── tests/                     # 测试代码
├── qwen_vs_multi_对比评测整体方案.md   # 方案设计文档（1268 行）
└── qwen_vs_multi_可复用指标详解.md     # 指标定义文档（302 行）
```

### 流水线阶段

```
Phase 0: 数据集加载 → queries.xlsx
Phase 1a: 答案采集 → P1a_multi.xlsx + P1a_qwen.xlsx（最昂贵，尽量不重跑）
Phase 1b: LLM 评分 → 填充 P1a xlsx 的 scores 列（可独立重跑）
Phase 2: 指标计算 → P2_metrics.xlsx（多 Sheet）
Phase 3: 报告生成 → report/（PNG + xlsx + HTML）
```

---

## 四、运行方式

```bash
# 确保环境变量已设置
export VIVO_APP_ID="..."
export VIVO_APP_KEY="..."

# 完整流水线（300 条全量）
python -m search_eval.cli --input datasets/search_eval_queries_300.xlsx

# 只跑 qwen 方案的 Phase 1a（补完未完成部分）
python -m search_eval.cli --phase 1a --schemes qwen

# 断点续跑（基于已有 run 目录）
python -m search_eval.cli --resume latest

# 只重跑评分（评分标准变化后）
python -m search_eval.cli --phase 1b --force

# 只跑指标 + 报告（数据齐全后）
python -m search_eval.cli --phase 2
python -m search_eval.cli --phase 3
```

> **注意**：CLI 默认 input 路径为相对路径，代码会拼接项目根目录。运行前需 `cd` 到 `/home/bxk/projects/interview_agent/`。

---

## 五、接手人需要做的事（按优先级）

### 第一步：补完 qwen3.6-agent 答案采集

最新 run（`runs/qwen_vs_multi_20260730_164410/`）只有 `P1a_multi.xlsx`，缺少 `P1a_qwen.xlsx`。

```bash
cd /home/bxk/projects/interview_agent
python -m search_eval.cli \
    --resume runs/qwen_vs_multi_20260730_164410 \
    --phase 1a --schemes qwen
```

**注意事项**：
- qwen3.6-agent 是 SSE 流式接口，超时 120s/条，300 条串行跑预计 1~2 小时
- 如果遇到 Agent API 不可用或限流，检查 `VIVO_APP_ID` / `VIVO_APP_KEY` 环境变量
- `enable_thinking=True` 会导致响应较慢但答案质量更高，若耗时不可接受可改为 `False`（`callers/qwen_agent_caller.py` 第 53 行）

### 第二步：运行 LLM Judge 评分

```bash
python -m search_eval.cli \
    --resume runs/qwen_vs_multi_20260730_164410 \
    --phase 1b
```

- 已有的 multi 评分如果 `overall` 列已有值会被跳过（除非 `--force`）
- qwen 方案的新数据会被评分
- Judge 模型为 `Doubao-Seed-2.0-pro`（`judge.py` 第 24 行），单条约 2~3 秒

### 第三步：计算指标 + 生成报告

```bash
python -m search_eval.cli \
    --resume runs/qwen_vs_multi_20260730_164410 \
    --phase 2

python -m search_eval.cli \
    --resume runs/qwen_vs_multi_20260730_164410 \
    --phase 3
```

- Phase 2 生成 `P2_metrics.xlsx`（含总览/D5/D6/分场景/分行业/分复杂度 6 个 Sheet）
- Phase 3 生成 `report/` 目录（5 张 PNG 图表 + xlsx 报告 + HTML 仪表盘）
- 统计检验依赖 `scipy`（Mann-Whitney U），如未安装会跳过 p 值计算

### 第四步：人工校验 + 评审

- 打开 `report/eval_report.xlsx` 的"分歧Case"Sheet，抽查两方案 overall 差异 ≥1 的 case
- 人工判断 vs LLM Judge 评分一致率需 ≥80%
- 如一致率不达标，考虑调整 `judge.py` 的 `SCORING_PROMPT` 后 `--phase 1b --force` 重跑评分
- 与团队 review 评测结论，确认路由策略决策

---

## 六、已知问题与注意事项

### 代码与文档的差异

| 项 | 文档描述 | 实际代码 | 位置 |
|----|---------|---------|------|
| Judge 模型 | `Doubao-Seed-2.0-lite` | `Doubao-Seed-2.0-pro` | `judge.py:24` |
| 多引擎 LLM 模型 | `Doubao-Seed-2.0-lite` | `Doubao-Seed-2.0-pro` | `multi_engine_caller.py:19` |
| 并发 | 设计支持 concurrency ≤4 | 实际串行执行，`--concurrency` 参数保留但未生效 | `cli.py:82` |

### 潜在风险

1. **LLM Judge 偏差**：两方案输出风格不同（多引擎 = 结构化 + 引用标注，qwen = 自然对话），可能造成系统性评分偏差。缓解措施：低温度（0.1）+ 人工抽检
2. **qwen3.6-agent 无 references**：溯源覆盖率指标对 qwen 为 N/A，报告中需标注
3. **单轮评测约束**：qwen3.6-agent 可能返回确认卡/追问而非直接答案，Phase 1b 会将空答案标记为 overall=-1
4. **scipy 依赖**：Mann-Whitney U 检验需要 scipy，未安装时 p 值为 None，判定结论退化为"无显著差异"
5. **SSE 超时**：qwen3.6-agent 超时 120s，长 query 可能超时，建议关注超时率指标

### 历史运行记录

`runs/` 下有 8 个运行目录（20260730_154952 ~ 20260730_164410），均为 7 月 30 日下午的迭代调试产物。只有最后一个（`164410`）有完整的 Phase 2/3 产物，但仅含 multi 方案数据。建议以该目录为基础继续工作。

---

## 七、关键文件索引

| 需求 | 文件 | 行数 |
|------|------|:---:|
| 理解整体方案 | `qwen_vs_multi_对比评测整体方案.md` | 1268 |
| 理解指标定义 | `qwen_vs_multi_可复用指标详解.md` | 302 |
| 运行评测 | `cli.py` | 257 |
| 修改评分标准 | `judge.py` → `SCORING_PROMPT` | 148 |
| 修改多引擎调用 | `callers/multi_engine_caller.py` | 138 |
| 修改 qwen 调用 | `callers/qwen_agent_caller.py` | 92 |
| 修改指标计算 | `phase2_metrics.py` | 491 |
| 修改报告样式 | `phase3_report.py` | 510 |
| 运行测试 | `tests/test_full_pipeline.py` | 294 |
