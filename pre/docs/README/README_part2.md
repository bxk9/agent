# 配置中心每 30 秒同步一次
config.register_on_change("mcp_intention_mapping", reload_mcp_mapping)
```
**灵活性**：业务规则变更无需重启服务

---

## 📝 开发指南

### 代码规范
- 遵循 PEP 8 规范
- 使用类型注解
- 添加必要的注释和文档字符串

### 提交规范
```
<type>(<scope>): <subject>

<body>

<footer>
```

**type 类型：**
- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建/工具相关

### 分支管理
- `main`: 生产分支
- `develop`: 开发分支
- `feature/*`: 功能分支
- `hotfix/*`: 紧急修复分支

---

## 🤝 贡献指南

欢迎贡献代码、文档或提出建议！

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

---

## 📞 支持与反馈

如有问题或建议，请通过以下方式联系：

- 📧 邮箱：[team@example.com](mailto:team@example.com)
- 💬 内部沟通：企业微信群「Dynamic Router 技术支持」
- 🐛 问题���馈：GitLab Issues

---

## 📄 许可证

本项目仅供内部使用。

---

## 📚 相关资源

### 内部资源
- [GitLab 仓库](https://gitlab.example.com/dynamic_router)
- [Jenkins 构建](https://jenkins.example.com/job/dynamic_router)
- [Grafana 监控](https://grafana.example.com/d/dynamic_router)
- [日志平台](https://logs.example.com/app/dynamic_router)

### 外部资源
- [FastAPI 文档](https://fastapi.tiangolo.com/)
- [vLLM 文档](https://docs.vllm.ai/)
- [SGLang 文档](https://sgl-project.github.io/)
- [Qwen 模型](https://qwenlm.github.io/)

---

## 📊 版本历史

### v2.0.0 (2024-01)
- ✨ 支持 SGLang 早停优化
- ✨ 新增多维度分类体系
- 🚀 性能提升 80%
- 📝 完善文档体系

### v1.0.0 (2023-12)
- 🎉 首次发布
- ✨ 基础路由功能
- ✨ 向量检索辅助
- ✨ 动态配置管理

---

**文档版本**：v2.0.0  
**最后更新**：2024-01-XX  
**维护团队**：Dynamic Router Team

---

<div align="center">

**🌟 如果这个项目对你有帮助，请给一个 Star 支持！ 🌟**

[⬆ 返回顶部](#dynamic-router-项目文档集)

</div>
