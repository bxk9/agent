# 推理干预层设计 - 面试亮点

> **核心价值**：针对"场景化地在推理前后做定点干预"的需求膨胀问题，设计并落地了两段式 Hook 机制（PreInfer/PostInfer）+ 自注册 + 异常隔离 + 原地修改约定，将干预逻辑从主流程中完全解耦，新增干预场景从"修改主流程代码"降至"添加 Hook 文件"，是可扩展性设计的完整工程实践。

---

## 1. 核心概览

### 1.1 一句话摘要

面对"场景化地在推理前后做定点干预"的需求膨胀，我把干预逻辑按推理前后拆成两段式 Hook（PreInfer/PostInfer），通过自注册、异常隔离、原地修改约定，实现主流程与场景化规则的完全解耦，让新增干预场景无需修改主流程代码。

### 1.2 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"如何设计可扩展的插件机制？"** | 两段式 Hook + 自注册 + 异常隔离的完整设计 |
| **"如何解耦主流程与场景化规则？"** | Hook 层与主流程的职责边界划分 |
| **"如何保证插件异常不影响主流程？"** | 异常隔离 + 降级策略 |
| **"如何设计插件间的数据传递？"** | 原地修改约定 + Context 共享引用 |

**可回答的经典面试题**：
- 如何设计一个可扩展的插件系统？
- 如何解耦核心逻辑与业务规则？
- 如何保证插件异常不影响主流程？
- 如何设计插件间的数据传递机制？

### 1.3 方案演进与关键决策

**演进时间线**（git 证据）：

```
阶段 1（2026-03 ~ 2026-06）：干预需求膨胀期
  面板态首轮清理、多工具末条注入、个性化提示词等需求不断涌现
      ↓ 认识到：干预逻辑散落在主流程各处，新增场景需修改核心代码
阶段 2（2026-07-02）：架构设计时刻
  设计文档 docs/plans/2026-07-02-infer-hook-layer.md（19170 字）
      ↓ 两段式 Hook + 自注册 + 异常隔离完整设计
阶段 3（2026-07-03）：架构实施时刻
  e2357451 "refactor(agent): Agent 循环架构重构——三阶段流水线 + 推理干预 Hook 层"
      ↓ 推理干预层正式落地，主流程与场景化规则完全解耦
```

**关键决策 1：两段式 Hook，而不是单段式**

两段式对应干预时机的自然分界：

| 段 | Context | 干预产物 | 集成点 |
|:---|:---|:---|:---|
| **PreInfer** | `PreInferContext` | 改 `chat_history` / 追加 `system_prompt` | `_stage_prepare` 推理前 |
| **PostInfer** | `PostInferContext` | 改 `tool_call`（如注入上屏指令） | `_post_process_tool_results` |

**关键决策 2：原地修改约定**

Context 的可变字段只能原地修改（`ctx.chat_history[:] = [...]`），不得整体替换——主流程与其共享同一对象引用，整体替换会被静默丢弃。

**关键决策 3：异常隔离**

单个 Hook 异常不影响其他 Hook 和主流程，保证系统稳定性。

**淘汰的方案**：

| 淘汰方案 | 淘汰原因 |
|:---|:---|
| **单段式 Hook** | 推理前/后干预目标不同，单段式需要在 Hook 内部判断时机 |
| **返回值传递** | 需要显式回写，容易遗漏，多个 Hook 时复杂度高 |
| **配置文件驱动** | Hook 需要编写 Python 逻辑，配置文件无法表达 |
| **类继承方式** | 代码冗长，需要定义类、实例化，装饰器更简洁 |

---

## 2. 项目背景与问题定义

### 2.1 业务场景

pro_agent 需要支持多种场景化的推理干预需求：

```
场景 1：面板态首轮清理过期历史
  用户打开面板后，历史中可能包含过期的工具调用（如昨天的闹钟）
  → 需要在推理前清理过期历史，避免模型被过期信息干扰

场景 2：多工具末条注入上屏指令
  用户请求包含多个工具调用（如"定闹钟并查天气"）
  → 需要在最后一个工具执行完成后，注入上屏指令引导模型总结

场景 3：个性化提示词注入
  特定用户群体需要个性化提示词
  → 需要在推理前追加个性化提示词
```

**系统特征**：
- 干预场景多样：清理历史、注入指令、个性化提示词等
- 干预时机不同：推理前（修改输入）、推理后（修改输出）
- 干预逻辑复杂：需要编写 Python 逻辑，无法用配置文件表达

### 2.2 问题分析

**体系化之前（2026-07-02 设计文档记录）的真实问题清单**：

| # | 问题 | 严重程度 | 具体表现 |
|---|---|---|---|
| 1 | 干预逻辑散落在主流程各处 | **可维护性** | 新增场景需修改主流程，风险高 |
| 2 | 不同场景的干预规则相互耦合 | **可扩展性** | 修改一个场景可能影响其他场景 |
| 3 | 异常处理不统一 | **稳定性** | 单个场景异常可能中断整个推理 |
| 4 | 干预时机不明确 | **可理解性** | 难以判断干预发生在推理前还是推理后 |

**关键洞察**：
- 这些问题的根因是**主流程与场景化规则耦合**
- 单层修复只能挡住一类问题，所以需要体系化解耦
- **浪费**：每次新增干预场景都要修改主流程代码

**三类失败模式的典型样本**：

```
失败模式 1：干预逻辑散落
代码: if is_first_panel: chat_history = [msg for msg in chat_history if not is_stale(msg)]
问题: 清理逻辑写在主流程中，新增清理场景需修改主流程
后果: 主流程膨胀，难以维护

失败模式 2：场景间相互耦合
代码: if is_first_panel and need_custom_prompt: ...
问题: 两个场景的逻辑混在一起，修改一个可能影响另一个
后果: 场景间相互影响，难以测试

失败模式 3：异常处理不统一
代码: try: hook(ctx) except: pass
问题: 异常被静默吞掉，难以定位问题
后果: 系统稳定性差，问题难以排查
```

### 2.3 优化目标

**核心问题**：如何将干预逻辑从主流程中完全解耦，实现可扩展的插件机制？

**量化目标**：
- 新增干预场景成本从"修改主流程代码"降至"添加 Hook 文件"
- 单个 Hook 异常不影响其他 Hook 和主流程
- 干预时机明确（推理前/推理后）

---

## 3. 技术方案设计

### 3.1 核心思路

**两段式 Hook + 自注册 + 异常隔离**（命名直接来自设计文档"两段式契约"）：

```
_stage_prepare (推理前)
    │
    ├─ 构建 PreInferContext
    │   - is_first_panel: bool
    │   - query: str
    │   - body: dict
    │   - chat_history: list (可原地修改)
    │   - system_prompt_snippets: list (可追加)
    │   - session: ModelSession
    │
    └─ run_pre_hooks(ctx)
        ├─ panel_stale_hook (清理过期历史)
        ├─ custom_prompt_hook (注入个性化提示词)
        └─ ... (更多 Hook)

_stage_infer (推理)
    │
    └─ 模型推理 → 工具调用

_post_process_tool_results (推理后)
    │
    ├─ 构建 PostInferContext
    │   - tool_call_response: ToolCallResponse (可修改)
    │   - tool_exec_index: int
    │   - tool_exec_results: list
    │   - need_on_screen: bool
    │   - session: ModelSession
    │
    └─ run_post_hooks(ctx)
        ├─ composite_output_instruct_hook (多工具末条注入上屏指令)
        ├─ tool_priority_hook (调整工具优先级)
        └─ ... (更多 Hook)
```

**关键挑战**：
1. 如何划分推理前/后的边界？
2. 如何保证 Hook 异常不影响主流程？
3. 如何设计 Hook 间的数据传递？
4. 如何支持 Hook 的动态注册？

### 3.2 两段式职责规则表

**设计原则**：两段的干预目标不同——推理前修改输入，推理后修改输出

| 段 | 输入 | 干预目标 | 输出 | 集成点 |
|:---|:---|:---|:---|:---|
| **PreInfer** | chat_history, system_prompt | 修改输入，影响模型决策 | 修改后的 chat_history, system_prompt | `_stage_prepare` 推理前 |
| **PostInfer** | tool_call_response | 修改输出，影响工具执行 | 修改后的 tool_call_response | `_post_process_tool_results` |

---

## 4. 核心实现细节

### 4.1 PreInferContext：推理前干预上下文

**实现位置**：`agent/pro/hooks/base.py`

```python
@dataclass
class PreInferContext:
    """推理前干预的上下文信息"""
    is_first_panel: bool                    # 是否面板态首轮
    query: str                               # 用户查询
    body: dict                               # 请求体
    chat_history: list                       # 对话历史（可原地修改）
    system_prompt_snippets: list[str]        # 系统提示词片段（可追加）
    reminder_facts: list[str]                # 系统事实（可追加）
    session: ModelSession                    # 模型会话
```

**关键设计**：
- `chat_history` 只能原地修改：`ctx.chat_history[:] = [...]` 或 `ctx.chat_history.append(...)`
- 不得整体替换：`ctx.chat_history = [...]` ❌（会被静默丢弃）
- Context 与主流程共享同一对象引用，原地修改方能带出

### 4.2 PostInferContext：推理后干预上下文

**实现位置**：`agent/pro/hooks/base.py`

```python
@dataclass
class PostInferContext:
    """推理后干预的上下文信息"""
    tool_call_response: ToolCallResponse     # 工具调用响应（可修改）
    tool_exec_index: int                     # 工具执行索引
    tool_exec_results: list                  # 工具执行结果
    need_on_screen: bool                     # 是否需要上屏
    session: ModelSession                    # 模型会话
```

**关键设计**：
- 可修改 `tool_call_response` 的字段（如 `add_output_instruct`）
- 不得整体替换 `tool_call_response` 对象

### 4.3 Hook 注册表

**实现位置**：`agent/pro/hooks/registry.py`

```python
_pre_hooks: list[Callable[[PreInferContext], None]] = []
_post_hooks: list[Callable[[PostInferContext], None]] = []

def register_pre_hook(func: Callable[[PreInferContext], None]):
    """注册 PreInfer hook"""
    _pre_hooks.append(func)
    return func

def register_post_hook(func: Callable[[PostInferContext], None]):
    """注册 PostInfer hook"""
    _post_hooks.append(func)
    return func

def run_pre_hooks(ctx: PreInferContext):