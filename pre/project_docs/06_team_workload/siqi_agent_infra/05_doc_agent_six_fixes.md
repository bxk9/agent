# 05 · 07-21 doc_agent 六连修单日攻坚

## 一句话概括

**2026-07-21 一天内，司棋在文档 Agent 桥接层连续提交 6 个修复**——覆盖时序、命名、鉴权、进度、超时、复合任务共 5 大类问题，是**典型的深度攻坚日**。

---

## 时间线（同一日 6 提交）

| 序号 | Commit | 问题域 |
|:---:|:---|:---|
| 1 | `fix(doc_agent): 移除 lastChunk 缩短 deadline 逻辑，避免提前退出丢失后续 artifact` | 超时/时序 |
| 2 | `fix(doc_agent): 收到进度消息时重置 deadline，确保所有后续 artifacts 完整接收` | 超时/时序 |
| 3 | `fix(doc_agent): 进度文本保留换行，修复手机端思考过程不换行问题` | 进度渲染 |
| 4 | `fix(doc_agent): 原文件名已含日期时不再追加时间戳，避免日期重复` | 命名 |
| 5 | `feat(doc_agent): 日志改用 ctx_log 绑定 session_id/user_id，打印完整调用 payload` | 可观测 |
| 6 | `fix(format_document): 修复复合任务场景下文档 Agent 收到错误 file_url 的问题` | 参数路由 |
| 7 | `feat(agent_executor): 文档 Agent 链接注入 metadata.resources 兜底传递` | 参数路由 |

---

## 每一项修复的技术分析

### #1 & #2：deadline 语义修复（成对）

**问题**：
- A2A 协议中收到 `lastChunk=true` 后系统会缩短 deadline
- 但 lastChunk 之后还可能有 `artifactUpdate`（生成完成 → 上传 → 返回 URL 需要时间）
- 结果：产物 URL 还没到就被 deadline 强制关闭连接

**修复**：
- 移除 lastChunk 缩短 deadline 逻辑
- 收到**任何**进度消息时重置 deadline

**影响**：产物丢失率从"偶发"降为 0

### #3：进度换行保留

**问题**：手机端展示"思考过程"时全挤成一行
**修复**：进度文本保留 `\n`

### #4：日期重复

**问题**：原文件名 `简历-20260721.docx` 被再次追加时间戳 → `简历-20260721_20260721.docx`
**修复**：检测原文件名已含 `\d{8}` 时跳过追加
**与 11099826 协作**：与 `naming.py` 的 ORIGINAL_FILE 模式对齐

### #5：ctx_log 全绑定

**问题**：日志没有 session_id / user_id，难以在日志中心定位问题
**修复**：所有 doc_agent 日志改用 `ctx_log`，绑定完整上下文 + payload
**后续影响**：成为可观测性建设的模板（详见 [07](./07_observability_ctx_log.md)）

### #6 & #7：复合任务参数路由

**问题**：同会话内多次调用 format_document，file_url 参数被上次任务污染
**修复**：
- 工具层：显式清理旧 file_url
- Executor 层：通过 `metadata.resources` 兜底传递

---

## 方法论提炼

这天的六连修体现了一个**"深度攻坚日"**范式：

1. **同一域集中攻坚**：全部围绕 doc_agent，不散射
2. **成对提交**：#1 + #2 是对同一问题的两侧修复（移除错逻辑 + 加正确逻辑）
3. **修 bug 同时加可观测**：#5 顺手把日志系统升级，为下次调试铺路
4. **业务修复关联架构改进**：#6 修 bug、#7 把兜底放到 executor 层

---

## 与 07-27 A2A 三 bug 的关系

- 07-21 六连修：**同步链路问题**（deadline / 命名 / 进度）
- 07-27 三 bug：**静默超时问题**（`fix(doc_agent_client): 修复 A2A 静默超时导致产物丢失的三个 bug`）

两次攻坚串联起来，doc_agent 从"能跑"到"稳定"。

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="司棋" --since="2026-07-21" --until="2026-07-22" --pretty=format:"%ad|%s" --date=short
```
