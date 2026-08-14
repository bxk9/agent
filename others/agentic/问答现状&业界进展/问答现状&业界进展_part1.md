![截屏2026-04-14 15.15.46.png](http://veditor.vivo.xyz/api/v1/attachment/file/PzxCtP39A4dMka6HKK5y56bDd28Vui8SD59s6V0mIHjT-D6Ylp4CjwC_epecaCfN "截屏2026-04-14 15.15.46.png")

1 问题背景：

- 问题分布暴露->需要agentic（效果）；【待办： 三方进展：边想边搜； 后续加上对比】；
- 待办： 3.0现状-产品
- 不好合并到智能路由/pro模型-提升问答&同时不影响工具；

2 前沿进展： web 搜 协同 工具调用 （普通问答 协同 工具调用）； 问答的智能路由

- 待办： 顶尖agent中哪些工具和 ai搜/技能  类似， 框架怎么设计
- agent： open claw/claude code/hermes
- 问答工具： openai/gemini

3 中控的分享

- 待办： 中控做agentic的经验

3 方案

# 0、背景

中控目前的架构是智能路由，简单问题走flash，复杂问题走pro

问题：agentic问答怎么和中控配合，短期问答（rag框架->agentic框架）以智能体接入；长期agentic框架是完全合并进中控层还是在路由层/中控层新添一个并行

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/6AcCfMj0ymLLa4JunWFfUIQVVEuuVr0mDCoj4X7Qr_hVFIsG5K8RVLQHFtnSFiB3 "image.png")

现在的架构让“执行的复杂度”强行兼容了“问答”，这会导致系统的耦合度过高，且无法灵活调用最合适的模型或工具。

问答（QA）的复杂度和执行（Action）的复杂度，其评判标准是完全不同的：

- **问答的复杂：** 往往意味着需要多步推理、全网搜索（RAG）、长文本总结（例如：“对比一下iPhone 15和Mate 60的优缺点”）。
- **执行的复杂：** 往往意味着跨应用操作、缺乏直接API需要模拟UI点击、或者带有条件判断的分步任务（例如：“帮我在美团点一杯昨天的奶茶，如果超过20块就算了”）。

为了解决这个问题，最优的方案是重构中控（Router），采用 **“意图-复杂度”二维矩阵分发架构 (Intent-Complexity Matrix Routing)**

# 1、问答和中控对接的长期方案

## 长期：二维解耦路由架构，将问答提升到第一层级进行判别

我们需要将中控拆分为两个层级：**第一层管“干什么”，第二层管“怎么干”。**

#### 阶段一：顶层意图识别 (Intent Dispatcher)

当用户输入一条指令时，最外层的中控首先**只做一件事：判断意图类别**。 将所有请求分为三类：

1. **纯问答 (Pure QA):** “今天天气怎么样？”、“解释一下相对论”。
2. **纯执行 (Pure Action):** “帮我定个明天早上8点的闹钟”、“打开微信扫一扫”。
3. **混合型 (Hybrid):** “查一下明天去北京的航班，然后帮我把最便宜的那趟发给小明”。（包含信息获取 + 复杂执行）

_技术建议：这一层需要极高的响应速度，通常使用体积较小的、经过微调的模型（如基于本地算力的小模型或快速API）来专门做意图分类。_

#### 阶段二：垂直领域的复杂度评估 (Complexity Classifier)

一旦意图明确，任务就会被下发到对应的专属通道。此时，在各自的通道内再进行“简单/复杂”的拆分。

**1. 问答通道 (QA Router):**

- **简单 QA 节点:** 针对事实性问题、闲聊、常识。
  - _处理方式:_ 直接调用主 LLM 的知识库生成回复。速度快，成本低。
- **复杂 QA 节点:** 针对需要时效性、深度总结、多步检索的问题。
  - _处理方式:_ 触发 **Research Agent**。调用 Web Search 工具、本地文档 RAG、甚至进行多次 ReAct 循环来收集信息并汇总。

**2. 执行通道 (Action Router)****==flash中控**

- **简单执行节点:** 针对系统自带 API、单一 App 的 DeepLink、单步操作。**==flash中控**
  - _处理方式:_ 提取 Slot（参数，如时间、联系人），直接调用系统接口（如设定系统闹钟 API）。
- **复杂执行节点:** 针对跨应用、无直接 API 需要 UI 自动化（如屏幕理解、模拟点击）的操作。
  - _处理方式:_ 触发 **Plan & Execute Agent**。先生成操作步骤，再配合屏幕截图理解（VLM）一步步执行验证。

#### 阶段三：混合型任务的编排 (Orchestrator) ==pro中控

如果第一阶段识别出是**混合型任务**，此时不能直接扔给某一个简单/复杂中控，而是需要引入一个**编排器 (Orchestrator / Planner)**。

- _处理流程:_ 编排器将大任务拆解为 DAG（有向无环图）工作流。
- _例如:_ “查一下明天去北京的航班，发给小明” ->
1. 节点 A: `复杂 QA` -> 搜索航班信息（输出：航班列表）。
2. 节点 B: `简单执行` -> 提取列表中的航班，调用微信发送接口（输入：航班列表，联系人：小明）。

## 当前：

## 短期：子agent整体打包：智能路由-pro问答/flash

补充pro问答：

# 2、主流agent方案（主要调研子agent/直接搜索接口）

## 2.1 Open Claw：异步事件流 (Event-Stream)

OpenHands 采用的是典型的**微服务/微 Agent 架构**，其 Sandbox 运行在隔离的 Docker 容器中。

- **协作模式：** 基于“观察者模式”的事件驱动。
- **做法：**
  - **Browser Agent 协作：** 当主 Agent（Coder）发现知识缺失，它会发送一条消息给 `Browser Agent`（专门负责搜索和网页解析的子智能体）。
  - **沙盒镜像化：** `Browser Agent` 找到代码示例后，主 Agent 会尝试在 Docker Sandbox 中**复现**这个示例。
  - **失败反馈：** 如果 Sandbox 报错，Traceback 会被反馈给 `Browser Agent`，触发“深度搜索”或“寻找替代库”。
- **核心特质：** **鲁棒性**。它允许搜索和执行在不同的“脑区”并行，互不干扰。

## 2.2 Claude Code ：统一终端上下文 (Unified Context)

Claude Code 的做法非常硬核，它将 Web 搜索视为**终端能力的延伸**。

- **协作模式：** 它没有独立的“搜索界面”，而是将搜索结果直接流式传输到**当前的会话上下文**中。
- **做法：** * 当 Agent 在 Sandbox（本地终端）执行任务遇到未知的 API 或报错时，它会调用 `Google Search` 工具。
  - **上下文对齐：** 搜索回来的文档片段被立即转化为 Markdown，作为“虚拟文件”或“背景知识”注入。
  - **即时执行：** 模型读取文档后，**立刻**在同一个 Sandbox 终端编写脚本验证该文档的正确性。
- **核心特质：** 极高的**时效性**。它不相信过时的训练数据，只相信“搜索+沙盒运行结果”的组合。

## 2.3 Hermes：极限 Function Calling (Tool-Centric)

Hermes（Nous Research）代表了开源界对工具调用的最高水准，它的协作重点在于**决策的原子化**。

- **协作模式：** 搜索与 Sandbox 被抽象为平等的 **Tools**。
- **做法：**
  - **推理驱动：** Hermes 不设预定的流程，而是通过 `Thought -> Call -> Observation` 循环。
  - **参数传递：** 搜索工具产生的输出被严格结构化（JSON），直接作为参数喂给 Sandbox 工具。例如，搜索获取了一个最新的 API Key 或 Endpoint，它会直接生成 `curl` 命令在 Sandbox 中运行。
  - **多轮博弈：** 如果搜索结果与 Sandbox 实际环境不匹配（例如文档说有这个参数，但环境里没有），模型会触发自我纠错。
- **核心特质：** **逻辑严密性**。它非常依赖模型对“工具输出”的理解能力

# 3、做法

### 最优实现架构：双级过滤模型 (Dual-Stage Filtering)

为了兼顾手机端的**响应速度**和**准确度**，建议采用以下流水线：

#### 第一级：极速分水岭 (Lightweight Router)

- **模型：** 极小的本地模型 (如 SLM) 或 Fast API。
- **任务：** 剔除无效闲聊和超简单的系统指令（如“调高音量”）。
- **动作：** 如果是简单指令，**跳过**后续所有复杂逻辑，直接执行。

#### 第二级：语义精算师 (Reasoning Router)

- **模型：** 性能较强的模型（如 Claude 3.5 Sonnet 或经过微调的 Hermes-Llama3）。
- **任务：** 1. **问答拆解：** 判断是“自有知识”还是“需要联网搜索”。 2. **执行拆解：** 判断是“原子操作”还是“长链条操作”。 3. **冲突检测：** 用户意图是否模糊（需要反问）。

### 1. 路由协议化：从“分类”转向“语义路由”

Claude Code 和 Hermes 系列模型非常强调**结构化输出**。不要让中控返回模糊的“简单/复杂”，而是让它返回一个标准的**路由协议 (Routing Protocol)**。

```plaintext
{
  "intent": "EXECUTE | QUERY | HYBRID",
  "domain": "SYSTEM | APP | KNOWLEDGE | SOCIAL",
  "complexity_score": 0.0 - 1.0,
  "requires_search": true/false,
  "plan_preview": ["step1", "step2"], // 仅在复杂度高时生成
  "suggested_agent": "research_agent | automation_agent | chit_chat"
}
```

- **实现方式：** 你的意图识别层应输出一个 `complexity_score`。
- **Claude Code 的启示：** 它在处理 CLI 指令时，会先快速判断这是“查看文件”（简单）还是“修复 Bug”（复杂）。如果是后者，它会进入一个思考循环（Thought Loop）。
- `< 0.3`：直接扔给简单中控（Fast Path）。
- `> 0.3`：扔给复杂中控，启动规划器（Slow Path）。

### 2. 借鉴 Hermes：利用 Tool-Calling 进行“虚构执行”

Hermes Agents 的强项在于对 **Function Calling** 的极致优化。你可以为顶层意图识别设计一组“虚拟工具”。

- **逻辑：** 顶层模型并不直接执行任务，而是拥有几个“分发工具”。
- **操作：** * 定义 `answer_user_question(query, needs_web_search)`
  - 定义 `execute_phone_action(action_description, is_multi_step)`
- **效果：** 模型通过“选择调用哪个工具”来完成意图识别。如果模型选择了 `execute_phone_action` 并且标记 `is_multi_step: true`，中控就会自动将其路由到“复杂执行 Agent”。

### 3. 借鉴 OpenHands：状态感知的异步路由
