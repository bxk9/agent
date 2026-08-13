# Operations 运营能力模块详解

> 本文档详细描述 operations 模块的架构设计、彩蛋系统、Patch 系统和仲裁系统。

## 目录

1. [模块概述](#1-模块概述)
2. [设计理念](#2-设计理念)
3. [彩蛋系统](#3-彩蛋系统)
4. [Patch 系统](#4-patch-系统)
5. [仲裁系统](#5-仲裁系统)
6. [三大系统协作](#6-三大系统协作)
7. [接口说明](#7-接口说明)

---

## 1 模块概述

### 1.1 模块定位

operations 模块是 pro_agent 的运营能力层，提供三大运营干预系统：

- **彩蛋系统**：基于关键词匹配触发特殊效果（特效/跳转/定制文本）
- **Patch 系统**：基于请求特征动态注入工具/设置/提示词
- **仲裁系统**：解决能力重叠工具的共现冲突

### 1.2 模块结构

```
operations/
├── __init__.py
├── easter_egg/              # 彩蛋系统
│   ├── __init__.py          # 导出核心函数
│   ├── loader.py            # EasterEggManager：规则轮询
│   ├── matcher.py           # 匹配引擎
│   └── injector.py          # 工具注入器
├── patches/                 # Patch 系统
│   ├── __init__.py          # 导出核心函数
│   ├── registry.py          # Patch 注册表与匹配引擎
│   ├── PATCH_SKILL.md       # Patch 编写指南
│   ├── configs/             # 本地 Patch 配置
│   └── custom_triggers/     # 自定义触发器
└── arbitration/             # 仲裁系统
    ├── __init__.py          # 导出核心函数
    ├── engine.py            # 仲裁引擎
    └── configs/             # 仲裁规则配置
```

### 1.3 核心职责

| 系统 | 职责 | 触发时机 |
|---|---|---|
| **彩蛋系统** | 关键词匹配 → 注入 `trigger_easter_egg` 工具 | `_stage_prepare` |
| **Patch 系统** | 请求特征匹配 → 注入工具/设置/提示词 | `_stage_prepare` |
| **仲裁系统** | 工具共现 → 注入仲裁策略提示词 | `_stage_infer` |

---

## 2 设计理念

### 2.1 声明式配置

三大系统都采用声明式配置，运营人员可通过配置文件或配置中心修改规则，无需修改代码：

```json
// 彩蛋规则
{
    "id": "egg_001",
    "triggerContents": ["新年快乐"],
    "resultType": "effect",
    "resultValue": "fireworks"
}

// Patch 规则
{
    "patch_id": "patch_001",
    "trigger": {"query_contains": "设置闹钟"},
    "inject_tools": ["create_alarm"],
    "inject_system_prompt": "用户想要设置闹钟..."
}

// 仲裁规则
{
    "name": "alarm_schedule_arbitration",
    "trigger_tools": ["create_alarm", "create_schedule"],
    "prompt_file": "alarm_schedule.md"
}
```

### 2.2 热更新支持

三大系统都支持通过 `ManagedConfigBridge` 热更新：

- **彩蛋系统**：`EasterEggManager` 每 30s 轮询远程规则 API
- **Patch 系统**：通过 `patch_configs` 配置键热更新
- **仲裁系统**：预留 `reload_rules()` 接口（暂未接入配置中心）

### 2.3 安全降级

所有系统异常时静默跳过，不影响核心推理流程：

```python
try:
    matched_egg = match_easter_egg(query, body)
except Exception:
    logger.error(f"彩蛋匹配异常: {traceback.format_exc()}")
    matched_egg = None
```

---

## 3 彩蛋系统

### 3.1 架构设计

```
EasterEggManager（规则轮询）
    ↓
match_easter_egg()（匹配引擎）
    ↓
inject_easter_egg_tool()（工具注入器）
    ↓
trigger_easter_egg 工具进入候选池
    ↓
模型自主决策是否调用
```

### 3.2 EasterEggManager

**文件**：`operations/easter_egg/loader.py`

```python
class EasterEggManager:
    """单例模式，守护线程定时轮询远程规则 API"""

    def start(self):
        """启动轮询（首次同步 + 后台守护线程）"""

    def get_rules(self) -> list[dict]:
        """返回当前生效规则的浅拷贝"""

    def _poll_rules(self):
        """轮询远程 API，失败时保留旧数据"""
```

**设计要点**：
- 单例模式，全局唯一实例
- 守护线程轮询，不阻塞主线程
- 拉取失败时保留旧数据（不清空）

### 3.3 匹配引擎

**文件**：`operations/easter_egg/matcher.py`

```python
def match_easter_egg(query: str, body: dict) -> dict | None:
    """匹配彩蛋规则，返回命中的规则或 None"""
```

**匹配维度**：

| 维度 | 说明 |
|---|---|
| **关键词** | `triggerContents` 列表精确匹配 |
| **设备类型** | 手机/平板/折叠屏/翻盖/眼镜 |
| **设备列表** | 白名单/黑名单 |
| **客户端版本** | 版本范围过滤 |
| **操作系统版本** | OS 版本过滤 |

**优先级规则**：多规则命中时按优先级 + ID 排序，取第一个。

### 3.4 工具注入器

**文件**：`operations/easter_egg/injector.py`

```python
def inject_easter_egg_tool(matched_egg: dict, tools: list, tool_list: list) -> bool:
    """将 trigger_easter_egg 工具注入候选池"""
```

**注入逻辑**：
1. `deepcopy` 工具定义（不污染全局）
2. 动态改写工具描述（追加命中规则信息）
3. 注入 `trigger_easter_egg` 工具到候选池
4. 通过 `ToolProcessContext.extras[EASTER_EGG_MATCHED_KEY]` 传递命中信息

**设计变化（v3.0）**：从"短路跳过模型推理"演进为"注入候选池让模型自主决策"，提升了彩蛋调用的稳定性和灵活性。

### 3.5 结果类型

| resultType | 客户端呈现方式 |
|---|---|
| `effect` | 特效（如烟花、撒花） |
| `jump` | 跳转到指定页面 |
| `text` | 定制文本回复 |

---

## 4 Patch 系统

### 4.1 架构设计

```
query_patch_match()（匹配引擎）
    ↓
PatchResult（匹配结果）
    ↓
apply_tool_patches()（应用工具补丁）
collect_injected_tools()（收集注入工具）
collect_injected_settings()（收集注入设置）
collect_injected_prompts()（收集注入提示词）
```

### 4.2 Patch 注册表

**文件**：`operations/patches/registry.py`

```python
class PatchRegistry:
    """Patch 注册表与匹配引擎"""

    def register(self, patch: Patch):
        """注册 Patch 规则"""

    def match(self, query: str, tools: list, body: dict) -> list[PatchResult]:
        """匹配当前请求，返回命中的 Patch 列表"""
```

### 4.3 Patch 触发条件

| 触发器 | 说明 |
|---|---|
| `query_contains` | 查询包含指定字符串 |
| `query_equals` | 查询精确匹配 |
| `query_regex` | 查询正则匹配 |
| `tools_contains` | 工具列表包含指定工具 |
| `model_type` | 模型类型匹配 |
| `version_range` | 客户端版本范围 |
| `custom_trigger` | 自定义触发器函数 |

### 4.4 Patch 能力

| 能力 | 说明 |
|---|---|
| `inject_tools` | 注入工具到候选池 |
| `remove_tools` | 从候选池移除工具 |
| `inject_settings` | 注入设置项 |
| `inject_system_prompt` | 追加系统提示词（≤200 字硬校验） |
| `disable_prompt_modules` | 禁用指定提示词模块 |
| `bypass_batch_validators` | 豁免指定批量验证器 |
| `target_model` | 切换到指定模型类型 |

### 4.5 配置方式

**本地配置**：`operations/patches/configs/*.json`

**配置中心**：通过 `ManagedConfigBridge` 热更新

```python
@managed_config("patch_configs")
def on_patch_configs(data:list[dict]):
    patch_registry.reload(data)
```

### 4.6 自定义触发器

**文件**：`operations/patches/custom_triggers/*.py`

```python
@register_custom_trigger("my_trigger")
def my_trigger(query: str, body: dict, patch: Patch) -> bool:
    """自定义触发逻辑"""
    return some_condition
```

### 4.7 200 字硬校验

`inject_system_prompt` 字段有 200 字硬校验（`_MAX_PROMPT_LENGTH`），超限静默跳过该 patch。

**设计原因**：Patch 定位为"轻量引导"，长策略正文应投仲裁系统。

---

## 5 仲裁系统

### 5.1 架构设计

```
collect_arbitration_prompts()（仲裁引擎）
    ↓
评估所有规则（trigger_tools + trigger_flags）
    ↓
返回命中的 prompt 列表
    ↓
注入到 system_prompt 末尾
```

### 5.2 仲裁引擎

**文件**：`operations/arbitration/engine.py`（117 行）

```python
def init():
    """初始化仲裁规则（启动时调用一次）"""

def reload_rules(rules_data: list[dict] | None = None):
    """热更新仲裁规则"""

def collect_arbitration_prompts(
    tool_names: list[str],
    request_flags: set[str] | None = None
) -> list[str]:
    """评估所有规则，返回命中的 prompt 列表"""
```

### 5.3 触发条件

两个维度（可单用亦可叠加）：

| 维度 | 说明 |
|---|---|
| `trigger_tools` | 声明的所有工具同时出现在当前轮次 |
| `trigger_flags` | 声明的所有请求特征标记均由调用方传入 |

**组合规则**：
- 两者同时声明时取 **AND**
- 某项留空则该项不约束
- **两者皆空视为非法配置**，跳过并告警（防止无条件全局注入）

### 5.4 请求特征 flag

由 `stage_infer.py` 产出，当前支持的 flag：

| flag | 说明 |
|---|---|
| `image_mock_query` | 用户仅上传图片未输入文字 |

**设计原则**：工程判定归代码（产出 flag），产品策略归配置（MD 正文）。

### 5.5 规则配置

**JSON 元数据**：`operations/arbitration/configs/*.json`

```json
{
    "name": "alarm_schedule_arbitration",
    "description": "闹钟/日程仲裁",
    "trigger_tools": ["create_alarm", "create_schedule"],
    "prompt_file": "alarm_schedule.md"
}
```

**MD 策略正文**：`operations/arbitration/configs/*.md`

策略 prompt 正文外置为独立 MD 文件，可直接预览编辑，JSON 仅存元数据。

### 5.6 当前规则

| 规则 | 触发条件 | 策略 |
|---|---|---|
| `alarm_schedule_arbitration` | create_alarm + create_schedule | 5 维度递减判断（打断强度 > 时间形态 > 信息复杂度 > 规划感 > 兜底） |
| `volume_settings_arbitration` | adjust_volume + adjust_phone_settings | 调节音量数值 → adjust_volume；跳转设置页面 → adjust_phone_settings |
| `alarm_delete_confirm` | show_alarm_card + operate_alarm | 闹钟删除/开关操作与展示卡片的分流 |