# 动态配置桥接框架

> 面试价值：⭐⭐⭐⭐ | 技术深度：⭐⭐⭐⭐⭐ | 业务影响：⭐⭐⭐⭐

## 一句话总结

设计并实现声明式动态配置桥接框架，通过 `@managed_config` 装饰器和 `ManagedConfigBridge` 适配器，实现配置中心与子系统的解耦，支持配置热更新、安全降级、全量原子更新，新增配置只需一个装饰器函数，无需修改核心代码。

---

## 1. 问题背景

### 1.1 业务场景

pro_agent 需要支持多种动态配置：
- **工具意图映射**：意图名 → 工具名的映射关系
- **模型类型映射**：model_type → 具体模型名的映射
- **系统提示词**：全局系统提示词
- **Patch 规则**：运营干预规则
- **验证器规则**：工具调用验证规则
- **模型配置覆盖**：运行时调整模型参数

这些配置需要支持：
- **热更新**：配置中心变更后自动生效，无需重启服务
- **安全降级**：配置解析/校验/应用失败时保持旧状态
- **本地兜底**：配置中心不可用时使用本地配置

### 1.2 技术痛点

在引入桥接框架前，配置管理存在严重问题：

| # | 问题 | 严重程度 | 影响 |
|---|---|---|---|
| 1 | 配置加载逻辑散落在 main.py | **可维护性** | 新增配置需修改核心启动代码 |
| 2 | 配置变更回调手动注册 | **可扩展性** | 容易遗漏或重复注册 |
| 3 | 异常处理不统一 | **稳定性** | 配置解析失败可能导致服务崩溃 |
| 4 | 缺乏本地兜底机制 | **可用性** | 配置中心不可用时服务无法启动 |
| 5 | 配置更新非原子性 | **一致性** | 更新过程中可能读到中间态 |

### 1.3 核心矛盾

**"配置管理应该声明式而非命令式"** —— 但在旧架构中，每个配置都需要：
1. 手动编写加载逻辑
2. 手动注册变更回调
3. 手动处理异常
4. 手动实现兜底

这导致大量重复代码，且容易出错。

---

## 2. 技术方案

### 2.1 设计思路

**声明式配置桥接**：

1. **装饰器驱动**：通过 `@managed_config` 装饰器声明配置键和处理函数
2. **桥接适配器**：`ManagedConfigBridge` 统一管理解析、校验、应用、兜底
3. **集中注册**：`ConfigRegistry` 集中管理所有配置桥接
4. **生命周期管理**：统一的 `init_load` 和 `on_change` 流程

**四个核心原则**：

1. **声明式优先**：接入新配置只需声明"做什么"，框架负责"怎么做"
2. **合理默认值**：parser 默认 `json.loads`、validator 默认跳过、fallback 默认 None
3. **安全降级**：解析/校验/应用任一环节失败，保持旧状态不变
4. **全量原子**：要么全量生效，要么全部不生效

### 2.2 架构总览

```
配置中心 (远程)
    ↓ 每 30s 轮询
VivoConfigManager
    ↓ 触发 on_change 回调
ManagedConfigBridge
    ├─ parser(raw) → data
    ├─ validator(data) → bool
    ├─ applier(data) → None
    └─ fallback_loader() → data (本地兜底)
    ↓
子系统 (tool_store / model_registry / ...)
```

**生命周期**：

```
启动时 init_load():
    1. fallback_loader() → 本地数据 → applier() → 子系统就绪
    2. config 中有远程值 → on_change() 覆盖

运行时 on_change() (每 30s 配置中心轮询触发):
    parser(raw) → validator(data) → applier(data)
    任一步骤异常 → 保持旧状态 + logger.error
```

### 2.3 核心对象设计

#### ManagedConfigBridge：配置桥接器

```python
class ManagedConfigBridge:
    """动态配置桥接器 —— 配置中心与子系统之间的标准化适配层。"""
    
    def __init__(
        self,
        key: str,
        parser: Callable[[str], Any],
        validator: Callable[[Any], bool] | None,
        applier: Callable[[Any], None],
        fallback_loader: Callable[[], Any] | None,
    ):
        self._key = key
        self._parser = parser
        self._validator = validator
        self._applier = applier
        self._fallback_loader = fallback_loader

    def init_load(self) -> None:
        """启动时初始化：先加载本地兜底，再尝试用配置中心值覆盖"""
        # 本地兜底
        if self._fallback_loader is not None:
            try:
                local_data = self._fallback_loader()
                if local_data is not None:
                    self._applier(local_data)
                    logger.info(f"[ManagedConfig:{self._key}] 本地兜底加载成功")
            except Exception:
                logger.error(
                    f"[ManagedConfig:{self._key}] 本地兜底加载失败: {traceback.format_exc()}"
                )
        # 配置中心覆盖
        raw = config.get_config(self._key)
        if raw is not None:
            self.on_change()

    def on_change(self) -> None:
        """注册到 config.register_on_change 的无参回调"""
        raw = config.get_config(self._key)
        if raw is None:
            logger.warning(f"[ManagedConfig:{self._key}] 配置中心值为空，保持现状")
            return
        # 解析
        try:
            data = self._parser(raw) if isinstance(raw, str) else raw
        except Exception:
            logger.error(
                f"[ManagedConfig:{self._key}] 解析失败，保持现状: {traceback.format_exc()}"
            )
            return
        # 校验
        if self._validator is not None:
            try:
                if not self._validator(data):
                    logger.error(f"[ManagedConfig:{self._key}] 校验不通过，保持现状")
                    return
            except Exception:
                logger.error(
                    f"[ManagedConfig:{self._key}] 校验异常，保持现状: {traceback.format_exc()}"
                )
                return
        # 应用
        try:
            self._applier(data)
            logger.info(f"[ManagedConfig:{self._key}] 热更新成功")
        except Exception:
            logger.error(
                f"[ManagedConfig:{self._key}] 应用失败，保持现状: {traceback.format_exc()}"
            )
```

**设计要点**：
- **三阶段管道**：parser → validator → applier，任一环节失败保持旧状态
- **本地兜底优先**：`init_load` 先加载本地，再尝试远程覆盖
- **异常隔离**：每个阶段独立 try-except，异常不传播

#### ConfigRegistry：配置注册表

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

**设计要点**：
- **优先级排序**：按 priority 升序初始化，保证依赖顺序
- **去重机制**：重复注册时后者覆盖前者
- **集中初始化**：`init_all` 一次性完成所有配置的加载和注册

#### @managed_config 装饰器

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

**设计要点**：
- **合理默认值**：parser 默认 `json.loads`，validator 默认 None（跳过校验）
- **灵活兜底**：fallback 可以是文件路径或 callable
- **自动注册**：装饰器自动创建 Bridge 并注册到 ConfigRegistry

### 2.4 使用示例

#### 示例 1：模型类型映射

```python
# config/managed_configs/model_type_mapping.py

from config.managed_config import managed_config
from config.model_registry import model_registry

@managed_config("model_type_mapping")
def on_model_type_mapping(data:dict):
    """配置中心下发 model_type → model_name 映射时调用"""
    model_registry.update_type_mapping(data)
```

**说明**：
- 只需一个装饰器函数，无需手动注册
- parser 默认 `json.loads`，validator 默认跳过
- 无本地兜底（fallback=None）
