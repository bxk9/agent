# 推理干预层设计 - 原因说明

> 本文档详细说明推理干预层（Hook 机制）的设计原因和决策依据
>
> 结构说明：**第 1 部分为简略分析**（原文档保留，便于快速理解）；**第 2 部分为详细原因说明**（逐决策展开，含来源、原文、解释、场景示例）
>
> 标注规则：**（真实原因）** = 有 git 提交/文档直接支撑；**（合理推断）** = 无直接证据，按业务场景推断

---

# 第一部分：简略分析（原文档保留）

## 1.1 结论先行

推理干预层（Hook 机制）不是"设计出来的"，而是**被场景化干预需求膨胀逼出来的**。git 历史清晰显示：2026-07-03 提交 `e2357451` 首次出现"推理干预 Hook 层"的完整表述——这标志着从"干预逻辑散落在主流程"转向"两段式 Hook 机制"。

## 1.2 真实原因（git 证据链）

### 场景化干预需求膨胀：多个场景需要在推理前后做定点干预

| 场景 | Hook 类型 | 功能 | 业务需求 |
|:---|:---|:---|:---|
| 面板态首轮 | PreInfer | 清理过期历史 | 用户打开面板后，历史中可能包含过期的工具调用 |
| 多工具末条 | PostInfer | 注入上屏指令 | 多工具调用时需要模型总结所有结果 |

**关键观察**：这些需求的根因是**场景化干预需求膨胀**——
1. 不同场景需要在推理前后做定点干预
2. 如果直接写在主流程中，会导致主流程膨胀、难以维护
3. 不同场景的干预规则相互耦合，新增场景需要修改核心代码

**任何单点修复都只能挡住一类**，这就是为什么需要体系化的 Hook 机制。

### 体系化时刻：`e2357451`（2026-07-03）

提交信息原文（节选）：

> refactor(agent): Agent 循环架构重构——三阶段流水线 + 推理干预 Hook 层 + body 两层上下文

这条提交是推理干预层的"出生证明"，它同时说明了三个关键决策：

1. **两段式 Hook**（PreInfer/PostInfer），而不是单段式
2. **原地修改约定**，而不是返回值
3. **自注册机制**，而不是配置文件

### 体系化之后的验证：Hook 与 Patch 的分工

设计文档特别强调"Hook 与 Patch 的分工"：

> hook 层只承载 **patches 机制够不到的推理前/后产物**——即"改哪个产物 + 谁拥有该产物"。改 `chat_history` / `tool_call` 的 owner 是主流程本身 → 归 hook；而**工具集的场景化增删** owner 是 `_resolve_tools` + patches → **不进 hook**，避免并行数据源。

**分工原则**：
- **Hook**：修改推理前/后的产物（chat_history、tool_call），owner 是主流程
- **Patch**：修改工具集（注入/剔除工具），owner 是 `_resolve_tools`

如果 Hook 也改工具集，会导致 Patch 和 Hook 两个数据源并行，难以维护。

## 1.3 为什么是两段式 Hook，而不是其他方案？

**淘汰方案 A：单段式 Hook**

- 【真实】推理前和推理后的干预目标不同：推理前修改输入（chat_history、system_prompt），推理后修改输出（tool_call_response）
- 【推断】如果用单段式 Hook，需要在 Hook 内部判断当前是推理前还是推理后，增加复杂度
- 【真实佐证】设计文档明确提到"两段式明确区分干预时机，避免混淆"

**淘汰方案 B：直接在主流程中写干预逻辑**

- 【真实】设计文档记录了 3 个核心问题：主流程膨胀、干预规则耦合、新增场景需要修改核心代码
- 【真实】如果直接在主流程中写干预逻辑，会导致主流程膨胀到 2000+ 行
- 【真实佐证】设计文档明确提到"场景化干预需求膨胀，如果直接写在主流程中，会导致主流程膨胀、难以维护"

**淘汰方案 C：用 Patch 系统解决所有干预需求**

- 【真实】设计文档明确提到"Hook 与 Patch 的分工"
- 【真实】Patch 的 owner 是 `_resolve_tools`，Hook 的 owner 是主流程
- 【真实佐证】设计文档明确提到"如果 Hook 也改工具集，会导致 Patch 和 Hook 两个数据源并行，难以维护"

**两段式各自的不可替代性**：

| 段 | 干预目标 | 被哪类需求证明必要 |
|:---|:---|:---|
| **PreInfer** | 修改输入（chat_history、system_prompt） | 面板态首轮清理过期历史 |
| **PostInfer** | 修改输出（tool_call_response） | 多工具末条注入上屏指令 |

两段式干预目标的**交集为空**——没有任何一段能覆盖另外一段的干预目标，这是两段式架构的根本理由。

## 1.4 为什么"原地修改约定"？

设计文档特别强调"原地修改约定"。

代码注释中明确记录了设计约定：

> 约定：hook 必须原地修改可变字段（见 PreInferContext 注释），Context 与下方 turn.xxx /
> _patch_prompt_snippets 共享同一对象引用，原地修改方能带出，故此处无需回写。

如果用返回值而不是原地修改：
- 需要显式回写：`new_chat_history = hook(ctx.chat_history); turn.chat_history = new_chat_history`
- 容易遗漏回写
- 多个 Hook 时需要链式调用，复杂度高
- 无法区分"修改了"和"没修改"

**教训**：原地修改约定必须严格遵守，否则会出现"修改丢失"的 bug。代码注释中明确说明了这个约定，并在 PreInferContext 的 docstring 中强调。

## 1.5 反事实推理：如果不做推理干预层会怎样？

1. **主流程持续膨胀**：按场景化干预需求的增长速度，没有体系化 Hook 机制，主流程会膨胀到 2000+ 行
2. **干预规则相互耦合**：不同场景的干预逻辑混杂在一起，修改一个场景可能影响其他场景
3. **无法扩展**：没有 Hook 机制，就不知道"新场景的干预逻辑应该放在哪里"，只能继续往主流程中塞代码，做不出精细扩展

---

# 第二部分：详细原因说明

## 2.1 核心设计原因

### 2.1.1 两段式 Hook 的提出与命名（真实原因）

**来源**：git 提交记录 - `e2357451`

**提交信息原文**：
```
e2357451 | 2026-07-03 | 李明政 | refactor(agent): Agent 循环架构重构——三阶段流水线 + 推理干预 Hook 层 + body 两层上下文
```

**详细解释**：
- 这是"推理干预 Hook 层"概念的出生证明——提交者明确把架构命名为"推理干预 Hook 层"
- 两段式分别是：PreInfer（推理前干预）→ PostInfer（推理后干预）
- 同时引入了三阶段流水线，Hook 层是三阶段流水线的配套设计

**业务场景**：
```
重构前：干预逻辑散落在主流程中
       → 不同场景的干预逻辑混杂在一起
       → 新增场景需要修改核心代码
重构后：两段式 Hook 机制
       → PreInfer 和 PostInfer 职责清晰
       → 新增场景只需添加 Hook，无需修改核心代码
```

### 2.1.2 两段式划分对应两类正交干预目标（真实原因）

**来源**：设计文档 - `docs/plans/2026-07-02-infer-hook-layer.md`

**设计文档原文**：
```
两段式契约：
- PreInfer：修改输入（chat_history、system_prompt），影响模型决策
- PostInfer：修改输出（tool_call_response），影响工具执行
```

**详细解释**：
- 两段式对应两类正交干预目标，交集为空
- PreInfer 负责"输入侧"：修改 chat_history、system_prompt，影响模型决策
- PostInfer 负责"输出侧"：修改 tool_call_response，影响工具执行

**干预目标对照**：
```
干预目标 1（PreInfer）：修改输入
  例：清理过期历史、注入个性化提示词
  单层方案"只有 PostInfer"无法解决——PostInfer 只修改输出，不修改输入

干预目标 2（PostInfer）：修改输出
  例：注入上屏指令、调整工具优先级
  单层方案"只有 PreInfer"无法解决——PreInfer 只修改输入，不修改输出
```

### 2.1.3 原地修改约定（真实原因）

**来源**：代码注释 - `agent/pro/hooks/base.py`

**代码注释原文**：
```python
# 约定：hook 必须原地修改可变字段（见 PreInferContext 注释），Context 与下方 turn.xxx /
# _patch_prompt_snippets 共享同一对象引用，原地修改方能带出，故此处无需回写。
```

**详细解释**：
- Context 与主流程共享同一对象引用
- 原地修改方能带出，故此处无需回写
- 如果用返回值，需要显式回写，容易遗漏

**业务场景**：
```
错误示例：整体替换（修改会丢失）
  ctx.chat_history = [msg for msg in ctx.chat_history if not is_stale(msg)]
  → 整体替换对象，主流程仍持有旧引用
  → 修改丢失

正确示例：原地修改（修改会生效）
  ctx.chat_history[:] = [msg for msg in ctx.chat_history if not is_stale(msg)]
  → 原地修改列表，主流程持有同一引用
  → 修改生效
```

**旁证**（真实原因）：
```
agent/pro/hooks/base.py | 2026-07-03 | 李明政 | feat(agent): 新增 Hook 机制
```
——原地修改约定的设计再次验证了同一教训——**整体替换，就会在某条路径丢失**。

## 2.2 技术实现原因

### 2.2.1 为什么用装饰器而不是配置文件（真实原因）

**来源**：代码实现 - `agent/pro/hooks/registry.py`

**代码实现原文**：
```python
_pre_hooks: list[Callable[[PreInferContext], None]] = []

def register_pre_hook(func):
    """注册 PreInfer hook"""
    _pre_hooks.append(func)
    return func

@register_pre_hook
def panel_stale_hook(ctx: PreInferContext):
    """面板态首轮清理过期历史"""
    if ctx.is_first_panel and ctx.chat_history:
        ctx.chat_history[:] = [
            msg for msg in ctx.chat_history
            if not is_stale_tool_call(msg)
        ]
```

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