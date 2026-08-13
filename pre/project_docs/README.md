# Interview Agent — 项目文档集

> 本目录是 Interview Agent（求职面试助手）后端项目的**详细项目文档集**，面向新加入的工程师、架构评审人和运维人员。
>
> 与 `docs/` 目录的关系：
> - `docs/` 存放**变更类**记录（bug 报告、方案分析、单点问题追踪、API 契约草案）。
> - `project_docs/`（本目录）存放**结构类**知识（架构、模块设计、数据流、约定）。
> - 项目根的 `ARCHITECTURE.md` 是**权威运行手册**（症状速查、开发任务），是本文档集的重要素材来源之一。

## 目录结构

文档按主题分类归档到 5 个子目录：

```
project_docs/
├── README.md                       ← 本文件（文档集入口）
│
├── 01_getting_started/             入门与总览
│   ├── 00_INDEX.md                 全文档导航与阅读路径
│   └── 01_overview.md              项目定位 / 能力 / 技术栈 / 目录树
│
├── 02_architecture/                架构与设计理念
│   ├── 02_architecture.md          分层 / 请求生命周期 / 事件模型
│   └── 03_design_philosophy.md     10 条核心设计原则
│
├── 03_modules/                     单模块文档（六段式）
│   ├── 10_module_claw_protocol.md  Claw 协议层
│   ├── 11_module_llm.md            LLM 工厂
│   ├── 12_module_agent_core.md     Agent 核心（LangGraph）
│   ├── 13_module_skills.md         Skill Markdown 系统
│   ├── 14_module_tools.md          工具集（30+）
│   ├── 15_module_vfs.md            VFS 抽象
│   ├── 16_module_memory.md         持久化存储
│   ├── 17_module_voice.md          语音面试
│   ├── 18_module_resume_pipeline.md 简历上游解析（离线）
│   ├── 19_module_messages.md       FlatBuffers 消息协议
│   └── 20_module_resume_templates.md HTML 模板体系
│
├── 04_data_flows/                  跨模块数据流
│   ├── 30_data_flow_resume.md      简历生成 10 步
│   ├── 31_data_flow_voice.md       语音面试链路
│   └── 32_data_flow_ai_marks.md    AI 标记生命周期
│
├── 05_references/                  约定与调试参考
│   ├── 40_key_conventions.md       ID/路径/schema/环境变量
│   └── 50_debugging_guide.md       症状速查表
│
├── 06_workload_showcase/           个人工作量展示（yitong / 本人）
│   ├── README.md                    入口 + 关键数字
│   ├── 00_workload_overview.md      总览：数字/热力/责任地图
│   ├── 01_voice_interview_module.md 语音面试端到端攻坚
│   ├── 02_mock_interview_prompt_engineering.md Prompt 工程演进
│   ├── 03_error_book_system.md      错题本系统建设
│   ├── 04_llm_latency_optimization.md LLM 耗时优化实战
│   ├── 05_agent_executor_refactor.md Agent 执行层重构
│   ├── 06_observability_and_telemetry.md 埋点与可观测性
│   ├── 07_bugfix_battle.md          Bug 战役集
│   ├── 08_skill_system_iteration.md Skill 体系迭代
│   ├── 09_reliability_fallback.md   稳健性与兜底
│   └── 10_commit_timeline.md        提交时间线
│
└── 07_team_workload/               团队工作量画像（其他 6 位主要贡献者）
    ├── README.md                    团队分布 / 责任地图 / 取数口径
    ├── 01_11099826_resume_core.md   简历生成与渲染核心 (#1, 366 提交)
    ├── 02_siqi_agent_infra.md       Agent 执行层与基础设施 (252 提交)
    ├── 03_chenqian_review.md        面试复盘与 ASR (79 提交)
    ├── 04_11197109_vlm.md           VLM 视觉与头像提取 (26 提交)
    ├── 05_chenni_voice_prompt.md    语音面试 Prompt 与出题策略 (11 提交)
    ├── 06_zhangmengyu_voice_infra.md 语音面试环境与安全合规 (9 提交)
    └── 07_ownership_matrix.md        团队协作矩阵（git blame 行级 Ownership）
```

## 快速导航

**新人入门**：`01_getting_started/01_overview.md` → `02_architecture/02_architecture.md` → `02_architecture/03_design_philosophy.md`

**按角色速通**：见 [`01_getting_started/00_INDEX.md`](./01_getting_started/00_INDEX.md)

**日常查阅**：
- 改代码前 → [`05_references/40_key_conventions.md`](./05_references/40_key_conventions.md)
- 排查 bug → [`05_references/50_debugging_guide.md`](./05_references/50_debugging_guide.md)
- 找模块细节 → [`03_modules/`](./03_modules/)

**评审 / 汇报 / 展示工作量**：
- 个人工作量（yitong）：见 [`06_workload_showcase/`](./06_workload_showcase/)（基于 Git 数据与设计文档，量化 + 定性还原个人贡献）
- 团队工作量画像：见 [`07_team_workload/`](./07_team_workload/)（覆盖另 6 位主要贡献者，同样基于 Git 客观数据）

## 版本

- 生成时间：项目当前主线（对应 `ARCHITECTURE.md` v3+）
- 维护策略：结构层（模块拆分/关键约定）变更时同步更新本目录；小 bug 修复走 `docs/bug_reports/`。