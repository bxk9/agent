# 三阶段流水线架构重构

> 面试价值：⭐⭐⭐⭐⭐ | 技术深度：⭐⭐⭐⭐⭐ | 业务影响：⭐⭐⭐⭐⭐

## 一句话总结

将 1100+ 行的单体 `process()` 函数重构为三阶段流水线（prepare → infer → finalize），引入 TurnState 单一真值来源和 RetryController 重试引擎，彻底消除 `ExitException` 控制流滥用，使代码可维护性、可测试性和可扩展性全面提升。

---

## 1. 问题背景

### 1.1 业务场景

pro_agent 是蓝心小V语音助手的中控服务，核心职责是接收用户指令、通过 LLM 进行意图理解与工具编排、以 SSE 流式协议返回结果。每轮请求的处理逻辑集中在 `HostAgent.process()` 方法中。

### 1.2 技术痛点

随着业务迭代，`process()` 方法膨胀到 **1100+ 行**，暴露出严重的架构问题：

| # | 问题 | 严重程度 | 影响 |
|---|---|---|---|
| 1 | `ExitException` 被当控制流（goto）使用，8 处 raise 跨 3 个方法层级 | **设计缺陷** | 读者需跳到 600 行外的 except 才能理解后续 |
| 2 | 正常提前退出与真错误共用同一 `ExitException` | **设计缺陷** | 正常路径与异常路径无法区分 |
| 3 | 单方法 650 行，三层嵌套 `try / while True / try` | **可维护性** | 混合早退判断、prompt 构建、推理循环、重试闸门 |
| 4 | 本轮决策状态无单一真值来源：14 个跨阶段局部变量，130 处散落引用 | **正确性** | "多处赋值 + 兜底覆盖"导致状态不一致 |
| 5 | `except FunctionNotRegisterException` 为死分支 | **死代码** | 全项目无任何 raise |
| 6 | `StreamResult` 通过闭包写回，跨重试循环手动重建 | **可读性** | 状态传递不透明 |

### 1.3 核心矛盾

**"早退是数据不是异常"** —— 但在旧架构中，所有提前退出（任务完成、已上屏、需交互、工具声明 EXIT）都通过 `raise ExitException()` 实现，导致：
- 正常业务路径被异常机制承载
- 每个早退点都需要手动赋值状态变量
- 异常处理块中塞满了业务逻辑

---

## 2. 技术方案

### 2.1 设计思路

**三条支柱**：

1. **单一真值来源**：`TurnState` 承载本轮全部演进状态 + 控制信号，任何阶段只写这一个对象
2. **早退是数据不是异常**：彻底删除 `ExitException`，阶段内要早退就 `turn.stop(reason=...)`
3. **收口与清理由结构保证**：`try / except Exception / finally` 包裹流水线，保证任何路径退出都执行收口

### 2.2 架构总览

```
HostAgent.process()  # 薄壳编排器（~10 行）
    │
    ├─ _stage_prepare(turn, session, body, context)
    │   输入解析 → 工具集构建 → Patch/彩蛋/仲裁 → geocode → 工具结果后处理
    │   产出：turn.tools, turn.tool_list, turn.patch_prompt_snippets
    │   可能 turn.stop：need_exit / schedule_shortcut
    │
    ├─ _stage_infer(turn, session, body, context)  # if not turn.should_stop
    │   构建 system_prompt → 推理-校验-重试循环 → 解析工具调用
    │   产出：turn.assist_content, turn.tool_call_requests
    │   内含 RetryController 管理三套重试机制
    │
    └─ _stage_finalize(turn, body, context)
        上屏合并 → session 去重 → 推荐位 → emit SSE → 持久化
        产出：SSE 事件流
```

### 2.3 核心对象设计

#### TurnState：单轮唯一真值

```python
@dataclass
class TurnState:
    """单轮编排的决策状态——本轮所有"最终要下发什么"的唯一真值来源。"""
    # ---- 数据字段（本轮演进状态）----
    query: str = ""
    chat_history: list = field(default_factory=list)
    tools: list = field(default_factory=list)
    tool_list: list = field(default_factory=list)
    assist_content: str = ""
    tool_call_requests: list = field(default_factory=list)
    session_finished: bool = False
    # ... 更多字段

    # ---- 控制信号（取代 ExitException）----
    should_stop: bool = False
    stop_reason: str = ""
    error: dict | None = None

    # ---- 埋点数据收集 ----
    stat: StatCollector = field(default_factory=StatCollector)

    def stop(self, reason: str, **overrides) -> None:
        """标记本轮提前结束；overrides 就地写入终态字段"""
        self.should_stop = True
        self.stop_reason = reason
        for k, v in overrides.items():
            setattr(self, k, v)

    def set_error(self, payload: dict) -> None:
        """记录未预期崩溃/业务错误载荷"""
        self.error = payload
        self.session_finished = True
```

**设计要点**：
- `stop()` 方法支持 overrides，一次性写入终态字段
- `set_error()` 区分业务错误和未预期崩溃
- `stat` 字段内嵌埋点收集器，各阶段独立写入

#### ModelSession：模型会话

```python
class ModelSession:
    """持有当前模型实例并提供切换能力。引用共享，切换后各阶段读到即新模型。"""
    def __init__(self, model: Model):
        self.model = model

    def switch(self, target_model_type: str) -> bool:
        """切换到指定的模型类型，返回 True 表示确实发生了切换"""
```

**设计动机**：阶段函数真正依赖的只是"模型能力"，而非整个 HostAgent 实例。此前把 self/agent 整体传入各阶段，导致依赖被放大。

#### RetryController：重试引擎

```python
class RetryController:
    """管理三套重试机制：验证器 RETRY / 空响应兜底 / 流式安全约束"""
    def can_retry(self, has_emitted: bool) -> bool
    def accept(self, signal: RetryInferenceSignal) -> bool
    def try_empty_fallback(self, session: ModelSession) -> bool
    def build_messages(self, system_prompt, chat_history, ...)
```

**三套机制**：
- **验证器 RETRY**：校验器返回 RETRY 时回滚并重新推理，RetryHint 携带 drop_tools/extra_system_prompt
- **空响应兜底**：Flash 静默退出时切 Pro 重推
- **流式安全约束**：已 yield 文本 token 则禁止回退

### 2.4 阶段函数契约

每个阶段函数都是**纯函数**，依赖通过显式参数传入：

| 阶段 | 签名 | 消费 turn 字段 | 产出 turn 字段 | 可能 stop |
|---|---|---|---|---|
| prepare | `(turn, session, body, context) → None` | body, context | tools, tool_list, patch_prompt_snippets | need_exit |
| infer | `(turn, session, body, context) → AsyncGenerator` | tools, tool_list | assist_content, tool_call_requests | stream error |
| finalize | `(turn, body, context) → AsyncGenerator` | 全部终态字段 | SSE 事件流 | 不 |

---

## 3. 实现细节

### 3.1 重构步骤（11 个 Task，严格按序）

重构分为两个 PR，每个 Task 保持行为等价：

**PR 1：控制流改造（Task 1-6）**

| Task | 内容 | 关键改动 |
|---|---|---|
| 1 | StreamResult 增加 should_stop 字段 | 为流式层提供显式终止信号 |
| 2 | `_stream_model_response` 的 raise → return | 4 处 `raise ExitException()` → `return` |
| 3 | 推理循环消费端适配 should_stop | `if stream_result.should_stop: break` |
| 4 | 新建 TurnState 并引入 process | 14 个局部变量 → TurnState 字段 |
| 5 | `_prepare_tool_call_requests` 兜底失败改为返回终止标记 | `return [], True` |
| 6 | 阶段4 早退改为 turn.stop + try/finally + 删除 ExitException | **核心步骤** |

**PR 2：结构抽取（Task 7-11）**

| Task | 内容 |
|---|---|
| 7 | 抽取 `_stage_post_process_and_early_exit` |
| 8 | 抽取 `_stage_build_input` |
| 9 | 抽取 `_stage_inference_loop` |
| 10 | 抽取 `_stage_finalize` |
| 11 | 文档与注释收尾 |

### 3.2 关键代码：process() 目标骨架

```python
async def process(self, body=None, context=None):
    turn = TurnState()
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
    # finally: write_stat_log + cleanup
```

**对比旧架构**：
- 旧：1100 行单体函数，8 处 raise ExitException，14 个散落局部变量
- 新：~10 行编排 + 3 个独立阶段函数 + 1 个 TurnState

### 3.3 关键代码：RetryController 重试引擎

```python
class RetryController:
    def __init__(self):
        self.retry_count = 0
        self.tool_list = []
        self.extra_system_prompts = []
        self._seen_tags = set()
        self._empty_fallback_count = 0

    def accept(self, signal: RetryInferenceSignal) -> bool:
        if signal.hint.tag in self._seen_tags:
            return False  # tag 去重，防循环
        self._seen_tags.add(signal.hint.tag)
        self.retry_count += 1
        
        if signal.hint.drop_tools:
            self.tool_list = [t for t in self.tool_list 
                             if t["name"] not in signal.hint.drop_tools]
        if signal.hint.extra_system_prompt:
            self.extra_system_prompts.append(signal.hint.extra_system_prompt)
        return True

    def build_messages(self, system_prompt, chat_history, ...):
        messages = [{"role": "system", "content": system_prompt}]
        for prompt in self.extra_system_prompts:
            messages.append({"role": "system", "content": prompt})
        messages.extend(chat_history)
        return messages
```

### 3.4 边界处理

| 场景 | 处理方式 |
|---|---|
| 客户端断连 | `asyncio.CancelledError` → `turn.set_error(ClientDisconnect)` → re-raise |
| 未预期崩溃 | `except Exception` → `turn.set_error(AgentProcessError)` |
| 业务错误 | `turn.error` → finalize 前 yield error 事件 |
| 正常早退 | `turn.stop(reason)` → 跳过 infer → 直接 finalize |
| 流式已发射 | `has_emitted=True` → 禁止重试回退 |

---

## 4. 技术亮点

### 4.1 创新点
