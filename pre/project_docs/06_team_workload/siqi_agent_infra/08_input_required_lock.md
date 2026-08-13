# 08 · INPUT_REQUIRED 任务锁与 task_store 治理

## 一句话概括

司棋在 06-23 引入的 **INPUT_REQUIRED 任务锁机制**——解决了 Agent 需要用户补充信息时"并发消息互相打断"的核心问题，是 task_store 治理的关键里程碑。

---

## 背景

### 问题场景

Agent 在执行过程中经常需要询问用户（例如："请上传您的简历"），此时：
- 用户如果连发两条消息，会创建两个 task
- 两个 task 同时改一份 state，state 撕裂
- 用户以为发了新消息，实际系统还在等前一条的输入

### 需要的语义

- 一个 session 在等待用户输入时，**锁住**该 session
- 后续消息作为"对该锁的应答"，而不是新任务
- 应答后释放锁，继续原任务

---

## 时间线

| 日期 | Commit |
|:---:|:---|
| 06-23 | **feat(agent): INPUT_REQUIRED 状态下 task 加锁，防止并发消息撕裂状态** |
| 06-23 | fix(task_store): 释放锁的时序修复 |
| 06-24 | refactor(context): namespace 单一真理源（配套 task_store 治理） |
| 06-25 | feat(user): 用户中心化 Phase 1（用户身份下沉，task_store 按用户隔离） |

---

## 方案

### 锁的核心逻辑

```
新消息到达
  ↓
查询 session 是否处于 INPUT_REQUIRED
  ├─ 是 → 作为 continuation，注入到原 task
  │       完成后释放锁
  └─ 否 → 创建新 task
```

### 关键设计点

1. **锁 = state 位**：`state = INPUT_REQUIRED` 本身就是锁标记，无需额外锁字段
2. **注入路径**：新消息通过 `task.update_with_user_input()` 而非 `task.new()`
3. **释放时机**：LLM 响应完成或超时（超时也释放，防死锁）
4. **粒度**：session 级（不是 user 级，允许同一用户多会话并发）

---

## 配套治理

### namespace 单一真理源（06-24）

在锁修复的次日，司棋做了 namespace 治理：
- 之前 task_store / vfs / ctx 各自有 namespace 概念
- 统一为一处产生、多处消费

### 用户中心化 Phase 1（06-25）

- task_store 按 user_id 分区
- 一个用户看不到另一个用户的 task（安全）
- session_id 全局唯一但 user_id 是主 partition key

---

## 量化成果

| 指标 | 改造前 | 改造后 |
|:---|:---|:---|
| 并发消息 state 撕裂 | 偶发 | 0 |
| 用户"连发两条被吞"的报障 | 每周多起 | 0 |
| task_store 数据模型清晰度 | 各处不一致 | 单一真理源 |

---

## 与团队协作

- **yitong**：session 侧对接（前端如何展示锁状态、如何提示用户"正在等待你补充"）
- **11099826**：简历上传流程直接受益（Agent 询问缺失字段时可靠等待）
- **陈乾**：面试复盘 Agent 也复用该锁机制

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="司棋" --grep="INPUT_REQUIRED\|task_store\|namespace" --pretty=format:"%ad|%s" --date=short
```
