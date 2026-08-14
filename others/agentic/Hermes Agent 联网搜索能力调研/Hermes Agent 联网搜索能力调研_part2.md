- 将`web_search`和`web_extract`纳入**沙箱允许工具白名单**，是 ProCode 模式下首批开放的核心工具，无需额外配置即可使用。
- 严格约束调用

```plaintext
DEFAULT_TIMEOUT = 300        # 5 minutes
DEFAULT_MAX_TOOL_CALLS = 50
MAX_STDOUT_BYTES = 50_000    # 50 KB
MAX_STDERR_BYTES = 10_000    # 10 KB
```

```plaintext
SANDBOX_ALLOWED_TOOLS = frozenset([
    "web_search",
    "web_extract",
    "read_file",
    "write_file",
    "search_files",
    "patch",
    "terminal",
])
```

- 全链路执行架构：

**桩模块生成**：父进程自动生成`hermes_tools.py` RPC 桩模块，包含`web_search`/`web_extract`的调用签名，脚本可直接导入使用。

**RPC 服务启动**：父进程开启 Unix 域套接字（UDS），启动 RPC 监听线程，负责接收脚本的工具调用请求。

**沙箱脚本执行**：父进程 spawn 隔离的子进程，执行 LLM 生成的 Python 批量搜索脚本，环境隔离无 API 密钥泄露风险。

**工具调用转发**：脚本调用`web_search`/`web_extract`时，请求通过 UDS 回传给父进程，走标准`handle_function_call`工具调度逻辑，和原生工具调用完全一致。

**结果回流与汇总**：工具执行结果通过 RPC 返回给脚本，脚本可做过滤、清洗、二次批量调用，最终将结果打印到 stdout，一次性返回给 LLM。

- 形态 1：批量并行 web_search / web_extract

在单个 ProCode 脚本中，通过线程池（Hermes支持最多8个）并行执行多个`web_search`调用，一次性获取多个关键词的搜索结果，支持批量 query、自动重试、结果去重过滤。

- 形态 2：搜索 + 提取 全流程联合批量调用

将「批量搜索→URL 筛选→批量提取→结果汇总」全流程闭环在单个 ProCode 脚本中，全程仅需 1 次 LLM 交互。

## 5.2 子Agent 分布式联合调用

只有当任务超出单 Agent 的处理上限、有强隔离需求、强专业分工需求时，子 Agent 才是最优解。

- **子Agent委派：** 针对可拆分的复杂任务，通过delegate_tool.py中`delegate_task`工具实现子Agent委派，最多可同时启动**3个**独立子Agent并行执行子任务；
- **隔离能力**：每个子 Agent 是一个独立的`AIAgent`实例，拥有**完全隔离的上下文、受限的工具集、独立的终端会话、专属的系统 Prompt**，父 Agent 通过`_active_children`属性追踪所有活跃子 Agent，可随时发送中断信号
- **工具权限控制**：父 Agent 可为子 Agent 开放最小必要的工具集，比如仅给子 Agent 开放`web_search`和`web_extract`，禁用高风险的`web_crawl`、终端执行等工具，实现精细化的权限管控
- **结果标准化**：框架要求子 Agent 返回结构化的执行结果，自动销毁实例，父 Agent 可直接将结果注入上下文，无需额外处理，实现无缝协作

# 6.缓存

## 无原生搜索缓存

## 6.1 Prompt前缀缓存

- 原生支持 Anthropic 的断点缓存、OpenAI 兼容格式的服务端前缀缓存，可通过`config.yaml`中`prompt_caching: mode: enabled`一键开启
- 系统 Prompt 中包含`web_search`/`web_extract`的工具 Schema、角色定义、使用规则等固定内容，占比超过 80%，这部分内容会被标记为缓存断点，重复对话中不会重复计费、重复计算
- 即使是多轮搜索对话，固定前缀的缓存命中率可达 90% 以上，大幅降低高频搜索场景的 token 成本

## 6.2 会话历史检索缓存

四层记忆架构的核心组成，实现跨轮次、跨会话的搜索结果复用。

- 所有对话内容（包括`web_search`/`web_extract`的返回结果、LLM 基于搜索结果的总结），都会自动持久化到本地 SQLite 数据库（`~/.hermes/state.db`），并通过 FTS5 全文搜索引擎建立索引
- 同一个会话内：LLM 可直接复用上下文里已有的搜索结果，不会重复调用相同 query 的`web_search`，实现会话内的零成本复用
- 跨会话场景：当用户发起新的搜索请求时，LLM 会先通过`session_search`检索历史会话中的相关搜索结果，若已有匹配的有效信息，可直接复用，避免重复 API 调用

## 6.3 内容摘要缓存

- `web_extract`提取的超长内容，会通过辅助 LLM 做智能摘要压缩，平均压缩比可达 93%，大幅降低 token 占用
- 框架对摘要结果做了内存 LRU 缓存，缓存键为原始内容的 HASH 值，相同 URL 的相同内容，不会重复触发摘要计算
- 支持设置缓存 TTL 与最大条目数，避免内存持续增长，默认最大缓存 1000 条摘要结果
- 对同一个 URL 的重复`web_extract`调用，可直接复用已缓存的摘要结果，跳过 LLM 摘要步骤，降低辅助模型（gemini flash）调用成本。

## 6.4 会话持久化与记忆更新

会话结束后，将完整对话轨迹持久化到数据库，更新用户记忆与技能库，完成Hermes Agent的闭环学习循环，实现跨会话的能力沉淀。

- 实现细节

1. 会话全量持久化：将完整对话消息、工具调用全记录、执行结果、会话元数据（session_id、平台、时间、模型等）写入SQLite数据库，同时建立FTS5全文索引，支持后续跨会话检索。

2. 记忆系统更新：基于本次会话的执行结果，通过memory_tool.py更新两类核心记忆：

memory.md：存储环境事实、项目惯例、工具特性等任务相关知识；

USER.md：存储用户偏好、沟通风格、工作流习惯等用户画像信息；

记忆采用有界设计，强制Agent优先保留高价值信息，避免记忆无限膨胀。

3. 技能自主沉淀：若本次会话完成了复杂多步工具调用任务，Agent可自主将执行流程沉淀为可复用的Skill文件，存入技能库，后续会话可直接调用，实现能力的自我进化。

# 7.总结

Hermes Agent联网搜索能力主要来自两个工具web_search,web_extract。两个工具独立实现，框架启动时通过全局工具注册表，统一注册工具，完成工具元信息、入参 Schema、能力描述的全局录入。同时把工具分组为不同工具集，根据会话权限、配置开关，选用工具集注入prompt，暴露给llm。llm自主推理是否需要调用工具联网搜索，若不需要，纯问答；若需要，llm返回标准化 `tool_calls` 结构化指令。解析指令+参数校验后，工具调度层统一解析多工具调用关系，内置固定调度策略。调度器根据工具名分发至对应工具类的handler方法。LLM 基于搜索 / 提取结果判断信息是否充足，充足则生成最终回答，不足则启动多轮补充搜索，形成闭环。