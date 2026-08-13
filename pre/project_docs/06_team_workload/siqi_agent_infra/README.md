# 司棋（李司棋）· Agent 执行层与基础设施 · 工作量展示文档集

> **本目录定位**：为 **司棋** 建立一份规格对齐 [`06_workload_showcase/`](../../06_workload_showcase/) 的完整工作量展示文档集。所有数据以 `git log` / `git blame` 为唯一事实源。

---

## 关键数字（截至 2026-08-10）

| 指标 | 数值 | 说明 |
|:---|---:|:---|
| 总提交数 | **252** | 全项目 #3 |
| 时间跨度 | 2026-06-04 → 2026-08-07（65 天） | 最早入场（早于 11099826 一天） |
| 代码增量 | +43,045 | #2 |
| 代码删量 | −22,747（占比 **52.8%**） | **全项目最高**，反映强重构风格 |
| 涉及文件 | 697 | #2 |
| 独占文件（blame ≥ 90%） | `doc_agent_tool.py` 90.2%、`review_report_tool.py`（司棋主导之外司棋无参与） | — |
| Owner 文件 | `agent_executor.py` / VFS 全链 / doc_agent 全链 / BlueClaw 网关 | — |

### 按周提交热力

```
W23 ████████████ 12（06-02~06-08，项目奠基）
W24 ██████████████████████████████████████████████████ 50（06-09~06-15）
W25 ████████████████████████████████ 32（06-16~06-22）
W26 ████████████████████████ 24（06-23~06-29）
W27 █████████ 9
W28 ███████████████████ 19（07-07~07-13，Doc Agent 接入）
W29 ██████████████████████████████████████████████████ 51（07-14~07-20）
W30 ██████████████████ 18（07-21~07-27，A2A 修复）
W31 ██████████████████████ 22（07-28~08-03，可观测性）
W32 ███████████████ 15（08-04~08-10，收尾）
```

**信号**：W24（首周）50 提交 + W29（Doc Agent 接入完成）51 提交，是两个建设高峰。

---

## 文档索引（10 篇）

| # | 文档 | 主题 |
|:---:|:---|:---|
| 00 | [`00_workload_overview.md`](./00_workload_overview.md) | 总览：责任地图 / 阶段划分 / 能力标签 |
| 01 | [`01_agent_executor.md`](./01_agent_executor.md) | Agent Executor 主链（47 次改动） |
| 02 | [`02_vfs_system.md`](./02_vfs_system.md) | VFS 云空间：三头统一 / 产物转存 / user 中心化 |
| 03 | [`03_doc_agent_a2a.md`](./03_doc_agent_a2a.md) | 文档 Agent A2A 协议桥接 |
| 04 | [`04_llm_gateway_migration.md`](./04_llm_gateway_migration.md) | LLM 网关迁移：玄机 → BlueClaw |
| 05 | [`05_doc_agent_six_fixes.md`](./05_doc_agent_six_fixes.md) | 07-21 doc_agent 六连修单日攻坚 |
| 06 | [`06_context_truncation_and_token.md`](./06_context_truncation_and_token.md) | 上下文裁剪 + token 观测 |
| 07 | [`07_observability_ctx_log.md`](./07_observability_ctx_log.md) | 可观测性建设：ctx_log 与全链路日志 |
| 08 | [`08_input_required_lock.md`](./08_input_required_lock.md) | INPUT_REQUIRED 锁与 task_store 治理 |
| 09 | [`09_commit_timeline.md`](./09_commit_timeline.md) | 完整时间线（W23-W32） |

---

## 每篇文档统一结构（六段式）

对齐 `docs/design/20260729_...` 风格。

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立司棋工作量展示文档集 |
