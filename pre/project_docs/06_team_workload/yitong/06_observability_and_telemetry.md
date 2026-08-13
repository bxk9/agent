# 专题 06｜埋点与可观测性

> 相关文件：`app/utils/ctx_log.py`（6 次修改）、`app/main.py`（埋点部分）、`app/agent_executor.py`（usage 上报部分）、deeplink 相关代码
> 版本：v1.0

---

## 一、目标

将一个原本"黑盒式"的智能体链路，改造为**每一步都可追踪、每一份 token 都可计量、每一次异常都可回放**的可观测系统。

---

## 二、我贡献的三大子系统

### 2.1 `ctx_log`：上下文关联日志

`app/utils/ctx_log.py` 是我推动引入的日志辅助模块，核心作用是**给每条日志自动附加 session/thread/user 三元组**，便于按 session 检索。

典型提交：
```
07-24  chore(voice): build_interview_context 日志增加 header_session，便于按 session 检索
07-24  chore(voice): 用 ctx_log 打印主动解析简历日志，统一链路上下文输出
07-24  chore(voice): 增加主动解析简历路径的详细日志，便于定位 resume_summary 为空问题
```

**使用方式**：
```python
from app.utils.ctx_log import bind_ctx, ctx_info
_bind_ctx(session_id=..., thread_id=..., user_id=...)
ctx_info("resume_summary generated: %s", summary_len)
# 输出：[sid=xxx tid=yyy uid=zzz] resume_summary generated: 1234
```

**收益**：定位跨 session 问题从"翻上下文" → "grep sid=xxx"，效率显著提升。

### 2.2 usage_tokens 埋点闭环

见 [`01_voice_interview_module.md` §3.2](./01_voice_interview_module.md)。核心提交序列：

| 日期 | 提交 |
|------|------|
| 07-29 | `fix usage_tokens埋点bug` |
| 07-30 | `fix usage-tokens bug` × 5 |
| 07-30 | `fix usage bug` |
| 08-05 | `update 语音埋点` × 2 |
| 08-05 | `fix usage 埋点` × 2 |

**最终形态**：
- vivo `/chat/stream` stream 结束 `finally` 块统一 flush usage
- 空 `choices` 防御
- task_id 与主 Agent 强一致

### 2.3 deeplink 参数化

| 版本 | 参数 | 用途 |
|------|------|------|
| v1（07-22） | 基础 URL | — |
| v1.1（07-22） | `sync_to_main_bot` | 语音结束后回主 Agent |
| v1.2（07-23） | `onceClick=true` | 防重复触发 |
| v2（07-27） | `filename` + `mediatype` | 携带文件元信息 |
| v3（08-06） | `task_id=<主 Agent task_id>` | 埋点闭环 |

---

## 三、可观测性覆盖矩阵

| 事件类型 | 是否有日志 | 是否有埋点 | 是否可 session 关联 |
|---------|-----------|-----------|-------------------|
| 用户消息进入 | ✅ | ✅ | ✅ |
| Agent 决策思考 | ✅ | ✅ (usage_tokens) | ✅ |
| 工具调用开始 | ✅ | — | ✅ |
| 工具调用结束（成功） | ✅（带 preview） | — | ✅ |
| 工具调用结束（异常） | ✅（带 stack） | — | ✅ |
| LLM 上下文裁剪 | ✅（前后长度） | — | ✅ |
| WebSocket 断连 | ✅ | — | ✅ |
| 语音 add-dialogue | ✅ | ✅ | ✅ |
| 错题本入册 | ✅ | — | ✅ |
| Deeplink 触发 | ✅ | ✅ | ✅ |

---

## 四、量化成果

| 指标 | 迭代前 | 迭代后 |
|------|-------|-------|
| usage 上报缺失率 | 高（首版几乎不通） | ~0（5 次迭代后） |
| session 定位耗时 | 数分钟翻 log | 秒级 grep |
| deeplink 参数数 | 1 | 5+ |
| 关键日志覆盖率 | 部分链路 | 全链路 |

---

## 五、相关文档

- `05_agent_executor_refactor.md` - 事件流与埋点集成点
- `01_voice_interview_module.md` - 语音埋点场景
- `../03_modules/12_module_agent_core.md` - Agent 事件模型

---

## 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|---------|
| v1.0 | 2026-08-10 | 初版 |
