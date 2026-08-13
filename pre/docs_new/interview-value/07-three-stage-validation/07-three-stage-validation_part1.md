# 三阶段验证框架

> 面试价值：⭐⭐⭐⭐⭐ | 技术深度：⭐⭐⭐⭐⭐ | 业务影响：⭐⭐⭐⭐⭐

## 一句话总结

设计并实现三阶段工具调用验证框架（逐工具验证 → 批量验证 → 配置驱动验证），通过 RuleValidator、LLMValidator、GlobalValidator 三种验证器类型，结合重试机制和安全降级策略，将工具调用准确率从 85% 提升到 98%，同时保证验证失败不阻塞主流程。

---

## 1. 问题背景

### 1.1 业务场景

pro_agent 需要调用各种工具完成用户任务：

```
用户: "定一个明天早上八点的闹钟"
  → 模型输出: create_alarm(time="明天早上八点")
  → 工具调用: create_alarm(time="2026-08-12 08:00:00")
```

**工具调用的质量要求**：
- 参数正确：时间格式、枚举值、必填字段
- 语义合理：不重复创建、不冲突
- 跨工具一致：多个工具调用之间不矛盾

### 1.2 技术痛点

**核心问题**：模型生成的工具调用可能存在各种错误，直接执行会导致用户体验下降。

| 错误类型 | 示例 | 影响 |
|---|---|---|
| 参数格式错误 | `time="明天八点"`（未标准化） | 工具执行失败 |
| 必填字段缺失 | `create_alarm()`（缺少 time） | 工具执行失败 |
| 枚举值错误 | `repeat="每天"`（应为 "daily"） | 工具执行失败 |
| 语义不合理 | 同一时间创建两个闹钟 | 用户体验差 |
| 跨工具冲突 | 同时调用 `create_alarm` 和 `create_schedule`（时间冲突） | 用户体验差 |

**现有方案的问题**：
1. **无验证**：直接执行模型输出，错误率高
2. **简单校验**：只检查必填字段，无法检测语义错误
3. **硬编码规则**：每个工具单独写校验逻辑，难以维护

### 1.3 核心矛盾

**"需要在工具执行前检测并修复错误，但验证逻辑不能阻塞主流程"** —— 验证是"锦上添花"，不能因为验证失败就中断用户请求。

---

## 2. 技术方案

### 2.1 设计思路

**三阶段验证框架**：

```
Phase 1: 逐工具验证（tool_validate）
  ├─ RuleValidator: 规则验证（参数格式、必填字段）
  ├─ LLMValidator: LLM 验证（语义合理性）
  └─ ConfigValidator: 配置驱动验证（声明式规则）
  ↓
Phase 2: 批量验证（tool_validate_batch）
  └─ GlobalValidator: 跨工具一致性验证
  ↓
Phase 3: 配置驱动验证
  └─ 支持热更新验证规则
```

### 2.2 验证动作定义

```python
# tools/validator.py

class ValidationAction(Enum):
    """验证动作枚举"""
    PASS = "pass"    # 通过，继续执行
    FIX = "fix"      # 修复参数，继续执行
    RETRY = "retry"  # 重试推理（回滚并重新推理）
    DROP = "drop"    # 丢弃工具调用（Phase 2 专用）
```

**动作语义**：
- **PASS**：验证通过，继续执行工具
- **FIX**：验证发现问题，但可以自动修复（如标准化时间格式）
- **RETRY**：验证发现严重问题，需要重新推理（如模型幻觉）
- **DROP**：验证发现跨工具冲突，丢弃所有工具调用（Phase 2 专用）

### 2.3 Phase 1: 逐工具验证

#### 验证器接口

```python
# tools/validator.py

class Validator(ABC):
    """验证器基类"""
    
    @abstractmethod
    async def validate(
        self, 
        function_name: str, 
        arguments: dict, 
        ctx: ToolProcessContext
    ) -> ValidationResult:
        """验证工具调用"""
        pass

@dataclass
class ValidationResult:
    """验证结果"""
    action: ValidationAction
    reason: str = ""
    fixed_arguments: dict | None = None
    retry_hint: RetryHint | None = None
```

#### RuleValidator: 规则验证

```python
# tools/mcp/validators/adjust_phone_settings.py

class AdjustPhoneSettingsValidator(RuleValidator):
    """adjust_phone_settings 工具的规则验证器"""
    
    name = "adjust_phone_settings_rule"
    
    async def validate(self, function_name, arguments, ctx):
        setting_name = arguments.get("setting_name", "")
        
        # 规则 1: setting_name 必须在召回集中
        recall_set = ctx.extras.get("settings_recall", [])
        if recall_set and setting_name not in recall_set:
            # Flash 模型可能幻觉 setting_name，需要重试并切换到 Pro
            if ctx.model_type == "flash":
                return ValidationResult(
                    action=ValidationAction.RETRY,
                    reason=f"setting_name '{setting_name}' 不在召回集中，疑似幻觉",
                    retry_hint=RetryHint(
                        target_model="pro",
                        extra_system_prompt="请确保 setting_name 在用户请求的设置项范围内",
                        tag="flash_hallucination",
                    )
                )
        
        return ValidationResult(action=ValidationAction.PASS)
```

**验证逻辑**：
- 检查 `setting_name` 是否在召回集中
- Flash 模型可能幻觉，需要重试并切换到 Pro 模型

#### LLMValidator: LLM 验证

```python
# tools/validator.py

class LLMValidator(Validator):
    """使用轻量模型判断工具调用合理性"""
    
    def __init__(self, model_name: str = "Doubao-Seed-2.0-lite"):
        self.model_name = model_name
        self.timeout = common_config.get("llm_validator_timeout", 5.0)
    
    async def validate(self, function_name, arguments, ctx):
        # 构建验证 Prompt
        prompt = self._build_prompt(function_name, arguments, ctx)
        
        try:
            # 调用轻量模型（5s 超时）
            result = await asyncio.wait_for(
                self._call_llm(prompt),
                timeout=self.timeout
            )
            
            if result.get("valid"):
                return ValidationResult(action=ValidationAction.PASS)
            else:
                return ValidationResult(
                    action=ValidationAction.RETRY,
                    reason=result.get("reason", "LLM 判断不合理"),
                    retry_hint=RetryHint(
                        extra_system_prompt=result.get("hint", ""),
                        tag="llm_validator",
                    )
                )
        except asyncio.TimeoutError:
            # 超时降级为 PASS
            logger.warning(f"[LLMValidator] 超时，降级为 PASS")
            return ValidationResult(action=ValidationAction.PASS)
    
    def _build_prompt(self, function_name, arguments, ctx):
        return f"""
判断以下工具调用是否合理：

工具名: {function_name}
参数: {json.dumps(arguments, ensure_ascii=False)}
用户查询: {ctx.query}

请判断：
1. 参数是否符合用户意图
2. 参数值是否合理

输出 JSON: {{"valid": true/false, "reason": "...", "hint": "..."}}
"""
```

**验证逻辑**：
- 使用轻量模型（Doubao-Seed-2.0-lite）判断工具调用合理性
- 5s 超时，超时降级为 PASS
- 不合理时返回 RETRY，附带修复建议

#### ConfigValidator: 配置驱动验证

```python
# tools/mcp/validators/config_loader.py

class ConfigValidator(Validator):
    """从 JSON 配置加载声明式验证规则"""
    
    def __init__(self, config: dict):
        self.tool = config.get("tool")
        self.conditions = config.get("conditions", [])
        self.action = ValidationAction(config.get("action", "pass"))
        self.fix_args = config.get("fix_args", {})
    
    async def validate(self, function_name, arguments, ctx):
        if function_name != self.tool:
            return ValidationResult(action=ValidationAction.PASS)
        
        # 检查条件
        for condition in self.conditions:
            if not self._check_condition(condition, arguments):
                # 条件不满足，执行动作
                if self.action == ValidationAction.FIX:
                    fixed_args = {**arguments, **self.fix_args}
                    return ValidationResult(
                        action=ValidationAction.FIX,
                        reason=f"条件 {condition} 不满足，自动修复",
                        fixed_arguments=fixed_args
                    )
                elif self.action == ValidationAction.RETRY:
                    return ValidationResult(
                        action=ValidationAction.RETRY,
                        reason=f"条件 {condition} 不满足",
                        retry_hint=RetryHint(
                            extra_system_prompt=self.fix_args.get("hint", ""),
                            tag=f"config_{self.tool}",
                        )
                    )
        
        return ValidationResult(action=ValidationAction.PASS)
    
    def _check_condition(self, condition: dict, arguments: dict) -> bool:
        field = condition.get("field")
        op = condition.get("op")
        value = condition.get("value")
        
        actual = arguments.get(field)
        
        if op == "exists":
            return actual is not None
        elif op == "equals":
            return actual == value
        elif op == "in":
            return actual in value
        # ... 更多操作符
```

**验证逻辑**：
- 从 JSON 配置加载验证规则
- 支持声明式条件（exists、equals、in 等）
- 支持 FIX 和 RETRY 动作

**配置示例**：
```json
{
    "tool": "create_alarm",
    "conditions": [
        {"field": "time", "op": "exists"}
    ],
    "action": "fix",
    "fix_args": {
        "time": "08:00:00"
    }
}
```

### 2.4 Phase 2: 批量验证

```python
# tools/tool.py

async def tool_validate_batch(
    tool_call_requests: list[dict],
    ctx: BatchValidationContext
) -> tuple[list[dict], list[ValidationResult]]:
    """全局批校验：在 _prepare_tool_call_requests 之后、emit_sse_response 之前调用"""
    results = []
    final_requests = tool_call_requests
    
    # 获取被 patch 豁免的验证器
    bypass_names = set()
    bypass_raw = (ctx.extra or {}).get("bypass_batch_validators")
    if bypass_raw:
        bypass_names = {n for n in bypass_raw if isinstance(n, str) and n}
    
    for v in GLOBAL_VALIDATORS:
        v_name = getattr(v, "name", v.__class__.__name__)
        