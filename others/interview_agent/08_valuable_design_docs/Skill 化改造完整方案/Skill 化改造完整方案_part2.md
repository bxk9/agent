```

### 5.2 详细任务列表

#### Phase 1：协议对齐

- [ ] 拿到主 Claw skill 协议规范文档
- [ ] 对比 §4 契约草案，列出差异
- [ ] 与主 Claw 团队对齐 6 个 P0 问题（见 §7）
- [ ] 输出《协议适配 spec v1.0》并双方签字

#### Phase 2：适配层开发

- [ ] 新建 `app/skill_adapter/` 模块
- [ ] 实现 `SkillRequest` → `query 字符串`（参考现有 `_build_user_query`）
- [ ] 实现 `agent.stream()` 事件 → `SkillEvent` 映射
- [ ] 实现收尾状态判定（complete / need_memory / out_of_scope）
- [ ] 实现 attachment 转 VFS 链接的逻辑（复用现有）
- [ ] 实现 `%%VOICE_CHAT_URL%%` 占位符替换（复用现有）
- [ ] 写单测：3 类典型 case 端到端跑通

#### Phase 3：本地联调

- [ ] Mock 一个主 Claw 客户端，按 skill 协议调用
- [ ] 跑通"简历优化"端到端
- [ ] 跑通"模拟面试"端到端
- [ ] 跑通"面试复盘 + 错题本"端到端
- [ ] 跑通"NEED_MEMORY 索要 + 重发"流程
- [ ] 跑通"域外拒答"流程
- [ ] 跑通"长耗时工具"（parse_resume_file 100s+）
- [ ] 验证流式输出体验（打字机效果）

#### Phase 4：主 Claw 联调

- [ ] 接入主 Claw 测试环境
- [ ] 主 Claw 路由命中率验证
- [ ] 流式 / 工具气泡 / 文件下载 / 引用框 4 类输出全跑通
- [ ] 跨轮对话（session 续轨）验证
- [ ] 长耗时 / 错误场景 / 用户取消等异常路径验证
- [ ] 修兼容性问题

#### Phase 5：切流 + 退场

- [ ] 灰度 5% 用户切到 skill 入口
- [ ] 监控对话质量指标（错答率、首 token 延迟、工具失败率）
- [ ] 灰度 20% → 50% → 100%
- [ ] 观察 1 周，无回归 → A2A 入口下线
- [ ] 删除 `agent_executor.py` 或保留只读

---

## 6. 关键技术点

### 6.1 业务内核保留不动

```python
# app/skill_adapter/executor.py（伪代码）
from app.agent import InterviewAgent

class SkillExecutor:
    def __init__(self):
        self.agent = InterviewAgent()  # ← 复用现有
    
    async def execute(self, req: SkillRequest, writer: SkillWriter):
        # 1. 绑定 VFS sid
        bind_sid(req.session_id)
        
        # 2. 入参映射
        query = build_query(req)
        history = req.history or None
        
        # 3. 跑业务内核
        async for event in self.agent.stream(query, req.session_id, history):
            # 4. 事件映射到 skill 输出
            await map_event(event, writer)
        
        # 5. 收尾
        await emit_final(writer, ...)
```

**核心**：`agent.stream` 一行不动。

### 6.2 收尾状态映射

| agent 内部信号 | skill 输出状态 | 主 Claw 行为 |
|---|---|---|
| 拒答模板"抱歉，我专注于..." | `out_of_scope` | 自由路由 |
| `[NEED_MEMORY]` 首 token | `need_memory` | 补 history 重发 |
| 正常回答 | `completed` | 保持对话黏性 |

复用现有 `_is_refusal_reply` / `_is_need_memory_reply` 判定函数。

### 6.3 长耗时工具的两条路径

```
Plan A：争取白名单（首选）
   主 Claw 给我们 skill 一个 180s 超时
   ↓
   现有所有工具直接复用

Plan B：异步任务模式（保底）
   长工具改为：
     1. 立即返回 task_id
     2. skill 流式输出 "处理中..."
     3. 后台跑工具
     4. 完成后推送结果
   ↓
   需要额外开发任务队列
```

### 6.4 用户身份与 VFS 隔离

```
A2A 现状：
  context_id → bind_sid → vfs_* 工具自动带 X-Tenant-Id

Skill 模式：
  req.user_id → bind_sid → 同上
```

**核心要求**：让主 Claw 强制透传 `user_id`，否则跨会话查历史简历会失败。

### 6.5 跨轮记忆双轨制

```
情况 1：主 Claw 透传 history
  → 注入为 system 消息，使用一次性 thread_id

情况 2：主 Claw 不透传
  → 回退到本地 MemorySaver，thread_id = session_id
```

完全复用现有 `agent.stream()` 的双轨逻辑。

### 6.6 流式输出兼容矩阵

| 我方输出类型 | 主 Claw 支持 | 不支持时降级方案 |
|---|---|---|
| token 流（打字机） | 必须 | 没有降级方案，必须支持 |
| 工具气泡（tool_call/result） | 期望 | 降级为纯文字"正在调用..." |
| 文件附件 | 必须 | 拼成 markdown 链接 |
| references 结构化 | 期望 | 拼到文末作为参考来源 |
| 占位符替换（语音 URL） | N/A | 我方在 skill 内部处理完再输出 |

---

## 7. 风险与兜底

### 7.1 P0 风险（决定方案能否成立）

| # | 风险 | 影响 | 缓解 |
|---|---|---|---|
| 1 | 主 Claw 不支持流式 token | 用户体验崩塌 | 不接受，整改方案 |
| 2 | 主 Claw 不允许工具自治调度 | 等于回到 3-skill 方案 | 不接受，整改方案 |
| 3 | 主 Claw 不透传 user_id | 历史简历查询失效 | 必须争取 |
| 4 | 主 Claw 单次超时 < 30s | 简历视觉解析挂掉 | 争取白名单 or 异步化 |
| 5 | 主 Claw 强制注入业务 prompt | 业务话术被覆盖 | 不接受，整改方案 |
| 6 | NEED_MEMORY marker 信号不通 | 缺历史时降级为反问 | 可接受 |

### 7.2 P1 风险（可降级接受）

| # | 风险 | 影响 | 缓解 |
|---|---|---|---|
| 7 | 工具气泡不透传 | 用户看不到"正在调用..." | 降级为纯文字 |
| 8 | references 不透传 | 引用框消失 | 拼到文末 |
| 9 | 灰度粒度不够细 | 整体回滚 | 不致命 |

### 7.3 回滚预案

```
现象                  →  动作
─────────────────         ─────────────────────
对话质量明显下降       →  立刻切流回 A2A 入口
长耗时工具批量超时     →  暂停 skill 入口，调超时阈值
特定场景频繁失败       →  保留双入口，按场景路由
```

---

## 8. 里程碑与排期

```
Week 1
├─ Day 1-2  Phase 1 协议对齐（卡主 Claw 团队节奏）
├─ Day 3-5  Phase 2 适配层开发

Week 2
├─ Day 1-3  Phase 2 继续 + Phase 3 本地联调
├─ Day 4-5  本地联调收尾，回归 case 全绿

Week 3
├─ 全周      Phase 4 主 Claw 联调

Week 4
├─ Day 1-3  灰度 5% → 20%
├─ Day 4-5  灰度 50%

Week 5
├─ 全周      灰度 100%，观察

Week 6
├─ A2A 入口下线
└─ 项目收尾
```

**关键路径**：Phase 1 卡主 Claw 团队，他们不出协议规范就动不了。

---

## 9. 验收标准

### 9.1 功能验收

- [ ] 简历优化端到端通过率 ≥ 现状
- [ ] 模拟面试端到端通过率 ≥ 现状
- [ ] 复盘 + 错题本端到端通过率 ≥ 现状
- [ ] 域外拒答首句正确率 = 100%
- [ ] NEED_MEMORY 在缺历史时触发率 ≥ 95%

### 9.2 性能验收

- [ ] 首 token 延迟 ≤ 现状 + 200ms
- [ ] 工具调用成功率 ≥ 99%
- [ ] 长耗时工具（>30s）成功率 ≥ 现状

### 9.3 体验验收

- [ ] 流式打字机效果保留
- [ ] 工具调用气泡保留（或降级版本可接受）
- [ ] 文件下载链接可点
- [ ] 跨轮对话上下文不丢

### 9.4 工程验收

- [ ] 业务代码（agent / skills / tools）0 改动
- [ ] A2A 入口可随时回滚
- [ ] 监控日志能对齐主 Claw trace
- [ ] DLP 合规审计通过

---

## 10. 附录

### 10.1 关键提问清单（给主 Claw 团队）

复制下面这份去开会，逐条让对方表态：

```
P0（决定方案能否成立）：

1. □ Skill 支持流式 token 输出吗？
2. □ Skill 内部能自由调度自己注册的工具吗？（不需要主 Claw LLM 介入）
3. □ Skill 入参能拿到稳定的 user_id 吗？
4. □ Skill 单次调用超时上限是多少？能否申请白名单（180s）？
5. □ Skill 是否会被主 Claw 注入额外 prompt？我们能 opt-out 吗？
6. □ Skill 能返回控制信号让主 Claw 调用 search_user_memory 吗？

P1（影响体验）：

7. □ Skill 是否支持工具气泡事件透传？
8. □ Skill 是否支持结构化 references（引用框）？
9. □ Skill 输出文件链接，主 Claw 客户端能直接打开吗？
10. □ Skill 是否支持渐进式灰度（按用户 / 按比例）？

P2（工程协作）：

11. □ Skill 部署形态：远调 vs SDK 嵌入？
12. □ Skill 监控日志怎么对齐主 Claw trace？
13. □ Skill prompt 热更新通道？
14. □ DLP / 计费 / 合规接入流程？
```

### 10.2 现状不动的代码清单

```
保留 0 改动：
├─ app/agent.py
├─ app/llm.py
├─ app/skills/*.md
├─ app/skills/_loader.py
├─ app/tools/*
├─ app/vfs/*
├─ app/utils/*
└─ app/claw_protocol/* （仅供 A2A 备用入口使用）

新增：
├─ app/skill_adapter/*

保留备用（可回滚）：
└─ app/agent_executor.py
```

### 10.3 相关文档

- 《Agent 拆 Skill 跨团队对齐材料.md》（本文方案 C 的扩展版）
- 《产品契约》（`app/skills/_product_contract.md`）
- 《主系统 prompt》（`app/skills/_system_prompt.md`）
- 《客户端引用框渲染需求文档.md》

---

## 决策建议

**方案核心要点**：
1. **一个大 skill 接入**，不拆分
2. **业务代码 0 改动**，只新增适配层
3. **A2A 入口保留备用**，确保可回滚
4. **关键卡点是 §10.1 的 6 个 P0 问题**，主 Claw 团队明确表态后才能动手

**当前需要决策的事项**：
- [ ] 是否采纳本方案？
- [ ] 是否同意先暂停所有 sub-agent 优化，集中处理 skill 化改造？
- [ ] 是否同意按本方案与主 Claw 团队约会议？
