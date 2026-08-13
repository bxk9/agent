# 02 · find_dialogues 检索修复

## 一句话概括

张梦宇在 07-29 修复的**"context_id 过滤误伤跨会话复盘"**——一个看似简单的 SQL/查询过滤问题，实则是影响用户复盘正确性的关键 bug。

---

## 时间线

| 日期 | Commit |
|:---:|:---|
| 07-29 | 去掉 find_dialogues_by_context_id 中 context_id 过滤，修复复盘答案错误问题 |

---

## 问题根因

### 原逻辑

```python
def find_dialogues_by_context_id(context_id):
    return db.query(dialogues).filter(context_id == context_id).all()
```

看上去合理——按 context_id 查对话。

### 实际问题

**场景**：用户在会话 A 做面试，之后开新会话 B 请求复盘

- 复盘时 context_id = **会话 B 的**
- 但对话数据存在**会话 A 的 context 里**
- 结果：查不到数据，或查到部分错误数据
- **表现**：复盘答案错误 / 缺失

### 修复

**去掉 context_id 过滤**，改用其他更合理的关联条件（例如 user_id + 时间范围 + session 关联）。

---

## 影响范围

| 下游 | 影响 |
|:---|:---|
| **陈乾复盘 skill** | 输入数据错误 → 输出报告错误 |
| **yitong 错题本** | 错题归档到错误会话 |
| **用户体验** | "AI 分析了不是我说过的话" |

---

## 为什么这是"小提交高价值"典范

- 提交量：1 次
- 代码量：可能几行
- 但**影响面**：全部复盘流程

体现了 **"精准定位 + 果断修复"** 的能力。

---

## 与团队协作

- **陈乾**：复盘 skill 直接受益
- **司棋**：context/session 治理的相关方（本 bug 属于 context 语义与业务查询的边界问题）

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author=张梦宇 --grep="find_dialogues\|context_id\|复盘" --pretty=format:"%ad %s" --date=short
```
