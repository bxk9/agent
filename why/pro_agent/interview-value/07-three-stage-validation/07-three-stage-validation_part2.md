- FIX：修复参数，继续执行下一个验证器
- RETRY：抛出 RetryInferenceSignal，由上层捕获并重试
- 验证器异常时降级为 PASS，不阻塞主流程

### 4.3 RuleValidator: 规则验证器

**实现位置**：`tools/mcp/validators/adjust_phone_settings.py`

```python
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

**关键设计**：
- 规则明确：setting_name 必须在召回集中
- 性能高：规则验证耗时微秒级
- 可解释：验证结果可以明确解释

### 4.4 LLMValidator: LLM 验证器

**实现位置**：`tools/validator.py`

```python
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

**关键设计**：
- 使用轻量模型（Doubao-Seed-2.0-lite），成本低
- 5s 超时，超时降级为 PASS
- 灵活性强，可以处理各种复杂场景

### 4.5 ConfigValidator: 配置驱动验证器

**实现位置**：`tools/mcp/validators/config_loader.py`

```python
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

**关键设计**：
- 声明式配置：JSON 格式，运营人员可直接编辑
- 支持热更新：通过 ManagedConfigBridge 热更新
- 灵活性强：支持各种条件组合（exists、equals、in 等）

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

### 4.6 Phase 2: 批量验证

**实现位置**：`tools/tool.py`

```python
async def tool_validate_batch(tool_call_requests, ctx):
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
        
        # 检查是否被豁免
        if v_name in bypass_names:
            logger.info(f"[validate-batch] validator={v_name} 被 patch 声明式豁免，跳过")
            continue
        
        try:
            result = await v.validate(final_requests, ctx)
        except Exception as e:
            logger.error(f"[validate] global validator={v_name} 异常 → PASS降级: {e}")
            continue
        
        if result.action != ValidationAction.PASS:
            results.append(result)
        
        if result.action == ValidationAction.DROP:
            final_requests = []  # 清空所有工具调用
            break
    
    return final_requests, results
```

**关键设计**：
- 遍历所有全局验证器，依次执行
- DROP：清空所有工具调用
- 支持 patch 豁免：某些场景可以豁免特定验证器
- 验证器异常时降级为 PASS

### 4.7 GlobalValidator: 全局验证器

**实现位置**：`tools/mcp/validators/_global/chat_intent_validator.py`

```python
class ChatIntentValidator(GlobalValidator):
    """检测 is_use_tool=CHAT 时是否误调用了工具"""
    
    name = "chat_intent_validator"
    
    async def validate(self, tool_call_requests, ctx):
        is_use_tool = ctx.smart_route_info.is_use_tool if ctx.smart_route_info else None
        
        # 如果上游判断是 CHAT，但模型仍然调用了工具，可能是误判
        if is_use_tool == UseTool.CHAT and tool_call_requests:
            logger.warning(
                f"[validate-batch] is_use_tool=CHAT 但模型调用了工具，"
                f"tool_count={len(tool_call_requests)}"
            )
            return ValidationResult(
                action=ValidationAction.DROP,
                reason="is_use_tool=CHAT，不应调用工具"
            )
        
        return ValidationResult(action=ValidationAction.PASS)
```

**关键设计**：
- 检测上游智能路由判断（`is_use_tool`）与模型行为是否一致
- 如果上游判断是 CHAT（闲聊），但模型调用了工具，可能是误判
- 返回 DROP，清空所有工具调用

### 4.8 重试机制：RetryController

**实现位置**：`agent/pro/retry_controller.py`

```python
class RetryController:
    """重试控制器，管理验证失败后的重试逻辑"""
    
    def __init__(self):
        self.retry_count = 0
        self.tool_list = []
        self.extra_system_prompts = []
        self._seen_tags = set()
        self._empty_fallback_count = 0
    
    def can_retry(self, has_emitted: bool) -> bool:
        """判断是否可以重试"""
        # 流式安全约束：已 yield 文本 token，禁止回退
        if has_emitted:
            return False
        
        # 全局闸门：超过最大重试次数
        max_retry = common_config.get("tool_validate_retry_max", 1)
        if self.retry_count >= max_retry:
            return False
        
        return True
    
    def accept(self, signal: RetryInferenceSignal) -> bool:
        """接受重试信号，更新工具列表和系统提示词"""
        # per-tag 闸门：防止同一 tag 无限重试
        if signal.hint and signal.hint.tag in self._seen_tags:
            return False
        
        if signal.hint:
            self._seen_tags.add(signal.hint.tag)
        
        self.retry_count += 1
        
        # 应用 drop_tools
        if signal.hint and signal.hint.drop_tools: