        """切换到指定的模型类型，返回 True 表示确实发生了切换"""
        if not target_model_type:
            return False
        _target_name = model_registry.resolve(target_model_type)
        _current_name = getattr(self.model, 'model_name', '')
        if _target_name == _current_name:
            return False
        try:
            self.model = model_registry.create_model(target_model_type)
        except ValueError as e:
            logger.warning(f"[ModelSession.switch] 切换失败: {e}")
            return False
        return True
```

**关键设计**：
- 引用共享：切换后各阶段读到即新模型，无需回传
- 支持运行时切换：Flash 幻觉时切换到 Pro 模型

### 4.3 RetryController：重试引擎

**实现位置**：`agent/pro/retry_controller.py`

```python
class RetryController:
    """管理三套重试机制：验证器 RETRY / 空响应兜底 / 流式安全约束"""
    
    def __init__(self):
        self.retry_count = 0
        self.tool_list = []
        self.extra_system_prompts = []
        self._seen_tags = set()
        self._empty_fallback_count = 0

    def can_retry(self, has_emitted: bool) -> bool:
        """判断是否可以重试"""
        if has_emitted:
            return False  # 已 yield 文本 token，禁止回退
        if self.retry_count >= common_config.get("tool_validate_retry_max", 1):
            return False
        return True

    def accept(self, signal: RetryInferenceSignal) -> bool:
        """接受重试信号，更新工具列表和系统提示词"""
        if signal.hint.tag in self._seen_tags:
            return False  # tag 已见过，防循环
        self._seen_tags.add(signal.hint.tag)
        self.retry_count += 1
        
        # 应用 drop_tools
        if signal.hint.drop_tools:
            self.tool_list = [t for t in self.tool_list 
                             if t["name"] not in signal.hint.drop_tools]
        
        # 应用 extra_system_prompt
        if signal.hint.extra_system_prompt:
            self.extra_system_prompts.append(signal.hint.extra_system_prompt)
        
        return True
```

**三套重试机制**：
- **验证器 RETRY**：校验器返回 RETRY 时回滚并重新推理
- **空响应兜底**：Flash 静默退出时切 Pro 重推
- **流式安全约束**：已 yield 文本 token 则禁止回退

### 4.4 完整处理流程

```python
# agent/pro/agent.py

class HostAgent:
    def __init__(self, model: Model):
        self.session = ModelSession(model)

    async def process(self, body=None, context=None):
        """单轮编排主入口：TurnState 单一真值 + 阶段流水线 + try/finally 收口。"""
        turn = TurnState()
        if context is None:
            context = AgentContext(**(body.get("context", {}) or {}) if body else {})

        try:
            try:
                await _stage_prepare(turn, self.session, body, context)
                if not turn.should_stop:
                    async for sse in _stage_infer(turn, self.session, body, context):
                        yield sse
            except asyncio.CancelledError:
                turn.set_error({...ClientDisconnect...})
                raise
            except Exception as e:
                turn.set_error({...AgentProcessError...})

            if turn.error:
                yield "event:error\ndata:" + json.dumps(turn.error) + "\n\n"

            async for sse in _stage_finalize(turn, body, context):
                yield sse
        finally:
            write_stat_log(build_trace_data(turn, body, context))
            self._cleanup(turn)
```

### 4.5 边界 case 处理

**Case 1：客户端断连**
```
场景: 用户关闭页面，客户端断开连接
处理: asyncio.CancelledError → turn.set_error(ClientDisconnect) → re-raise
结果: 统一错误处理，埋点数据完整记录
```

**Case 2：未预期崩溃**
```
场景: 代码 bug 导致未预期异常
处理: except Exception → turn.set_error(AgentProcessError)
结果: 错误信息下发给客户端，埋点数据完整记录
```

**Case 3：正常早退**
```
场景: need_exit=True，工具声明 EXIT
处理: turn.stop("need_exit", session_finished=True)
结果: 跳过 infer 阶段，直接进入 finalize
```

**Case 4：模型切换**
```
场景: Flash 模型幻觉，验证器 RETRY
处理: session.switch("pro") → 切换到 Pro 模型
结果: 重试时使用 Pro 模型，避免幻觉
```

---

## 5. 效果评估与优化

### 5.1 代码规模对比

| 指标 | 重构前 | 重构后 | 改进 |
|---|---|---|---|
| **process() 行数** | 1100+ 行 | ~10 行编排 | -99% |
| **ExitException 引用** | 8 处 | 0 处 | -100% |
| **局部变量数** | 14 个 | 1 个 TurnState | -93% |
| **可独立测试的模块** | 0 个 | 3 个阶段 | +3 |

### 5.2 可扩展性验证

```
新增场景：推理干预层（Hook 机制）
  → 在 prepare 阶段添加 PreInfer Hook
  → 在 infer 阶段添加 PostInfer Hook
  → 无需修改主流程代码
  → 新增场景成本从"修改 1100 行函数"降至"添加 Hook 文件"
```

---

## 6. 技术亮点总结

### 6.1 创新性

1. **三阶段流水线**：prepare → infer → finalize，职责清晰，可独立测试
2. **TurnState 单一真值**：收敛 14 个散落局部变量，杜绝"多处赋值 + 兜底覆盖"
3. **早退是数据不是异常**：`turn.stop()` 替代 `raise ExitException()`，控制流线性可读

### 6.2 技术深度

1. **11 个 Task 分步提交**：每个 Task 保持行为等价，降低重构风险
2. **两个 PR 切分**：PR1 控制流改造，PR2 结构抽取
3. **冒烟测试验证**：每个 Task 后用场景 query 验证行为等价

### 6.3 业务价值

1. **可维护性提升**：process() 从 1100+ 行降至 ~10 行编排
2. **可扩展性提升**：新增场景无需修改主流程代码
3. **开发效率提升**：定位问题从"在 1100 行中找"降至"在对应阶段中找"

### 6.4 方法论抽象与迁移

**抽象出的通用方法论——"复杂函数重构三步法"**：

1. **识别职责边界**：按业务流程的自然分界划分阶段
2. **收敛状态**：引入单一真值对象，取代散落局部变量
3. **显式化控制流**：用数据替代异常，控制流线性可读

**可迁移场景**：

| 场景 | 迁移点 |
|:---|:---|
| 复杂 Web 服务 | 请求处理 → 多阶段流水线 |
| 数据处理管道 | ETL 流程 → 多阶段流水线 |
| 工作流引擎 | 任务编排 → 多阶段流水线 |

---

## 7. 面试问答准备

### Q1: 为什么是三阶段，不是两阶段或四阶段？

**A**：
1. 三阶段对应业务流程的自然分界：准备输入、核心推理、输出处理
2. 两阶段会漏：prepare+infer 合并会导致 infer 过于庞大
3. 四阶段没必要：三阶段职责已清晰，加层只增加复杂度
4. 实证：原代码已有阶段 1-7 的注释横幅，合并为 3 个阶段是最佳平衡

### Q2: 为什么用 dataclass 而不是字典？

**A**：
1. 类型安全：IDE 可以提供自动补全和类型检查
2. 默认值：`field(default_factory=list)` 避免可变默认值陷阱
3. 文档化：字段定义本身就是文档
4. 轻量级：比 Pydantic BaseModel 更轻量，无需序列化

### Q3: 如何保证重构过程中的行为等价？

**A**：
1. 分步提交：11 个 Task，每个 Task 保持行为等价
2. 两个 PR：PR1 控制流改造，PR2 结构抽取
3. 冒烟测试：每个 Task 后用场景 query 验证
4. 逐处对照：8 处 raise 逐行改造，不遗漏

### Q4: TurnState 的线程安全性如何保证？

**A**：
1. Python 的 asyncio 是单线程事件循环，同一时刻只有一个协程在执行
2. TurnState 的生命周期是单轮请求，请求结束后即销毁
3. 不存在并发写入问题

### Q5: 这个方法论能迁移到什么场景？

**A**：
1. 任何"复杂函数需要重构"的场景：Web 服务、数据处理管道、工作流引擎
2. 迁移要点：识别职责边界 → 收敛状态 → 显式化控制流
3. 反例警示：不分阶段会导致函数膨胀，不收敛状态会导致状态不一致

---

## 8. 代码文件索引

- `agent/pro/agent.py`：HostAgent 薄壳编排器（108 行）
- `agent/pro/turn_state.py`：TurnState 单轮状态（81 行）
- `agent/pro/model_session.py`：ModelSession 模型会话（48 行）
- `agent/pro/retry_controller.py`：RetryController 重试引擎
- `agent/pro/stage_prepare.py`：准备阶段（353 行）
- `agent/pro/stage_infer.py`：推理阶段（613 行）
- `agent/pro/stage_finalize.py`：收尾阶段（141 行）
- `docs/plans/2026-06-30-agent-process-refactor.md`：设计文档（624 行）

---

## 9. 总结

三阶段流水线架构重构是一个典型的**复杂系统架构重构工程案例**，展示了：

1. **问题抽象能力**：从 6 类问题中归纳出控制流滥用和状态散落两个根因
2. **体系化设计**：三阶段流水线 + TurnState 单一真值 + RetryController 重试引擎
3. **工程落地能力**：11 个 Task 分步提交 + 两个 PR 切分 + 冒烟测试验证
4. **方法论沉淀**：可迁移到任何复杂函数重构场景

**一句话总结**：针对 1100+ 行单体函数的可维护性危机，设计三阶段流水线架构 + TurnState 单一真值来源，将代码行数从 1100+ 行降至 ~10 行编排，是复杂 Agent 系统架构重构的完整工程实践。

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-11 | 首次建立 |
| v2.0 | 2026-08-14 | 参照三层防御示例标准全面改写：补充核心概览、失败模式分析、边界 case、面试问答、代码文件索引 |
