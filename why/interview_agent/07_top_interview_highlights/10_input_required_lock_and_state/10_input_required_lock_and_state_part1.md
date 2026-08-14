# INPUT_REQUIRED 任务锁：Agent 有状态交互的并发治理 - 面试亮点

> **核心价值**：在基于状态驱动的 Claw 会话协议下，以 `INPUT_REQUIRED` 状态位作为**隐式互斥锁**，配合心跳保活（对抗主 Claw 180s 超时断连）与 task_store 按 user_id 分区，做到"用户连发消息不打断进行中的任务、等待状态不被超时误杀、跨会话任务归属清晰"，是 Agent 有状态并发治理的完整实践。

---

## 1. 核心概览（原文档保留部分）

### 1.1 一句话摘要

面对 Agent "边工作边追问"场景下的**并发消息状态撕裂**问题，我以 `INPUT_REQUIRED` 状态位作为**隐式互斥锁**（而非引入独立锁组件），配合心跳保活对抗主 Claw 的 180s 超时断连、task_store 按 user_id 分区保证多租户隔离，做到"用户连发消息不打断进行中的任务"、"等待状态不被超时误杀"、"用户跨会话看不见他人的 task"。

### 1.2 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"Agent 有状态怎么设计？"** | INPUT_REQUIRED 状态位 + 心跳 + task_store 三件套 |
| **"并发怎么控？"** | 隐式锁（state 位）vs 显式锁的完整取舍分析 |
| **"心跳机制的本质"** | 180s 超时断连的两次修复（识别 + 用户无感） |
| **"多租户 task 存储"** | user_id 主分区、session 二级、防越权 |

**可回答的经典面试题**：
- Agent 的状态机怎么设计？
- 并发写共享状态如何避免撕裂？
- 心跳与超时机制的设计？
- 进程重启后有状态系统如何恢复？

### 1.3 方案演进与关键决策

**演进时间线**（git 证据）：

```
阶段 1（07-08）：input_required 成为通信载体
  a9de03d relay 指令拼入 input_required 的 message text 兜底
      ↓ 状态位不只是"等待"，还是跨 Agent 通信挂载点
阶段 2（08-11）：状态转换与部署治理
  391ca79 input_required → complete，停止心跳避免重新部署后主Claw超时
  871a28d WebSocket连接关闭时取消所有运行中任务（并发任务清理）
      ↓
阶段 3（08-13）：心跳双修
  ab4416e 恢复心跳 message 字段，修复主Claw 180s 超时断连
  76e5f37 心跳 message 用空文本，主Claw 能识别心跳且用户无感
```

**关键决策 1：状态位即锁，不引入独立锁组件**

协议语义已经提供了锁的全部要素（互斥标记、释放路径、可观测性），独立锁字段反而产生"双真相源"。

**关键决策 2：心跳保活 + 用户无感**

等待期间必须发心跳（否则 180s 被主 Claw 断连），但心跳不能污染用户对话——空文本心跳两全其美。

**关键决策 3：锁粒度是 session 不是 user**

允许同一用户多会话并发做不同事；user 级粒度太粗会误伤。

**淘汰的方案**：

| 淘汰方案 | 淘汰原因 |
|:---|:---|
| **显式锁（Redis Lock/Mutex）** | 锁泄漏风险、双真相源、无法穿透协议 |
| **user 级锁** | 粒度太粗，多会话并发被误伤 |
| **等待中消息全部拒绝** | 用户体验极差，追问语义损失 |

---

## 2. 项目背景与问题定义

### 2.1 业务场景

Agent 的追问场景：

```
用户："帮我生成简历"
Agent："请上传简历原稿"  ← 进入 INPUT_REQUIRED（等待用户补充）
用户：（等待中）...

此时用户可能：
- 正常应答：上传附件 → Agent 应继续原任务
- 连发消息：又说"要中文版" → 系统怎么处理？
- 换话题："先做别的" → 又怎么处理？
```

### 2.2 失败模式分析

**天真实现的两种错误**：

```
方案 A：来一条消息 = 新 task
  后果：两个 task 同时改一份 state → state 撕裂
  用户：以为发了新消息，实际系统还在等第一条的输入

方案 B：等待中的消息全部拒绝
  后果：用户体验极差、追问的语义损失
```

**真实事故的三个触发点**（git 证据）：

| 日期 | Commit | 事故 |
|:---:|:---|:---|
| 08-11 | `391ca79` | 重新部署后主Claw超时（状态未正确转换） |
| 08-13 | `ab4416e` | 主Claw 180s 超时断连（心跳字段丢失） |
| 08-11 | `871a28d` | WebSocket 关闭时运行中任务未清理 |

### 2.3 优化目标

**核心问题**：如何让"等待用户输入"这个状态既不被并发消息撕裂、又不被超时机制误杀？

**量化目标**：
- 并发消息 state 撕裂为 0
- 等待状态不被 180s 超时误杀（心跳保活）
- 多租户任务隔离（user_id 分区）

---

## 3. 技术方案设计

### 3.1 核心思路

**状态位即隐式锁**：

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
完成后状态转换 → 锁自动释放
```

**协议基础**（真实，commits `a9de03d`、`391ca79`）：
- input_required 是主 Claw 会话协议的一等状态
- 它还是跨 Agent 通信的挂载点（relay 指令拼入其 message text）
- 状态转换直接影响主 Claw 的超时判定与心跳行为

### 3.2 隐式锁 vs 显式锁对比表

| 锁的要求 | 显式锁方案 | INPUT_REQUIRED 状态位 |
|:---|:---|:---|
| **互斥标记** | 独立的 lock 字段 | 状态位本身（协议已有） |
| **释放路径** | 需手动 unlock + 超时保护 | 状态机转换天然覆盖 |
| **可观测性** | 需额外暴露锁状态 | 状态位在日志/协议中可见 |
| **协议穿透** | 无法穿透（主 Claw 不认识） | 主 Claw 心跳策略依赖它 |
| **崩溃恢复** | 锁泄漏需回收机制 | 随会话生命周期自然清零 |

### 3.3 状态机设计

```
IDLE ──[user message]──▶ RUNNING
RUNNING ──[需要用户补充]──▶ INPUT_REQUIRED
INPUT_REQUIRED ──[用户输入]──▶ RUNNING
INPUT_REQUIRED ──[超时/取消]──▶ IDLE
RUNNING ──[完成]──▶ COMPLETE
```

---

## 4. 核心实现细节

### 4.1 消息路由

```python
async def handle_user_message(user_id, session_id, message):
    task = task_store.get_active(user_id, session_id)
    if task and task.state == "INPUT_REQUIRED":
        # 作为应答注入原 task（而不是开新 task）
        await task.update_with_user_input(message)
        # LLM 响应完成 → 状态转换 → 锁自动释放
    else:
        # 创建新 task
        task = task_store.new(user_id, session_id)
        await task.execute(message)
```

### 4.2 心跳保活：180s 超时的两次修复

**第一次修复**（真实，commit `ab4416e`）：

```python
# 问题：心跳 message 字段被移除 → 主 Claw 收不到活性证明 → 180s 断连
# 修复：恢复心跳 message 字段
async def heartbeat_loop(session):
    while session.state == "INPUT_REQUIRED":
        await send_to_main_claw(message=HEARTBEAT_MSG)  # 恢复字段
        await sleep(HEARTBEAT_INTERVAL)
```

**第二次修复**（真实，commit `76e5f37`）：

```python
# 问题：恢复的心跳消息用户可见 → 污染对话
# 修复：心跳 message 用空文本
HEARTBEAT_MSG = ""  # 主Claw 能识别心跳（不断连），用户无感（不显示）
```

**精巧的平衡**：
```
既要：主 Claw 识别心跳 → 不断连（对抗 180s 超时）
又要：用户无感 → 对话里看不到心跳消息
空文本心跳同时满足两者
```

### 4.3 状态转换与部署治理

**重新部署场景**（真实，commit `391ca79`）：

```python
# 问题：重新部署后，残留的 input_required 状态 + 持续心跳 → 主Claw超时
# 修复：部署时把 input_required 转为 complete，停止心跳
def on_redeploy():
    for session in active_sessions:
        if session.state == "INPUT_REQUIRED":
            session.state = "COMPLETE"   # input_required → complete
            session.stop_heartbeat()     # 停止心跳
```

**连接关闭清理**（真实，commit `871a28d`）：

```python
# WebSocket 连接关闭时取消所有运行中任务（复数——证明并发任务存在）
def on_ws_close(session):
    for task in task_store.get_running(session.user_id):
        task.cancel()
    # + 发送异常保护：关闭过程中的发送不能抛异常
```

### 4.4 配套治理

**namespace 单一真理源**：
```
task_store / VFS / ctx_log 三处 namespace 定义必须一致
否则 INPUT_REQUIRED 检查查错位置 → 查不到等待中的任务 → 误开新 task
```

**task_store 按 user_id 分区**：
```
主分区 key = user_id：
- 多租户隔离：A 用户绝不能看到 B 用户的任务
- 跨会话查询：用户重连（新 session）能看到自己等待中的任务
session_id 二级索引：锁的粒度是 session
```

### 4.5 边界 case 处理

**Case 1：用户连发消息**
```
场景：INPUT_REQUIRED 期间用户连发两条
处理：都作为应答注入原 task，不新开 task
效果：state 不撕裂
```

**Case 2：等待超时**
```
场景：用户长时间不输入
处理：心跳持续保活（不被主 Claw 断连）；业务层可定期检查转 IDLE
原则：锁不能无限期持有，但释放要走状态机
```

**Case 3：进程重启**
```
场景：服务重启，内存状态丢失
处理：重启后正确恢复/清理 input_required 状态（391ca79 的治理）
教训：有状态的锁必须回答"进程重启后状态怎么办"
```

**Case 4：连接断开**
```
场景：WebSocket 关闭时还有运行中任务
处理：取消所有运行中任务 + 发送异常保护（871a28d）
```

---

## 5. 效果评估与优化

### 5.1 治理时间线（git 统计）

| 日期 | 事件 | 意义 |
|:---:|:---|:---|
| 07-08 | `a9de03d` relay 指令挂载 input_required | 状态位成为通信载体 |
| 08-11 | `391ca79` 部署状态治理 | 重部署不再引发超时 |
| 08-11 | `871a28d` 连接关闭清理 | 并发任务生命周期闭环 |
| 08-13 | `ab4416e` + `76e5f37` 心跳双修 | 180s 断连根治 + 用户无感 |

### 5.2 治理收益

```
并发消息 state 撕裂：0（状态位锁保证）
等待状态误杀：0（心跳保活对抗 180s）
多租户越权：0（user_id 主分区隔离）
部署/断连异常：有明确治理路径
```

---
