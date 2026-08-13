# 02 · LLM 长上下文裁剪：tool_call ↔ tool_response 配对保留策略

> **作者**：司棋 · **场景**：Agent 长会话 context window 治理

---

## 一句话摘要

面对 Agent 长会话（简历修改 20 轮 + 面试 30 分钟）撑爆 LLM context window 的问题，我设计了**"System 保留 + 最近 N 轮 + tool_call/response 配对守护 + 早期淘汰"四段式裁剪算法**，核心难点在于**tool 调用必须成对保留否则 LLM 报 orphan tool_call 错**。上线后长会话超限率降为 0，token 成本节省约 35%。

---

## 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"长对话怎么处理？"** | 完整讲一套裁剪算法，不是简单的"截断最后 N 条" |
| **"你有什么 Agent 相关经验？"** | tool_call/response 的配对语义 + 淘汰边界 |
| **"Token 成本怎么控？"** | 裁剪策略 + 观测（配合 06 号文档 usage_tokens 修复） |
| **"讲一个你踩过最深的坑"** | orphan tool_call 的"边界不完整"故障 |

**可回答的经典面试题**：
- LLM context 超限如何处理？
- Sliding window / Summarization / Retrieval 三种方案的取舍
- Tool Use / Function Calling 的语义完整性
- 为什么不能简单截断？

---

## 背景与问题定义

### 业务场景

Interview Agent 场景下典型的长会话：
- **简历生成**：用户来回改简历，一次会话 30+ 轮
- **模拟面试**：语音面试 30-60 分钟，累积 50+ 轮对话
- **面试复盘**：需要**完整回看**面试全过程 + 简历上下文

### Context window 超限的三种失败模式

| 失败模式 | 表现 | 影响 |
|:---|:---|:---|
| **直接超限** | LLM 网关拒绝请求 | 用户彻底卡死，无法继续 |
| **首 token 延迟** | 长 context → prefill 慢 | UX 崩溃 |
| **成本失控** | Token 线性增长 | 商业不可持续 |

### 天真方案的坑

**方案 A：截断最早 N 条**

```python
messages = messages[-N:]
```

**踩坑**：
- 如果第 N 条恰好是 `tool_response`，但对应的 `tool_call` 被截掉了
- LLM 报错：`orphan tool_response, no matching tool_call`
- 会话直接崩溃

**方案 B：只保留 user/assistant，删除所有 tool 消息**

**踩坑**：
- Tool 调用产生的中间结果（如"我搜到了 3 篇资料"）丢失
- 模型下一轮不知道之前查过什么，重复调用工具

**核心难点**：**tool_call 与 tool_response 是原子对**，必须成对存在或成对淘汰。

---

## 方案演进与关键决策

### 最终方案：四段式裁剪

```
输入：完整 messages（可能有 100+ 条）
        ↓
┌──────────────────────────────────────┐
│ Segment 1：System Prompt             │ ← 永久保留
│  （角色定义、能力约束）                 │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│ Segment 2：最近 N 轮 user/assistant   │ ← 永久保留
│  （近期对话上下文）                     │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│ Segment 3：tool_call/response 配对    │ ← 永久保留
│  （近 N 轮中的完整工具调用记录）         │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│ Segment 4：早期轮次（可淘汰）           │ ← 按时间从早到晚淘汰
│  （直到总 token 落在 budget 内）        │
└──────────────────────────────────────┘
```

### 关键决策 1：为什么不用 Summarization

**Summarization 方案**：定期用 LLM 把早期对话压缩成摘要
- 优点：保留信息
- 缺点：（1）需要额外 LLM 调用（成本 + 延迟）；（2）**摘要 = 二次幻觉源**；（3）用户很难 debug

**权衡**：本场景对**可追溯性**要求高（复盘要看原始对话），因此选择"截断而非压缩"。

### 关键决策 2：为什么不用 Retrieval

**RAG 方案**：把历史消息塞向量库，按需检索
- 优点：理论上无长度限制
- 缺点：（1）向量检索质量对提示词敏感；（2）对话语义连贯性差；（3）复盘场景需要**全量顺序**回看

**权衡**：短期收益不明显 + 工程复杂度激增 → 暂不使用。

### 关键决策 3：tool 配对的算法

```python
def preserve_tool_pairs(messages_to_keep, all_messages):
    """给定要保留的消息集，展开出所有必须一起保留的 tool 配对"""
    kept_ids = set(id(m) for m in messages_to_keep)
    for m in list(messages_to_keep):
        if is_tool_response(m):
            call = find_matching_tool_call(m, all_messages)
            if call and id(call) not in kept_ids:
                messages_to_keep.append(call)
                kept_ids.add(id(call))
        elif is_tool_call(m):
            resp = find_matching_tool_response(m, all_messages)
            if resp and id(resp) not in kept_ids:
                messages_to_keep.append(resp)
                kept_ids.add(id(resp))
    return sorted(messages_to_keep, key=lambda m: m.timestamp)
```

**核心**：
- 双向配对（找 call 也找 response）
- **顺序保留**（tool_call 必须在 tool_response 之前）
- 展开可能触发链式（一个 tool_call 保留 → 拉入 response → 可能拉入更多）

---

## 算法/工程实现细节

### Budget 计算

```python
def compute_budget(messages, model_ctx_size):
    system_and_recent = sum(t.tokens for t in must_keep(messages))
    budget = model_ctx_size - system_and_recent - RESPONSE_HEADROOM
    return budget
```

- `RESPONSE_HEADROOM`：给 LLM 输出预留的空间（通常 4096）
- 剩下的 budget 给"早期可淘汰段"

### 淘汰顺序

```
从时间最早的一条开始淘汰
  ↓
如果是 tool_call → 一起淘汰对应的 tool_response
  ↓
如果是 tool_response → 一起淘汰对应的 tool_call
  ↓
更新已用 token
  ↓
直到已用 token ≤ budget
```

### 边界处理

| 边界 | 处理 |
|:---|:---|
| **孤儿 tool_response**（没找到 call） | 直接淘汰（数据异常，容忍） |
| **单条消息超 budget** | 报错 + 降级（不裁剪，直接送 LLM，让网关拒绝） |
| **淘汰后仍超限** | 强制截断"最近 N 轮"（次坏方案） |

---

## 量化验证与效果

| 指标 | 治理前 | 治理后 | 备注 |
|:---|---:|---:|:---|
| 长会话 context 超限率 | 偶发（周报障） | **0%** | 上线 4 周未复现 |
| orphan tool_call 错误率 | ~2%（配对策略引入前） | **0** | 配对算法后 |
| Token 成本节省 | - | **~35%**（长会话） | 早期淘汰有效 |
| 首 token 延迟（长会话） | 12s+ | **~4s** | context 变小 |

### 压测样本

- 50 场真实模拟面试完整会话
- 平均 68 轮对话、含 12 次 tool 调用
- 通过率：100%（无一超限、无一 orphan 错误）

---

## 方法论抽象与迁移

### 三个"必须"

1. **tool 必须成对**——任何裁剪算法都要守护
2. **顺序必须保留**——tool_call 在 tool_response 之前，否则���义错乱
3. **淘汰必须可解释**——写清"因为 budget 超了，淘汰了 W23 之前的对话"日志（便于事后排查）

### 可迁移场景

| 场景 | 迁移点 |
|:---|:---|
| RAG 系统的 chunk 裁剪 | 类似"必须成对"思路（题目和答案不能拆） |
| Agent 记忆压缩 | 保留最近 + 压缩早期（Summarization 混合） |
| 多轮问答系统 | user-assistant 天然配对 |

### 未来演进方向

- **Segment 4 用 Summarization**：早期段淘汰前先摘要，摘要放入 System 附加区
- **重要度打分**：不按时间淘汰，按"下轮使用可能性"打分
- **动态 budget**：根据模型能力（K/V cache 大小）动态调整

---

## 关联提交

| 日期 | Commit |
|:---:|:---|
| 07-30 | feat(context): Agent 上下文长度裁剪策略 |
| 07-30 | fix(context): 保留 tool_call / tool_response 配对 |

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |
