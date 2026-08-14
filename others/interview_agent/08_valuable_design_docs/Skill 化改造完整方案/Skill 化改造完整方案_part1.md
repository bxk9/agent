
# 求职面试 Agent → 主 Claw Skill 化改造方案

> **版本**：v1.0  
> **状态**：草案（待与主 Claw 团队对齐后定稿）  
> **核心策略**：**单一大 skill 接入**，业务自治、协议归一  
> **预计周期**：1~1.5 个月（含联调与灰度）

---

## 目录

1. [改造目标与原则](#1-改造目标与原则)
2. [现状分析](#2-现状分析)
3. [总体架构](#3-总体架构)
4. [Skill 对外契约](#4-skill-对外契约)
5. [改造工作分解](#5-改造工作分解)
6. [关键技术点](#6-关键技术点)
7. [风险与兜底](#7-风险与兜底)
8. [里程碑与排期](#8-里程碑与排期)
9. [验收标准](#9-验收标准)
10. [附录](#10-附录)

---

## 1. 改造目标与原则

### 1.1 目标

把现在通过 A2A 协议被主 Claw 调用的独立 sub-agent，改造为**一个挂在主 Claw 下的大 skill**：

```
现状：interview_agent  ← A2A 协议 ←  BlueClaw 主网关
目标：interview_assistant skill  ← skill 协议 ←  主 Claw
```

### 1.2 核心原则

| 原则 | 含义 |
|---|---|
| **业务自治** | 内部 prompt / 工具 / 决策层 / 节奏控制全部保留，不下沉到主 Claw |
| **协议归一** | 弃用 A2A 特例，遵循主 Claw 标准 skill 协议 |
| **0 业务侵入** | 主 Claw 不学我们的业务规则，我们也不依赖主 Claw 的业务上下文 |
| **可回滚** | A2A 入口在切流验证完成前保留，出问题立即回滚 |
| **渐进式** | 协议适配 → 内部联调 → 主 Claw 联调 → 灰度切流，每步可单独验证 |

### 1.3 不做的事（明确边界）

- ❌ 不拆为 3 个独立 skill（决策层会丢失）
- ❌ 不让主 Claw LLM 学习我们的业务规则
- ❌ 不重写 `agent.py` / `tools/*` / `skills/*.md` 业务代码
- ❌ 不引入新的 LLM 依赖（继续用现有 chat model）

---

## 2. 现状分析

### 2.1 当前架构

```
┌─────────────┐    A2A jsonrpc    ┌─────────────────────────────┐
│ BlueClaw    │ ────────────────► │  InterviewAgentExecutor     │
│ 主网关      │                   │  (协议层 ~700 行)            │
└─────────────┘ ◄──────────────── └──────────────┬──────────────┘
                artifact / status                │
                                                 ▼
                                  ┌──────────────────────────────┐
                                  │  InterviewAgent              │
                                  │  (业务层，LangGraph ReAct)   │
                                  ├──────────────────────────────┤
                                  │  • system_prompt (5 类规则)  │
                                  │  • 20+ 业务工具              │
                                  │  • MemorySaver 跨轮记忆      │
                                  │  • VFS 沙箱（sid 隔离）      │
                                  └──────────────────────────────┘
```

### 2.2 主流程承载的 5 类逻辑

| # | 类型 | 改造后归宿 |
|---|---|---|
| 1 | 路由前置（域内外、NEED_MEMORY） | ✅ 保留在 skill 内部 |
| 2 | 意图识别 / 子流程路由 | ✅ 保留在 skill 内部 |
| 3 | 工具调用纪律（顺序约束、不重复） | ✅ 保留在 skill 内部 |
| 4 | 输出格式控制（拒答话术、占位符） | ✅ 保留在 skill 内部 |
| 5 | 多轮节奏控制（不剧透、跨场景引用） | ✅ 保留在 skill 内部 |

**所有逻辑都不外溢，这是方案能成立的关键。**

---

## 3. 总体架构

### 3.1 目标架构

```
┌─────────────┐  skill 协议   ┌────────────────────────────────┐
│  主 Claw    │ ────────────► │  SkillAdapter （新增 ~300 行）  │
│             │ ◄──────────── │  • 入参映射                    │
└─────────────┘  流式输出      │  • 事件映射                    │
                              │  • 收尾映射                    │
                              └──────────────┬─────────────────┘
                                             │
                          ┌──────────────────┴─────────────────┐
                          │                                    │
                          ▼                                    ▼
              ┌────────────────────┐              ┌────────────────────┐
              │ InterviewAgent     │              │ A2A Executor       │
              │ （0 改动）         │              │ （保留，备用）     │
              └────────────────────┘              └────────────────────┘
```

### 3.2 模块分层

```
app/
├── agent.py                 ← 业务层，0 改动
├── llm.py                   ← 0 改动
├── skills/                  ← 0 改动
├── tools/                   ← 0 改动
├── vfs/                     ← 0 改动
│
├── agent_executor.py        ← A2A 协议层，保留备用
│
└── skill_adapter/           ← 【新增】skill 协议层
    ├── __init__.py
    ├── executor.py          ← 主入口
    ├── input_mapper.py      ← 入参映射
    ├── event_mapper.py      ← 事件 → skill 输出
    ├── lifecycle.py         ← 收尾控制
    └── schema.py            ← 数据结构定义
```

### 3.3 关键解耦

```
agent.stream()   ← 业务内核（协议无关）
       ▲
       │
   ┌───┴───┐
   │       │
A2A 适配  skill 适配  ← 两个独立的协议层，可插拔
   │       │
   ▼       ▼
A2A 入口  skill 入口
```

---

## 4. Skill 对外契约

### 4.1 注册元信息

```yaml
name: interview_assistant
display_name: 求职面试助手
description: |
  vivo 求职面试一站式助手，覆盖简历优化、模拟面试、面试复盘、
  岗位/公司分析。基于用户的简历、JD、公司画像和历史记忆，
  提供对齐式陪跑反馈（不打分、不自造数字）。

trigger_keywords:
  - 简历 / 优化简历 / 改简历 / 投递
  - 模拟面试 / 练面试 / 出题 / 面试题
  - 复盘 / 面试录音 / 错题本
  - JD / 岗位 / 公司怎么样 / 薪资 / 求职

estimated_latency: 5~120s   # 视觉解析最长
supports_streaming: true
supports_attachments: true
supported_attachment_types: [pdf, png, jpg, jpeg, m4a, mp3, wav]
```

### 4.2 入参契约（主 Claw → Skill）

```typescript
interface SkillRequest {
  // ===== 必传 =====
  user_id: string              // 用户唯一标识，用于 VFS 隔离
  session_id: string           // 会话 id，用于跨轮记忆
  message: {
    text: string               // 用户输入
    attachments?: Array<{
      url: string              // 文件外链
      filename: string
      mime_type: string
    }>
  }
  
  // ===== 可选 =====
  history?: Array<{            // 主 Claw 提供的历史摘要
    role: 'user' | 'assistant'
    text: string
  }>
  
  context?: {
    // 主 Claw 透传的额外上下文
    channel?: string           // 来源渠道
    locale?: string            // 用户语言
  }
}
```

### 4.3 出参契约（Skill → 主 Claw）

**流式事件序列**：

```typescript
type SkillEvent =
  | { type: 'token', text: string }                   // 模型 token
  | { type: 'tool_call', id: string, name: string,    // 工具调用开始
      label: string, params: any }
  | { type: 'tool_result', id: string, ok: boolean,   // 工具调用结束
      result?: string, error?: string, latency_ms?: number }
  | { type: 'attachment', url: string, mime: string,  // 产物文件
      label: string }
  | { type: 'references', items: Array<{              // 引用来源
      title: string, url: string, snippet?: string }> }
  | { type: 'final', status: FinalStatus }            // 收尾

type FinalStatus =
  | 'completed'         // 正常完成，保持对话黏性
  | 'need_memory'       // 缺历史，请主 Claw 补 history 后重发
  | 'out_of_scope'      // 域外，主 Claw 自由路由
```

### 4.4 工具 schema 暴露

主 Claw 是否要看到我们的工具列表？两种姿态：

| 姿态 | 含义 | 推荐度 |
|---|---|---|
| 黑盒 | 主 Claw 不知道我们内部有什么工具，只看输入输出 | ⭐⭐⭐⭐ |
| 半透明 | 主 Claw 知道工具名（用于审计/计费），但不调度 | ⭐⭐⭐ |
| 透明 | 主 Claw LLM 直接调度我们的工具 | ❌ 否决，等于回到 3-skill 方案 |

**推荐黑盒姿态**。

---

## 5. 改造工作分解

### 5.1 工作量分配

```
┌──────────────────────────────────────────────────┐
│  Phase 1：协议对齐         1~2 天                 │
│  Phase 2：适配层开发       3~5 天                 │
│  Phase 3：本地联调         2~3 天                 │
│  Phase 4：主 Claw 联调     1 周（跟对方节奏）     │
│  Phase 5：切流 + 退场      1~2 周                 │
│                                                  │
│  合计：4~6 周                                    │
└──────────────────────────────────────────────────┘