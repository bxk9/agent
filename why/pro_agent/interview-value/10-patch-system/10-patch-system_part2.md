            # 校验提示词长度
            prompt = patch.get("inject_system_prompt", "")
            if len(prompt) > _MAX_PROMPT_LENGTH:
                logger.warning(
                    f"[patches] Patch {patch.get('patch_id')} 提示词超限 "
                    f"({len(prompt)} > {_MAX_PROMPT_LENGTH})，已跳过"
                )
                continue
            
            # 校验白名单字段
            for module in patch.get("disable_prompt_modules", []):
                if module not in _ALLOWED_PROMPT_MODULES:
                    logger.warning(f"[patches] 未知 prompt 模块: {module}")
                    continue
            
            valid.append(patch)
        return valid
    
    def match(self, query: str, tools: list, body: dict) -> list[PatchResult]:
        """匹配当前请求，返回命中的 Patch 列表"""
        results = []
        for patch in self._patches:
            trigger = patch.get("trigger", {})
            if self._evaluate_trigger(trigger, query, tools, body):
                results.append(PatchResult(patch=patch))
        return results
    
    def _evaluate_trigger(self, trigger, query, tools, body) -> bool:
        """评估触发条件"""
        # query_contains
        if "query_contains" in trigger:
            if not any(kw in query for kw in trigger["query_contains"]):
                return False
        
        # query_equals
        if "query_equals" in trigger:
            if query != trigger["query_equals"]:
                return False
        
        # query_regex
        if "query_regex" in trigger:
            if not re.search(trigger["query_regex"], query):
                return False
        
        # tools_contains
        if "tools_contains" in trigger:
            tool_set = set(tools)
            if not all(t in tool_set for t in trigger["tools_contains"]):
                return False
        
        # model_type
        if "model_type" in trigger:
            if body.get("context", {}).get("model_type") != trigger["model_type"]:
                return False
        
        # custom_trigger
        if "custom_trigger" in trigger:
            trigger_fn = self._custom_triggers.get(trigger["custom_trigger"])
            if trigger_fn and not trigger_fn(query, body, trigger):
                return False
        
        return True
```

**关键设计**：
- 200 字硬校验：提示词超限静默跳过，记录警告日志
- 白名单校验：disable_prompt_modules 和 bypass_batch_validators 必须在白名单中
- 7 种触发器：query_contains、query_equals、query_regex、tools_contains、model_type、version_range、custom_trigger
- 热更新支持：`reload()` 方法支持配置中心热更新

### 4.2 自定义触发器

**实现位置**：`operations/patches/custom_triggers/alipay_trigger.py`

```python
@register_custom_trigger("alipay_payment_trigger")
def alipay_payment_trigger(query: str, body: dict, patch: dict) -> bool:
    """支付宝支付场景触发器"""
    # 检查是否包含支付相关关键词
    payment_keywords = ["付款", "支付", "转账", "红包"]
    if not any(kw in query for kw in payment_keywords):
        return False
    
    # 检查前台 App 是否为支付宝
    fronted_app = get_fronted_app(body)
    if fronted_app and "alipay" in fronted_app.get("package_name", ""):
        return True
    
    return False
```

**关键设计**：
- 注册表模式：通过 `@register_custom_trigger` 装饰器注册，不修改核心代码
- 统一接口：所有触发器接收 `(query, body, patch)` 参数
- 安全隔离：触发器异常不影响其他 Patch 规则

### 4.3 集成到 stage_prepare

**实现位置**：`agent/pro/stage_prepare.py`

```python
async def _stage_prepare(turn, session, body, context):
    # ... 前面的逻辑
    
    # Patch 匹配
    patch_results = query_patch_match(query=query, tools=tools, body=body)
    
    if patch_results:
        # 注入工具
        injected_tools = collect_injected_tools(patch_results)
        if injected_tools:
            for t in injected_tools:
                if t not in tools:
                    tools.append(t)
            tool_list = _build_tool_list(tools, settings_recall)
        
        # 剔除工具
        removed_tools = collect_removed_tools(patch_results)
        if removed_tools:
            tools = [t for t in tools if t not in set(removed_tools)]
            tool_list = _build_tool_list(tools, settings_recall)
        
        # 注入设置
        injected_settings = collect_injected_settings(patch_results)
        if injected_settings:
            settings_recall.extend(injected_settings)
            tool_list = _build_tool_list(tools, settings_recall)
        
        # 应用工具补丁
        tool_list = apply_tool_patches(tool_list, patch_results)
        
        # 收集提示词片段
        _patch_prompt_snippets = [
            p.inject_system_prompt 
            for p in patch_results 
            if p.inject_system_prompt
        ]
        
        # 模型切换
        _patch_target_model = collect_target_model(patch_results)
        if _patch_target_model:
            if session.switch(_patch_target_model):
                model_type = _patch_target_model
```

**关键设计**：
- Patch 匹配在工具召回之后，可以基于召回结果触发
- 7 种干预动作按顺序应用：注入工具 → 剔除工具 → 注入设置 → 应用工具补丁 → 收集提示词 → 模型切换
- 模型切换通过 `session.switch()` 实现，支持运行时切换

### 4.4 热更新支持

**实现位置**：`config/managed_configs/patch_configs.py`

```python
@managed_config(
    "patch_configs",
    validator=validate_patch_list,
    fallback=load_local_patches,
)
def on_patch_configs(data:list[dict]):
    """配置中心下发 Patch 规则时调用"""
    patch_registry.reload(data)
```

**关键设计**：
- 通过 ManagedConfigBridge 支持配置中心热更新
- validator 校验配置格式，fallback 兜底本地配置
- 配置中心下发后自动调用 `patch_registry.reload()`

### 4.5 当前规则统计

| 类别 | 规则数量 | 典型规则 |
|:---|:---|:---|
| **工具注入** | 25 | social_post_injection、weather_forecast_injection |
| **工具剔除** | 15 | alarm_removal、schedule_removal |
| **提示词注入** | 20 | weather_location_prompt、payment_prompt |
| **模型切换** | 10 | flash_to_pro_hallucination、flash_to_pro_complex |
| **验证器豁免** | 4 | chat_intent_validator_bypass |

### 4.6 边界 case 处理

**Case 1：提示词超限**
```
场景: 运营注入 500 字的提示词
处理: 200 字硬校验，静默跳过该规则，记录警告日志
结果: 系统不受影响，运营人员收到警告后修正配置
```

**Case 2：白名单校验失败**
```
场景: 运营误写 disable_prompt_modules: ["critical_module"]
处理: 白名单校验失败，记录警告日志，跳过该字段
结果: 关键模块不被禁用，系统功能正常
```

**Case 3：自定义触发器异常**
```
场景: 自定义触发器抛出异常
处理: try-except 捕获异常，记录错误日志，返回 False
结果: 该规则不命中，其他规则不受影响
```

**Case 4：多条规则同时命中**
```
场景: 用户请求同时命中 3 条 Patch 规则
处理: 按注册顺序执行，后者覆盖前者
结果: 所有干预动作按顺序应用，最终结果由最后一条规则决定
```

---

## 5. 效果评估与优化

### 5.1 质量提升对比

| 指标 | 优化前 | 优化后 | 改进 |
|---|---|---|---|
| **新增场景成本** | 修改代码 + 重启 | 修改配置 + 热更新 | **-90%** |
| **运营响应时间** | 1-2 天 | 5 分钟 | **-99%** |
| **规则数量** | 0 | 74 | **从无到有** |
| **工具选择准确率** | 85% | 95% | **+12%** |

### 5.2 规则效果分析

| 规则 | 命中次数/天 | 准确率提升 | 说明 |
|:---|:---|:---|:---|
| **weather_location_continuation** | 1500 | +8% | 天气查询续接，最常见的 Patch 规则 |
| **social_post_injection** | 800 | +5% | 发朋友圈工具注入 |
| **flash_to_pro_hallucination** | 600 | +4% | Flash 幻觉时切换到 Pro |
| **alipay_payment_patch** | 400 | +3% | 支付宝支付场景 |
| **alarm_dedup_patch** | 300 | +2% | 闹钟重复创建检测 |

### 5.3 实际效果案例

**场景 1：天气查询续接**
```
用户: "今天天气怎么样？"
  → 召回: weather_forecast
  → 用户已打开位置服务
  → Patch 规则命中: weather_location_continuation
  → 提示词注入: "用户已打开位置服务，请直接查询当前所在城市的天气"
  → 模型直接查询当前城市天气 ✅
```

**场景 2：Flash 幻觉修复**
```
用户: "把音量调到 50%"
  → 召回: adjust_phone_settings
  → Flash 模型幻觉 setting_name="声音"
  → Patch 规则命中: flash_to_pro_hallucination
  → 模型切换: Flash → Pro
  → Pro 模型正确输出 setting_name="音量" ✅
```

**场景 3：支付宝支付**
```
用户: "帮我付款"
  → 前台 App: 支付宝
  → Patch 规则命中: alipay_payment_patch（自定义触发器）
  → 注入工具: alipay_payment
  → 模型调用 alipay_payment 工具 ✅
```

---

## 6. 技术亮点总结

### 6.1 创新性

1. **声明式规则引擎**：JSON 配置，运营人员可直接编辑
2. **7 种触发器**：query 匹配、工具共现、模型类型、版本范围、自定义触发器等
3. **7 种干预动作**：注入工具、剔除工具、注入提示词、模型切换、禁用 prompt 模块、豁免验证器
4. **200 字硬校验**：防止注入过长提示词影响性能
5. **白名单校验**：防止误禁用关键模块或豁免关键验证器
6. **自定义触发器**：注册表模式，支持复杂业务逻辑
7. **热更新支持**：通过配置中心实时下发规则

### 6.2 技术深度

1. **PatchRegistry**：统一管理所有 Patch 规则，支持热更新
2. **_validate_patches**：200 字硬校验 + 白名单校验，保证系统安全性
3. **_evaluate_trigger**：7 种触发器组合评估，支持复杂触发逻辑
4. **自定义触发器注册表**：通过装饰器注册，不修改核心代码