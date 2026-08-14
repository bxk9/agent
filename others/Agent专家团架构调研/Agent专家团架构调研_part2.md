##### Agent 层

各专职 Agent 独立工作。每个 Agent 有独立的系统提示词+最小化工具集+明确输入输出契约。接收子任务+上下文
→ 使用工具集 → 返回结构化结果。

##### 4


##### 能力层

原子工具——Agent 的「手��」。文件读写、代码执行、搜索引擎、数据库查询、API 调用等。遵循 MCP 标准
接入。

##### 5


##### 基础层

LLM 推理引擎 + 记忆系统（长期/工作/短期三层）+ 可观测性基础设施。是所有上层能力的底座。

##### 编排层核心能力

任务分解：拆分子任务，构建 DAG 依赖图
Agent 调度：匹配最合适的 Agent，决定
串行/并行
上下文管理：最小上下文原则，为每个
Agent 准备恰好够用的上下文
流程控制：监控执行，异常处理：重试→
换 Agent→降级→终止
结果聚合：将各 Agent 产出整合为完整
交付物
设计类比：编排层是「项目经理」，Agent
是「团队成员」，能力层是「办公工具」，
基础层是「办公基础设施」

##### CHAPTER 05


##### 专家团协作模式 — 4 种基础模式


##### 层级式（Hierarchical）最常用
中心编排者统一分配任务、收集结
果。控制清晰，易追踪，排错简单。
优势
最常用，任务有明确分解结构
注意
编排者可能成为瓶颈和单点故障
适用：子任务之间有依赖关系

##### 对等式（Peer-to-Peer）

Agent 之间直接通信协商，没有中
心节点。灵活，动态协作，无单点
瓶颈。
优势
适合需要频繁协商讨论
注意
难以控制追踪，可能陷入循环讨论
适用：头脑风暴、方案评审

##### 流水线式（Pipeline）

任务按固定顺序流经各 Agent，每
个负责一个阶段。流程清晰，每阶
段可独立优化和替换。
优势
流程清晰，易于优化
注意
串行延迟高，前一阶段阻塞影响全
流程
适用：任务有明确阶段划分

##### 黑板模式（Blackboard）

多个 Agent 共享知识空间，各自
独立读写。异步工作，信息共享方
便，适合探索性问题。
优势
异步协作，信息共享
注意
需要并发控制，数据一致性维护成
本高
适用：多 Agent 协同分析同一问题

##### 11 / 28


##### CHAPTER 05


##### 协作模式 — 4 种高级 + 混合模式


##### 4 种高级模式（2026 生产验证）


##### 5


##### Router 路由分发

低成本模型做分类→分发到对应领域 Agent。节约 40-60% 成本。失败模式：路由错误导致任务进入错误的
Agent → 建议给出置信度分数。

##### 6


##### Critic Loop 审查循环

生成→审查→修正→再审查，直到通过。成本翻倍但错误率大幅下降，可拦截约 70% 幻觉输出。对面向用户的
敏感场景不可省略。

##### 7


##### Swarm 并行采样

多 Agent 并行处理→Judge 选最佳。5 倍成本投入，仅在输出质量比成本更重要时使用。典型场景：广告文案、
营销方案。

##### 8

Bounded Autonomy 边界自治2026 推荐
4 个硬约束：
1、明确的操作范围：代理之间的 Handoff 必须做 Schema 校验
2、置信度阈值——低于阈值时标记为待人工审查，不自动传递给下游 Agent
3、操作日志—每次工具调用、Agent 间通信都被完整记录到审计日志中
4、人工升级路径——高风险操作、低置信度结果、异常输出 → 预定义触发条件，必须人工签字才能继续

##### 模式选择决策

有顺序依赖 → 流水线 | 需协商讨论 → 对等
式
共享数据空间 → 黑板 | 其余 → 层级式
生产验证结论
✅ Orchestrator+Specialists（主导）|
✅ Pipeline with Checkpoints |
✅ Router |
✅ 混合模式

##### 12 / 28


##### CHAPTER 06


##### 关键技术


##### 任务分解 · 上下文管理


##### 任务分解


##### 粒度控制原则：太粗退化为单 Agent，太细通信开销超过收益，合适粒度是每个子任务在一个 Agent 能力范围内可独立


##### 完成和验证。


##### 四种分解策略：功能分解（按模块）· 阶段分解（按流程）· 角色分解（按专业）· 数据分解（按范围）


##### 依赖管理：独立子任务并行执行，有依赖关系的串行执行。通过 depends_on 构建 DAG，编排层按拓扑顺序调度。


##### 上下文管理


##### 最小上下文原则：每个 Agent 只获取完成任务所需的最小上下文。过多浪费 token，过少无法完成任务。


##### 三种传递策略：完整传递（❌上下文爆炸，噪音大）→ 摘要传递（✅精简但可能丢失信息）→ 结构化传递（✅✅推荐：


##### JSON/Schema 作为下游输入契约，信息无损耗，下游可校验）


##### 工具集成（MCP）

描述要明确：LLM 根据工具描述决定是否调用，描述模糊会导致错误调用。好的描述应清晰说明工具的用途和使用场景。
参数要简单：参数越少 LLM 越不容易出错。复杂参数用嵌套对象封装而非平铺大量参数。幂等性：相同输入相同输出，方便失
败重试。

##### 错误处理与恢复

Agent 执行错误（工具调用失败、超时）：重试最多 3 次 → 仍失败上报编排层 → 换工具 / 换 Agent / 标记失败。
输出不合规（格式不匹配 Schema、缺失必填字段）：Schema 校验 → 不通过反馈具体错误让 Agent 修正 → 仍不行降级处理。
流程级错误（Agent 彻底失败、上游依赖缺失）：编排层决策——跳过非关键步骤 / 启用备用 Agent / 回退到检查点 / 终止并通
知用户。

##### CHAPTER 07


##### 工程实践 — 框架对比（2026 最新）

框架 / 版本 定位与核心优势
LangGraph v1.2 生产级图编排：状态机控制、checkpoint 暂停恢复、人机协作中断、LangSmith 可观测性
Claude SDK
2026. 06
Anthropic 原生：分层子 Agent 架构、Skill 系统、MCP 原生集成
CrewAI v1.14 角色驱动快速原型：声明式 API、可插拔 LLM 后端、上手最快
MS Agent FW
v1.0
微软统一框架：合并 Semantic Kernel + AutoGen，.NET / Python 双语言
LlamaIndex v1.0 RAG 驱动：数据密集型场景最佳
Pydantic AI V2 类型安全：Pydantic 团队出品，最佳 Python 开发体验
AutoGen / AG2 维护模式：AutoGen 已并入 MAF，AG2 是社区 fork
2026 关键变化：
开发框架走向统一：微软和OpenAI都整合了自己的工具链，为开发者提供了更清晰、稳定的选择。
连接标准走向统一：MCP协议解决了AI与外部工具连接的碎片化问题。
协作标准走向统一：A2A协议解决了AI与其他AI协作的互通性问

##### 选型速查

Python 生产级 → LangGraph
Anthropic 生态 → Claude SDK
快速原型 → CrewAI
微软 / .NET → MS Agent FW
类型安全 → Pydantic AI
RAG 场景 → LlamaIndex
最大控制 → 自研
常见混合模式
LangGraph 做外层编排，内嵌
AutoGen/AG2 Agent 做对话推理——
LangGraph 负责流程控制，AutoGen Agent
负责专业领域的多轮思考。

##### 16 / 28

CHAPTER 08 github.com/2FastLabs/agent-squad

##### Agent Squad — Classifier 驱动的意图路由

7. 7K stars 原 AWS Labs 项目 · Apache 2.0 · Python/TS/Swift 三语言运行时

##### 核心设计

不预定义 Agent 协作图，而是让 Classifier 根据实时上下文动态决定由谁来处理当前
请求。每个 Agent 注册时提供 name + description 作为分类标签。
Classifier 三要素
1. Agent descriptions——注册时的描述文本，作为分类标签
2. Conversation history——多轮对话上下文，保证连贯性
3. LLM 语义推理——非关键词匹配，纯语义理解

##### 开源参考实现1


##### 关键优势

动态路由：不预定义 Agent 协作图，实时决策
语义驱动：非关键词匹配，避免规则覆盖不全
上下文感知：多轮对话自动切换 Agent
CHAPTER 08 github.com/2FastLabs/agent-squad

##### 进阶SupervisorAgent- 采用 agent-as-tools 架构


##### agent-as-tools 架构：把一个 Supervisor LLM + 多个子 Agent 当作 Tool 调用

多轮思考决策调用链路 调用多个 Agent 后再汇总 共享上下文在各子 Agent 间传递
Supervisor LLM 将子 Agent 视为 Tool → 自主推理「先调谁、后调谁」→ 调多个 → 汇总结果 → 继续推理 → 直到任务完成。不是写死的流水线，而是 LLM 运行
时动态决策。
CHAPTER 08 github.com/google/A2A

##### Google A2A — 协议驱动的 Agent 间通信

24K stars Google 官方 · Apache 2.0 · 示例路径 /samples/python/hosts/multiagent/

##### 核心差异

每个 Specialist 是独立部署的服务（独立端口、独立进程），通过 A2A 协议通信。
Orchestrator 通过 Agent Card 自动发现所有 Specialist 的能力。
运行流程
1. Agent Card 自动发现（/.well-known/agent-card.json）
2. LLM 查卡决定调度策略
3. 通过 JSON-RPC 2.0 调用 Specialist
4. message/send · tasks/get · tasks/cancel
5. Streaming (SSE) + Push Notifications

##### 关键特性


##### ·

零硬编码路由：LLM 看完 Agent 列表自己决定调用策略，新增 Specialist 不需要
改 Orchestrator 代码

##### ·

跨框架天然支持：LangChain 写的 Orchestrator 可以调用 CrewAI 或 ADK 写的
Specialist，只要遵循 A2A 协议

##### ·

Agent Card 是契约：标准化的 JSON 描述，Orchestrator 不需要知道
Specialist 内部实现

##### 两种模式对比

Squad：同进程 Agent 对象 / 一次分类单 Agent / 低复杂度
A2A：独立部署服务 / 多轮灵活调度 / 跨框架天然支持

##### 推荐双层组合

Layer 1：Agent Squad Classifier 入口路由（简单请求直接分发）
Layer 2：A2A Orchestrator 多步骤编排（识别到复杂任务时升级）

##### 19 / 28

CHAPTER 08 github.com/google/A2A

##### Google A2A — 协议驱动的 Agent 间通信


##### 21


##### /


##### Step 1


##### Specialist 端 — 暴露 Agent Card

每个 Specialist 在 /.well-known/agent-card.json 端点暴露自己的能力声明：名
称、技能列表、输入输出格式、端点地址。
Orchestrator 通过 A2ACardResolver 并行获取所有 Agent Card
