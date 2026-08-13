# Patch 动态干预系统

> 面试价值：⭐⭐⭐⭐ | 技术深度：⭐⭐⭐⭐ | 业务影响：⭐⭐⭐⭐⭐

## 一句话总结

设计并实现 Patch 动态干预系统，通过声明式规则配置和多种触发条件（query 匹配、工具共现、模型类型、版本范围、自定义触发器），在运行时动态注入工具、设置、提示词，支持模型切换和验证器豁免，实现 74 个运营干预规则的灵活管理。

---

## 1. 问题背景

### 1.1 业务场景

pro_agent 需要支持多种运营干预需求：

- **工具注入**：特定 query 时注入额外工具（如"发朋友圈"注入 social_post）
- **工具剔除**：特定场景下移除不合适的工具
- **提示词注入**：追加轻量引导提示词（200 字以内）
- **模型切换**：特定场景切换到更强的模型（如 Flash 转 Pro）
- **设置注入**：补充设置项召回结果

### 1.2 技术痛点

| 问题 | 表现 | 影响 |
|---|---|---|
| 干预逻辑硬编码 | 每个场景单独写 if-else | 代码膨胀、难以维护 |
| 修改需重启 | 新增场景需修改代码并重启 | 响应慢、风险高 |
| 缺乏统一管理 | 规则散落在各处 | 难以审计和追踪 |
| 无安全校验 | 提示词长度无限制 | 可能注入过长内容影响性能 |

### 1.3 核心矛盾

**"需要灵活的运营干预能力，但干预规则应该由运营人员配置而非开发人员编码"** —— 需要一个声明式的规则引擎，支持运营人员通过配置文件管理干预规则。

---

## 2. 技术方案

### 2.1 设计思路

**声明式 Patch 系统**：

1. **规则配置**：JSON 格式，声明触发条件和干预动作
2. **多种触发器**：query 匹配、工具共现、模型类型、版本范围、自定义触发器
3. **多种干预动作**：注入工具、剔除工具、注入提示词、模型切换、禁用 prompt 模块、豁免验证器
4. **安全校验**：提示词 200 字硬校验，防止注入过长内容
5. **热更新支持**：通过 ManagedConfigBridge 支持配置中心热更新

### 2.2 架构总览

```
_stage_prepare
  |
  v
query_patch_match(query, tools, body)
  |-- 遍历所有 Patch 规则
  |-- 评估触发条件
  |-- 返回命中的 PatchResult 列表
  |
  v
应用 Patch 干预
  |-- collect_injected_tools() -> 注入工具
  |-- collect_removed_tools() -> 剔除工具
  |-- collect_injected_settings() -> 注入设置
  |-- apply_tool_patches() -> 应用工具补丁
  |-- collect_target_model() -> 模型切换
  |-- collect_disabled_modules() -> 禁用 prompt 模块
  |-- collect_bypass_validators() -> 豁免验证器
```

### 2.3 规则配置格式

```json
{
    "patch_id": "weather_location_continuation",
    "description": "天气查询续接：用户打开位置服务后继续走 weather_forecast",
    "trigger": {
        "query_contains": ["天气", "气温", "下雨"],
        "tools_contains": ["weather_forecast"],
        "model_type": "flash"
    },
    "inject_tools": ["weather_forecast"],
    "inject_system_prompt": "用户已打开位置服务，请直接查询当前所在城市的天气。",
    "target_model": "pro",
    "disable_prompt_modules": [],
    "bypass_batch_validators": []
}
```

### 2.4 触发条件类型

| 触发器 | 说明 | 示例 |
|---|---|---|
| query_contains | query 包含指定字符串 | ["天气", "气温"] |
| query_equals | query 精确匹配 | "发朋友圈" |
| query_regex | query 正则匹配 | "定.*闹钟" |
| tools_contains | 工具列表包含指定工具 | ["weather_forecast"] |
| model_type | 模型类型匹配 | "flash" |
| version_range | 客户端版本范围 | ">=3.0.0" |
| custom_trigger | 自定义触发器函数 | "my_custom_trigger" |

### 2.5 干预动作类型

| 动作 | 说明 | 限制 |
|---|---|---|
| inject_tools | 注入工具到候选池 | 无 |
| remove_tools | 从候选池移除工具 | 无 |
| inject_settings | 注入设置项 | 无 |
| inject_system_prompt | 追加系统提示词 | 200 字硬校验 |
| target_model | 切换到指定模型类型 | 无 |
| disable_prompt_modules | 禁用指定 prompt 模块 | 白名单校验 |
| bypass_batch_validators | 豁免指定批量验证器 | 白名单校验 |

---

## 3. 实现细节

### 3.1 Patch 注册表

```python
# operations/patches/registry.py

_MAX_PROMPT_LENGTH = 200  # 提示词长度硬校验

class PatchRegistry:
    """Patch 注册表与匹配引擎"""
    
    def __init__(self):
        self._patches: list[dict] = []
        self._custom_triggers: dict[str, Callable] = {}
    
    def reload(self, patches: list[dict]):
        """热更新 Patch 规则"""
        self._patches = self._validate_patches(patches)
        logger.info(f"[patches] 重新加载 {len(self._patches)} 条 Patch 规则")
    
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

### 3.2 自定义触发器

```python
# operations/patches/custom_triggers/alipay_trigger.py

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

### 3.3 集成到 stage_prepare

```python
# agent/pro/stage_prepare.py

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

### 3.4 热更新支持

```python
# config/managed_configs/patch_configs.py

@managed_config(
    "patch_configs",
    validator=validate_patch_list,
    fallback=load_local_patches,
)
def on_patch_configs(data:list[dict]):
    """配置中心下发 Patch 规则时调用"""
    patch_registry.reload(data)
```

---

## 4. 技术亮点

### 4.1 创新点

1. **声明式规则**：JSON 配置，运营人员可直接编辑
2. **多种触发器**：7 种触发条件，覆盖各种场景
3. **多种干预动作**：7 种干预动作，灵活组合
4. **200 字硬校验**：防止注入过长提示词影响性能