# 工作量总览

> 时间窗口：2026-06-04 → 2026-08-10（68 天，含周末）
> 数据口径：`git log --author=yitong`
> 版本：v1.0

---

## 一、关键数字（Executive Summary）

| 维度 | 数值 | 备注 |
|------|------|------|
| **提交数** | **239** | 占全仓 993 提交的 24.1%，个人排名第 2 |
| **代码增删** | **+25,575 / -8,381** | 净增 17,194 行；日均净增 253 行 |
| **涉及文件** | **532** | 覆盖 `app/`、`memory/`、`web/`、`docs/` |
| **提交日** | 约 47 个 | 有效工作日密度 ~69% |
| **月度分布** | 06 月 26 / 07 月 179 / 08 月 34 | 7 月为攻坚高峰月 |
| **高频文件 Top 3** | `mock_interview_word.md` (67) / `mock_interview_voice.md` (56) / `main.py` (47) | Prompt + 主入口 |
| **产出设计文档** | 全仓 58 篇设计 + 26 篇修复 + 8 篇 bug 复盘 | 参与撰写与评审的占多数 |

---

## 二、月度提交热力

```
2026-06 (26)  ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  预研 + 语音链路搭建
2026-07 (179) ██████████████████████████████████████████████████ 攻坚高峰：Prompt + 错题本 + Voice
2026-08 ( 34) ██████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  收敛 + 稳定性 + 埋点
```

7 月单月 179 次提交 ≈ **每天 5.8 次**，处于典型的 Feature Freeze 前冲刺节奏。

---

## 三、贡献主线（六大方向）

```
                                yitong 239 commits
                                       │
        ┌──────────────┬───────────────┼───────────────┬──────────────┐
        │              │               │               │              │
   语音面试(01)   Prompt工程(02)   错题本(03)    Agent执行层(05)  埋点/deeplink(06)
     ~85 次         ~60 次          ~25 次          ~40 次          ~20 次
        │              │               │               │              │
   • WS 建链       • voice.md 56  • LLM Judge     • agent_executor  • usage_tokens
   • context 装配    改动          自动入册         45 次改动        埋点
   • FALLBACK 兜底 • word.md 67   • session 双   • 事件流规范化    • deeplink 三代
   • vivo 桥接       改动          维度检索      • main.py 47 改   • ctx_log 上下文
```

*上述次数为语义分类估算，同一次提交可能落入多个方向。*

---

## 四、责任地图（我主导 vs 我参与）

### 4.1 我主导的模块（Owner）

| 模块 | 关键文件 | 我修改次数 | 说明 |
|------|---------|-----------|------|
| **语音模拟面试** | `app/voice/*` | interview_ws 12、context_builder 13、interview_prompts 13 | 全链路建设与优化 |
| **Mock Interview Prompt** | `app/skills/mock_interview_voice.md`、`mock_interview_word.md` | 56 + 67 = **123** | 全部话术策略由我制定与迭代 |
| **错题本系统** | `app/tools/error_book.py`、`memory/error_book_index.py`、`app/tools/voice_error_book_judge.py` | 23 + 11 + 12 | LLM Judge 自动入册 + 批量增删 |
| **Skill 系统入口** | `app/skills/_system_prompt.md`、`app/skills/_loader.py` | 33 + 14 | 系统级提示词与技能加载器 |

### 4.2 我深度参与的模块（Contributor）

| 模块 | 我修改次数 | 主要贡献 |
|------|-----------|---------|
| `app/main.py` | 47 | WebSocket 事件流、字段兼容、埋点 |
| `app/agent_executor.py` | 45 | 事件规范化、上下文注入、异常兜底 |
| `app/agent.py` | 8 | 模型工厂对接、recursion_limit 调整 |
| `app/tools/__init__.py` | 12 | 工具注册总线维护 |

---

## 五、时间线（按周精粹）

| 周次 | 里程碑 | 代表提交 |
|------|--------|---------|
| W1 (06-04 ~ 06-08) | 项目预研、agent 骨架 | 初始化 |
| W2-W4 (06 中下旬) | 简历链路 + Skill 化改造 | 26 次预研提交 |
| W5 (07-14 ~ 07-19) | **语音链路 Day 1**：主 Agent session 透传、context 双维查询 | `feat(voice-session): 主 Agent session_id 透传` |
| W6 (07-20 ~ 07-26) | **语音上下文预加载重构** + FALLBACK 兜底 | `refactor(voice-session): 预加载链路重构`、`voice: 单一 prompt 源 + 流式 LLM + FALLBACK` |
| W7 (07-27 ~ 08-02) | Prompt 12 条核心策略成型、埋点上报、错题本 session 化 | `1. 语音面试点评策略调整...`（12 条硬约束单提交） |
| W8 (08-03 ~ 08-09) | 稳定性收尾：话术拆分、批量删恢、上下文裁剪、重试机制 | `强化错题本的调用和追问只问一题`、`语音错题本识别增加重试机制` |
| W9 (08-10) | 出题策略默认深度追问 | `出题策略默认改为深度追问`（最新提交） |

---

## 六、能力标签自评

| 能力 | 证据 |
|------|------|
| **系统设计** | 完整设计并落地语音模拟面试全链路，`docs/design/` 中至少 5 篇为主导设计 |
| **Prompt 工程** | 单文件 `mock_interview_voice.md` 迭代 56 次，形成 12 条可复用硬约束 |
| **性能优化** | 主导 LLM 耗时优化方案 v1→v7，见 `docs/design/20260729_LLM思考耗时优化_实测验证与补充方案.md` |
| **可观测性** | 引入 `ctx_log`、按 session 检索、usage_tokens 全链路埋点 |
| **稳定性** | 5 次 `fix usage-tokens bug` 迭代、FALLBACK 兜底、错题本重试机制、批量增删规避 limit 限制 |
| **协作与文档** | 84+ 篇技术文档，单次提交承载 12 条产品策略（见 07-30 提交） |

---

## 七、后续文档导航

- 想看**做了哪些具体事情**：`10_commit_timeline.md`
- 想看**单模块技术深度**：`01_voice_interview_module.md`、`03_error_book_system.md`
- 想看**性能与稳定性攻坚**：`04_llm_latency_optimization.md`、`07_bugfix_battle.md`、`09_reliability_fallback.md`

---

## 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|---------|
| v1.0 | 2026-08-10 | 初版，基于 git 数据抓取与手工分类汇总 |
