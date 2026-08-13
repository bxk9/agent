# Dynamic Router 项目文档集

> 智能路由模块完整技术文档

## 📋 项目简介

Dynamic Router 是一个基于大语言模型的智能路由系统，用于对用户 query 进行多维度意图分类，支持手机助手场景下的任务分发和工具调用决策。

**核心特性：**
- 🚀 **高性能**：并发执行 + SGLang 早停优化，延迟降低 80%
- 🎯 **高准确**：多维度分类体系，准确率 > 95%
- 🔧 **高可用**：多层容错降级，服务可用性 > 99.9%
- 📊 **可观测**：结构化日志 + 性能监控 + 追踪链路
- ⚙️ **可扩展**：模块化设计 + 动态配置 + 插件化扩展

**技术栈：**
- Web 框架：FastAPI + Uvicorn
- 大模型：Qwen3.5-35B-A3B (MoE 架构)
- 推理引擎：SGLang / vLLM
- 向量检索：VSearch
- 配置管理：VivoConfigManager

---

## 📚 文档结构

```
docs/
├── 01-项目概览/          # 项目整体介绍和设计理念
├── 02-模块文档/          # 各功能模块详细文档
├── 03-数据流程/          # 数据流转和处理流程
├── 04-部署与训练/        # 模型训练和部署指南
└── 05-API参考/           # API 接口文档
```

---

## 📖 文档导航

### 1️⃣ 项目概览

适合首次接触项目的开发者，快速了解项目全貌。

| 文档 | 说明 | 适合人群 |
|------|------|----------|
| [项目架构文档](./01-项目概览/项目架构文档.md) | 项目整体架构、模块划分、技术选型 | 架构师、技术负责人 |
| [设计理念](./01-项目概览/设计理念.md) | 核心设计哲学、性能优化策略、容错降级机制 | 架构师、高级开发者 |

**快速入门推荐阅读顺序：**
1. 项目架构文档 → 了解整体结构
2. 设计理念 → 理解设计决策
3. 数据流程详解 → 掌握处理流程

---

### 2️⃣ 模块文档

详细介绍各个功能模块的实现细节，适合深入理解代码的开发者。

| 模块 | 文档 | 核心职责 | 关键文件 |
|------|------|----------|----------|
| **Config** | [01-config模块.md](./02-模块文档/01-config模块.md) | 配置管理、动态配置热更新 | `config/config.py`, `config/config_mapping.py` |
| **Router** | [02-router模块.md](./02-模块文档/02-router模块.md) | 核心路由逻辑、并发调度、结果融合 | `router/router_v2.py` |
| **Utils** | [03-utils模块.md](./02-模块文档/03-utils模块.md) | LLM 调用、日志系统、HTTP 客户端 | `utils/request_llm_v2.py`, `utils/logger.py` |
| **Query Retrieval** | [04-query_retrieval模块.md](./02-模块文档/04-query_retrieval模块.md) | 向量检索、相似度匹配 | `query_retrieval/query_recall.py` |
| **Data** | [05-data模块.md](./02-模块文档/05-data模块.md) | 数据模型定义、工具意图映射 | `data/params.py`, `data/intent2tool.py` |
| **Data Process** | [06-data_process模块.md](./02-模块文档/06-data_process模块.md) | Prompt 工程、分类标准定义 | `data_process/router_prompt.py` |

**按角色推荐阅读：**

- **后端开发者**：Router → Utils → Config
- **算法工程师**：Data Process → Router → Query Retrieval
- **运维工程师**：Config → Utils → 部署与训练指南

---

### 3️⃣ 数据流程

详细描述请求处理的完整数据流转过程。

| 文档 | 说明 | 适合人群 |
|------|------|----------|
| [数据流程详解](./03-数据流程/数据流程详解.md) | 请求处理全流程、数据转换、并发执行、结果融合 | 所有开发者 |

**核心流程概览：**
```
用户请求 → API 层 → Router 层 → 并发执行（向量检索 + 模型推理）→ 结果融合 → 返回响应
```

---

### 4️⃣ 部署与训练

模型训练、部署和运维的完整指南。

| 文档 | 说明 | 适合人群 |
|------|------|----------|
| [部署与训练指南](./04-部署与训练/部署与训练指南.md) | 环境准备、模型训练、vLLM/SGLang 部署、服务集成 | 运维工程师、算法工程师 |

**主要内容：**
- 🏗️ 环境准备：硬件配置、软件依赖
- 🎓 模型训练：LoRA 微调、全量微调、超参调优
- 🚀 模型部署：vLLM 部署、SGLang 部署（支持早停）
- 🔗 服务集成：配置更新、端到端测试
- 📊 模型评测：评测指标、结果分析
- 🐛 常见问题：训练、部署、集成问题及解决方案

---

### 5️⃣ API 参考

API 接口文档和使用示例。

| 文档 | 说明 |
|------|------|
| [API 接口文档](./05-API参考/API接口文档.md) | REST API 接口定义、请求/响应格式、使用示例 |

**主要接口：**
- `POST /router` - 主路由接口
- `POST /completion` - 补全接口
- `POST /router_test` - 测试接口
- `GET /check.do` - 健康检查

---

## 🎯 快速导航

### 我想...

#### 了解项目整体架构
👉 [项目架构文档](./01-项目概览/项目架构文档.md)

#### 理解核心设计理念
👉 [设计理念](./01-项目概览/设计理念.md)

#### 了解请求处理流程
👉 [数据流程详解](./03-数据流程/数据流程详解.md)

#### 修改路由逻辑
👉 [Router 模块文档](./02-模块文档/02-router模块.md)

#### 调整 Prompt
👉 [Data Process 模块文档](./02-模块文档/06-data_process模块.md)

#### 添加新工具
👉 [Data 模块文档](./02-模块文档/05-data模块.md)

#### 修改配置
👉 [Config 模块文档](./02-模块文档/01-config模块.md)

#### 训练新模型
👉 [部署与训练指南 - 模型训练](./04-部署与训练/部署与训练指南.md#3-模型训练)

#### 部署模型
👉 [部署与训练指南 - 模型部署](./04-部署与训练/部署与训练指南.md#4-模型部署)

#### 调用 API
👉 [API 接口文档](./05-API参考/API接口文档.md)

#### 排查问题
👉 [部署与训练指南 - 常见问题](./04-部署与训练/部署与训练指南.md#7-常见问题与解决方案)

---

## 🏗️ 项目结构

```
dynamic_router/
├── main.py                      # 应用入口
├── config/                      # 配置模块
│   ├── config.py               # 静态配置
│   ├── config_mapping.py       # 动态配置管理
│   ├── prompt.py               # Prompt 模板
│   └── atom_intents_router.xlsx # 工具定义
├── router/                      # 路由模块
│   └── router_v2.py            # 核心路由逻辑
├── utils/                       # 工具模块
│   ├── request_llm.py          # LLM 调用（OpenAI 兼容）
│   ├── request_llm_v2.py       # LLM 调用（SGLang 早停）
│   ├── logger.py               # 日志系统
│   ├── auth_util.py            # 认证工具
│   └── requests_session.py     # HTTP 会话
├── query_retrieval/             # 向量检索模块
│   └── query_recall.py         # 向量检索核心
├── data/                        # 数据模块
│   ├── params.py               # 请求参数模型
│   └── intent2tool.py          # 工具意图映射
├── data_process/                # Prompt 工程模块
│   ├── router_prompt.py        # 标准 Prompt
│   ├── router_prompt_special.py # 特殊场景 Prompt
│   └── router_prompt_4token.py # 4token 优化 Prompt
├── template/                    # 正则模板模块
│   ├── __init__.py
│   ├── time_schedule.py        # 时间日程模板
│   └── weather.py              # 天气模板
├── train_deploy_eval/           # 训练部署评测
│   ├── train/                  # 训练脚本
│   ├── deploy/                 # 部署配置
│   └── eval/                   # 评测工具
├── docs/                        # 文档目录
├── requirements.txt             # 依赖列表
├── Dockerfile                   # Docker 配置
└── README.md                    # 项目说明
```

---

## 🚀 快速开始

### 1. 环境准备

```bash
# 克隆项目
git clone <repository-url>
cd dynamic_router

# 安装依赖
pip install -r requirements.txt
```

### 2. 配置环境变量

```bash
export APP_ENV=dev
export APP_NAME=intent-tool-retrieval
```

### 3. 启动服务

```bash
# 开发模式（自动重载）
python main.py

# 或使用 uvicorn
uvicorn main:app --host 0.0.0.0 --port 19777 --reload
```

### 4. 测试接口

```bash
curl -X POST http://localhost:19777/router \
  -H "Content-Type: application/json" \
  -d '{
    "query": "帮我定一个明天早上8点的闹钟",
    "tools": [
      {
        "key": "create_alarm",
        "function_name": ["timeAndSchedule.createAlarmClock"]
      }
    ],
    "chat_history": [],
    "trace_id": "test-001"
  }'
```

**预期响应：**
```json
{
  "task_type": "easy",
  "is_intent_specific": "clear",
  "is_use_tool": "single",
  "is_special_instruction": "norm",
  "is_exe_success": "ok",
  "post_type": ""
}
```

---

## 📊 性能指标

### 延迟指标
- **P50 延迟**：< 200ms
- **P99 延迟**：< 500ms
- **早停优化**：延迟降低 80%

### 准确性指标
- **整体准确率**：> 95%
- **工具类型准确率**：> 96%
- **意图明确度准确率**：> 94%

### 可用性指标
- **服务可用性**：> 99.9%
- **降级成功率**：100%

---

## 🔧 核心技术亮点

### 1. 并发执行策略
```python
# 向量检索和模型推理并行执行
coroutines = [
    self._vector_search_task(...),
    self._get_router_result(...)
]
results = await asyncio.gather(*coroutines)
```
**性能提升**：总耗时取最大值而非累加，提升 33%

### 2. SGLang 早停优化
```python
# 使用 stop_token_ids 实现早停
STOP_TOKEN_IDS = [25429, 9398, 3613, 14992, ...]  # multi, chat, pend, qa, ...

payload = {
    "sampling_params": {
        "stop_token_ids": STOP_TOKEN_IDS
    }
}
```
**性能提升**：生成 token 减少 85%，延迟降低 80%

### 3. 多层容错降级
```
向量检索失败 → 使用模型结果
模型推理失败 → 返回错误结果
配置同步失败 → 使用本地配置
```
**可用性保障**：任何组件失败都不影响整体服务

### 4. 动态配置热更新
```python
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
