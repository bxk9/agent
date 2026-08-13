async def tool_pre_process(function_name, arguments, ctx):
    tool = tool_store.get(function_name)
    if not tool:
        return ToolCallRequest(tool_name=function_name, tool_args=arguments)
    handler = tool.resolve_pre_process(ctx.model_type)
    if handler:
        function_name, arguments = await handler(function_name, arguments, ctx)
    return ToolCallRequest(tool_name=function_name, tool_args=arguments)
```

### 6.2 模型类型分发

```python
def resolve_pre_process(self, model_type: str):
    if model_type == 'pro':
        return self.pro_pre_process or self.pre_process
    elif model_type == 'flash':
        return self.flash_pre_process or self.pre_process
    return self.pre_process
```

### 6.3 典型预处理场景

| 工具 | 预处理内容 |
|---|---|
| `create_alarm` | 时间归一化、RRULE 重复规则处理 |
| `create_schedule` | 时间格式化、提醒设置 |
| `weather_query` | 地理位置补全 |
| `adjust_phone_settings` | setting_name 标准化 |
| `snapshot_for_qa` | photo_source 逻辑判断 |

---

## 7 后处理流水线

### 7.1 调度逻辑

```python
async def tool_post_process(function_name, arguments, tool_call_response, ctx):
    tool = tool_store.get(function_name)
    if not tool:
        return tool_call_response
    handler = tool.resolve_post_process(ctx.model_type)
    if handler:
        return await handler(function_name, arguments, tool_call_response, ctx)
    return tool_call_response
```

### 7.2 典型后处理场景

| 工具 | 后处理内容 |
|---|---|
| `create_alarm` | 注入 output_instruct（闹钟设置成功提示） |
| `weather_query` | 注入天气结果上屏文本 |
| `snapshot_for_qa` | 非终态引导（提示用户截图） |
| `system` | 下载应用重试逻辑 |
| `easter_egg` | EXIT/NORMAL 行为分流 |

---

## 8 三阶段验证框架

### 8.1 架构总览

```
Phase 1：逐工具验证（tool_validate）
    ├─ RuleValidator: 规则条件匹配 → PASS/FIX/RETRY
    ├─ LLMValidator: 轻量模型判断 → PASS/RETRY
    └─ ConfigValidator: JSON 配置驱动 → PASS/FIX/RETRY

Phase 2：全局批量验证（tool_validate_batch）
    └─ GlobalValidator: 跨工具一致性检查 → PASS/DROP

Phase 3：配置驱动验证器
    └─ validators/configs/*.json → 声明式规则
```

### 8.2 验证动作枚举

```python
class ValidationAction(Enum):
    PASS = "pass"    # 通过，继续执行
    FIX = "fix"      # 修复参数，继续执行
    RETRY = "retry"  # 重试推理（回滚并重新推理）
    DROP = "drop"    # 丢弃工具调用（Phase 2 专用）
```

### 8.3 RetryHint（重试引导）

```python
class RetryHint:
    drop_tools: list[str]           # 排除工具列表
    boost_tools: list[str]          # 提升工具列表
    extra_system_prompt: str        # 追加提示词
    feedback_message: str           # 反馈消息
    tag: str                        # 去重标签
    position: str                   # 注入位置
    include_violation_context: bool # 是否注入违例事实
    violation_summary: str          # 自定义违例描述
    target_model: str               # 目标模型类型
```

### 8.4 Phase 1 验证流程

```python
async def tool_validate(function_name, arguments, ctx):
    tool = tool_store.get(function_name)
    if not tool or not tool.validators:
        return arguments, ValidationResult(PASS)

    final_args = arguments
    for v in tool.validators:
        result = await v.validate(function_name, final_args, ctx)
        if result.action == PASS:
            continue
        if result.action == FIX:
            final_args = result.fixed_arguments
            continue
        if result.action == RETRY:
            hint = _augment_hint_with_violation(result.retry_hint, ...)
            raise RetryInferenceSignal(hint=hint, ...)

    return final_args, ValidationResult(PASS)
```

### 8.5 Phase 2 批量验证

```python
async def tool_validate_batch(tool_call_requests, ctx):
    for v in GLOBAL_VALIDATORS:
        if v.name in bypass_names:
            continue  # 被 patch 声明式豁免
        result = await v.validate(tool_call_requests, ctx)
        if result.action == DROP:
            return [], [result]  # 清空所有工具调用
    return tool_call_requests, results
```

### 8.6 当前验证器

| 验证器 | 工具 | 策略 |
|---|---|---|
| `adjust_phone_settings` | adjust_phone_settings | Flash 模型 setting_name 幻觉检测 → RETRY 降级 Pro |
| `document_context_check` | document_qa / document_summary | 上下文无文档标志 → RETRY |

### 8.7 设计原则

1. **与 pre_process 严格分离**：pre_process = 无条件变换；validate = 有条件决策
2. **零侵入**：异常时降级为 PASS，不阻塞主流程
3. **流安全**：Agent 决定是否实际回滚，验证器仅给建议
4. **Dry-run 模式**：新规则观察期只记日志不执行
5. **支持热更新**：通过 ManagedConfigBridge 热更新验证规则

---

## 9 MCP 工具定义

### 9.1 工具 JSON Schema 格式

```json
{
    "definition": {
        "name": "create_alarm",
        "description": "创建闹钟",
        "parameters": {
            "type": "object",
            "properties": {
                "raw_datetime": {
                    "type": "string",
                    "description": "用户原始时间表达"
                },
                "repeat_rule": {
                    "type": "string",
                    "description": "重复规则"
                }
            },
            "required": ["raw_datetime"]
        }
    },
    "type": 0,
    "extra_system_prompt": {
        "base": "通用额外提示",
        "pro": "Pro 模型专用提示",
        "flash": "Flash 模型专用提示"
    }
}
```

### 9.2 工具领域分布

| 领域 | 工具数 | 代表工具 |
|---|---|---|
| alarm | 7 | create_alarm, modify_alarm, search_alarm |
| weather | 1 | weather_query |
| schedule | 4 | create_schedule, search_schedule |
| travel | 16 | perform_navigation, search_poi |
| phone | 12 | make_phone_call, adjust_volume |
| media | 7 | play_music, play_video |
| document | 2 | document_qa, document_summary |
| image_edit | 3 | generate_images, generate_id_photo |
| image_query | 7 | general_image_qa, image_text_translate |
| system | 40+ | open_app, close_app, adjust_phone_settings |
| common | 7 | knowledgeQA, snapshot_for_qa |
| visual_agent | 1 | visual_agent |

---

## 10 接口说明

### 10.1 工具预处理接口

```python
@register_tool_pre_process(key="your_tool", related_tools=["related_tool"])
async def your_preprocess(function_name, arguments, ctx: ToolProcessContext):
    # 参数校验、补全、转换
    return function_name, arguments
```

### 10.2 工具后处理接口

```python
@register_tool_post_process(key="your_tool")
async def your_postprocess(function_name, arguments,
                           tool_call_response: ToolCallResponse,
                           ctx: ToolProcessContext):
    tool_call_response.output_instruct = "请将结果呈现给用户"
    return tool_call_response
```

### 10.3 验证器接口

```python
class YourValidator:
    name = "your_validator"

    async def validate(self, function_name, arguments, ctx):
        if some_condition:
            return ValidationResult(
                action=ValidationAction.RETRY,
                reason="参数不合理",
                retry_hint=RetryHint(
                    drop_tools=["bad_tool"],
                    extra_system_prompt="请使用 xxx 工具",
                    tag="your_tag",
                ),
            )
        return ValidationResult(action=ValidationAction.PASS)
```

---

**相关文档**：
- [Agent 模块详解](./agent.md)
- [Model 模块详解](./model.md)
- [Config 模块详解](./config.md)
