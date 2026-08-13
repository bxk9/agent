| `_stage_infer` | `stage_infer.py` | 构建 system_prompt/消息 → 推理-校验-重试循环 → 解析工具调用 |
| `_stage_finalize` | `stage_finalize.py` | 上屏合并 → session 去重 → 推荐位 → emit SSE → 持久化 |

### 4.3 模型层（model/）

**职责**：模型协议适配、流式推理、工具调用解析

**核心组件**：

| 组件 | 文件 | 职责 |
|---|---|---|
| `Model` | `model/base.py` | 模型抽象基类 |
| `XuanjiModel` | `model/xuanji/` | 玄机网关客户端（双协议） |
| `Model` | `model/openai_model/` | OpenAI 兼容协议模型 |
| `StreamMeta` | `model/stream_events.py` | 流式元数据（TTFT、token 统计） |

**多协议支持**：

| 模型 | 协议 | 用途 |
|---|---|---|
| `Doubao-Seed-2.0-pro` | 玄机 | 生产主力模型（Pro type 默认） |
| `BlueLM-Qwen3.5-35B-A3B-sft` | OpenAI 兼容 | Flash type 默认 |

### 4.4 工具层（tools/）

**职责**：工具注册、预处理、后处理、验证

**核心组件**：

| 组件 | 文件 | 职责 |
|---|---|---|
| `Tool` | `tools/tool.py` | 工具数据模型 + pre/post_process 调度 |
| `ToolRegistry` | `tools/tool_registry.py` | 类型化注册表 + 原子替换 |
| `validator.py` | `tools/validator.py` | 三阶段验证框架核心逻辑 |
| `mcp/` | `tools/mcp/` | MCP 工具定义、预处理、后处理、验证器 |

**工具生命周期**：

```
工具召回 → 预处理(pre_process) → 验证(validate) → 执行 → 后处理(post_process)
```

### 4.5 配置层（config/）

**职责**：配置管理、模型注册、动态配置桥接

**核心组件**：

| 组件 | 文件 | 职责 |
|---|---|---|
| `ModelRegistry` | `config/model_registry.py` | model_type → 模型实例的单一真相源 |
| `ManagedConfigBridge` | `config/managed_config.py` | 配置中心→子系统标准化适配 |
| `VivoConfigManager` | `config/config_server/` | 远程配置中心轮询（30s） |
| `managed_configs/` | `config/managed_configs/` | 声明式配置注册目录 |

**动态配置桥接**：

| 配置键 | 子系统 |
|---|---|
| `mcp_intention_mapping` | 工具意图映射 |
| `model_type_mapping` | 模型类型映射 |
| `system_prompt` | 系统提示词 |
| `patch_configs` | Patch 规则 |
| `validator_configs` | 验证器规则 |
| `model_config_override` | 模型配置覆盖 |

### 4.6 运营能力层（operations/）

**职责**：运营干预、彩蛋、Patch、仲裁

**核心组件**：

| 组件 | 目录 | 职责 |
|---|---|---|
| 彩蛋系统 | `operations/easter_egg/` | 运营彩蛋匹配与注入 |
| Patch 系统 | `operations/patches/` | Query Patch 动态注入 |
| 仲裁系统 | `operations/arbitration/` | 工具共现仲裁 |

### 4.7 基础设施层（infra/）

**职责**：通用工具、上下文压缩、日志、认证

**核心组件**：

| 组件 | 文件 | 职责 |
|---|---|---|
| `ContextPipeline` | `infra/context_pipeline/` | 四级上下文压缩管道 |
| `logger.py` | `infra/logger.py` | loguru 日志 + trace_id |
| `auth_utils.py` | `infra/auth_utils.py` | 玄机协议 HMAC-SHA256 签名 |
| `special_token_utils.py` | `infra/special_token_utils.py` | SpecialToken 状态机 |
| `extra_system_prompt_utils.py` | `infra/extra_system_prompt_utils.py` | 动态系统提示词片段 |

---

## 5 核心模块地图

### 5.1 模块依赖关系

```
main.py
  ├─ agent/pro/agent.py (HostAgent)
  │   ├─ agent/pro/stage_prepare.py
  │   │   ├─ operations/easter_egg/
  │   │   ├─ operations/patches/
  │   │   ├─ tools/tool.py
  │   │   └─ agent/pro/hooks/
  │   ├─ agent/pro/stage_infer.py
  │   │   ├─ model/base.py
  │   │   ├─ operations/arbitration/
  │   │   ├─ tools/validator.py
  │   │   └─ agent/pro/stream/
  │   └─ agent/pro/stage_finalize.py
  │       └─ tools/tool_response.py
  ├─ config/
  │   ├─ model_registry.py
  │   ├─ managed_config.py
  │   └─ config_server/
  └─ infra/
      ├─ logger.py
      └─ context_pipeline/
```

### 5.2 数据流方向

```
请求入口 (main.py)
    ↓
AgentContext + body
    ↓
_stage_prepare (工具集构建、Patch/彩蛋注入)
    ↓
TurnState (单轮状态)
    ↓
_stage_infer (推理、验证、重试)
    ↓
SSE 事件流 (text/tool/end)
    ↓
_stage_finalize (去重、推荐位、持久化)
    ↓
响应返回客户端
```

---

## 6 关键技术栈

### 6.1 核心框架

| 技术 | 版本 | 用途 |
|---|---|---|
| Python | 3.10+ | 开发语言 |
| FastAPI | - | Web 框架 |
| Uvicorn | - | ASGI 服务器 |
| Pydantic | v2 | 数据建模与校验 |
| httpx | - | 异步 HTTP 客户端 |
| loguru | - | 结构化日志 |

### 6.2 外部依赖

| 服务 | 用途 |
|---|---|
| 意图检索服务 | 工具/设置召回 |
| 玄机网关 | LLM 推理 |
| 配置中心 | 远程配置管理 |
| Redis | 缓存/会话存储 |
| Elasticsearch | 工具意图检索 |

### 6.3 开发工具

| 工具 | 用途 |
|---|---|
| ruff | 代码格式化与 lint |
| pytest | 单元测试 |
| Docker | 容器化部署 |

---

## 7 部署架构

### 7.1 容器化部署

```dockerfile
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### 7.2 运行配置

```python
uvicorn.run(
    'main:app',
    host='0.0.0.0',
    port=8080,
    reload=False,
    workers=1,  # 单 worker，批处理逻辑在模型内部
    timeout_keep_alive=75
)
```

### 7.3 环境配置

通过 `APP_ENV` 环境变量选择配置：

| 环境 | 说明 |
|---|---|
| `dev` | 开发环境 |
| `test` | 测试环境 |
| `pre` | 预发布环境 |
| `prd` | 生产环境 |

---

## 附录：术语表

| 术语 | 说明 |
|---|---|
| **TurnState** | 单轮编排的唯一真值状态，收敛所有散落的局部变量 |
| **ModelSession** | 持有当前模型实例 + 切换能力的会话级状态 |
| **SSE** | Server-Sent Events，流式响应协议 |
| **MCP** | Model Context Protocol，工具调用协议 |
| **TTFT** | Time To First Token，首字时间 |
| **Patch** | Query Patch，基于请求特征动态注入工具/设置/提示词 |
| **仲裁** | 工具共现仲裁，解决能力重叠工具的选择问题 |
| **彩蛋** | 运营彩蛋，特定关键词触发特效或跳转 |
| **Context Pipeline** | 上下文压缩管道，四级压缩策略 |
| **Responses API** | 模型推理 API，支持 KV Cache 复用 |

---

**下一步阅读**：
- [设计理念文档](../design/README.md) - 深入理解架构设计背后的思考
- [模块详解文档](../modules/README.md) - 各模块的详细实现与接口
- [数据流文档](../dataflow/README.md) - 完整请求数据流与状态流转
