# pro_agent 整体设计理念

> 本文档阐述 pro_agent 架构设计背后的核心思想、权衡取舍与演进逻辑。

## 目录

1. [设计哲学](#1-设计哲学)
2. [核心设计模式](#2-核心设计模式)
3. [关键设计决策](#3-关键设计决策)
4. [架构权衡与取舍](#4-架构权衡与取舍)
5. [演进式架构](#5-演进式架构)

---

## 1 设计哲学

### 1.1 薄壳编排器 + 纯函数阶段

**核心理念**：`HostAgent` 只是一个"薄壳"，负责串联三阶段流水线，自身不承载业务逻辑。各阶段（prepare/infer/finalize）是独立模块的**纯函数**，依赖通过显式参数传入。

**设计动机**：
- **可测试性**：阶段函数不依赖 HostAgent 实例，可独立单元测试
- **可替换性**：各阶段可独立替换或扩展，不影响其他阶段
- **可理解性**：业务逻辑集中在阶段函数中，而非散落在 HostAgent 方法里

**实现方式**：
```python
class HostAgent:
    def __init__(self, model: Model):
        self.session = ModelSession(model)  # 持有模型会话

    async def process(self, body, context):
        turn = TurnState()  # 单轮唯一真值
        try:
            await _stage_prepare(turn, self.session, body, context)
            if not turn.should_stop:
                async for sse in _stage_infer(turn, self.session, body, context):
                    yield sse
            # ... 错误处理
            async for sse in _stage_finalize(turn, body, context):
                yield sse
        finally:
            write_stat_log(...)  # 统一埋点
```

### 1.2 单一真值来源（Single Source of Truth）

**核心理念**：单轮编排的所有状态收敛到 `TurnState` 对象，避免"多处赋值 + 兜底覆盖"的来源不唯一问题。

**设计动机**：
- **状态一致性**：所有阶段只写入 `TurnState`，finalize 只读取 `TurnState`
- **调试友好**：只需查看 `TurnState` 即可了解当前轮次的所有状态
- **避免竞态**：杜绝多个局部变量同时修改导致的状态不一致

**实现方式**：
```python
@dataclass
class TurnState:
    # 请求上下文（prepare 阶段写入）
    query: str = ""
    chat_history: list = field(default_factory=list)
    tools: list = field(default_factory=list)
    
    # 推理产出（infer 阶段写入）
    assist_content: str = ""
    tool_call_requests: list = field(default_factory=list)
    session_finished: bool = False
    
    # 控制信号
    should_stop: bool = False
    error: dict | None = None
    
    # 埋点数据
    stat: StatCollector = field(default_factory=StatCollector)
```

### 1.3 安全降级（Graceful Degradation）

**核心理念**：任何环节异常时降级而非崩溃，保证主流程不中断。

**设计动机**：
- **可靠性**：辅助功能（验证器、彩蛋、Patch）异常不应影响核心推理
- **用户体验**：宁可返回"可能不完美"的结果，也不返回错误
- **可观测性**：异常降级时记录日志，便于事后排查

**实现方式**：
```python
# 验证器异常降级为 PASS
try:
    result = await validator.validate(...)
except Exception as e:
    logger.error(f"validator 异常 → PASS降级: {e}")
    continue  # 继续执行下一个验证器

# 彩蛋/Patch 异常静默跳过
try:
    matched_egg = match_easter_egg(query, body)
except Exception:
    logger.error(f"彩蛋匹配异常: {traceback.format_exc()}")
    matched_egg = None
```

### 1.4 声明式优于命令式

**核心理念**：通过声明式配置（JSON/YAML/装饰器）描述"做什么"，框架负责"怎么做"。

**设计动机**：
- **降低门槛**：新增工具/验证器/Patch 只需声明配置，无需修改核心代码
- **热更新**：配置可通过配置中心热更新，无需重启服务
- **可审计**：配置文件易于 review 和版本管理

**实现方式**：
```python
# 声明式配置注册
@managed_config("model_type_mapping")
def on_model_type_mapping(data:dict):
    model_registry.update_type_mapping(data)

# 声明式验证规则（JSON）
{
    "tool": "adjust_phone_settings",
    "type": "rule",
    "conditions": [{"field": "setting_name", "op": "in_recall_set"}],
    "action": "RETRY",
    "retry_hint": {"target_model": "pro"}
}
```

---

## 2 核心设计模式

### 2.1 三阶段流水线模式

**模式描述**：将复杂的请求处理流程拆分为三个独立阶段，每个阶段职责单一、可独立测试。

**阶段划分**：

| 阶段 | 职责 | 输入 | 输出 |
|---|---|---|---|
| **prepare** | 输入解析、工具集构建、运营干预 | body, context | TurnState（工具集、Patch 片段） |
| **infer** | 推理、验证、重试 | TurnState, session | TurnState（推理结果、工具调用） |
| **finalize** | 去重、推荐位、SSE 下发 | TurnState | SSE 事件流 |

**优势**：
- **职责清晰**：每个阶段只做一件事
- **可测试性**：可独立测试每个阶段
- **可扩展性**：可在阶段间插入新阶段（如 post_infer）

### 2.2 两段式 Hook 模式

**模式描述**：在推理前后提供定点干预能力，隔离主流程与场景化规则。

**两段式契约**：

| 段 | Context | 干预产物 | 集成点 |
|---|---|---|---|
| **PreInfer** | `PreInferContext` | 改 `chat_history` / 追加 `system_prompt` | `_stage_prepare` 推理前 |
| **PostInfer** | `PostInferContext` | 改 `tool_call`（如注入上屏指令） | `_post_process_tool_results` |

**设计要点**：
- **自注册表**：hook 通过装饰器自注册，主流程只负责遍历
- **异常隔离**：单 hook 异常不影响其余 hook 与主流程
- **原地修改**：Context 的可变字段只能原地修改，不得整体重新赋值

**实现方式**：
```python
# 自注册 hook
@register_pre_hook
def panel_stale_hook(ctx: PreInferContext):
    if ctx.is_first_panel and ctx.chat_history:
        ctx.chat_history[:] = [msg for msg in ctx.chat_history if not is_stale(msg)]

# 主流程遍历
def run_pre_hooks(ctx: PreInferContext):
    for hook in _pre_hooks:
        try:
            hook(ctx)
        except Exception as e:
            logger.error(f"hook 异常: {e}")
```

### 2.3 类型化注册表 + 原子替换

**模式描述**：使用类型化的注册表管理工具/意图映射，支持热更新时的原子替换。

**设计动机**：
- **类型安全**：注册表存储的是 `Tool` 对象，而非裸 dict
- **原子替换**：热更新时先构建新字典，再一次性替换，避免并发读看到中间态
- **热更新友好**：支持配置中心下发新映射，无需重启服务

**实现方式**：
```python
class ToolRegistry:
    def __init__(self):
        self._store: dict[str, Tool] = {}

    def replace(self, new_data: dict[str, Tool]):
        """原子替换全部内容（热更新用）"""
        self._store.clear()
        self._store.update(new_data)

# 热更新流程
def reload_mcp_mapping(new_mapping):
    new_tools = build_tools(new_mapping)
    tool_store.replace(new_tools)  # 原子替换
```

### 2.4 声明式动态配置桥接

**模式描述**：通过装饰器声明配置键，框架自动处理解析、校验、应用、热更新。

**生命周期**：
```
启动时 init_load():
    1. fallback_loader() → 本地数据 → applier() → 子系统就绪
    2. config 中有远程值 → on_change() 覆盖

运行时 on_change() (每 30s 配置中心轮询触发):
    parser(raw) → validator(data) → applier(data)
    任一步骤异常 → 保持旧状态 + logger.error
```

**优势**：
- **声明式优先**：接入新配置只需声明"做什么"，框架负责"怎么串"
- **合理默认值**：parser 默认 `json.loads`、validator 默认跳过、fallback 默认 None
- **安全降级**：解析/校验/应用任一环节失败，保持旧状态不变

---

## 3 关键设计决策

### 3.1 为什么选择三阶段而非单体函数？

**背景**：v1.0-v2.0 采用单体 `process()` 函数，承载所有业务逻辑。

**问题**：
- 代码耦合度高，难以理解和维护
- 状态散落在多个局部变量，容易出现"多处赋值 + 兜底覆盖"
- 难以独立测试各个阶段

**决策**：拆分为 `prepare → infer → finalize` 三阶段。

**收益**：
- 职责清晰，每个阶段只做一件事
- 状态收敛到 `TurnState`，避免来源不唯一
- 可独立测试每个阶段

**代价**：
- 阶段间需要显式传递 `TurnState`，增加了参数传递开销
- 需要仔细设计阶段边界，避免循环依赖

### 3.2 为什么引入推理干预层（hooks）？

**背景**：随着业务场景增多，出现了大量"场景化地在推理前后做定点干预"的需求。

**问题**：
- 如果直接在主流程中写 `if` 分支，会导致主流程膨胀、难以维护
- 不同场景的干预规则相互耦合，新增场景可能影响已有场景

**决策**：引入两段式 Hook 层，隔离主流程与干预规则。

**收益**：
- 主流程保持简洁，只负责遍历 hook
- 各 hook 自注册、互不感知，新增场景不影响已有场景
- 单 hook 异常隔离，不影响主流程

**代价**：
- 需要理解 hook 的执行顺序和原地修改约定
- hook 只能干预 Context 暴露的字段，不能直接修改主流程内部状态

### 3.3 为什么验证器异常时降级为 PASS？

**背景**：验证器用于检测工具调用的合理性，但验证器自身也可能出现异常。

**问题**：
- 如果验证器异常时阻塞主流程，会导致用户体验下降
- 验证器是"锦上添花"层，不应成为主流程的瓶颈

**决策**：验证器异常时降级为 PASS，记录日志供事后排查。

**收益**：
- 主流程不中断，用户体验不受影响
- 异常日志便于事后排查和修复

**代价**：
- 可能放过一些不合理的工具调用
- 需要通过日志监控验证器异常率，及时发现和修复

### 3.4 为什么选择声明式配置而非命令式？

**背景**：项目需要支持大量工具、验证器、Patch 的动态配置。

**问题**：
- 如果采用命令式（在代码中写 `if` 分支），新增配置需要修改核心代码