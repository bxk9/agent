- 命令式配置难以热更新，需要重启服务

**决策**：采用声明式配置（JSON/YAML/装饰器），框架负责解析和应用。

**收益**：
- 新增配置只需声明配置文件，无需修改核心代码
- 配置可通过配置中心热更新，无需重启服务
- 配置文件易于 review 和版本管理

**代价**：
- 需要设计和维护配置框架
- 配置文件的表达能力有限，复杂逻辑仍需代码实现

### 3.5 为什么引入 Responses API 缓存？

**背景**：多轮对话中，system_prompt 和 chat_history 往往不变，但每次推理都要重新计算 KV Cache。

**问题**：
- 重复计算 KV Cache 导致首字时间（TTFT）增加
- 模型推理成本高，需要优化

**决策**：引入 Responses API，复用 KV Cache。

**收益**：
- 减少重复计算，降低 TTFT
- 降低模型推理成本

**代价**：
- 需要维护 response_id 和 prefix_hash，增加了状态管理复杂度
- 需要处理缓存失效场景（如历史压缩导致前缀变化）

---

## 4 架构权衡与取舍

### 4.1 性能 vs 可靠性

**权衡点**：验证器、彩蛋、Patch 等辅助功能会增加请求处理时间，但能提升可靠性。

**取舍策略**：
- **安全降级**：辅助功能异常时降级而非阻塞，保证主流程不中断
- **超时控制**：LLM 验证器设置 5s 超时，避免长时间等待
- **Dry-run 模式**：新规则先观察期（只记日志不执行），确认无误后再启用

### 4.2 灵活性 vs 复杂度

**权衡点**：hooks、patches、仲裁等机制提升了灵活性，但也增加了系统复杂度。

**取舍策略**：
- **明确边界**：hook 只承载"patches 机制够不到的推理前/后产物"，避免并行数据源
- **声明式优先**：尽量通过声明式配置描述规则，减少代码逻辑
- **文档化**：详细记录各机制的使用场景和边界，避免滥用

### 4.3 一致性 vs 可用性

**权衡点**：热更新时，原子替换可能导致短暂的不一致（旧请求用旧配置，新请求用新配置）。

**取舍策略**：
- **原子替换**：先构建新字典，再一次性替换，将不一致窗口降至最小
- **最终一致性**：接受短暂的不一致，保证系统可用性
- **日志监控**：记录热更新事件，便于排查问题

### 4.4 可测试性 vs 性能

**权衡点**：纯函数阶段易于测试，但需要显式传递参数，增加了开销。

**取舍策略**：
- **接受开销**：参数传递开销远小于模型推理开销，可忽略
- **Mock 友好**：纯函数阶段易于 Mock，可独立测试
- **集成测试**：通过集成测试验证阶段间的协作

---

## 5 演进式架构

### 5.1 从单体到三阶段

**v1.0-v2.0**：单体 `process()` 函数
```python
async def process(self, body, context):
    # 1000+ 行代码，承载所有业务逻辑
    query = body.get("query")
    tools = resolve_tools(body)
    # ... 省略 500 行
    async for token in model.stream(messages):
        # ... 省略 300 行
    yield sse_response
```

**v3.0+**：三阶段流水线
```python
async def process(self, body, context):
    turn = TurnState()
    await _stage_prepare(turn, self.session, body, context)
    async for sse in _stage_infer(turn, self.session, body, context):
        yield sse
    async for sse in _stage_finalize(turn, body, context):
        yield sse
```

### 5.2 从硬编码到声明式

**v1.0**：硬编码工具定义
```python
if tool_name == "create_alarm":
    definition = {"name": "create_alarm", "parameters": {...}}
```

**v2.0+**：声明式 JSON 配置
```json
{
    "definition": {
        "name": "create_alarm",
        "parameters": {...}
    },
    "type": 0,
    "extra_system_prompt": {"base": "...", "pro": "..."}
}
```

### 5.3 从命令式到声明式配置

**v1.0**：命令式配置注册
```python
def init_config():
    config.register("model_type_mapping", on_model_type_mapping)
    config.register("system_prompt", on_system_prompt)
    # ... 手动注册 10+ 个配置
```

**v2.0+**：声明式装饰器
```python
@managed_config("model_type_mapping")
def on_model_type_mapping(data: dict):
    model_registry.update_type_mapping(data)

@managed_config("system_prompt")
def on_system_prompt(data: str):
    system_prompt_loader.update(data)
```

### 5.4 从裸 dict 到类型化注册表

**v1.0**：裸 dict 注册表
```python
tool_store = {}  # dict[str, dict]
tool_store["create_alarm"] = {"definition": {...}, "pre_process": ...}
```

**v2.0+**：类型化注册表
```python
class ToolRegistry:
    def __init__(self):
        self._store: dict[str, Tool] = {}

tool_store = ToolRegistry()
tool_store.update({"create_alarm": Tool(definition=..., pre_process=...)})
```

### 5.5 未来演进方向

1. **更细粒度的阶段拆分**：将 `_stage_infer` 进一步拆分为 `build_prompt → stream → validate → retry`
2. **更智能的缓存策略**：基于请求特征预测缓存命中率，动态选择是否使用 Responses API
3. **更完善的可观测性**：引入 OpenTelemetry，实现全链路追踪
4. **更灵活的 Hook 机制**：支持异步 Hook、Hook 优先级、Hook 条件化启用

---

## 总结

pro_agent 的设计理念可以概括为：

1. **薄壳编排器 + 纯函数阶段**：HostAgent 只负责串联，业务逻辑集中在阶段函数
2. **单一真值来源**：单轮状态收敛到 `TurnState`，避免来源不唯一
3. **安全降级**：辅助功能异常时降级而非崩溃，保证主流程不中断
4. **声明式优于命令式**：通过声明式配置描述"做什么"，框架负责"怎么做"
5. **演进式架构**：从单体到三阶段、从硬编码到声明式、从裸 dict 到类型化注册表

这些设计理念共同构成了 pro_agent 的架构基础，使其能够在保证可靠性的同时，支持灵活的业务扩展和性能优化。

---

**下一步阅读**：
- [模块详解文档](../modules/README.md) - 各模块的详细实现与接口
- [数据流文档](../dataflow/README.md) - 完整请求数据流与状态流转
