##### 示例

CHAPTER 08 github.com/google/A2A

##### Google A2A — 协议驱动的 Agent 间通信


##### 2


##### 2


##### Step 2


##### Orchestrator 端 — 通过 A2ACardResolver 动态发现所有 Agent

Orchestrator 启动后，通过 A2ACardResolver 并行向所有已知 Specialist 的 Agent
Card 端点发起请求：
1. 读取每个 Specialist 的 name、description、skills 等能力声明
2. 将所有 Agent Card 信息注入 LLM 的上下文（作为系统提示的一部分）
3. LLM 看完所有 Agent 列表，自主决定「用户的任务需要调哪些 Agent」
关键：发现过程是 LLM 驱动的，不是硬编码的路由规则。新增 Specialist 不需要改 Orchestrator
代码，只需启动服务并暴露 Agent Card。
CHAPTER 08 github.com/google/A2A

##### Google A2A — 协议驱动的 Agent 间通信


##### 23


##### /


##### 零硬编码路由

LLM 看完 Agent 列表自己决定调
用策略。新增 Specialist 不需要改
Orchestrator 代码，只需启动服务
并暴露 Agent Card 即可被自动发
现。

##### Agent Card 是契约

标准化的 JSON 描述，
Orchestrator 不需要知道
Specialist 内部实现。只要符合
A2A 协议，任意框架构建的 Agent
都可以加入协作。

##### 跨框架天然支持

LangChain 写的 Orchestrator 可
以调用 CrewAI 或 ADK 写的
Specialist，只要双方都遵循 A2A
协议。不同厂商的 Agent 可以互操
作。

##### Turn Limit 防死循环

设置最大调用回合数，防止 LLM
在「还要再调一个 Agent」的推理
中无限循环烧 Token。生产环境必
须设置硬上限。
CHAPTER 08 github.com/google/A2A

##### 实际业务中 —推荐的双层组合架构


##### 24


##### /


##### Layer 1


##### Agent Squad Classifier — 入口路由层

适用场景：简单请求、单领域问题
- 用户意图分类 → 直接分发到对应 Specialist
- 一次 LLM 推理完成路由决策
- 低延迟、低成本、适合 80% 日常请求
- 多轮对话上下文感知，自动切换 Agent
- 三语言运行时（Python/TS/Swift）
- pip install agent-squad 即用
识别到复杂多步骤任务 ↑ 自动升级到 Layer 2

##### Layer 2


##### A2A Orchestrator — 多步骤编排层

适用场景：复杂任务、多领域交叉、多步骤编排
- Agent Card 自动发现各 Specialist 能力
- LLM 多轮推理决定调用顺序和并行策略
- 独立部署服务，跨框架天然支持
- JSON-RPC 2.0 / SSE 流式通信
- Turn Limit 防止死循环
- 基于 github.com/google/A2A 协议
编排结果 ↓ 返回 Layer 1 统一输出

##### 推荐方案：Layer 1（Squad Classifier）处理日常路由 → Layer 2（A2A Orchestrator）编排复杂任务。简单快，复杂强。

两套方案各取所长——Squad 的轻量语义路由 + A2A 的协议化多 Agent 编排，覆盖从简单意图分发到复杂多步骤协作的全部场景

##### CHAPTER 09


##### 生产挑战


##### 2026 年实际生产教训�高

##### 静默质量退化

模型更新导致输出格式变化，下游 Agent 解析失败。某团队 3% 错误率但未触发告警
（错误被静默吞噬）。
Handoff 做 Schema 校验
+ 主动告警
�高

##### 成本失控

Supervisor 生产环境单任务消耗 400K tokens。测试环境和生产表现差异大，
Supervisor 更容易「完美主义」。
硬 Token 预算 + 70% 阈值
告警 + 路由层用小模型
� 中

##### 上下文被协议占用

MCP 元信息占 72% 上下文窗口（Perplexity CTO 在 LangChain 大会报告）。
按需加载 MCP 服务器，非启
动时全量连接
� 中

##### 确定性不足

LLM 输出不稳定，同样的输入可能得到不同的任务分解和执行路径。多 Agent 链路长，
累积不确定性更大。
Schema 校验 + 多次采样取
众数 + Critic Agent 兜底
� 中

##### 调试困难

多 Agent 链路长，出问题后难以定位是哪个 Agent 的哪一步出错。多 Agent 系统没
有好监控就是黑箱。
LangSmith / Arize
Phoenix /
OpenTelemetry 全链路
Trace
� 中

##### 死循环

Agent 间互相推诿（A 说 B 的工作，B 说 A 的工作）；对等模式下讨论不休。
最大迭代次数 + 全局超时 +
仲裁 Agent 强制决策

##### 25 / 28


##### PRACTICE


##### 实践建议


##### 多 Agent 不是必须，引入它是为了解决单 Agent 确实解决不了的问题，而不是为了「架构好看」


##### 1


##### 先验证单 Agent

Prompt Engineering + RAG 能通过评估就先用。多 Agent 不是「更好」，而
是解决特定问题的工具。

##### 2


##### 从双 Agent 起步

生成 Agent + 审查 Agent（Critic Loop）是性价比最高的多 Agent 起步，实
现简单，质量提升明显。

##### 3


##### 从 Router 而非 Orchestrator 开始

路由分发比任务编排简单得多，但能解决 80% 的实际问题。不要一上来就做复
杂编排。

##### 4


##### 可观测性第一天接入

LangSmith / Arize Phoenix / OpenTelemetry，第一个 Agent 上线时就接入。
不要等功能完成再补监控。

##### 5


##### 设置硬预算

每个工作流设 Token 上限 + Agent 最大迭代次数。成本失控通常是逐渐发生的，
等你注意到时已经烧了很多钱。

##### 6


##### 输出校验是必须的

每个 Agent 间 Handoff 做 Schema 校验。生产事故往往来自静默的格式变化
导致下游解析出错。

##### 7


##### 采用 MCP 作为工具层标准

避免为每个工具手写 connector。MCP 已经是事实标准，所有主流框架原生支
持。

##### 8


##### 先人机协作，后全自动

高风险操作保留人工审批节点（Bounded Autonomy 模式）。验证稳定后再逐
步自动化。

##### 先验证单 Agent → 从双 Agent 起步 → 从 Router 而非 Orchestrator 开始


##### 27 / 28


#### 谢谢


##### Agent 专家团不是终点，而是 AI 协作的起点
