# 架构演进历程

> 本文档记录 pro_agent 项目的架构演进历程、重大重构和技术债务清理。

## 📊 演进概览

### 架构版本

| 版本 | 时间 | 架构特征 | 核心改进 |
|---|---|---|---|
| **v1.0** | 2026-03 | 单体架构 | 基础框架搭建 |
| **v2.0** | 2026-04 | 功能扩展 | 工具系统、验证框架 |
| **v3.0** | 2026-05 | 功能完善 | Bug 修复、性能优化 |
| **v4.0** | 2026-07 | **三阶段流水线** | 架构重构、性能优化 |

### 重构统计

| 指标 | 数值 |
|---|---|
| **重构提交数** | 59 次 |
| **设计文档** | 27 篇 |
| **重构周期** | 2 个月（06-07 月） |
| **重构代码量** | ~15,000 行 |

## 🏗️ v1.0：单体架构（2026-03）

### 架构特征

```
main.py
    ↓
HostAgent.process()  # 单体函数，1000+ 行
    ├─ 输入解析
    ├─ 工具集构建
    ├─ 系统提示词构建
    ├─ 模型推理
    ├─ 工具验证
    ├─ 工具执行
    └─ 响应返回
```

### 核心组件

- **HostAgent**：单体 Agent 循环
- **Tool**：基础工具数据模型
- **ToolRegistry**：裸 dict 注册表

### 问题

1. **代码耦合度高**：所有逻辑集中在 `process()` 函数
2. **状态散落**：多个局部变量，容易出现"多处赋值 + 兜底覆盖"
3. **难以测试**：无法独立测试各个阶段
4. **难以维护**：修改一个功能可能影响其他功能

### 代码示例

```python
# v1.0 单体 process() 函数（简化）
async def process(self, body, context):
    # 1000+ 行代码
    query = body.get("query")
    tools = resolve_tools(body)
    
    # 工具集构建
    tool_list = build_tool_list(tools)
    
    # 系统提示词构建
    system_prompt = build_system_prompt(body)
    
    # 模型推理
    async for token in model.stream(messages):
        yield token
    
    # 工具验证
    for tool_call in tool_calls:
        result = validate(tool_call)
        if result == RETRY:
            # 重试逻辑
            pass
    
    # 响应返回
    yield sse_response
```

## 🚀 v2.0：功能扩展（2026-04）

### 架构特征

```
main.py
    ↓
HostAgent.process()
    ├─ 工具系统（148 个工具）
    ├─ 预处理/后处理流水线
    ├─ 验证框架 Phase 1
    ├─ 彩蛋系统
    └─ Patch 系统
```

### 新增组件

#### 工具系统

- **ToolRegistry**：类型化注册表（替代裸 dict）
- **IntentionIndex**：意图 → 工具映射
- **tool_pre_process**：工具参数预处理
- **tool_post_process**：工具结果后处理

#### 验证框架

- **Phase 1**：逐工具验证（Rule/LLM/Config）
- **ValidationAction**：PASS/FIX/RETRY/DROP
- **RetryHint**：重试引导信息

#### 运营能力

- **彩蛋系统**：关键词匹配 + 工具注入
- **Patch 系统**：动态工具/设置/提示词注入

### 关键提交

```
# 工具系统
commit: 初始化工具注册系统
commit: 实现 tool_pre_process / tool_post_process

# 验证框架
commit: 开发 tool_validate 验证框架
commit: 实现 Phase 1 逐工具验证

# 运营能力
commit: 实现彩蛋系统
commit: 实现 Patch 系统
```

### 问题

1. **单体架构未变**：`process()` 仍然过于复杂
2. **状态管理混乱**：多个局部变量，来源不唯一
3. **难以扩展**：新增功能需要修改核心代码

## 🔧 v3.0：功能完善（2026-05）

### 架构特征

```
main.py
    ↓
HostAgent.process()
    ├─ Bug 修复（~150 次）
    ├─ 系统提示词优化
    ├─ 错误处理完善
    └─ 性能调优
```

### 主要工作

#### Bug 修复

- 修复工具调用参数问题
- 修复系统提示词问题
- 修复错误处理问题

#### 性能优化

- 优化系统提示词构建
- 优化工具排序策略
- 优化日志输出

### 关键提交

```
# Bug 修复
fix: 修复工具调用参数问题
fix: 修复系统提示词问题
fix: 修复错误处理问题

# 性能优化
perf: 优化系统提示词构建
perf: 优化工具排序策略
```

### 问题

1. **技术债务积累**：单体架构问题日益严重
2. **维护成本高**：修改一个功能需要理解整个 `process()` 函数
3. **测试困难**：无法独立测试各个阶段

## 🎯 v4.0：三阶段流水线（2026-07）

### 架构特征

```
main.py
    ↓
HostAgent.process()  # 薄壳编排器
    ├─ _stage_prepare()  # 准备阶段
    ├─ _stage_infer()    # 推理阶段
    └─ _stage_finalize() # 收尾阶段
```

### 核心改进

#### 1. 三阶段流水线

**设计文档**：`2026-06-30-agent-process-refactor.md`（32,195 字）

**实施时间**：2026-07-03

**核心思想**：
- **薄壳编排器**：HostAgent 只负责串联，不承载业务逻辑
- **纯函数阶段**：各阶段是独立模块的纯函数
- **单一真值来源**：TurnState 收敛所有状态

**阶段划分**：

| 阶段 | 职责 | 输入 | 输出 |
|---|---|---|---|
| **prepare** | 输入解析、工具集构建、运营干预 | body, context | TurnState |
| **infer** | 推理、验证、重试 | TurnState, session | TurnState |
| **finalize** | 去重、推荐位、SSE 下发 | TurnState | SSE 事件流 |

**代码示例**：

```python
# v4.0 三阶段流水线
class HostAgent:
    def __init__(self, model: Model):
        self.session = ModelSession(model)

    async def process(self, body, context):
        turn = TurnState()  # 单轮唯一真值
        try:
            # 阶段 1：准备
            await _stage_prepare(turn, self.session, body, context)
            
            # 阶段 2：推理
            if not turn.should_stop:
                async for sse in _stage_infer(turn, self.session, body, context):
                    yield sse
            
            # 错误处理
            if turn.error:
                yield "event:error\ndata:" + json.dumps(turn.error) + "\n\n"
            
            # 阶段 3：收尾
            async for sse in _stage_finalize(turn, body, context):
                yield sse
        finally:
            write_stat_log(build_trace_data(turn, body, context))
```

#### 2. TurnState：单轮唯一真值

**设计文档**：包含在 `2026-06-30-agent-process-refactor.md`

**核心思想**：
- 收敛所有状态到单一对象
- 避免"多处赋值 + 兜底覆盖"
- 提供状态方法（stop/set_error）

**代码示例**：

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

    def stop(self, reason: str, **overrides) -> None:
        """标记本轮提前结束"""
        self.should_stop = True
        self.stop_reason = reason
        for k, v in overrides.items():
            setattr(self, k, v)

    def set_error(self, payload: dict) -> None:
        """记录错误载荷"""
        self.error = payload
        self.session_finished = True
```

#### 3. ModelSession：模型会话

**核心思想**：
- 持有当前模型实例 + 切换能力
- 引用共享，切换后各阶段读到即新模型

**代码示例**：

```python
class ModelSession:
    def __init__(self, model: Model):
        self.model = model

    def switch(self, target_model_type: str) -> bool:
        """切换到指定的模型类型"""
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

#### 4. 推理干预层（Hooks）

**设计文档**：`2026-07-02-infer-hook-layer.md`（19,170 字）

**实施时间**：2026-07-03

**核心思想**：
- 两段式 Hook（PreInfer/PostInfer）
- 隔离主流程与场景化规则
- 自注册 + 异常隔离

**代码示例**：

```python
# PreInfer Hook
@register_pre_hook
def panel_stale_hook(ctx: PreInferContext):
    """面板态首轮清理过期历史"""
    if ctx.is_first_panel and ctx.chat_history:
        ctx.chat_history[:] = [
            msg for msg in ctx.chat_history
            if not is_stale_tool_call(msg)
        ]

# PostInfer Hook
@register_post_hook
def composite_output_instruct_hook(ctx: PostInferContext):
    """多工具末条注入上屏指令"""
    if ctx.tool_exec_index == len(ctx.tool_exec_results) - 1:
        if not ctx.need_on_screen:
            ctx.tool_call_response.add_output_instruct(
                "请将工具执行结果以自然语言形式呈现给用户"
            )
```

#### 5. 流式处理管道

**设计文档**：`2026-07-09-stream-pipeline-architecture.md`（30,054 字）

**实施时间**：2026-07-09

**核心思想**：
- 处理器链模式
- 统一处理模型输出
- 可扩展、可组合

**代码示例**：

```python
class StreamPipeline:
    def __init__(self, source: AsyncGenerator, processors: list[StreamProcessor]):
        self.source = source
        self.processors = processors

    async def __aiter__(self):
        """异步迭代器，yield 处理后的事件"""
        async for event in self.source:
            for processor in self.processors:
                event = processor.process(event)
                if event is None:
                    break
            if event is not None:
                yield event

# 处理器链
processors = [
    EosFilter(),              # 过滤 EOS token
    MarkerFilter(),           # 过滤模型控制标记
    SpecialTokenExtractor(),  # 提取特殊 token
]
```

#### 6. Responses API 缓存
