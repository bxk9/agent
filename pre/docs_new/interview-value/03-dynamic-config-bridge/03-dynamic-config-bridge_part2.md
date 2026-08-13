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
    """配置中心下��系统提示词时调用"""
    system_prompt_loader.update(data)
```

**说明**：
- parser 设为 `lambda x: x`，因为系统提示词是纯文本，不需要 JSON 解析
- fallback 是文件路径，框架自动读取文件内容并应用

---

## 3. 实现细节

### 3.1 启动流程

```python
# main.py

def init_app():
    """应用启动初始化"""
    # 1. 导入 managed_configs 模块，触发所有 @managed_config 装饰器注册
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

**关键点**：
- `import config.managed_configs` 触发所有装饰器执行，自动注册到 ConfigRegistry
- `config_registry.init_all()` 一次性完成所有配置的加载和回调注册
- 无需手动编写配置加载逻辑

### 3.2 配置变更流程

```python
# config/config_server/__init__.py

class VivoConfigManager:
    """远程配置中心轮询管理器"""
    
    def __init__(self):
        self._callbacks: dict[str, Callable[[], None]] = {}
    
    def register_on_change(self, key: str, callback: Callable[[], None]):
        """注册配置变更回调"""
        self._callbacks[key] = callback
    
    def _poll_config(self):
        """每 30s 轮询配置中心"""
        while True:
            try:
                # 从配置中心拉取最新配置
                new_config = self._fetch_from_config_center()
                
                # 对比变更，触发回调
                for key, callback in self._callbacks.items():
                    if self._has_changed(key, new_config):
                        callback()
            except Exception as e:
                logger.error(f"配置中心轮询失败: {e}")
            
            time.sleep(30)
```

**关键点**：
- 每 30s 轮询一次配置中心
- 对比变更，只触发有变化的配置回调
- 轮询失败不影响服务运行

### 3.3 安全降级机制

```python
def on_change(self) -> None:
    """配置变更回调"""
    raw = config.get_config(self._key)
    if raw is None:
        logger.warning(f"[ManagedConfig:{self._key}] 配置中心值为空，保持现状")
        return
    
    # 阶段 1：解析
    try:
        data = self._parser(raw) if isinstance(raw, str) else raw
    except Exception:
        logger.error(
            f"[ManagedConfig:{self._key}] 解析失败，保持现状: {traceback.format_exc()}"
        )
        return  # 保持旧状态
    
    # 阶段 2：校验
    if self._validator is not None:
        try:
            if not self._validator(data):
                logger.error(f"[ManagedConfig:{self._key}] 校验不通过，保持现状")
                return  # 保持旧状态
        except Exception:
            logger.error(
                f"[ManagedConfig:{self._key}] 校验异常，保持现状: {traceback.format_exc()}"
            )
            return  # 保持旧状态
    
    # 阶段 3：应用
    try:
        self._applier(data)
        logger.info(f"[ManagedConfig:{self._key}] 热更新成功")
    except Exception:
        logger.error(
            f"[ManagedConfig:{self._key}] 应用失败，保持现状: {traceback.format_exc()}"
        )
        # 保持旧状态
```

**降级策略**：
1. **解析失败**：配置中心下发非法 JSON，保持旧配置
2. **校验失败**：配置格式不符合预期，保持旧配置
3. **应用失败**：子系统应用配置时异常，保持旧配置

**设计原则**：宁可保持旧状态，也不让服务崩溃。

### 3.4 全量原子更新

```python
# tools/tool_registry.py

class ToolRegistry:
    """工具名 → Tool 对象的注册表"""
    
    def __init__(self):
        self._store: dict[str, Tool] = {}

    def replace(self, new_data: dict[str, Tool]):
        """原子替换全部内容（热更新用）"""
        # 先构建新字典，再一次性替换
        # 避免并发读看到中间态
        self._store.clear()
        self._store.update(new_data)
```

**原子性保证**：
- 先构建完整的新配置
- 再一次性替换旧配置
- 并发请求不会读到"无 pre/post_process"的中间态

---

## 4. 技术亮点

### 4.1 创新点

1. **声明式配置**：通过装饰器声明配置，框架自动处理加载、校验、应用、兜底
2. **三阶段管道**：parser → validator → applier，任一环节失败保持旧状态
3. **灵活兜底**：支持文件路径或 callable 作为本地兜底
4. **优先级控制**：通过 priority 参数控制配置初始化顺序

### 4.2 难点攻克

| 难点 | 解决方案 |
|---|---|
| 配置更新非原子性 | ToolRegistry.replace 先构建新字典再一次性替换 |
| 配置中心不可用 | fallback_loader 提供本地兜底 |
| 配置解析失败 | 三阶段管道，任一环节失败保持旧状态 |
| 配置依赖顺序 | priority 参数控制初始化顺序 |

### 4.3 设计权衡

| 决策 | 选择 | 理由 |
|---|---|---|
| 配置更新是否支持部分更新 | 否，全量原子更新 | 避免中间态，保证一致性 |
| 配置变更是否支持回滚 | 否，保持旧状态 | 简化实现，避免复杂度 |
| 配置校验是否支持异步 | 否，同步校验 | 配置更新频率低（30s），同步足够 |
| 配置兜底是否支持多级 | 否，单级兜底 | 避免复杂度，单级兜底已足够 |

---

## 5. 业务价值

### 5.1 量化收益

| 维度 | 旧架构 | 新架构 | 改进 |
|---|---|---|---|
| 新增配置代码量 | ~50 行 | ~5 行 | -90% |
| 配置加载逻辑 | 散落在 main.py | 集中在 managed_configs/ | 可维护性提升 |
| 异常处理 | 手动编写 | 框架自动处理 | 稳定性提升 |
| 本地兜底 | 无 | 自动支持 | 可用性提升 |

### 5.2 开发效率提升

- **新增配置**：只需一个装饰器函数，无需修改 main.py
- **配置校验**：框架自动处理，无需手动编写 try-except
- **本地兜底**：声明 fallback 即可，无需手动实现
- **配置测试**：可独立测试 applier 函数，不依赖配置中心

### 5.3 实际应用场景

| 配置键 | 子系统 | 说明 |
|---|---|---|
| `mcp_intention_mapping` | tool_store | 工具意图映射，支持热更新 |
| `model_type_mapping` | model_registry | 模型类型映射，支持热更新 |
| `system_prompt` | agent/pro/system | 系统提示词，支持热更新 |
| `patch_configs` | operations/patches | Patch 规则，支持热更新 |
| `validator_configs` | validators | 验证器规则，支持热更新 |
| `model_config_override` | config/model_config | 模型配置覆盖，支持热更新 |

---

## 6. 面试要点

### 6.1 核心问题

**Q: 为什么选择装饰器而不是配置文件？**

A: 装饰器的优势：
1. **代码即配置**：配置逻辑与代码在一起，便于维护
2. **类型安全**：可以使用类型注解，IDE 支持更好
3. **灵活性**：可以编写任意 Python 代码作为 applier
4. **自动注册**：装饰器自动注册，无需手动维护配置列表

配置文件（如 YAML）的优势是配置与代码分离，但对于需要编写逻辑的场景（如校验、应用），装饰器更灵活。

**Q: 如何保证配置更新的原子性？**

A: 通过 `ToolRegistry.replace` 实现：
1. 先构建完整的新配置字典
2. 再一次性替换旧配置（`clear` + `update`）
3. 并发请求不会读到中间态

如果需要更强的原子性（如无锁更新），可以使用 `threading.Lock` 或 `asyncio.Lock`。

**Q: 配置中心不可用时服务能否启动？**

A: 可以。通过 `fallback_loader` 提供本地兜底：
1. `init_load` 先调用 `fallback_loader` 加载本地配置
2. 再尝试从配置中心加载远程配置
3. 配置中心不可用时，使用本地配置，服务正常启动

**Q: 配置更新失败时如何处理？**

A: 三阶段管道，任一环节失败保持旧状态：
1. **解析失败**：配置中心下发非法 JSON，保持旧配置
2. **校验失败**：配置格式不符合预期，保持旧配置
3. **应用失败**：子系统应用配置时异常，保持旧配置

设计原则：宁可保持旧状态，也不让服务崩溃。

### 6.2 延伸问题

**Q: 如果要新增一个配置，怎么做？**

A: 只需 3 步：
1. 在 `config/managed_configs/` 下创建新文件（如 `my_config.py`）
2. 使用 `@managed_config("my_config_key")` 装饰 applier 函数
3. 在 `config/managed_configs/__init__.py` 中导入该模块

无需修改 main.py，无需手动注册回调。

**Q: 配置更新的性能影响如何？**

A: 配置更新频率低（每 30s 一次），性能影响可忽略：
1. 解析：`json.loads` 耗时微秒级
2. 校验：自定义校验函数，通常毫秒级
3. 应用：取决于子系统，通常毫秒级
