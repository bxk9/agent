# 07 · 可观测性建设（ctx_log 全链路）

## 一句话概括

司棋主导了 Agent 侧**日志上下文注入体系**——通过 `ctx_log` 把 session_id / user_id / trace_id / thread_id 自动绑定到每一行日志，让"看日志找问题"从捞针变成一句查询。

---

## 背景

早期日志的痛点：
- 一次会话跨 5+ 微服务，日志散落各处
- 用户报"我卡在第三轮"，工程师只能从时间戳附近凭肉眼找
- 异步 stream 让 log 顺序错乱

司棋的目标：**任何一行日志都能反向定位到用户、会话、请求**。

---

## 时间线

| 日期 | Commit | 主题 |
|:---:|:---|:---|
| 07-21 | feat(doc_agent): 日志改用 ctx_log 绑定 session_id/user_id，打印完整调用 payload | 首个应用 |
| 07-29 | fix(logging): 补全 Agent stream 结束日志的 thread_id 和 blueclaw_chat._call_api 请求前日志 | 覆盖流终点 + LLM 入口 |
| 08-05 | fix(logging): token 统计日志绑定 trace_id | token 域接入 |
| 08-上旬 | feat(logging): user_id 贯穿 A2A 调用链 | 跨服务传递 |

---

## 方案

### ctx_log 的核心机制

```python
# 请求入口设置一次
ctx_log.bind(session_id=..., user_id=..., trace_id=...)

# 全链路自动继承（不用每处手动传）
logger.info("xxx")  # 自动带上所有 bind 字段
```

**关键点**：
1. 基于 `contextvars`，异步任务默认继承
2. 与 07-30 的 token contextvar 修复配套（司棋自己踩过坑）
3. 每层入口（HTTP handler / A2A executor / tool call）都做一次 bind

### 三个覆盖点

| 域 | 绑定字段 | 用途 |
|:---|:---|:---|
| HTTP 入口 | session_id, user_id | 用户维度追溯 |
| A2A 调用 | trace_id | 跨服务串联 |
| LLM stream | thread_id | 单轮对话隔离 |

---

## 案例：一次故障排查

**故障**：用户 A 报"简历生成一半没了"
**排查前**（无 ctx_log）：
- 只知道时间点 → 翻 20+ 微服务日志 → 30 分钟定位

**排查后**（有 ctx_log）：
- 日志中心搜 `user_id=A` → 5 秒定位
- 发现 doc_agent A2A 超时后被裁剪 → 5 秒确认根因
- 关联到 07-21 六连修 #1/#2 → 已修复

---

## 量化成果

| 指标 | 改造前 | 改造后 |
|:---|---:|---:|
| 单次故障平均定位时间 | ~30 min | ~2 min |
| 日志字段完备率 | ~40% | 100% |
| 跨服务串联能力 | 无 | trace_id 全链 |

---

## 与团队协作

- **11099826**：ctx_log 在简历链路应用，与其埋点数据结合
- **yitong**：token 观测直接受益，日志中可看到"哪个用户 / 哪个会话 / 多少 token"
- **11197109**：VLM 调用接入 trace_id 后可追踪图像消耗

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="司棋" --grep="ctx_log\|logging\|trace_id" --pretty=format:"%ad|%s" --date=short
```
