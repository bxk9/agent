    patch_prompt_snippets: list = field(default_factory=list)
    reminder_facts: list = field(default_factory=list)
    assist_content: str = ""
    tool_call_requests: list = field(default_factory=list)
    session_finished: bool = False
    enable_voice: bool = False
    mcp_tools: list = field(default_factory=list)
    should_stop: bool = False
    stop_reason: str = ""
    error: dict = field(default_factory=dict)
```

**详细解释**：
- dataclass 提供类型提示，IDE 可以自动补全和类型检查
- dataclass 自动生成 `__init__`、`__repr__`、`__eq__` 等方法，减少样板代码
- dataclass 支持 `field(default_factory=list)`，避免可变默认值陷阱
- dict 没有类型提示，IDE 无法自动补全，容易拼写错误

**处理逻辑**：
```
输入: TurnState 实例
访问: turn.query（IDE 自动补全，类型检查）
输入: dict 实例
访问: turn["query"]（无自动补全，容易拼写错误为 turn["qeury"]）
```

### 2.2.2 为什么早退用 turn.stop() 而不是 raise ExitException（真实原因）

**来源**：设计文档 - `docs/plans/2026-06-30-agent-process-refactor.md`

**设计文档原文**：
```
早退是数据不是异常：
- 彻底删除 ExitException
- 用 turn.stop(reason=...) 替代
- 早退是"正常业务逻��"，不是"异常"
```

**详细解释**：
- 旧代码中 `ExitException` 被当控制流（goto）使用，8 处 raise 跨 3 个方法层级
- 正常提前退出与真错误共用同一 `ExitException`，无法区分
- 异常应该用于"异常情况"，而不是"正常业务逻辑"
- turn.stop() 明确表示"早退是正常业务逻辑"，而不是"异常"

**处理逻辑**：
```
重构前：if need_interact: raise ExitException()
       → 正常业务逻辑用异常实现
       → 读者需要跳到 600 行外的 except 块才能理解"正常退出"后做什么
重构后：if need_interact: turn.stop("need_interact")
       → 正常业务逻辑用数据表示
       → 读者在当前行就能理解"早退"的含义
```

### 2.2.3 为什么需要 ModelSession（真实原因）

**来源**：代码注释 - `agent/pro/model_session.py`

**代码注释原文**：
```python
class ModelSession:
    """
    模型会话管理
    
    设计动机：
    - 阶段函数真正依赖的只是「模型能力」，而不是「模型实例」
    - 如果直接传递模型实例，阶段函数会依赖具体的模型类
    - 通过 ModelSession 抽象，阶段函数只依赖「模型能力」，不依赖具体的模型类
    - 支持运行时切换模型（如 Flash → Pro）
    """
```

**详细解释**：
- 阶段函数真正依赖的只是"模型能力"（stream/complete），而不是"模型实例"
- 如果直接传递模型实例，阶段函数会依赖具体的模型类（XuanjiModel/OpenAIModel）
- 通过 ModelSession 抽象，阶段函数只依赖"模型能力"，不依赖具体的模型类
- 支持运行时切换模型（如 Flash → Pro），只需修改 ModelSession.model，无需修改阶段函数

**业务场景**：
```
场景 1：Flash 模型幻觉，验证器 RETRY
  → RetryController 决定切换到 Pro 模型
  → 只需修改 session.model = pro_model
  → 下一次推理自动使用 Pro 模型
  → 无需修改阶段函数

场景 2：Mock query 场景切换到 Pro 模型
  → prepare 阶段检测到 mock query
  → 只需修改 session.model = pro_model
  → infer 阶段自动使用 Pro 模型
  → 无需修改阶段函数
```

### 2.2.4 为什么需要 RetryController（真实原因）

**来源**：设计文档 - `docs/plans/2026-06-30-agent-process-refactor.md`

**设计文档原文**：
```
RetryController：重试控制器
- 管理三套重试机制：验证器 RETRY、空响应兜底、流式安全约束
- 双闸门机制：全局闸门（retry_count < max_retry）+ per-tag 闸门（tag not in seen_tags）
- 防止无限重试循环
```

**详细解释**：
- 旧代码中重试逻辑散落在 process() 中，难以理解和维护
- 三套重试机制（验证器 RETRY、空响应兜底、流式安全约束）各自独立，容易遗漏
- RetryController 统一管理三套重试机制，提供清晰的 API
- 双闸门机制防止无限重试循环：全局闸门限制总重试次数，per-tag 闸门防止同一类型错误无限重试

**处理逻辑**：
```
场景：Flash 模型幻觉 setting_name
  → 验证器 RETRY，tag="flash_hallucination"
  → RetryController.accept(signal)
  → 检查全局闸门：retry_count < max_retry（默认 1 次）
  → 检查 per-tag 闸门：tag not in seen_tags
  → 通过双闸门，接受重试
  → retry_count += 1，seen_tags.add(tag)
  → 切换到 Pro 模型，重新推理

场景：Pro 模型也幻觉 setting_name
  → 验证器 RETRY，tag="flash_hallucination"
  → RetryController.accept(signal)
  → 检查全局闸门：retry_count < max_retry（retry_count=1，不通过）
  → 或者检查 per-tag 闸门：tag in seen_tags（不通过）
  → 拒绝重试，降级放行
  → 避免无限重试循环
```

## 2.3 性能与质量原因

### 2.3.1 为什么 geocode 改为串行 await（真实原因）

**来源**：设计文档 - `docs/plans/2026-06-30-agent-process-refactor.md`

**设计文档原文**：
```
geocode 决策（2026-06-30）：
- 经纬度反查改为串行 await + 保留缓存（方案 2）
- 理由：并行预取优化的是「单请求延迟」而非「服务吞吐」
- 高流量下 asyncio 靠并发请求已填满资源，单请求内并行对 QPS 无提升
- 其唯一价值是隐藏 reverse_geocode 的 RTT
- 权衡该 RTT 量级与 create_task/cancel 的复杂度后，简化为 prepare 阶段内同步完成
```

**详细解释**：
- 旧代码中 geocode 使用并行预取（create_task），试图隐藏 reverse_geocode 的 RTT
- 但并行预取优化的是"单请求延迟"，而不是"服务吞吐"
- 高流量下 asyncio 靠并发请求已填满资源，单请求内并行对 QPS 无提升
- reverse_geocode 的 RTT 通常只有 50-100ms，create_task/cancel 的复杂度不值得
- 简化为 prepare 阶段内同步完成：命中缓存则复用、否则 await 反查

**量化示例**：
```
并行预取方案：
  - create_task(reverse_geocode)
  - 其他逻辑执行
  - await geocode_task
  - 复杂度：需要处理 task 取消、异常传播
  - 收益：隐藏 50-100ms RTT

串行 await 方案：
  - if cache_hit: use cache
  - else: await reverse_geocode
  - 复杂度：简单直接
  - 收益：代码简洁，易于理解和维护
```

### 2.3.2 为什么分两个 PR 提交（真实原因）

**来源**：设计文档 - `docs/plans/2026-06-30-agent-process-refactor.md`

**设计文档原文**：
```
执行顺序：
- Task 1-6 是行为等价的控制流改造（TurnState 先行，让早退/停止/错误都有唯一归宿）
- 必须先完成并充分回归
- Task 7-11 是纯结构抽取（四阶段做成 _stage_* 标准模块）
- 在前者稳定后进行
- PR 切分点：Task 6 完成后，ExitException 已消除、行为等价已达成
```

**详细解释**：
- PR 1（Task 1-6）是行为等价的控制流改造，风险高（改变程序行为）
- PR 2（Task 7-11）是纯结构抽取，风险低（纯重构，不改变行为）
- 如果全在一个 PR 中，一旦出问题难以定位是控制流改造还是结构抽取导致的
- 分两个 PR 提交，降低风险，便于回滚

**处理逻辑**：
```
PR 1（Task 1-6）：控制流改造
  - Task 1：新增 TurnState
  - Task 2：process() 使用 TurnState
  - Task 3：_stream_model_response 使用 TurnState
  - Task 4：_prepare_tool_call_requests 使用 TurnState
  - Task 5：消除 ExitException（阶段 4）
  - Task 6：消除 ExitException（阶段 6）
  - 风险：高（改变程序行为）
  - 验证：充分回归测试

PR 2（Task 7-11）：结构抽取
  - Task 7：抽取 _stage_prepare
  - Task 8：抽取 _stage_infer
  - Task 9：抽取 _stage_finalize
  - Task 10：删除 process() 中的旧代码
  - Task 11：更新文档
  - 风险：低（纯重构，不改变行为）
  - 验证：简单回归测试
```

## 2.4 工程实现原因

### 2.4.1 为什么阶段函数是纯函数（真实原因）

**来源**：设计文档 - `docs/plans/2026-06-30-agent-process-refactor.md`

**设计文档原文**：
```
阶段函数是纯函数：
- 输入：TurnState + 其他参数
- 输出：修改 TurnState
- 不依赖外部状态，不修改外部状态
- 易于测试和调试
```

**详细解释**：
- 阶段函数是纯函数，输入是 TurnState + 其他参数，输出是修改 TurnState
- 不依赖外部状态，不修改外部状态
- 易于测试和调试：可以单独测试每个阶段函数，无需启动整个系统
- 易于理解和维护：每个阶段函数的职责清晰，输入输出明确

**处理逻辑**：
```
纯函数示例：
  async def _stage_prepare(turn: TurnState, session: ModelSession, body: dict, context: AgentContext):
      # 输入：turn + session + body + context
      # 输出：修改 turn
      # 不依赖外部状态，不修改外部状态
      turn.tools = build_tool_list(body)
      turn.tool_list = build_tool_definitions(turn.tools)
      # ...

非纯函数示例：
  async def _stage_prepare(body: dict, context: AgentContext):
      # 依赖外部状态：self.session, self.tool_registry
      # 修改外部状态：self.tools, self.tool_list
      # 难以测试和调试
      self.tools = self.tool_registry.build_tool_list(body)
      self.tool_list = self.tool_registry.build_tool_definitions(self.tools)
      # ...
```

### 2.4.2 为什么 Hook 机制用装饰器而不是配置文件（合理推断）

**详细解释**：
- Hook 需要编写 Python 逻辑（如判断 is_first_panel、修改 chat_history）
- 配置文件无法表达这些逻辑
- 装饰器方式更简洁，代码即配置
- 注册即生效，无需手动实例化

**处理逻辑**：
```
装饰器方式（当前实现）：
  @register_pre_hook
  def panel_stale_hook(ctx: PreInferContext):
      if ctx.is_first_panel and ctx.chat_history:
          ctx.chat_history[:] = [msg for msg in ctx.chat_history if not is_stale(msg)]

配置文件方式（未采用）：