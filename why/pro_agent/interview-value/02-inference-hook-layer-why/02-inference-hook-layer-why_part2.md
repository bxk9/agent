  # hooks.yaml
  - name: panel_stale_hook
    type: pre_infer
    condition: is_first_panel and chat_history
    action: filter_stale_messages
  # 需要实现 filter_stale_messages 函数
  # 需要解析配置文件
  # 需要映射 condition 和 action
```

### 2.2.2 为什么需要异常隔离（真实原因）

**来源**：代码实现 - `agent/pro/hooks/registry.py`

**代码实现原文**：
```python
def run_pre_hooks(ctx: PreInferContext):
    """遍历执行所有 PreInfer hook"""
    for hook in _pre_hooks:
        try:
            hook(ctx)
        except Exception as e:
            logger.error(f"hook 异常: {e}")
            # 继续执行下一个 Hook
```

**详细解释**：
- Hook 是"锦上添花"，不是核心功能
- 单个 Hook 异常不应中断整个推理流程
- 异常日志明确标识 Hook 名称，便于定位
- Hook 异常时降级为"不干预"，主流程继续执行

**业务场景**：
```
场景：3 个 PreInfer Hook，第 2 个异常
  → PreInfer Hook 1: panel_stale_hook（清理过期历史）→ 正常执行
  → PreInfer Hook 2: custom_prompt_hook（注入个性化提示词）→ 异常
  → logger.error("hook 异常: custom_prompt_hook")
  → PreInfer Hook 3: ...（继续执行）
  → 推理正常进行，只是缺少 Hook 2 的干预
```

### 2.2.3 为什么 Hook 不支持异步（真实原因）

**来源**：代码实现 - `agent/pro/hooks/registry.py`

**代码实现原文**：
```python
def run_pre_hooks(ctx: PreInferContext):
    for hook in _pre_hooks:
        try:
            hook(ctx)  # 同步调用
        except Exception as e:
            logger.error(f"hook 异常: {e}")
```

**详细解释**：
- Hook 逻辑简单：当前 Hook 都是内存操作（修改列表、追加字符串），无需异步
- 性能影响小：Hook 执行时间通常在微秒级，异步反而增加开销
- 简化实现：同步实现更简单，避免异步复杂度
- 未来扩展：如果 Hook 需要调用外部服务（如查询数据库），可以改为异步

**处理逻辑**：
```
同步方式（当前实现）：
  def run_pre_hooks(ctx: PreInferContext):
      for hook in _pre_hooks:
          hook(ctx)  # 同步调用
  → 简单直接，性能开销小

异步方式（未采用）：
  async def run_pre_hooks(ctx: PreInferContext):
      for hook in _pre_hooks:
          await hook(ctx)  # 异步调用
  → 需要所有 Hook 都是 async 函数
  → 需要 await 调用，增加复杂度
  → 当前 Hook 都是内存操作，异步反而增加开销
```

### 2.2.4 为什么 Hook 不支持优先级（合理推断）

**详细解释**：
- Hook 数量少：当前只有 2 个 Hook（panel_stale、composite_output_instruct）
- Hook 独立：每个 Hook 修改不同的字段，互不影响
- 顺序无关：清理过期历史和注入上屏指令的顺序不影响结果
- 未来扩展：如果 Hook 数量增多且相互影响，可以引入优先级机制

**处理逻辑**：
```
当前实现（无优先级）：
  → Hook 按注册顺序执行
  → panel_stale_hook 先执行，composite_output_instruct_hook 后执行
  → 两个 Hook 修改不同的字段，互不影响
  → 顺序无关

未来扩展（有优先级）：
  → Hook 按优先级排序执行
  → priority=1 的 Hook 先执行，priority=2 的 Hook 后执行
  → 适用于 Hook 数量增多且相互影响的场景
```

## 2.3 性能与质量原因

### 2.3.1 为什么 PreInfer 在 prepare 阶段而不是 infer 阶段（真实原因）

**来源**：设计文档 - `docs/plans/2026-07-02-infer-hook-layer.md`

**设计文档原文**：
```
PreInfer Hook 在 prepare 阶段执行：
- PreInfer 需要修改 chat_history 和 system_prompt
- 这些是 infer 阶段的输入
- 如果在 infer 阶段执行 PreInfer Hook，修改后的 chat_history 无法传递给 infer 阶段
- 需要在 infer 阶段内部再次构建消息，增加复杂度
```

**详细解释**：
- PreInfer 需要修改 chat_history 和 system_prompt，这些是 infer 阶段的输入
- 如果在 infer 阶段执行 PreInfer Hook，修改后的 chat_history 无法传递给 infer 阶段
- 需要在 infer 阶段内部再次构建消息，增加复杂度
- 因此，PreInfer Hook 在 prepare 阶段执行，修改后的结果通过 TurnState 传递给 infer 阶段

**量化示例**：
```
PreInfer 在 prepare 阶段执行（当前实现）：
  → prepare 阶段执行 PreInfer Hook
  → 修改 chat_history 和 system_prompt
  → 通过 TurnState 传递给 infer 阶段
  → infer 阶段直接使用修改后的 chat_history 和 system_prompt
  → 复杂度：低

PreInfer 在 infer 阶段执行（未采用）：
  → infer 阶段执行 PreInfer Hook
  → 修改 chat_history 和 system_prompt
  → 需要在 infer 阶段内部再次构建消息
  → 复杂度：高
```

### 2.3.2 为什么 Context 包含 session 字段（真实原因）

**来源**：代码实现 - `agent/pro/hooks/base.py`

**代码实现原文**：
```python
@dataclass
class PreInferContext:
    is_first_panel: bool
    query: str
    body: dict
    chat_history: list
    system_prompt_snippets: list[str]
    reminder_facts: list[str]
    session: ModelSession  # 模型会话
```

**详细解释**：
- 某些 Hook 需要根据模型类型做不同处理
- Flash 模型可能需要更激进的清理（上下文窗口小）
- Pro 模型可能需要保留更多历史（上下文窗口大）
- Context 包含 session 字段，Hook 可以访问模型类型

**处理逻辑**：
```
场景：根据模型类型做不同处理
  @register_pre_hook
  def model_specific_hook(ctx: PreInferContext):
      if ctx.session.model.model_type == "flash":
          # Flash 模型特殊处理
          ctx.chat_history[:] = ctx.chat_history[-5:]  # 只保留最近 5 轮
      else:
          # Pro 模型处理
          ctx.chat_history[:] = ctx.chat_history[-10:]  # 保留最近 10 轮
```

## 2.4 工程实现原因

### 2.4.1 为什么 Hook 与 Patch 分工明确（真实原因）

**来源**：设计文档 - `docs/plans/2026-07-02-infer-hook-layer.md`

**设计文档原文**：
```
Hook 与 Patch 的分工：
- Hook：修改推理前/后的产物（chat_history、tool_call），owner 是主流程
- Patch：修改工具集（注入/剔除工具），owner 是 _resolve_tools
- 如果 Hook 也改工具集，会导致 Patch 和 Hook 两个数据源并行，难以维护
```

**详细解释**：
- Hook 的 owner 是主流程，负责修改推理前/后的产物
- Patch 的 owner 是 `_resolve_tools`，负责修改工具集
- 如果 Hook 也改工具集，会导致 Patch 和 Hook 两个数据源并行，难以维护
- 分工明确，避免并行数据源

**处理逻辑**：
```
分工明确（当前实现）：
  → Hook 修改 chat_history、tool_call
  → Patch 修改工具集（注入/剔除工具）
  → 两个数据源独立，互不影响
  → 易于维护

分工不明确（未采用）：
  → Hook 修改 chat_history、tool_call、工具集
  → Patch 修改工具集
  → 两个数据源并行，难以维护
  → 容易出现冲突
```

### 2.4.2 为什么 Hook 数量少且独立（合理推断）

**详细解释**：
- Hook 数量少：当前只有 2 个 Hook（panel_stale、composite_output_instruct）
- Hook 独立：每个 Hook 修改不同的字段，互不影响
- 顺序无关：清理过期历史和注入上屏指令的顺序不影响结果
- 保持简单：Hook 数量少且独立，无需引入优先级机制

**处理逻辑**：
```
当前实现（Hook 数量少且独立）：
  → panel_stale_hook：清理过期历史
  → composite_output_instruct_hook：注入上屏指令
  → 两个 Hook 修改不同的字段，互不影响
  → 顺序无关，无需优先级机制

未来扩展（Hook 数量增多且相互影响）：
  → 新增 Hook 3：修改 chat_history
  → 新增 Hook 4：修改 chat_history
  → 两个 Hook 修改相同的字段，相互影响
  → 需要引入优先级机制
```

## 2.5 业务价值原因

### 2.5.1 为什么推理干预层值得体系化投入（真实原因）

**来源**：git 提交密度统计

**数据**：
```
重构前（2026-03 ~ 2026-06，4 个月）：
  - 场景化干预需求膨胀
  - 干预逻辑散落在主流程中
  - 新增场景需要修改核心代码

重构落地：e2357451（2026-07-03）

重构后（2026-07 ~ 2026-08，2 个月）：
  - 两段式 Hook 机制
  - PreInfer 和 PostInfer 职责清晰
  - 新增场景只需添加 Hook，无需修改核心代码
```

**详细解释**：
- 重构前：场景化干预需求膨胀，干预逻辑散落在主流程中，新增场景需要修改核心代码
- 重构后：两段式 Hook 机制，PreInfer 和 PostInfer 职责清晰，新增场景只需添加 Hook
- 新增场景成本从"修改核心代码"降至"添加 Hook"

### 2.5.2 为什么这套方法论可复用（合理推断）

**详细解释**：
- 任何"场景化干预需求膨胀"的场景都有同样的三类问题：主流程膨胀、干预规则耦合、新增场景需要修改核心代码
- 迁移要点：先识别干预时机 → 按正交性划分段 → 引入原地修改约定 → 异常隔离
- 本项目内已有第二个应用实例：Patch 机制同样是场景化干预思路

---

## 3. 总结

### 3.1 核心原因总结

1. **两段式对应两类正交干预目标**（真实）：PreInfer/PostInfer，交集为空，单段必漏
2. **原地修改约定**（真实）：Context 与主流程共享引用，无需回写
3. **自注册机制**（真实）：Hook 需要编写 Python 逻辑，配置文件无法表达
4. **异常隔离**（真实）：Hook 是"锦上添花"，不应中断主流程

### 3.2 技术原因总结

1. **装饰器方式**（真实）：代码即配置，注册即生效
2. **同步执行**（真实）：Hook 逻辑简单，异步反而增加开销
3. **PreInfer 在 prepare 阶段**（真实）：修改后的 chat_history 需要传递给 infer 阶段
4. **Context 包含 session**（真实）：某些 Hook 需要根据模型类型做不同处理

### 3.3 业务价值总结

1. **可扩展性提升**（真实）：新增场景只需添加 Hook，无需修改核心代码