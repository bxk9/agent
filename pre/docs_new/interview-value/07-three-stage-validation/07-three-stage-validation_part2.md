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

#### GlobalValidator: 跨工具一致性验证

```python
# tools/mcp/validators/_global/chat_intent_validator.py

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

**验证逻辑**：
- 检查上游智能路由判断（`is_use_tool`）与模型行为是否一致
- 如果上游判断是 CHAT（闲聊），但模型调用了工具，可能是误判
- 返回 DROP，清空所有工具调用

### 2.5 重试机制

```python
# agent/pro/retry_controller.py

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
            self.tool_list = [
                t for t in self.tool_list 
                if t["name"] not in signal.hint.drop_tools
            ]
        
        # 应用 extra_system_prompt
        if signal.hint and signal.hint.extra_system_prompt:
            self.extra_system_prompts.append(signal.hint.extra_system_prompt)
        
        return True
```

**重试机制**：
1. **流式安全约束**：已 yield 文本 token，禁止回退（无法撤回已发送的数据）
2. **全局闸门**：超过最大重试次数（默认 1 次）
3. **per-tag 闸门**：防止同一 tag 无限重试（如 `flash_hallucination`）

### 2.6 集成到 stage_infer

```python
# agent/pro/stage_infer.py

async def _stage_infer(turn, session, body, context):
    ctrl = RetryController()
    ctrl.set_tool_list(turn.tool_list)
    
    while True:
        # 构建消息
        messages = ctrl.build_messages(...)
        
        # 推理
        _source = session.model.stream(messages=messages, ...)
        async for event in _pipeline:
            # ... 处理流式事件
        
        # 工具调用解析
        if not func_tools:
            break
        
        # Phase 1: 逐工具验证
        _allow_retry = ctrl.can_retry(emitter.has_emitted)
        try:
            tool_call_requests = await _prepare_tool_call_requests(
                func_tools, ctrl.tool_list, ...,
                allow_retry_signal=_allow_retry,
            )
        except RetryInferenceSignal as _sig:
            if ctrl.accept(_sig):
                # 重试：清空产出，继续循环
                tool_call_requests = []
                assist_content = ""
                continue
            else:
                # 重试被拒绝，降级为 PASS
                tool_call_requests = await _prepare_tool_call_requests(
                    func_tools, ctrl.tool_list, ...,
                    allow_retry_signal=False,
                )
        
        break
    
    # Phase 2: 批量验证
    if tool_call_requests and common_config.get("tool_validate_batch_enabled", True):
        _batch_ctx = BatchValidationContext(...)
        _post_batch_requests, _batch_results = await tool_validate_batch(
            tool_call_requests, _batch_ctx,
        )
        
        # Dry-run 模式：只记录日志，不实际执行 DROP
        _dryrun = common_config.get("tool_validate_batch_dryrun", True)
        _will_drop = len(_post_batch_requests) != len(tool_call_requests)
        
        if _will_drop:
            if _dryrun:
                logger.info(f"[validate-batch-dryrun] 命中清空规则但保留原行为")
            else:
                tool_call_requests = _post_batch_requests
```

---

## 3. 实现细节

### 3.1 验证器注册

```python
# tools/tool_register_factory.py

def register_validators():
    """注册所有验证器"""
    # 注册 RuleValidator
    register_validator("adjust_phone_settings", AdjustPhoneSettingsValidator())
    register_validator("document_qa", DocumentContextCheckValidator())
    
    # 注册 ConfigValidator（从 JSON 加载）
    config_dir = "tools/mcp/validators/configs"
    for config_file in os.listdir(config_dir):
        if config_file.endswith(".json"):
            config = load_json(os.path.join(config_dir, config_file))
            validator = ConfigValidator(config)
            register_validator(config["tool"], validator)
    
    # 注册 GlobalValidator
    register_global_validator(ChatIntentValidator())
```

### 3.2 验证器链执行

```python
# tools/tool.py

async def tool_validate(function_name, arguments, ctx):
    """工具调用的质检层"""
    tool = tool_store.get(function_name)
    if not tool or not tool.validators:
        return arguments, ValidationResult(action=ValidationAction.PASS)
    
    final_args = arguments
    last_non_pass = None
    
    for v in tool.validators:
        v_name = getattr(v, "name", v.__class__.__name__)
        
        try:
            result = await v.validate(function_name, final_args, ctx)
        except Exception as e:
            # 验证器异常 → 降级 PASS
            logger.error(f"[validate] validator={v_name} 异常 → PASS降级: {e}")
            continue
        
        if result.action == ValidationAction.PASS:
            continue
        
        if result.action == ValidationAction.FIX:
            if result.fixed_arguments is not None:
                final_args = result.fixed_arguments
            last_non_pass = result
            continue
        
        if result.action == ValidationAction.RETRY:
            # 自动拼接"违例事实"到 extra_system_prompt
            hint = _augment_hint_with_violation(
                result.retry_hint,
                function_name=function_name,
                arguments=final_args,
                reason=result.reason,
            )
            raise RetryInferenceSignal(
                hint=hint,
                function_name=function_name,
                validator_name=v_name,
                reason=result.reason,
            )
    
    if last_non_pass is not None:
        return final_args, last_non_pass
    
    return final_args, ValidationResult(action=ValidationAction.PASS)
```

### 3.3 违例事实注入

```python
# tools/tool.py

def _augment_hint_with_violation(hint, function_name, arguments, reason):
    """在 RetryHint.extra_system_prompt 前拼接"违例事实" """
    if hint is None:
        return None
    
    if not getattr(hint, "include_violation_context", True):
        return hint
    
    # 构造违例事实文本
    summary = (hint.violation_summary or "").strip()
    if not summary:
        args_text = json.dumps(arguments, ensure_ascii=False)
        if len(args_text) > 200:
            args_text = args_text[:200] + "..."
        summary = (
            f"上一次尝试调用工具 {function_name}（入参 {args_text}）"
            f"未通过校验，原因：{reason}"
        )
    
    # 消毒（防止模型输出注入攻击）
    summary = sanitize_untrusted(summary) or ""
    
    # 拼接到原 extra_system_prompt 前面
    original = hint.extra_system_prompt or ""
    merged = summary + ("\n" + original if original else "")
    
    return RetryHint(
        drop_tools=list(hint.drop_tools),
        extra_system_prompt=merged,
        tag=hint.tag,
        include_violation_context=False,  # 已注入过
    )
```

**违例事实注入**：
- 告诉模型"上一次调用为什么失败"
- 帮助模型在重试时避免同样的错误
- 消毒处理，防止注入攻击

---

## 4. 技术亮点

### 4.1 创新点

1. **三阶段验证**：逐工具 → 批量 → 配置驱动，覆盖不同粒度
2. **三种验证器**：RuleValidator、LLMValidator、ConfigValidator，覆盖不同场景
3. **重试机制**：双闸门（全局 + per-tag）防止无限重试
4. **违例事实注入**：告诉模型"上一次为什么失败"，提高重试成功率
5. **Dry-run 模式**：新规则观察期，只记录日志不实际执行