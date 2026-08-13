# 10 · INPUT_REQUIRED 任务锁：Agent 有状态交互的并发治理

> **作者**：司棋 · **场景**：Agent 需要向用户追问补充信息时的并发/状态治理

---

## 一句话摘要

面对 Agent "边工作边追问"场景下的**并发消息状态撕裂**问题，我以 `INPUT_REQUIRED` 状态位作为**隐式互斥锁**，配合 `task_store` 按 user_id 分区，做到"用户连发消息不打断进行中的任务"、"用户跨会话看不见他人的 task"。

---

## 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"Agent 有状态怎么设计？"** | INPUT_REQUIRED 状态位 + task_store 双支柱 |
| **"并发怎么控？"** | 隐式锁（state 位）vs 显式锁 的取舍 |
| **"用户请求的幂等性"** | 追问场景下"新消息 = 应答"而非"新任务" |
| **"多租户 task_store 怎么设计？"** | user_id 主分区、session 二级、防越权 |

**可回答的经典面试题**：
- Agent 的状态机怎么设计？
- 并发写共享状态如何避免撕裂？
- Task queue 与 state store 的关系
- 幂等性设计

---

## 背景与问题定义

### Agent 的追问场景

真实场景：
```
用户："帮我生成简历"
Agent："请上传简历原稿"  ← 【等待用户补充】
用户：（等待中）...
```

此时用户可能：
- **正常应答**：上传附件 → Agent 应继续原任务
- **连发消息**：又说了句"要中文版"→ 系统怎么处理？
- **换话题**：说"改天再弄，先做别的"→ 又怎么处理？

### 天真实现的问题

**方案 A：来一条消息 = 新 task**

- 后果：两个 task 同时改一份 state → **state 撕裂**
- 用户：以为发了新消息，实际系统还在等第一条的输入

**方案 B：用户等待中的消息全部拒绝**

- 后果：用户体验极差、追问的语义损失

---

## 方案：INPUT_REQUIRED 隐式锁

### 核心设计

**用状态位 `INPUT_REQUIRED` 本身作为锁标记，无需额外锁字段**：

```
新消息到达
      ↓
查询 session 是否处于 INPUT_REQUIRED
      ↓
   ┌──┴──┐
   是      否
   │       │
   ↓       ↓
作为    创建
应答    新 task
注入
原 task
   ↓
完成后
释放锁
（state 变化）
```

### 关键决策 1：为什么用 state 位而不是显式锁

- **显式锁**（Redis Lock / Mutex）：多一层组件、要处理"锁泄露"、要有超时保护
- **state 位**：state 本身就有生命周期（任务结束时清零）、锁泄露 = state 卡住（可观测）、无需额外基础设施

**取舍**：本场景状态机简单（一个用户会话一次只做一件事），state 位足够。

### 关键决策 2：粒度是 session 不是 user

- session 级：允许同一用户开多个会话并发做不同事（例如一个改简历、另一个做面试）
- user 级：粒度太粗，用户体验差

### 关键决策 3：超时也释放锁（防死锁）

**问题**：Agent 卡在思考中 → INPUT_REQUIRED 永不释放 → 用户永远无法开新任务

**修复**：
- LLM 响应完成 → 释放
- LLM 超时 → 强制释放
- 用户长时间无输入 → 定期检查

---

## 配套治理

### namespace 单一真理源（06-24）

- task_store / VFS / ctx_log 三个地方原本各自定义 namespace
- 统一为**一处产生、多处消费**
- INPUT_REQUIRED 检查需要 namespace 一致才能正确定位 task

### task_store 按 user_id 分区（06-25）

- 一个用户看不到另一个用户的 task（安全）
- session_id 全局唯一但 user_id 是主 partition key
- 支持跨会话查询（同用户可看见自己的历史 task）

### tenant 固定值 → 跨会话记忆（06-30）

- 之前 tenant 按 session 变化
- 修复后同一用户跨 session 可以引用"我的错题本"、"我的简历"
- 前提：user_id 主分区落地

---

## 算法/工程实现细节

### 消息路由伪代码

```python
async def handle_user_message(user_id, session_id, message):
    task = task_store.get_active(user_id, session_id)
    if task and task.state == "INPUT_REQUIRED":
        # 作为应答注入原 task
        await task.update_with_user_input(message)
        # LLM 响应完成 → 释放锁（state 变化）
    else:
        # 创建新 task
        task = task_store.new(user_id, session_id)
        await task.execute(message)
```

### 状态机

```
IDLE ──[user message]──▶ RUNNING
RUNNING ──[需要用户补充]──▶ INPUT_REQUIRED
INPUT_REQUIRED ──[用户输入]──▶ RUNNING
INPUT_REQUIRED ──[超时/取消]──▶ IDLE
RUNNING ──[完成]──▶ IDLE
```

### 多租户查询

```sql
-- 只有本人能看到
SELECT * FROM task_store
WHERE user_id = :current_user_id
  AND session_id = :session_id
  AND state = 'INPUT_REQUIRED';
```

---

## 量化验证与效果

| 指标 | 治理前 | 治理后 |
|:---|:---|:---|
| 并发消息 state 撕裂 | 偶发 | **0** |
| "连发两条被吞" 报障 | 每周多起 | **0** |
| task_store 数据模型清晰度 | 各处不一致 | **单一真理源** |
| 跨会话记忆能力 | 无 | **可用** |
| 多租户越权 | 有风险 | **主分区隔离** |

---

## 方法论抽象与迁移

### "隐式锁"设计的三个前提

1. **状态机简单**：单一 owner、状态迁移清晰
2. **释放路径完整**：所有可能路径都要释放（正常/超时/取消/异常）
3. **可观测**：卡在某个状态 → 日志能看到、监控能告警

### 更广义的启发

**任何有状态交互都要问三个问题**：
1. **谁有权限修改这个状态**？（并发写来源）
2. **状态卡住怎么办**？（死锁与恢复）
3. **状态需要跨越多长时间**？（生命周期）

### 可迁移场景

| 场景 | 迁移点 |
|:---|:---|
| **对话式 AI 的多轮追问** | 同架构 |
| **表单填写系统** | "上一步未完成不能进下一步" |
| **审批流** | state 位作为锁 |
| **游戏回合制** | 玩家 turn 作为隐式锁 |

### 反例警示

- **反例 1**：显式锁但不设超时 → 死锁
- **反例 2**：user 级锁 → 用户开多会话被误伤
- **反例 3**：没有单一真理源 → namespace 三处不一致 → 锁定位失败

---

## 关联提交

| 日期 | Commit |
|:---:|:---|
| 06-23 | feat(agent): INPUT_REQUIRED 状态下 task 加锁 |
| 06-23 | fix(task_store): 释放锁的时序修复 |
| 06-24 | refactor(context): namespace 单一真理源 |
| 06-25 | feat(user): 用户中心化 Phase 1 |
| 06-30 | feat: tenant 固定值实现跨会话记忆 |

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |
