# Config 模块详解

> 本文档详细描述 config 模块的架构设计、动态配置桥接框架、模型注册表和环境配置。

## 目录

1. [模块概述](#1-模块概述)
2. [设计理念](#2-设计理念)
3. [核心组件](#3-核心组件)
4. [动态配置桥接框架](#4-动态配置桥接框架)
5. [模型注册表](#5-模型注册表)
6. [环境配置](#6-环境配置)
7. [接口说明](#7-接口说明)

---

## 1 模块概述

### 1.1 模块定位

config 模块是 pro_agent 的配置管理层，负责：

- **环境配置**：按 `APP_ENV`（dev/test/pre/prd）选择对应配置
- **模型注册**：`ModelRegistry` 管理 model_type → 模型实例的映射
- **动态配置桥接**：`ManagedConfigBridge` 统一管理配置中心热更新
- **远程配置轮询**：`VivoConfigManager` 每 30s 轮询远程配置中心

### 1.2 模块结构

```
config/
├── __init__.py                # 配置入口，按环境选择配置
├── common_config.py           # 通用配置（运行时开关、错误码）
├── model_config.py            # 模型配置（域名、凭据、协议）
├── model_registry.py          # ModelRegistry：type→model 单一真相源
├── managed_config.py          # ManagedConfigBridge + @managed_config 装饰器
├── managed_configs/           # 声明式配置注册目录
│   ├── __init__.py            # 触发所有装饰器注册
│   ├── mcp_intention_mapping.py
│   ├── model_type_mapping.py
│   ├── system_prompt.py
│   ├── patch_configs.py
│   ├── validator_configs.py
│   ├── model_config_override.py
│   ├── flash_prompt_source.py
│   └── responses_cache.py
├── context_pipeline_config.py # Context Pipeline 压缩配置
├── easter_egg_config.py       # 彩蛋轮询配置
├── jovi_app_ids.py            # Jovi 应用 ID 配置
├── jovi_app_ids.yaml          # app_id YAML 配置
└── config_server/             # VivoConfigManager：远程配置中心轮询
    └── __init__.py
```

---

## 2 设计理念

### 2.1 声明式优于命令式

接入新配置只需一个文件、一个装饰器函数：

```python
@managed_config("model_type_mapping")
def on_model_type_mapping(data:dict):
    model_registry.update_type_mapping(data)
```

框架自动处理解析、校验、应用、热更新，无需修改 main.py。

### 2.2 安全降级

解析/校验/应用任一环节失败，保持旧状态不变：

```
parser(raw) → validator(data) → applier(data)
任一步骤异常 → 保持旧状态 + logger.error
```

### 2.3 全量原子

配置更新要么全量生效，要么全部不生效，不存在中间态。

---

## 3 核心组件

### 3.1 通用配置（common_config.py）

```python
common_config = {
    'type': 'pro',
    "voice_enable": True,
    "tool_validate_enabled": True,          # Phase 1 开关
    "tool_validate_retry_max": 1,           # 最大 RETRY 次数
    "llm_validator_timeout": 5.0,           # LLM 验证器超时
    "llm_validator_default_model": "Doubao-Seed-2.0-lite",
    "tool_validate_batch_enabled": True,    # Phase 2 开关
    "tool_validate_batch_dryrun": True,     # Phase 2 dry-run 模式
    "responses_cache_enabled": False,       # Responses API 缓存开关
    "image_upload_guidance_enabled": True,  # 图片上传引导开关
    "document_upload_guidance_enabled": True, # 文档上传引导开关
}
```

### 3.2 错误码体系

| 错误码 | 类型 | 触发层 | 说明 |
|---|---|---|---|
| `2011` | `ModelServiceError` | model/ | 模型服务返回错误 |
| `2012` | `AgentProcessError` | agent/ | Agent 内部处理异常 |
| `2013` | `RequestHandleError` | main.py | 请求入口层异常 |

### 3.3 模型配置（model_config.py）

| 模型 | 协议 | 用途 |
|---|---|---|
| `Doubao-Seed-2.0-pro` | 玄机 | 生产主力模型（Pro 默认） |
| `Doubao-Seed-2.0-lite` | 玄机 | 验证器用轻量模型 |
| `BlueLM-Qwen3.5-35B-A3B-sft` | OpenAI 兼容 | Flash 默认 |
| `BlueLM-VL-35B-flash-agentic-pre` | 玄机 | 视觉多模态模型 |

---

## 4 动态配置桥接框架

### 4.1 ManagedConfigBridge

**文件**：`config/managed_config.py`（183 行）

```python
class ManagedConfigBridge:
    def __init__(self, key, parser, validator, applier, fallback_loader):
        self._key = key
        self._parser = parser          # 解析函数（默认 json.loads）
        self._validator = validator    # 校验函数（默认 None 跳过）
        self._applier = applier        # 应用函数
        self._fallback_loader = fallback_loader  # 本地兜底加载器

    def init_load(self):
        """启动时初始化：先加载本地兜底，再尝试配置中心覆盖"""
        if self._fallback_loader:
            local_data = self._fallback_loader()
            if local_data is not None:
                self._applier(local_data)
        raw = config.get_config(self._key)
        if raw is not None:
            self.on_change()

    def on_change(self):
        """配置中心变更回调"""
        raw = config.get_config(self._key)
        if raw is None:
            return
        data = self._parser(raw) if isinstance(raw, str) else raw
        if self._validator and not self._validator(data):
            return
        self._applier(data)
```

### 4.2 ConfigRegistry

```python
class ConfigRegistry:
    _entries: list[tuple[int, str, ManagedConfigBridge]] = []

    def register(cls, key, bridge, priority):
        """由 @managed_config 装饰器自动调用"""

    def init_all(cls):
        """按 priority 升序执行 init_load + register_on_change"""
```

### 4.3 @managed_config 装饰器

```python
@managed_config(
    key="model_type_mapping",
    priority=100,                    # 初始化优先级（越小越先）
    parser=json.loads,               # 解析函数
    validator=None,                  # 校验函数
    fallback=None,                   # 本地兜底（文件路径或 callable）
)
def on_model_type_mapping(data: dict):
    model_registry.update_type_mapping(data)
```

### 4.4 当前注册的 6 个配置桥接

| 配置键 | parser | validator | fallback | 子系统 |
|---|---|---|---|---|
| `mcp_intention_mapping` | json.loads | — | 本地 JSON | tool_store 构建 |
| `model_type_mapping` | json.loads | — | — | model_registry |
| `system_prompt` | str 原样 | — | — | agent/pro/system |
| `patch_configs` | json.loads | validate_patch_list | load_local_patches | operations/patches |
| `validator_configs` | json.loads | validate_validator_list | load_local_configs | validators |
| `model_config_override` | json.loads | validate_override | — | model_config |

### 4.5 接入新配置标准流程

1. 在 `config/managed_configs/` 下新建 `<key>.py`
2. 用 `@managed_config("<key>")` 装饰 applier 函数
3. 在 `config/managed_configs/__init__.py` 中 import 该模块
4. 完毕。无需改 main.py

---

## 5 模型注册表

### 5.1 ModelRegistry

**文件**：`config/model_registry.py`

```python
class ModelRegistry:
    """model_type → 模型实例的单一真相源"""

    def resolve(self, model_type: str) -> str:
        """type → 具体模型名"""

    def create_model(self, model_type: str) -> Model:
        """type → 实例化模型客户端"""

    def update_type_mapping(self, new_mapping):
        """配置中心热更新回调"""
```

### 5.2 默认映射

```python
type_mapping = {
    "pro": "Doubao-Seed-2.0-pro",
    "flash": "BlueLM-Qwen3.5-35B-A3B-sft",
}
```

### 5.3 模型选择流程

```
task_type（easy/complex）
    ↓
model_type（flash/pro）
    ↓
ModelRegistry.resolve(model_type) → 具体模型名
    ↓
ModelRegistry.create_model(model_type) → 模型客户端实例
```

### 5.4 协议分发

```python
model_config[model_name].protocol == 'vivo'
    → XuanjiModel：HMAC 签名 + 特殊 token 工具调用

model_config[model_name].protocol == 'openai'
    → XuanjiModel / Model：Bearer Token + 标准 function_calls
```

---

## 6 环境配置

### 6.1 环境选择

通过 `APP_ENV` 环境变量选择配置：

| 环境 | 说明 |
|---|---|
| `dev` | 开发环境 |
| `test` | 测试环境 |
| `pre` | 预发布环境 |
| `prd` | 生产环境 |

### 6.2 远程配置中心

`VivoConfigManager` 每 30 秒轮询远程配置中心，支持的配置键见上表。

**禁用轮询**：设置 `CONFIG_SYNC_DISABLED=true` 环境变量。

### 6.3 Context Pipeline 配置

**文件**：`config/context_pipeline_config.py`

按 model_type 独立配置压缩参数：

```python
PipelineConfig(
    token_budget=8192,
    structured_result_enabled=True,
    tool_result_truncation_enabled=True,
    history_fading_enabled=True,
    old_turn_dropping_enabled=True,
)
```

---

## 7 接口说明

### 7.1 配置读取

```python
from config import common_config, model_config, model_registry

# 读取运行时开关
enabled = common_config.get("tool_validate_enabled", True)

# 读取模型配置
domain = model_config.get("Doubao-Seed-2.0-pro", {}).get("domain")

# 解析模型
model_name = model_registry.resolve("pro")
model = model_registry.create_model("pro")
```

### 7.2 声明式配置注册

```python
from config.managed_config import managed_config

@managed_config("your_config_key", priority=50)
def on_your_config(data: dict):
    # 应用配置到子系统
    your_subsystem.update(data)
```

---

**相关文档**：
- [Agent 模块详解](./agent.md)
- [Tools 模块详解](./tools.md)
- [Operations 模块详解](./operations.md)
