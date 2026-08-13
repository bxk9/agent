# 工作量展示文档集 (Workload Showcase)

> 本目录用于**量化 + 定性**地展示我在 `interview_agent` 项目中承担的工作。
> 素材来源：Git 提交历史（2026-06-04 → 2026-08-10）、`docs/design/`、`docs/fix/`、`docs/bug_reports/` 中的设计与复盘文档、以及现网代码。
> 参考风格：`docs/design/20260729_LLM思考耗时优化_实测验证与补充方案.md`（数据 + 时间线 + 方案 + 版本历史）。

---

## 📊 一句话结论

在 **68 个自然日**（2026-06-04 → 2026-08-10）内，我以主力身份贡献了 **239 次提交** / **+25,575 / -8,381** 行代码，覆盖 **532 个文件**，主导交付 **语音模拟面试链路 / Mock Interview Prompt 体系 / 错题本系统 / Agent 执行层重构 / LLM 耗时优化 / 埋点可观测性** 六大方向。

---

## 📁 文档索引

| # | 文档 | 主题 | 核心成果 |
|---|------|------|---------|
| 00 | [`00_workload_overview.md`](./00_workload_overview.md) | 工作量总览 | 关键数字、贡献热力、时间线、责任地图 |
| 01 | [`01_voice_interview_module.md`](./01_voice_interview_module.md) | 语音面试模块攻坚 | `/ws/interview` 建链、context 装配、vivo 桥接、错题本自动入册 |
| 02 | [`02_mock_interview_prompt_engineering.md`](./02_mock_interview_prompt_engineering.md) | Prompt 工程演进 | `mock_interview_voice.md` 56 次迭代、话术策略 12 条硬约束 |
| 03 | [`03_error_book_system.md`](./03_error_book_system.md) | 错题本系统 | LLM Judge 自动入册、批量删恢、session 维度检索 |
| 04 | [`04_llm_latency_optimization.md`](./04_llm_latency_optimization.md) | LLM 耗时优化实战 | 154.5s → 79s 的迭代过程、Schema 约束、并行化 |
| 05 | [`05_agent_executor_refactor.md`](./05_agent_executor_refactor.md) | Agent 执行层重构 | `agent_executor.py` 45 次改动、事件流规范化 |
| 06 | [`06_observability_and_telemetry.md`](./06_observability_and_telemetry.md) | 埋点与可观测性 | usage_tokens 上报、`ctx_log` 上下文日志、deeplink 参数化 |
| 07 | [`07_bugfix_battle.md`](./07_bugfix_battle.md) | Bug 战役集 | 26 篇 fix 报告、三层防御架构、根因复盘 |
| 08 | [`08_skill_system_iteration.md`](./08_skill_system_iteration.md) | Skill 体系迭代 | `_system_prompt.md` 33 改、Skill 加载器演进 |
| 09 | [`09_reliability_fallback.md`](./09_reliability_fallback.md) | 稳健性与兜底 | FALLBACK 兜底、重试机制、空 choices 防御 |
| 10 | [`10_commit_timeline.md`](./10_commit_timeline.md) | 提交时间线 | 按周展开的完整节奏图 |

---

## 🎯 如何阅读本目录

- **面向评审 / 汇报**：从 `00_workload_overview.md` 开始，能在 5 分钟内看到我全部产出的骨架。
- **面向技术深度评估**：优先读 `01`（模块攻坚）、`04`（性能优化）、`07`（Bug 战役）。
- **面向执行力评估**：读 `02`、`10`，可看到日均提交节奏与话术迭代密度。

---

## 🧾 数据取数口径

| 指标 | 取数命令 | 数值 |
|------|---------|------|
| 总提交数（全仓） | `git rev-list --count HEAD` | **993** |
| 本人提交数（yitong） | `git log --author=yitong --oneline \| wc -l` | **239** |
| 时间跨度 | 首次 → 最近 | 2026-06-04 → 2026-08-10（68 天） |
| 代码净增 | `git log --author=yitong --shortstat` | **+25,575 / -8,381**（净 +17,194 行） |
| 涉及文件 | 同上 | **532** 个 |
| 全仓 Python LOC | `find app -name "*.py" \| xargs wc -l` | **47,048** |
| 设计文档产出（全仓） | `ls docs/design \| wc -l` | **58** 篇 |
| 修复报告（全仓） | `ls docs/fix \| wc -l` | **26** 篇 |

> 注：数据抓取时间 2026-08-10 10:20，抓取脚本见 `10_commit_timeline.md`。
