如果配置非常大（如 MB 级），可以考虑增量更新或懒加载。

**Q: 如何监控配置更新？**

A: 通过日志监控：
1. `init_load` 成功：`[ManagedConfig:{key}] 本地兜底加载成功`
2. `on_change` 成功：`[ManagedConfig:{key}] 热更新成功`
3. 任何环节失败：`[ManagedConfig:{key}] {阶段}失败，保持现状`

可以接入日志监控系统（如 ELK），设置告警规则。

**Q: 配置桥接框架与 Spring Cloud Config 的区别是什么？**

A: 
- **Spring Cloud Config**：基于 Git 的配置中心，支持多环境、版本管理
- **本框架**：轻量级配置桥接，专注于配置加载、校验、应用、兜底

本框架更轻量，适合 Python 生态；Spring Cloud Config 更完整，适合 Java 生态。

---

**相关文档**：
- [三阶段流水线架构重构](./01-three-stage-pipeline.md)
- [Patch 动态干预系统](./10-patch-system.md)
- [工具共现仲裁系统](./09-tool-arbitration.md)
