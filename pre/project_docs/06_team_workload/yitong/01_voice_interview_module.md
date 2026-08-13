# 专题 01｜语音模拟面试模块端到端攻坚

> 模块路径：`app/voice/`（2777 行 Python）+ `app/main.py` 的 `/ws/interview` 端点 + `web/static/voice.html` 前端
> 时间跨度：2026-07-15 → 2026-08-10（约 25 天）
> 我的贡献：约 85 次提交，涵盖全链路搭建、Prompt 迭代、埋点、稳定性
> 版本：v1.0

---

## 一、模块概览

语音模拟面试是本项目最复杂的**长连接实时**模块，涉及：

```
用户 ──WSS/ws/interview──► FastAPI      ┌──► LangGraph MemorySaver
                            │           │    （历史与主 Agent 共享 thread）
                            ├───────────┤
                            │           ├──► voice_session（错题本入册）
                            │           │
                            └──WSS──────┴──► vivo /chat/stream（STT + LLM 一体）
```

关键难点：
1. **上下文一致性**：语音 session 与主 Agent session_id 必须打通，否则错题本、复盘功能会断裂。
2. **Prompt 稳定性**：语音 STT + LLM 一体，Prompt 稍有歧义就会导致 150 分钟输出、无限追问、点评越界。
3. **兜底与重试**：网络断开、模型未遵循 JSON、错题本识别失败，都必须优雅降级。
4. **埋点合规**：usage_tokens、task_id 与主 Agent 保持一致，供计费与审计。

---

## 二、我的核心贡献时间线

### 阶段 A：链路搭建（07-15 → 07-19，5 天）

| 日期 | 提交 | 说明 |
|------|------|------|
| 07-15 | `feat(voice-session): 主 Agent session_id 透传 + context 双维度查询 + 复盘链路修复` | 打通主 Agent 与语音 session，解决错题本无法按 session 检索问题 |
| 07-16 | `feat(voice-session): add-dialogue 后台 LLM judge 自动入册错题本` | 引入异步 LLM Judge，回答完成后自动判断是否入册 |
| 07-16 | `fix(voice-error-book): 补齐 VFS sid 绑定` | 修复错题本入册时"缺少会话标识"报错 |
| 07-19 | `feat: 语音模拟面试上下文与对话持久化到 VFS` | 对话落盘，供复盘链路读取 |

**产出**：3 个新增 API 端点（`/voice-session/context`、`/add-dialogue`、`/context 双维查询`），共对应 3 篇 API 文档：
- `docs/api/voice-context接口文档.md`
- `docs/api/voice-session-add-dialogue接口文档.md`
- `docs/api/voice-session-context接口文档.md`

---

### 阶段 B：Prompt 单一源 + 流式 + FALLBACK（07-23 → 07-24）

一次典型的"重构 + 兜底"复合动作：

```
07-23 23:19  voice: 单一 prompt 源 + 流式 LLM + FALLBACK 兜底 + 面经正文透传
```

**动机**：此前语音端 prompt 存在多源拼装（voice 端本地 + skill 内容 + 主 Agent 上下文），一次改动要同步三处，极易漂移。

**方案**：
- 单一源：所有 prompt 从 `app/skills/mock_interview_voice.md` 生成
- 流式：vivo `/chat/stream` 接入 SSE
- FALLBACK：任何一步失败自动回退到"简版面试官人设"，保证不断线

配套优化（07-24 密集）：
- `feat(voice): 让语音面试 system prompt 从 LangGraph 对话中提炼简历摘要` —— 免去用户重复上传
- `fix(voice): 优先从 LangGraph MemorySaver 拉历史；若只有上传文件无简历解析则主动调用工具读取/解析` —— 稳态兜底
- `refactor(voice): split resume summary and interviewer profile generation` —— 分离两个 LLM 调用，便于独立缓存

---

### 阶段 C：上下文预加载链路重构（07-25）

```
07-25 10:53  refactor(voice-session): 语音上下文预加载链路重构
```

**背景**：`/context` 端点原本在 WS 建链后再拉简历摘要，实测首包延迟 3-5s。

**改造**：将 `dialogue` 建档从 `/add-dialogue` 前移到 `/context`，与简历摘要并行生成，首包延迟降至 <1s。

同期 rename：`window_id → header_session`，语义更贴近"面试头会话"，减少歧义。

---

### 阶段 D：Prompt 12 条硬约束（07-30 单次提交）

最具代表性的一次提交：

```
07-30 23:35  1. 语音面试点评策略调整：从不提供反馈改为面试结束后通过复盘完成点评...
             2. 路由规则加固：用户要求点评/逐题反馈不改变路由结果...
             3. 面试结束评估：整体评估中去掉共N题计数...
             ...（共 12 条）
```

12 条策略覆盖：**点评时机、路由稳定性、题号语义、话术精简、冲突检查、反馈中立性、防剧透、语音链接刷新、结束确认**。这一次提交等价于把此前一周所有零散反馈闭环，全部编码到 Prompt 里。

详见：[02_mock_interview_prompt_engineering.md](./02_mock_interview_prompt_engineering.md)

---

### 阶段 E：稳定性收敛（08-04 → 08-10）

| 日期 | 提交 | 关键点 |
|------|------|--------|
| 08-04 | `语音上下文裁剪` | 引入 `_MAX_MEMORY_CHARS` 截断，防长会话上下文膨胀 |
| 08-04 | `强化错题本的调用和追问只问一题` | 用规则约束替代 LLM 判断，稳定性↑ |
| 08-05 | `强化语音内部不能点评，文字逐题出` | 语音/文字职责分离硬约束 |
| 08-06 | `优化语音输出150分钟的问题；解决模型未遵循json的问题` | 长输出+JSON 双 Bug 一并修复 |
| 08-06 | `deeplink task id改成用主agent的taskid` → 反复 3 次 | 埋点闭环：`回滚` → `恢复` |
| 08-07 | `语音错题本识别增加重试机制` | LLM Judge 加 3 次重试 + 指数退避 |
| 08-10 | `出题策略默认改为深度追问` | 产品策略调优（最新提交） |

---

## 三、关键技术难点

### 3.1 语音/文字双通道职责分离

| 通道 | 出题方式 | 反馈方式 | 错题本 |
|------|---------|---------|--------|
| 语音 | 一次一题 | **不点评**（避免打断沉浸） | 后台 LLM Judge 自动入册 |
| 文字 | 一次一题 | 逐题点评 + 集中点评 | 主 Agent 显式调用工具 |

**执行难点**：LLM 天然倾向于"看到答案就点评"。通过在 `mock_interview_voice.md` 中反复强化 "语音内部禁止点评"，并配套路由规则"用户要点评也不切通道"，稳定率从初期 60% 提升到 95%+。

### 3.2 usage_tokens 埋点闭环（5 次迭代）

```
07-29 19:37  fix usage_tokens埋点bug
07-30 21:45  fix usage-tokens bug
07-30 21:52  fix usage-tokens bug
07-30 21:58  fix usage-tokens bug
07-30 22:06  fix usage-tokens bug
07-30 23:51  fix usage bug
08-05 09:52  fix usage 埋点
```

**根因链**：
1. vivo `/chat/stream` 的 usage 只在最后一个 chunk，且可能为空 → 需在 stream 结束时统一上报
2. 空 `choices` 会 `list index out of range` → 见 `docs/design/20260729_LLM思考耗时优化...md` v1.6
3. 主 Agent 与语音 session 的 task_id 不一致 → 埋点被拆成两份

最终方案：`interview_ws.py` 内在 stream 结束 finally 块统一 flush，并通过 deeplink 参数强制携带主 Agent task_id。

### 3.3 deeplink 三代演进

| 代 | 提交 | 变化 |
|----|------|------|
| v1 | 07-22 `deeplink更加参数` | 初始形态 |
| v2 | 07-22 `deeplink增加sync_to_main_bot参数` | 增加回主 Agent 同步开关 |
| v2.1 | 07-23 `deeplink增加&onceClick=true限制单次点击` | 防重复触发 |
| v3 | 07-27 `deeplink增加filename和mediatype` | 携带文件元信息 |
| v3.1 | 08-06 `deeplink task id改成用主agent的taskid` | 埋点闭环 |

---

## 四、成果验证

- **可靠性**：从阶段 A 上线到 08-10，语音链路无重大线上故障；每次问题都有对应的复盘（见 `docs/fix/`）与话术更新。
- **性能**：首包延迟 3-5s → <1s；上下文膨胀通过裁剪彻底解决。
- **产品体验**：12 条硬约束落地后，用户投诉"打断/剧透/无限追问/无点评"归零。

---

## 五、相关文档

- [`02_mock_interview_prompt_engineering.md`](./02_mock_interview_prompt_engineering.md) - Prompt 演进详解
- [`03_error_book_system.md`](./03_error_book_system.md) - 错题本系统
- [`06_observability_and_telemetry.md`](./06_observability_and_telemetry.md) - 埋点细节
- `../03_modules/17_module_voice.md` - 模块架构文档
- `../04_data_flows/31_data_flow_voice.md` - 语音数据流

---

## 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|---------|
| v1.0 | 2026-08-10 | 初版 |
