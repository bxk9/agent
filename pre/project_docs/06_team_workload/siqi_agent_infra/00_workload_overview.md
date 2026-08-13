# 00 · 工作量总览

## 一句话概括

**司棋是 Interview Agent 项目的"基础设施 Owner"**——独立承担 Agent Executor、VFS 云空间、文档 Agent A2A 桥接、LLM 网关迁移、可观测性、上下文与 token 治理等所有"跑起来"层面的工程。65 天 252 提交，代码删占比 52.8%（全项目最高），是**持续重构而非堆积**的典型工程师。

---

## 核心数据卡片

| 维度 | 数值 | 说明 |
|:---|---:|:---|
| 总提交数 | 252 | 全项目 #3 |
| 时间跨度 | 65 天 | 06-04（**最早**）→ 08-07 |
| 代码增量 | +43,045 | #2 |
| 代码删量 | −22,747 | **删占比 52.8%（全项目最高）** |
| 涉及文件 | 697 | #2 |

---

## 责任地图

```
Interview Agent 基础设施
    │
    ├── [执行层] agent_executor.py (47 次) ← 司棋 blame 29%（共享）
    │            agent.py (10 次)
    │
    ├── [协议层] claw_protocol/ ← Owner
    │     ├── server.py (9 次)
    │     ├── jsonrpc.py (8 次)
    │     ├── task_updater.py (5 次)
    │     └── task_store.py (3 次)
    │
    ├── [存储层] vfs/ ← Owner，blame 56%（client.py）
    │     ├── client.py (22 次)
    │     ├── tools.py (15 次)
    │     ├── namespace.py (4 次)
    │     ├── uri.py / file_id.py / __init__.py
    │     └── memory 迁移：resume_index / review_report_index
    │
    ├── [Doc Agent A2A] doc_agent_* ← Owner，blame 90%（doc_agent_tool.py）
    │     ├── doc_agent_tool.py (31 次)
    │     └── doc_agent_client.py (18 次)
    │
    ├── [LLM 网关] llm/ ← Owner
    │     ├── blueclaw_chat.py (10 次)
    │     └── vivo_chat.py (8 次)
    │
    ├── [Skill 层] skills/ ← Contributor
    │     ├── _system_prompt.md (18 次, blame 74%)
    │     └── _loader.py (9 次)
    │
    ├── [入口] main.py (20 次) ← Owner
    │
    └── [部署] Dockerfile (17 次) ← Owner
```

---

## 阶段划分（7 个阶段）

| # | 阶段 | 时间 | 关键词 | 提交量级 |
|:---:|:---|:---:|:---|:---:|
| P1 | 项目奠基 | 06-04 → 06-10 | web demo / Dockerfile / agent 主流程 / skills 动态加载 | ~40 |
| P2 | VFS 建立 | 06-11 → 06-15 | BlueClaw VFS 接入 / 全工具异步 / a2a payload 日志 | ~30 |
| P3 | 语音合入 & VFS 稳定 | 06-15 → 06-17 | 语音深度对话 merge / 前端展示 / 短链签发 | ~30 |
| P4 | INPUT_REQUIRED & namespace | 06-23 → 06-30 | task 锁 / namespace 常量 / 用户中心化存储 | ~20 |
| P5 | Doc Agent 接入 | 07-14 → 07-17 | 文档 Agent 工具 / VFS 头统一 / LLM 网关迁移 | ~50 |
| P6 | A2A 攻坚 | 07-20 → 07-27 | doc_agent 六连修 / A2A 静默超时三 bug | ~35 |
| P7 | 可观测性 & 收尾 | 07-28 → 08-07 | ctx_log 补全 / token 汇总 / 上下文裁剪 / user_id 补漏 | ~40 |

---

## 能力标签

| 标签 | 证据 |
|:---|:---|
| **基础设施 Owner** | Agent Executor / VFS / Doc Agent / LLM 网关四大主控 |
| **重构驱动型** | 删占比 52.8%，全项目最高 |
| **协议设计** | Claw 协议、A2A JSON-RPC 深度改造 |
| **单日攻坚能力** | 07-21 一天修 6 个 doc_agent bug |
| **跨版本迁移能力** | 玄机 → BlueClaw 网关迁移 |
| **可观测性方法论** | ctx_log / user_id / trace_id 全链路 |
| **早期奠基** | 全项目最早入场（06-04） |

---

## 与他人的协作关系

| 对象 | 接触点 | 关系 |
|:---|:---|:---|
| **11099826** | agent_executor / VFS 客户端 / resume_parser | 基础设施 → 业务方 |
| **yitong** | agent_executor / _system_prompt / 上下文 & token | 联合作者，方法论互补 |
| **陈乾** | executor 音频 URL / VFS 短链 | 基础设施支撑 |
| **11197109** | VFS 视觉产物落地 / vivo_chat | 基础设施支撑 |

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立总览 |
