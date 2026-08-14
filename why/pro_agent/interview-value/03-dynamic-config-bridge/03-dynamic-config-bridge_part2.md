- 三阶段管道：parser → validator → applier，任一环节失败保持旧状态
- 本地兜底优先：`init_load` 先加载本地，再尝试远程覆盖
- 异常隔离：每个阶段独立 try-except，异常不传播

### 4.2 ConfigRegistry：配置注册表

**实现位置**：`config/managed_config.py`

```python
class ConfigRegistry:
    """全局配置注册表，管理所有 @managed_config 声明的 Bridge 实例"""
    
    _entries: list[tuple[int, str, ManagedConfigBridge]] = []

    @classmethod
    def register(cls, key: str, bridge: ManagedConfigBridge, priority: int) -> None:
        """由 @managed_config 装饰器自动调用"""
        existing_keys = [k for _, k, _ in cls._entries]
        if key in existing_keys:
            logger.warning(f"[ConfigRegistry] 配置 key={key} 重复注册，后者覆盖前者")
            cls._entries = [(p, k, b) for p, k, b in cls._entries if k != key]
        cls._entries.append((priority, key, bridge))

    @classmethod
    def init_all(cls) -> None:
        """启动时一次性调用：按 priority 升序执行 init_load + register_on_change"""
        cls._entries.sort(key=lambda x: x[0])
        for _, key, bridge in cls._entries:
            bridge.init_load()
            config.register_on_change(key, bridge.on_change)
        keys = [k for _, k, _ in cls._entries]
        logger.info(
            f"[ConfigRegistry] 已初始化 {len(cls._entries)} 个配置桥接: {keys}"
        )
```

**关键设计**：
- 优先级排序：按 priority 升序初始化，保证依赖顺序
- 去重机制：重复注册时后者覆盖前者，避免冲突
- 集中初始化：`init_all` 一次性完成所有配置的加载和注册

### 4.3 @managed_config 装饰器

**实现位置**：`config/managed_config.py`

```python
def managed_config(
    key: str,
    *,
    priority: int = 100,
    parser: Callable[[str], Any] = json.loads,
    validator: Callable[[Any], bool] | None = None,
    fallback: str | Callable[[], Any] | None = None,
):
    """声明式配置注册装饰器。
    
    Args:
        key: 配置中心的 key
        priority: 初始化优先级，数值越小越先执行（默认 100）
        parser: 将 raw string 解析为结构化数据，默认 json.loads
        validator: 校验函数，返回 False 时拒绝更新；None 表示跳过校验
        fallback: 本地兜底。str 视为文件路径（自动读取 + parser），callable 则直接调用
    """
    def _build_fallback_loader() -> Callable[[], Any] | None:
        if fallback is None:
            return None
        if callable(fallback):
            return fallback
        # fallback 是文件路径
        fallback_path: str = fallback
        def _load_from_file() -> Any:
            with open(fallback_path, "r", encoding="utf-8") as f:
                return parser(f.read())
        return _load_from_file

    def decorator(applier_fn: Callable[[Any], None]) -> Callable[[Any], None]:
        bridge = ManagedConfigBridge(
            key=key,
            parser=parser,
            validator=validator,
            applier=applier_fn,
            fallback_loader=_build_fallback_loader(),
        )
        config_registry.register(key, bridge, priority)
        return applier_fn

    return decorator
```

**关键设计**：
- 合理默认值：parser 默认 `json.loads`，validator 默认 None（跳过校验）
- 灵活兜底：fallback 可以是文件路径或 callable
- 自动注册：装饰器自动创建 Bridge 并注册到 ConfigRegistry

### 4.4 使用示例

#### 示例 1：模型类型映射

```python
# config/managed_configs/model_type_mapping.py

from config.managed_config import managed_config
from config.model_registry import model_registry

@managed_config("model_type_mapping")
def on_model_type_mapping(data: dict):
    """配置中心下发 model_type → model_name 映射时调用"""
    model_registry.update_type_mapping(data)
```

**说明**：
- 只需一个装饰器函数，无需手动注册
- parser 默认 `json.loads`，validator 默认跳过
- 无本地兜底（fallback=None）

#### 示例 2：Patch 规则配置

```python
# config/managed_configs/patch_configs.py

from config.managed_config import managed_config
from operations.patches import load_local_patches, validate_patch_list
from operations.patches.registry import patch_registry

@managed_config(
    "patch_configs",
    validator=validate_patch_list,
    fallback=load_local_patches,
)
def on_patch_configs(data: list[dict]):
    """配置中心下发 Patch 规则时调用"""
    patch_registry.reload(data)
```

**说明**：
- 使用自定义 validator 校验 Patch 规则格式
- 使用 callable 作为本地兜底（`load_local_patches`）
- 配置中心不可用时使用本地 Patch 规则

#### 示例 3：系统提示词

```python
# config/managed_configs/system_prompt.py

from config.managed_config import managed_config
from agent.pro.system import system_prompt_loader

@managed_config(
    "system_prompt",
    parser=lambda x: x,  # 原样返回，不解析 JSON
    fallback="agent/pro/system_prompt.md",  # 文件路径兜底
)
def on_system_prompt(data: str):
    """配置中心下发系统提示词时调用"""
    system_prompt_loader.update(data)
```

**说明**：
- parser 设为 `lambda x: x`，因为系统提示词是纯文本，不需要 JSON 解析
- fallback 是文件路径，框架自动读取文件内容并应用

### 4.5 完整处理流程

```python
# main.py

def init_app():
    """应用启动初始化"""
    # 1. 导入 managed_configs 模块，触发所有装饰器注册
    import config.managed_configs  # noqa: F401
    
    # 2. 调用 config_registry.init_all()，按 priority 升序初始化所有配置
    from config.managed_config import config_registry
    config_registry.init_all()
    
    # 3. 启动彩蛋规则加载器
    easter_egg_manager.start()
    
    # 4. 初始化工具共现仲裁规则
    from operations.arbitration.engine import init as init_arbitration
    init_arbitration()
```

### 4.6 边界 case 处理

**Case 1：配置中心下发非法 JSON**
```
场景: 配置中心下发 '{"pro": "Doubao-Seed-2.0-pro"'（缺少右括号）
处理: parser 抛出 JSONDecodeError → 捕获异常 → 保持旧状态 + logger.error
结果: 服务继续使用旧配置，不崩溃
```

**Case 2：配置校验失败**
```
场景: Patch 规则缺少必填字段 patch_id
处理: validator 返回 False → 保持旧状态 + logger.error
结果: 服务继续使用旧配置，不应用非法配置
```

**Case 3：配置中心不可用**
```
场景: 网络故障，无法连接配置中心
处理: init_load 先加载本地兜底 → 配置中心覆盖失败 → 使用本地配置
结果: 服务正常启动，使用本地配置
```

**Case 4：配置重复注册**
```
场景: 两个文件注册了同一个 key 的配置
处理: ConfigRegistry 检测重复 → 后者覆盖前者 → logger.warning
结果: 使用后者注册的配置，避免冲突
```

---

## 5. 效果评估与优化

### 5.1 配置管理对比

| 指标 | 重构前 | 重构后 | 改进 |
|---|---|---|---|
| **新增配置代码量** | ~50 行 | ~5 行 | -90% |
| **配置加载逻辑** | 散落在 main.py | 集中在 managed_configs/ | 可维护性提升 |
| **异常处理** | 手动编写 | 框架自动处理 | 稳定性提升 |
| **本地兜底** | 无 | 自动支持 | 可用性提升 |

### 5.2 可扩展性验证

```
新增配置：新增一个 "feature_flags" 配置
  → 创建 config/managed_configs/feature_flags.py
  → 使用 @managed_config("feature_flags") 装饰 applier 函数
  → 在 config/managed_configs/__init__.py 中导入
  → 无需修改 main.py
  → 新增配置成本从"修改 main.py + 手动注册回调"降至"一个文件、一个装饰器函数"
```

---

## 6. 技术亮点总结

### 6.1 创新性

1. **声明式装饰器**：接入新配置只需一个装饰器函数，框架自动处理加载、校验、应用、热更新
2. **三阶段管道**：parser → validator → applier，任一环节失败保持旧状态
3. **本地兜底 + 远程覆盖**：配置中心不可用时服务仍能启动
4. **优先级机制**：支持配置间的依赖顺序

### 6.2 技术深度

1. **ManagedConfigBridge**：统一的配置桥接器，封装三阶段管道和生命周期管理
2. **ConfigRegistry**：集中管理所有配置桥接，支持优先级排序和去重
3. **灵活兜底**：fallback 支持文件路径和 callable 两种方式

### 6.3 业务价值

1. **开发效率提升**：新增配置成本降低 90%
2. **稳定性提升**：配置更新失败时保持旧状态，服务不崩溃
3. **可用性提升**：配置中心不可用时使用本地配置，服务仍能启动

### 6.4 方法论抽象与迁移

**抽象出的通用方法论——"声明式配置管理四原则"**：

1. **声明式优先**：接入新配置只需声明"做什么"，框架负责"怎么做"
2. **三阶段管道**：解析 → 校验 → 应用，任一环节失败保持旧状态
3. **本地兜底**：配置中心不可用时使用本地配置
4. **集中管理**：统一注册、统一初始化、统一热更新

**可迁移场景**：

| 场景 | 迁移点 |
|:---|:---|
| 微服务配置管理 | 多服务共享配置中心 |
| 功能开关管理 | 动态开关 + 灰度发布 |
| A/B 测试配置 | 实验配置热更新 |

---

## 7. 面试问答准备

### Q1: 为什么选择装饰器而不是配置文件？

**A**：
1. 配置的 applier 需要编写 Python 逻辑（如调用 model_registry.update_type_mapping）
2. 配置文件无法表达这些逻辑
3. 装饰器方式代码更简洁，只需一个函数
4. 注册即生效，无需手动实例化

### Q2: 为什么需要三阶段管道？

**A**：
1. 解析：配置中心下发的是原始字符串，需要解析为结构化数据
2. 校验：防止配置中心下发非法配置导致服务崩溃
3. 应用：不同配置需要不同的应用逻辑
4. 三阶段各司其职，任一环节失败保持旧状态，保证系统不崩溃

### Q3: 为什么需要本地兜底？

**A**：
1. 配置中心不可用：网络故障、配置中心宕机