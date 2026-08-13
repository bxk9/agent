# 06 · 上下文裁剪与 Token 观测

## 一句话概括

司棋在 07 月末到 08 月初对 Agent 上下文长度做了**多轮裁剪治理**，并修复了 token 统计的 contextvar 传递问题，让长会话既能"跑得下"也能"看得清"。

---

## 时间线

| 日期 | Commit | 主题 |
|:---:|:---|:---|
| 07-29 | fix(agent): stream_agent 异常处理不再吞掉最后一个 chunk | 稳定性 |
| 07-29 | fix(llm): choices 空列表兜底 | 稳定性 |
| 07-29 | fix(llm): 异常信息不再混入模型内容 | 稳定性 |
| 07-30 | **feat(context): Agent 上下文长度裁剪策略** | 裁剪 |
| 07-30 | fix(context): 保留 tool_call / tool_response 配对 | 裁剪 |
| 08-05 | **fix(token): usage_tokens contextvar 跨异步任务传递** | 观测 |
| 08-05 | fix(logging): token 统计日志绑定 trace_id | 观测 |

---

## 背景

### 为什么要裁剪

长会话（用户改简历十几轮 + 面试 30 分钟）会导致：
- LLM context window 撑爆
- token 成本线性上升
- 首 token 延迟增加

### 为什么 token 会丢

- BlueClaw 网关的 usage_tokens 在异步流的**最后一个 chunk** 才返回
- 但监控代码用 `contextvar` 读取时，异步任务已切换到别的协程
- 结果：日志里 token 全是 0

---

## 方案

### 上下文裁剪策略（07-30）

```
1. 保留 system prompt（永远）
2. 保留最近 N 轮 user/assistant
3. 保留所有 tool_call ↔ tool_response 配对（不能拆散）
4. 中间轮次按时间从早到晚淘汰
```

**关键设计**：tool_call 和它对应的 tool_response 必须成对保留或成对淘汰，否则 LLM 会报"orphan tool_call"错误。

### Token contextvar 修复（08-05）

**问题**：
```python
# 错误：contextvar 在 async task 切换时不保留
usage_tokens_var.set(usage)  # 在 chunk_handler 内
# 主协程读取时已丢失
```

**修复**：
- 将 usage 显式挂到 stream 对象上
- 在流结束的同一协程内落库
- 绑定 `trace_id` 用于跨服务查询

---

## 量化成果

| 指标 | 治理前 | 治理后 |
|:---|---:|---:|
| 长会话 context 超限率 | 偶发 | 0 |
| token 日志覆盖率 | ~30%（丢失严重） | 100% |
| 平均 token 节省 | - | ~35%（长会话） |

---

## 与团队协作

- **yitong**：token 观测下游消费方，做了 5 次 `usage_tokens` 相关的迭代
- **11099826**：面试复盘场景的长上下文首个受益者

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="司棋" --grep="context\|token\|usage" --pretty=format:"%ad|%s" --date=short
```
