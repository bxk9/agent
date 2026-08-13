# pro_agent 项目文档集

> 版本：v4.0 | 更新时间：2026-08-11
>
> 本文档集基于项目实际代码，全面描述 pro_agent 的架构设计、模块实现、数据流转和核心机制。

---

## 📚 文档导航

### 🏗️ 架构文档

| 文档 | 说明 |
|---|---|
| [整体架构文档](./architecture/README.md) | 项目概述、架构演进、分层架构、核心模块地图、技术栈、部署架构 |
| [整体设计理念](./design/README.md) | 设计哲学、核心设计模式、关键设计决策、架构权衡与取舍、演进式架构 |

### 📦 模块详解

| 模块 | 文档 | 核心内容 |
|---|---|---|
| **Agent** | [agent.md](./modules/agent.md) | 薄壳编排器、TurnState、三阶段流水线、推理干预层、流式处理管道 |
| **Model** | [model.md](./modules/model.md) | 多协议适配、流式推理、工具调用解析、Responses API 缓存 |
| **Tools** | [tools.md](./modules/tools.md) | 工具注册、预处理/后处理、三阶段验证框架、MCP 工具定义 |
| **Config** | [config.md](./modules/config.md) | 动态配置桥接、模型注册表、环境配置 |
| **Infra** | [infra.md](./modules/infra.md) | Context Pipeline、日志系统、认证工具、系统提示词构建 |
| **Operations** | [operations.md](./modules/operations.md) | 彩蛋系统、Patch 系统、仲裁系统 |
| **Tests** | [tests.md](./modules/tests.md) | 批量评测、评估框架、脚本测试、测试数据管理 |

### 🔄 数据流文档

| 文档 | 说明 |
|---|---|
| [数据流与生命周期](./dataflow/README.md) | 完整请求数据流、状态流转图、生命周期管理、关键路径分析、错误处理、性能优化 |

---

## 🎯 快速入门

### 想了解项目全貌？

1. 阅读 [整体架构文档](./architecture/README.md) - 了解项目定位、架构总览、模块划分
2. 阅读 [整体设计理念](./design/README.md) - 理解设计哲学、核心模式、关键决策

### 想了解某个模块？

直接跳转到对应的模块文档：
- [Agent 模块](./modules/agent.md) - 核心编排层
- [Model 模块](./modules/model.md) - 模型推理层
- [Tools 模块](./modules/tools.md) - 工具管理层
- [Config 模块](./modules/config.md) - 配置管理层
- [Infra 模块](./modules/infra.md) - 基础设施层
- [Operations 模块](./modules/operations.md) - 运营能力层

### 想了解请求处理流程？

阅读 [数据流与生命周期](./dataflow/README.md) - 完整请求数据流、状态流转、关键路径

---

## 📖 文档结构

```
docs_new/
├── README.md                    # 本文档（总索引）
├── architecture/                # 架构文档
│   └── README.md               # 整体架构文档
├── design/                      # 设计理念文档
│   └── README.md               # 整体设计理念
├── modules/                     # 模块详解文档
│   ├── agent.md                # Agent 模块
│   ├── model.md                # Model 模块
│   ├── tools.md                # Tools 模块
│   ├── config.md               # Config 模块
│   ├── infra.md                # Infra 模块
│   ├── operations.md           # Operations 模块
│   └── tests.md                # Tests 测试体系
└── dataflow/                    # 数据流文档
    └── README.md               # 数据流与生命周期
```

---

## 🔑 核心概念速查

### 三阶段流水线

| 阶段 | 职责 | 文档 |
|---|---|---|
| **prepare** | 输入解析、工具集构建、运营干预 | [agent.md](./modules/agent.md#4-三阶段流水线详解) |
| **infer** | 推理、验证、重试 | [agent.md](./modules/agent.md#4-三阶段流水线详解) |
| **finalize** | 去重、推荐位、SSE 下发 | [agent.md](./modules/agent.md#4-三阶段流水线详解) |

### 核心状态对象

| 对象 | 说明 | 文档 |
|---|---|---|
| **TurnState** | 单轮唯一真值 | [agent.md](./modules/agent.md#32-turnstate单轮唯一真值) |
| **ModelSession** | 模型会话（当前模型 + 切换） | [agent.md](./modules/agent.md#33-modelsession模型会话) |
| **AgentContext** | 请求级上下文（跨轮次） | [agent.md](./modules/agent.md#35-agentcontext请求级上下文) |

### 验证框架

| 阶段 | 说明 | 文档 |
|---|---|---|
| **Phase 1** | 逐工具验证（Rule/LLM/Config） | [tools.md](./modules/tools.md#8-三阶段验证框架) |
| **Phase 2** | 全局批量验证（GlobalValidator） | [tools.md](./modules/tools.md#8-三阶段验证框架) |
| **Phase 3** | 配置驱动验证器 | [tools.md](./modules/tools.md#8-三阶段验证框架) |

### 运营干预系统

| 系统 | 说明 | 文档 |
|---|---|---|
| **彩蛋系统** | 关键词匹配 → 注入工具 | [operations.md](./modules/operations.md#3-彩蛋系统) |
| **Patch 系统** | 请求特征 → 注入工具/设置/提示词 | [operations.md](./modules/operations.md#4-patch-系统) |
| **仲裁系统** | 工具共现 → 注入策略提示词 | [operations.md](./modules/operations.md#5-仲裁系统) |

---

## 🚀 常见场景

### 新增工具

1. 阅读 [Tools 模块 - MCP 工具定义](./modules/tools.md#9-mcp-工具定义)
2. 在 `tools/mcp/mcp_definitions/` 下添加工具 JSON Schema
3. 在 `resources/mappings/mcp_intention_mapping/` 中添加意图映射
4. （可选）添加预处理/后处理/验证器

### 新增 Patch

1. 阅读 [Operations 模块 - Patch 系统](./modules/operations.md#4-patch-系统)
2. 在 `operations/patches/configs/` 下添加 Patch 配置
3. 或通过配置中心热更新

### 新增仲裁规则

1. 阅读 [Operations 模块 - 仲裁系统](./modules/operations.md#5-仲裁系统)
2. 在 `operations/arbitration/configs/` 下添加 JSON 元数据 + MD 策略正文
3. 重启服务或调用 `reload_rules()` 热加载

### 新增配置桥接

1. 阅读 [Config 模块 - 动态配置桥接框架](./modules/config.md#4-动态配置桥接框架)
2. 在 `config/managed_configs/` 下新建 `<key>.py`
3. 用 `@managed_config("<key>")` 装饰 applier 函数
4. 在 `config/managed_configs/__init__.py` 中 import

---

## 📊 性能优化

### TTFT 优化

阅读 [数据流 - 性能优化路径](./dataflow/README.md#6-性能优化路径)

- **Responses API 缓存**：复用 KV Cache，减少 TTFT 30-50%
- **Context Pipeline 压缩**：四级压缩策略，控制 token 预算
- **工具排序优化**：提升 prompt cache 前缀稳定性
- **TTFT 分桶埋点**：定位性能瓶颈（A/B/C/D 四段）

### 调试工具

| 工具 | 用途 |
|---|---|
| `dump_openai_raw_sse.py` | 导出 OpenAI 协议原始 SSE |
| `dump_vivo_raw_sse.py` | 导出 Vivo 协议原始 SSE |
| `debug_llm_judge.py` | 调试 LLM Judge 评估 |
| `verify_usage_capture.py` | 验证 usage 提取 |

---

## 🔗 相关资源

### 项目文件

- `main.py` - FastAPI 应用入口
- `requirements.txt` - Python 依赖
- `Dockerfile` - 容器化部署
- `ruff.toml` - 代码格式化配置

### 旧版文档

- `docs/architecture.md` - 旧版架构文档（v3.3）
- `docs/guides/` - 开发指南
- `docs/plans/` - 方案设计文档
- `docs/problems/` - 问题记录文档

---

## 📝 文档维护

### 更新原则

1. **代码优先**：文档应反映实际代码实现，而非设计意图
2. **及时更新**：代码变更后及时更新对应文档
3. **示例驱动**：尽量提供代码示例，便于理解
4. **交叉引用**：文档间相互引用，形成知识网络

### 文档格式

- 使用 Markdown 格式
- 表格展示结构化信息
- 代码块使用语法高亮
- 使用 emoji 增强可读性

---

## 🎓 学习路径

### 新手入门

1. 阅读 [整体架构文档](./architecture/README.md) - 了解项目全貌
2. 阅读 [数据流文档](./dataflow/README.md) - 理解请求处理流程
3. 阅读 [Agent 模块](./modules/agent.md) - 理解核心编排逻辑
4. 运行测试脚本 - 实践理解各模块功能

### 进阶学习

1. 阅读 [设计理念文档](./design/README.md) - 理解设计哲学和权衡
2. 深入各模块文档 - 理解实现细节
3. 阅读旧版 `docs/plans/` - 了解架构演进历程
4. 阅读旧版 `docs/problems/` - 了解问题分析和解决方案

### 专家级

1. 阅读源码 - 结合文档深入理解实现
2. 参与代码 review - 理解设计决策背后的思考
3. 优化性能 - 基于 TTFT 分桶埋点定位瓶颈
4. 扩展功能 - 新增工具/Patch/仲裁规则/配置桥接

---

## 📞 支持

如有问题或建议，请：

1. 查阅相关文档
2. 查看旧版文档（`docs/` 目录）
3. 查看源码注释
4. 联系项目维护者

---

**最后更新**：2026-08-11  
**文档版本**：v4.0  
**维护者**：pro_agent 团队
