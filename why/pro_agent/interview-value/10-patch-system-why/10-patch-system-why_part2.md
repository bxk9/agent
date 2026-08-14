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

**详细解释**：
- 7 种触发条件对应 7 类正交触发场景，交集为空
- query_contains 负责"关键词匹配场景"：最常见的触发条件
- query_equals 负责"精确匹配场景"：精确匹配特定 query
- query_regex 负责"正则匹配场景"：正则匹配复杂模式
- tools_contains 负责"工具召回场景"：基于工具召回结果触发
- model_type 负责"模型类型场景"：基于模型类型触发
- custom_trigger 负责"复杂逻辑场景"：声明式配置无法表达的复杂逻辑

**业务场景**：
```
场景 1：query_contains
  用户: "今天天气怎么样？"
  → query_contains: ["天气", "气温", "下雨"]
  → 命中 "天气"
  → 触发 Patch

场景 2：query_equals
  用户: "发朋友圈"
  → query_equals: "发朋友圈"
  → 精确匹配
  → 触发 Patch

场景 3：query_regex
  用户: "定一个明天早上八点的闹钟"
  → query_regex: "定.*闹钟"
  → 正则匹配
  → 触发 Patch

场景 4：tools_contains
  用户: "今天天气怎么样？"
  → 召回: weather_forecast
  → tools_contains: ["weather_forecast"]
  → 命中
  → 触发 Patch

场景 5：model_type
  用户: "今天天气怎么样？"
  → model_type: "flash"
  → model_type: "flash"
  → 命中
  → 触发 Patch（如 Flash 幻觉修复）

场景 6：custom_trigger
  用户: "帮我付款"
  → 前台 App: 支付宝
  → custom_trigger: "alipay_payment_trigger"
  → 命中
  → 触发 Patch
```

### 2.2.2 为什么需要 7 种干预动作（真实原因）

**来源**：代码实现 - `operations/patches/registry.py`

**代码实现原文**：
```python
# 注入工具
injected_tools = collect_injected_tools(patch_results)

# 剔除工具
removed_tools = collect_removed_tools(patch_results)

# 注入设置
injected_settings = collect_injected_settings(patch_results)

# 应用工具补丁
tool_list = apply_tool_patches(tool_list, patch_results)

# 收集提示词片段
_patch_prompt_snippets = [p.inject_system_prompt for p in patch_results if p.inject_system_prompt]

# 模型切换
_patch_target_model = collect_target_model(patch_results)

# 禁用 prompt 模块
_disable_prompt_modules = collect_disabled_modules(patch_results)

# 豁免验证器
_bypass_batch_validators = collect_bypass_validators(patch_results)
```

**详细解释**：
- 7 种干预动作对应 7 类正交干预需求，交集为空
- inject_tools 负责"工具注入需求"：特定场景需要注入额外工具
- remove_tools 负责"工具剔除需求"：特定场景需要移除不合适的工具
- inject_settings 负责"设置注入需求"：补充设置项召回结果
- inject_system_prompt 负责"提示词注入需求"：追加轻量引导提示词
- target_model 负责"模型切换需求"：特定场景需要切换到更强的模型
- disable_prompt_modules 负责"禁用 prompt 模块需求"：特定场景需要禁用某些 prompt 模块
- bypass_batch_validators 负责"豁免验证器需求"：特定场景需要豁免某些验证器

**业务场景**：
```
场景 1：inject_tools
  用户: "发朋友圈"
  → 意图检索未召回 social_post
  → Patch 注入 social_post
  → 模型可以调用 social_post

场景 2：remove_tools
  用户: "帮我查一下明天天气"
  → 意图检索召回 weather_forecast 和 create_alarm
  → Patch 移除 create_alarm（不合适）
  → 模型只能调用 weather_forecast

场景 3：inject_system_prompt
  用户: "今天天气怎么样？"
  → Patch 注入提示词: "用户已打开位置服务，请直接查询当前所在城市的天气。"
  → 模型根据提示词直接查询当前城市天气

场景 4：target_model
  用户: "把音量调到50%"
  → Flash 模型可能幻觉 setting_name
  → Patch 指定 target_model: "pro"
  → 切换到 Pro 模型，避免幻觉
```

### 2.2.3 为什么需要 custom_trigger（真实原因）

**来源**：代码实现 - `operations/patches/custom_triggers/alipay_trigger.py`

**代码实现原文**：
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

**详细解释**：
- 声明式配置无法表达复杂逻辑：如"前台 App 是否为支付宝"
- custom_trigger 支持复杂逻辑：可以编写 Python 函数
- 注册表模式：通过装饰器注册，不修改核心代码

**业务场景**：
```
场景：支付宝支付
  用户: "帮我付款"
  → 前台 App: 支付宝
  → custom_trigger: "alipay_payment_trigger"
  → 检查是否包含支付相关关键词 → 是
  → 检查前台 App 是否为支付宝 → 是
  → 触发 Patch

如果无 custom_trigger：
  → 无法表达"前台 App 是否为支付宝"
  → 无法触发 Patch
  → 用户体验差

有 custom_trigger：
  → 可以表达复杂逻辑
  → 触发 Patch
  → 用户体验好
```

### 2.2.4 为什么需要白名单校验（真实原因）

**来源**：代码实现 - `operations/patches/registry.py`

**代码实现原文**：
```python
# 校验白名单字段
for module in patch.get("disable_prompt_modules", []):
    if module not in _ALLOWED_PROMPT_MODULES:
        logger.warning(f"[patches] 未知 prompt 模块: {module}")
        continue

for validator in patch.get("bypass_batch_validators", []):
    if validator not in _ALLOWED_VALIDATORS:
        logger.warning(f"[patches] 未知验证器: {validator}")
        continue
```

**详细解释**：
- 防止误操作：运营人员可能误写模块名或验证器名
- 安全性：防止禁用关键模块或豁免关键验证器
- 可追溯：白名单变更需要代码审查，便于追溯

**业务场景**：
```
场景：运营人员误操作
  错误配置:
    {
        "disable_prompt_modules": ["critical_module"]  # 关键模块
    }
  
  → 白名单校验失败
  → 记录警告日志
  → 跳过该字段
  → 避免禁用关键模块

如果无白名单校验：
  → 关键模块被禁用
  → 系统功能异常
  → 用户投诉

有白名单校验：
  → 关键模块不被禁用
  → 系统功能正常
  → 用户体验好
```

## 2.3 性能与质量原因

### 2.3.1 为什么设置 200 字硬校验（真实原因）

**来源**：代码实现 - `operations/patches/registry.py`

**代码实现原文**：
```python
_MAX_PROMPT_LENGTH = 200  # 提示词长度硬校验

def _validate_patches(self, patches: list[dict]) -> list[dict]:
    """校验 Patch 规则"""
    valid = []
    for patch in patches:
        # 校验提示词长度
        prompt = patch.get("inject_system_prompt", "")
        if len(prompt) > _MAX_PROMPT_LENGTH:
            logger.warning(
                f"[patches] Patch {patch.get('patch_id')} 提示词超限 "
                f"({len(prompt)} > {_MAX_PROMPT_LENGTH})，已跳过"
            )
            continue
        valid.append(patch)
    return valid
```

**详细解释**：
- 性能保护：过长的提示词会增加 system_prompt 长度，影响模型性能
- 定位明确：Patch 定位为"轻量引导"，长策略应投仲裁系统
- 防止滥用：硬校验防止运营人员无意中注入过长内容

**量化示例**：
```
无 200 字硬校验：
  → 运营人员注入 1000 字提示词
  → system_prompt 长度增加 1000 字
  → 模型性能下降 10-20%
  → 难以定位是哪条规则导致的

有 200 字硬校验：
  → 运营人员尝试注入 1000 字提示词
  → 校验失败，记录警告日志
  → 跳过该规则
  → system_prompt 长度不增加
  → 模型性能不受影响
```

### 2.3.2 为什么 Patch 与仲裁系统分工明确（真实原因）

**来源**：设计文档 - `operations/patches/PATCH_SKILL.md`

**详细解释**：
- Patch：轻量引导，200 字以内
- 仲裁：产品策略，无限制（MD 文件）
- 分工明确：长策略投仲裁，短提示投 Patch

**业务场景**：
```
场景 1：轻量引导（Patch）
  用户: "今天天气怎么样？"
  → Patch 注入提示词: "用户已打开位置服务，请直接查询当前所在城市的天气。"
  → 提示词长度 30 字
  → 适合 Patch

场景 2：产品策略（仲裁）
  用户: "帮我定一个明天早上八点的闹钟"
  → 仲裁注入策略: "当用户请求可能同时适用于闹钟和日程时，请按以下优先级判断：..."
  → 策略长度 500 字
  → 适合仲裁

如果 Patch 和仲裁系统分工不明确：
  → Patch 注入 500 字提示词
  → system_prompt 长度增加
  → 模型性能下降
  → 难以维护

Patch 和仲裁系统分工明确：
  → Patch 注入 30 字提示词
  → 仲裁注入 500 字策略
  → system_prompt 长度合理
  → 模型性能不受影响
  → 易于维护
```

## 2.4 工程实现原因
