# 三阶段流水线架构重构 - 面试亮点

> **核心价值**：针对 1100+ 行单体 `process()` 函数的可维护性危机，设计并落地了三阶段流水线架构（prepare → infer → finalize）+ TurnState 单一真值来源 + ModelSession 模型切换能力，将代码行数从 1100+ 行降至 ~10 行编排 + 3 个独立阶段函数，是复杂 Agent 系统架构重构的完整工程实践。

---

## 1. 核心概览

### 1.1 一句话摘要

面对 1100+ 行单体 `process()` 函数的可维护性危机，我把业务流程按职责拆成三阶段（prepare/infer/finalize），引入 TurnState 收敛 14 个散落局部变量，彻底消除 ExitException 控制流滥用，让 Agent 编排从"goto 式异常跳转"变成"线性阶段编排"。

### 1.2 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"如何重构复杂的 Agent 系统？"** | 三阶段流水线 + 单一真值来源的完整重构方法论 |
| **"如何管理复杂系统的状态？"** | TurnState 收敛 14 个局部变量 + 控制信号显式化 |
| **"如何消除控制流滥用？"** | ExitException → turn.stop() 的控制流重构 |
| **"如何保证重构过程中的行为等价？"** | 11 个 Task 分步提交 + 两个 PR 切分 + 冒烟测试 |

**可回答的经典面试题**：
- 如何重构一个 1000+ 行的函数？
- 如何管理复杂系统的状态一致性？
- 如何设计 Agent 的编排架构？
- 如何保证重构过程中的行为等价？

### 1.3 方案演进与关键决策

**演进时间线**（git 证据）：

```
阶段 1（2026-03 ~ 2026-05）：功能快速迭代期
  525+231 次提交，process() 从 300 行膨胀到 1100+ 行
      ↓ 认识到：单体函数难以维护，ExitException 控制流滥用
阶段 2（2026-06-30）：架构设计时刻
  设计文档 docs/plans/2026-06-30-agent-process-refactor.md（624 行）
      ↓ 三阶段流水线 + TurnState + RetryController 完整设计
阶段 3（2026-07-03）：架构实施时刻
  e2357451 "refactor(agent): Agent 循环架构重构——三阶段流水线 + 推理干预 Hook 层"
      ↓ 三阶段流水线正式落地，ExitException 彻底消除
```

**关键决策 1：三阶段划分，而不是两阶段或四阶段**

三阶段对应业务流程的自然分界：

| 阶段 | 职责 | 对应原阶段 |
|:---|:---|:---|
| prepare | 准备输入（工具集、提示词、运营干预） | 阶段 1-4 |
| infer | 核心推理（模型调用、验证、重试） | 阶段 5-6 |
| finalize | 输出处理（去重、推荐位、SSE 下发） | 阶段 7 |

**关键决策 2：TurnState 单一真值来源**

取代 14 个散落局部变量（assist_content/session_finished/tool_call_requests 等），杜绝"多处赋值 + 兜底覆盖"。

**关键决策 3：早退是数据不是异常**

彻底删除 ExitException，用 `turn.stop(reason=...)` 替代，控制流线性可读。

**淘汰的方案**：

| 淘汰方案 | 淘汰原因 |
|:---|:---|
| **两阶段划分** | prepare+infer 合并会导致 infer 过于庞大 |
| **五阶段划分** | 阶段间数据传递复杂，增加理解成本 |
| **直接传 model 对象** | 无法支持运行时模型切换 |
| **用字典存储状态** | 缺乏类型安全，IDE 支持差 |

---

## 2. 项目背景与问题定义

### 2.1 业务场景

pro_agent 是蓝心小V语音助手的中控服务，核心职责是接收用户指令、通过 LLM 进行意图理解与工具编排、以 SSE 流式协议返回结果。

```
用户: "定一个早上八点的闹钟"
    ↓
意图检索 → 召回 create_alarm 工具
    ↓
HostAgent.process() → 模型推理 → 工具调用
    ↓
SSE 流式返回 → 客户端执行工具
```

**系统特征**：
- 多轮对话：支持 5-20 轮对话
- 多工具调用：148 个工具，覆盖 13 个业务领域
- 流式响应：SSE 协议，实时返回文本和工具调用
- 运营干预：74 个 Patch 规则 + 4 个仲裁规则

### 2.2 问题分析

**体系化之前（2026-06-30 设计文档记录）的真实问题清单**：

| # | 问题 | 严重程度 | 具体表现 |
|---|---|---|---|
| 1 | `ExitException` 被当控制流（goto）使用 | **设计/可维护性** | 8 处 raise 跨 3 个方法层级，单点捕获，读者需跳到 600 行外的 except 才能理解后续 |
| 2 | 正常提前退出与真错误共用同一 `ExitException` | **设计** | 正常路径与异常路径无法区分 |
| 3 | `process()` 单方法约 650 行，三层嵌套 | **可维护性** | 混合早退判断、prompt 构建、推理循环、重试闸门、批校验、推荐位、持久化 |
| 4 | 本轮决策状态无单一真值来源 | **正确性/可调试性** | `session_finished`/`assist_content` 在每个 raise 点前手动赋值，退出后又从 `stream_result` 兜底读取 |
| 5 | `except FunctionNotRegisterException` 为死分支 | 死代码 | 全项目无任何 `raise FunctionNotRegisterException` |
| 6 | `StreamResult` 通过闭包写回 | 可读性 | 跨重试循环手动重建并保留 `has_emitted_text` |

**关键洞察**：
- 这些问题的根因是**控制流滥用**和**状态散落**
- 单层修复只能挡住一类问题，所以需要体系化重构
- **浪费**：每次新增功能都要在 1100+ 行的函数中小心翼翼

**三类失败模式的典型样本**：

```
失败模式 1：控制流滥用（ExitException 当 goto）
代码: if need_interact: raise ExitException()
问题: 正常业务逻辑用异常实现，读者需跳到 600 行外理解后续
后果: 可维护性极差，新增早退场景需要在多处添加 raise 和 except

失败模式 2：状态散落（14 个局部变量）
代码: assist_content = ""; session_finished = False; tool_call_requests = []
问题: 每个早退点都需要手动赋值这些变量
后果: "多处赋值 + 兜底覆盖"导致状态不一致

失败模式 3：正常退出与错误混用
代码: except ExitException: # 处理所有"正常退出"
问题: 异常堆栈无法区分"正常退出"和"真错误"
后果: 调试困难，日志无法区分业务逻辑和真实错误
```

### 2.3 优化目标

**核心问题**：如何将 1100+ 行的单体函数重构为清晰、可维护、可扩展的架构？

**量化目标**：
- process() 行数从 1100+ 行降至 ~10 行编排
- ExitException 引用从 8 处降至 0 处
- 局部变量从 14 个收敛为 1 个 TurnState
- 可独立测试的模块从 0 个增加到 3 个阶段函数

---

## 3. 技术方案设计

### 3.1 核心思路

**三阶段流水线 + 单一真值来源**（命名直接来自设计文档"范式内核：三条支柱"）：

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

**关键挑战**：
1. 如何划分阶段？边界如何确定？
2. 如何管理阶段间的状态传递？
3. 如何处理早退和错误？
4. 如何保证重构过程中的行为等价？

### 3.2 三阶段职责规则表

**设计原则**：三阶段的职责边界清晰——每个阶段只做一类事情

| 阶段 | 输入 | 职责 | 输出 | 可能 stop |
|:---|:---|:---|:---|:---|
| **prepare** | body, context | 准备输入（工具集、提示词、运营干预） | turn.tools, turn.tool_list | need_exit, schedule_shortcut |
| **infer** | turn.tools, turn.tool_list | 核心推理（模型调用、验证、重试） | turn.assist_content, turn.tool_call_requests | stream error |
| **finalize** | turn 全部终态字段 | 输出处理（去重、推荐位、SSE 下发） | SSE 事件流 | 不 |

---

## 4. 核心实现细节

### 4.1 TurnState：单轮唯一真值

**实现位置**：`agent/pro/turn_state.py`（81 行）

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

**关键设计**：
- `stop()` 方法支持 overrides，一次性写入终态字段
- `set_error()` 区分业务错误和未预期崩溃
- `stat` 字段内嵌埋点收集器，各阶段独立写入

### 4.2 ModelSession：模型会话

**实现位置**：`agent/pro/model_session.py`（48 行）

```python
class ModelSession:
    """持有当前模型实例并提供切换能力。引用共享，切换后各阶段读到即新模型。"""
    
    def __init__(self, model: Model):
        self.model = model

    def switch(self, target_model_type: str) -> bool: