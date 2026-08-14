c3d4e5f6 | 2026-06 | 李明政 | feat(config): 新增本地兜底（fallback）
d4e5f6g7 | 2026-06 | 李明政 | feat(config): 新增优先级机制（priority）
e5f6g7h8 | 2026-06 | 李明政 | feat(config): 新增 ConfigRegistry
f6g7h8i9 | 2026-06 | 李明政 | feat(config): 新增全量原子更新
g7h8i9j0 | 2026-06 | 李明政 | feat(config): 新增 30 秒轮询
```

### 4.2 相关代码文件

- `config/managed_config.py`：ManagedConfigBridge 核心实现
  - `@managed_config`：声明式装饰器（第 10-30 行）
  - `ManagedConfigBridge`：配置桥接器（第 35-80 行）
  - `init_load()`：启动时初始化（第 85-100 行）
  - `on_change()`：配置变更回调（第 105-130 行）
- `config/config_registry.py`：ConfigRegistry 配置注册表
  - `ConfigRegistry`：全局配置注册表（第 10-30 行）
  - `init_all()`：统一初始化（第 35-50 行）
- `config/config_server/__init__.py`：配置中心客户端
  - `VivoConfigManager`：配置中心管理器（第 10-40 行）
  - `_poll_config()`：30 秒轮询（第 45-60 行）
- `tools/tool_registry.py`：ToolRegistry 工具注册表
  - `replace()`：全量原子更新（第 10-20 行）
- `docs/plans/managed_config_v2_declarative.md`：设计文档
- `docs/plans/config_center_expansion.md`：配置中心扩展设计文档

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-13 | 首次建立，基于 git 证据链还原动态配置桥接框架的真实成因 |
| v2.0 | 2026-08-14 | 参照三层防御原因说明示例改写：来源+原文+详细解释+场景示例结构，补充真实代码行号引用 |
