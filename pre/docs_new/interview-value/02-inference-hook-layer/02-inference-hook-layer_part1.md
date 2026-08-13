# 推理干预层设计

> 面试价值：⭐⭐⭐⭐⭐ | 技术深度：⭐⭐⭐⭐ | 业务影响：⭐⭐⭐

## 一句话总结

设计并实现两段式 Hook 机制（PreInfer/PostInfer），在推理前后提供可扩展的定点干预能力，通过自注册、异常隔离、原地修改约定，实现主流程与场景化规则的完全解耦，新增干预场景无需修改主流程代码。

---

## 1. 问题背景

### 1.1 业务场景

pro_agent 需要支持多种场景化的推理干预需求：
- **面板态首轮**：清理过期的工具调用历史
- **多工具末条**：注入上屏指令，引导模型总结
- **特定工具组合**：调整工具优先级
- **特殊用户群体**：注入个性化提示词

### 1.2 技术痛点

随着干预需求增多，主流程代码面临严重问题：

| # | 问题 | 严重程度 | 影响 |
|---|---|---|---|
| 1 | 干预逻辑散落在主流程各处 | **可维护性** | 新增场景需修改主流程，风险高 |
| 2 | 场景间相互耦合 | **可扩展性** | 修改一个场景可能影响其他场景 |
| 3 | 异常处理不统一 | **稳定性** | 单个场景异常可能中断整个推理 |
| 4 | 干预时机不明确 | **可理解性** | 难以判断干预发生在推理前还是推理后 |

### 1.3 核心矛盾

**"主流程应该保持简洁，场景化规则应该独立管理"** —— 但在旧架构中，所有干预逻辑都硬编码在主流程中，导致：
- 主流程膨胀，难以理解
- 新增场景需要修改核心代码
- 场景间相互影响，难以测试

---

## 2. 技术方案

### 2.1 设计思路

**两段式 Hook 机制**：

1. **PreInfer Hook**：推理前干预，可修改 chat_history、追加 system_prompt
2. **PostInfer Hook**：推理后干预，可修改 tool_call（如注入上屏指令）

**三个核心原则**：

1. **自注册**：Hook 通过装饰器自注册，主流程只负责遍历
2. **异常隔离**：单个 Hook 异常不影响其他 Hook 和主流程
3. **原地修改**：Context 的可变字段只能原地修改，不得整体替换

### 2.2 架构总览

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

### 2.3 核心对象设计

#### PreInferContext：推理前干预上下文

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

**使用约定**：
- `chat_history` 只能原地修改：`ctx.chat_history[:] = [...]` 或 `ctx.chat_history.append(...)`
- 不得整体替换：`ctx.chat_history = [...]` ❌（会被静默丢弃）

#### PostInferContext：推理后干预上下文

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

**使用约定**：
- 可修改 `tool_call_response` 的字段（如 `add_output_instruct`）
- 不得整体替换 `tool_call_response` 对象

#### Hook 注册表

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
    """遍历执行所有 PreInfer hook"""
    for hook in _pre_hooks:
        try:
            hook(ctx)
        except Exception as e:
            logger.error(f"hook 异常: {e}")

def run_post_hooks(ctx: PostInferContext):
    """遍历执行所有 PostInfer hook"""
    for hook in _post_hooks:
        try:
            hook(ctx)
        except Exception as e:
            logger.error(f"hook 异常: {e}")
```

### 2.4 Hook 实现示例

#### panel_stale：面板过期清理

```python
@register_pre_hook
def panel_stale_hook(ctx: PreInferContext):
    """面板态首轮清理过期历史
    
    场景：用户打开面板后，历史中可能包含过期的工具调用（如昨天的闹钟），
    这些过期信息会干扰模型判断，需要在推理前清理。
    """
    if ctx.is_first_panel and ctx.chat_history:
        # 清理过期的工具调用和响应
        ctx.chat_history[:] = [
            msg for msg in ctx.chat_history
            if not is_stale_tool_call(msg)
        ]
```

**技术要点**：
- 使用 `ctx.chat_history[:] = [...]` 原地修改
- 只在面板态首轮触发，避免过度清理
- `is_stale_tool_call` 判断工具调用是否过期（如时间戳超过 24 小时）

#### composite_output_instruct：复合输出指令

```python
@register_post_hook
def composite_output_instruct_hook(ctx: PostInferContext):
    """多工具末条注入上屏指令
    
    场景：用户请求包含多个工具调用（如"定闹钟并查天气"），
    模型需要在最后一个工具执行完成后，用自然语言总结所有结果。
    通过注入 output_instruct 引导模型行为。
    """
    if ctx.tool_exec_index == len(ctx.tool_exec_results) - 1:
        # 最后一个工具，且不需要上屏
        if not ctx.need_on_screen:
            ctx.tool_call_response.add_output_instruct(
                "请将所有工具执行结果以自然语言形式呈现给用户"
            )
```

**技术要点**：
- 通过 `tool_exec_index` 判断是否为最后一个工具
- 只在不需要上屏时注入（上屏工具已有自己的展示逻辑）
- `add_output_instruct` 修改 ToolCallResponse 的字段

---

## 3. 实现细节

### 3.1 集成点

#### PreInfer Hook 集成（stage_prepare.py）

```python
async def _stage_prepare(turn, session, body, context):
    # ... 前面的逻辑
    
    # 构建 PreInferContext
    _pre_ctx = PreInferContext(
        is_first_panel=body_context(body).is_panel_first,
        query=query,
        body=body,
        chat_history=chat_history,
        system_prompt_snippets=_patch_prompt_snippets,
        reminder_facts=_reminder_facts,
        session=session,
    )
    
    # 执行所有 PreInfer Hook
    run_pre_hooks(_pre_ctx)
    
    # Hook 产出的 reminder_facts 随 turn 传给 _build_messages
    turn.reminder_facts = _reminder_facts
    # ... 后面的逻辑
```

**关键点**：
- Context 与 `turn.reminder_facts` 共享同一对象引用
- Hook 原地修改后，`turn.reminder_facts` 自动更新
- 无需显式回写

#### PostInfer Hook 集成（agent_helpers.py）

```python
async def _post_process_tool_results(
    tool_exec_results, mcp_history, query, chat_history,
    body, model_type, smart_route_info,
    extras=None, session=None,
):
    tool_exec_post_processed = []
    tool_exec_post_processed_session = []
    
    for idx, tool_exec_result in enumerate(tool_exec_results):
        # ... 构建 ToolCallResponse
        
        # 构建 PostInferContext
        _post_ctx = PostInferContext(
            tool_call_response=tool_call_response,
            tool_exec_index=idx,
            tool_exec_results=tool_exec_results,
            need_on_screen=need_on_screen,
            session=session,
        )
        
        # 执行所有 PostInfer Hook
        run_post_hooks(_post_ctx)
        
        # Hook 修改后的 tool_call_response 自动生效
        tool_exec_post_processed.append(tool_call_response)
    
    return PostProcessResult(...)
```

**关键点**：
- 每个工具执行结果都会触发 PostInfer Hook
- Hook 可直接修改 `tool_call_response`
- 修改后的结果自动加入 `tool_exec_post_processed`

### 3.2 异常隔离机制

```python
def run_pre_hooks(ctx: PreInferContext):
    """遍历执行所有 PreInfer hook"""
    for hook in _pre_hooks:
        try:
            hook(ctx)
        except Exception as e:
            # 单个 Hook 异常不影响其他 Hook 和主流程
            logger.error(f"hook {hook.__name__} 异常: {e}")
            # 继续执行下一个 Hook
```

**设计要点**：
- 每个 Hook 独立 try-except
- 异常只记录日志，不抛出
- 主流程不受影响

### 3.3 原地修改约定

**正确示例**：

```python
# ✅ 原地修改列表
ctx.chat_history[:] = [msg for msg in ctx.chat_history if not is_stale(msg)]

# ✅ 追加元素
ctx.system_prompt_snippets.append("额外提示词")

# ✅ 修改对象字段
ctx.tool_call_response.add_output_instruct("上屏指令")
```

**错误示例**：

```python
# ❌ 整体替换列表（会被静默丢弃）