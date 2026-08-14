    """遍历执行所有 PreInfer hook"""
    for hook in _pre_hooks:
        try:
            hook(ctx)
        except Exception as e:
            logger.error(f"hook {hook.__name__} 异常: {e}")
            # 继续执行下一个 Hook

def run_post_hooks(ctx: PostInferContext):
    """遍历执行所有 PostInfer hook"""
    for hook in _post_hooks:
        try:
            hook(ctx)
        except Exception as e:
            logger.error(f"hook {hook.__name__} 异常: {e}")
            # 继续执行下一个 Hook
```

**关键设计**：
- 装饰器自注册：`@register_pre_hook` 自动注册到列表
- 异常隔离：单个 Hook 异常不影响其他 Hook 和主流程
- 按注册顺序遍历：保证执行顺序的确定性

### 4.4 Hook 实现示例

#### panel_stale：面板过期清理

**实现位置**：`agent/pro/hooks/panel_stale.py`

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

**实现位置**：`agent/pro/hooks/composite_output_instruct.py`

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

### 4.5 完整处理流程

```python
# agent/pro/stage_prepare.py

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

```python
# agent/pro/agent_helpers.py

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

### 4.6 边界 case 处理

**Case 1：Hook 异常**
```
场景: 某个 Hook 抛出异常
处理: try-except 捕获异常，记录日志，继续执行下一个 Hook
结果: 单个 Hook 异常不影响其他 Hook 和主流程
```

**Case 2：原地修改 vs 整体替换**
```
场景: Hook 使用 ctx.chat_history = [...] 整体替换
处理: 主流程仍持有旧引用，修改被静默丢弃
结果: 需要在文档中强调原地修改约定
```

**Case 3：多个 Hook 修改同一字段**
```
场景: 多个 Hook 都修改 chat_history
处理: 按注册顺序依次修改，后一个 Hook 看到前一个 Hook 的修改
结果: 修改累积，最终结果取决于执行顺序
```

**Case 4：Hook 需要根据模型类型做不同处理**
```
场景: Flash 模型和 Pro 模型需要不同的清理策略
处理: Hook 通过 ctx.session.model.model_type 判断模型类型
结果: 同一 Hook 支持多种模型类型
```

---

## 5. 效果评估与优化

### 5.1 可扩展性对比

| 指标 | 重构前 | 重构后 | 改进 |
|---|---|---|---|
| **新增场景成本** | 修改主流程代码 | 添加 Hook 文件 | -90% |
| **场景间耦合度** | 高 | 无 | -100% |
| **异常影响范围** | 整个推理 | 单个 Hook | -99% |
| **代码可测试性** | 低 | 高 | Hook 可独立测试 |

### 5.2 可扩展性验证

```
新增场景：个性化提示词注入
  → 创建 custom_prompt_hook.py
  → 使用 @register_pre_hook 装饰函数
  → 在 hooks/__init__.py 中导入
  → 无需修改主流程代码
  → 新增场景成本从"修改 1100 行函数"降至"添加 Hook 文件"
```

---

## 6. 技术亮点总结

### 6.1 创新性

1. **两段式 Hook**：明确区分推理前/后干预，时机清晰
2. **自注册机制**：装饰器自动注册，主流程无需感知具体 Hook
3. **异常隔离**：单个 Hook 异常不影响整体，提升稳定性
4. **原地修改约定**：通过引用共享实现数据传递，避免显式回写

### 6.2 技术深度

1. **Context 设计**：PreInferContext 和 PostInferContext 明确定义可修改字段
2. **注册表实现**：装饰器自注册 + 异常隔离 + 按顺序遍历
3. **集成点设计**：PreInfer 在 prepare 阶段，PostInfer 在 post_process 阶段

### 6.3 业务价值

1. **可扩展性提升**：新增场景无需修改主流程代码
2. **稳定性提升**：单个 Hook 异常不影响整体
3. **开发效率提升**：Hook 可独立测试，不依赖完整推理流程

### 6.4 方法论抽象与迁移

**抽象出的通用方法论——"插件系统设计四原则"**：

1. **明确干预时机**：按业务流程的自然分界划分插件类型
2. **自注册机制**：装饰器或配置文件自动注册，主流程无需感知
3. **异常隔离**：单个插件异常不影响其他插件和主流程
4. **数据传递约定**：明确定义可修改字段和修改方式

**可迁移场景**：

| 场景 | 迁移点 |
|:---|:---|
| Web 框架中间件 | 请求前/后干预 |
| 数据处理管道 | 数据转换插件 |
| 工作流引擎 | 任务前/后钩子 |

---

## 7. 面试问答准备

### Q1: 为什么选择两段式 Hook 而不是单段式？

**A**：
1. 推理前和推理后的干预目标不同：推理前修改输入，推理后修改输出
2. 单段式需要在 Hook 内部判断当前是推理前还是推理后，增加复杂度
3. 两段式明确区分干预时机，避免混淆
4. 实证：当前 2 个 Hook 分别属于 PreInfer 和 PostInfer，两段式划分清晰

### Q2: 为什么要求原地修改而不是整体替换？

**A**：
1. Context 与主流程共享同一对象引用
2. 原地修改保持引用不变，主流程可见修改
3. 整体替换创建新对象，主流程仍持有旧引用，修改被静默丢弃
4. 原地修改约定保证数据一致性，避免难以调试的"修改不生效"问题

### Q3: 如何保证 Hook 的执行顺序？

**A**：
1. 按注册顺序遍历执行
2. 注册顺序由 Python 模块加载顺序决定，通常是文件名的字典序
3. 如果需要特定顺序，可以在文件名中添加数字前缀（如 `01_panel_stale.py`）
4. 当前 Hook 数量少且独立，顺序无关

### Q4: Hook 异常如何处理？

**A**：
1. 每个 Hook 独立 try-except，异常只记录日志，不抛出
2. 这样设计的原因：Hook 是"锦上添花"，异常时降级为不干预
3. 稳定性：单个 Hook 异常不影响其他 Hook 和主流程
4. 可观测性：异常日志明确标识 Hook 名称，便于定位

### Q5: 这个方法论能迁移到什么场景？

**A**：
1. 任何"需要可扩展插件机制"的场景：Web 框架中间件、数据处理管道、工作流引擎
2. 迁移要点：明确干预时机 → 自注册机制 → 异常隔离 → 数据传递约定
3. 反例警示：不隔离异常会导致单个插件影响整体，不明确数据传递约定会导致"修改不生效"

---

## 8. 代码文件索引

- `agent/pro/hooks/base.py`：Hook 基类和 Context 定义
- `agent/pro/hooks/registry.py`：Hook 注册表
- `agent/pro/hooks/panel_stale.py`：面板过期清理 Hook
- `agent/pro/hooks/composite_output_instruct.py`：复合输出指令 Hook
- `agent/pro/stage_prepare.py`：PreInfer Hook 集成点
- `agent/pro/agent_helpers.py`：PostInfer Hook 集成点
- `docs/plans/2026-07-02-infer-hook-layer.md`：设计文档（19170 字）

---

## 9. 总结

推理干预层设计是一个典型的**可扩展插件机制设计工程案例**，展示了：

1. **问题抽象能力**：从干预需求膨胀中归纳出主流程与场景化规则耦合的根因
2. **体系化设计**：两段式 Hook + 自注册 + 异常隔离 + 原地修改约定
3. **工程落地能力**：装饰器自注册 + 异常隔离 + Context 设计
4. **方法论沉淀**：可迁移到任何需要可扩展插件机制的场景
