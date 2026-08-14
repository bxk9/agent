# blueclaw 云端 Agentic 架构进展、方案设计（含沙箱能力）

## 1、5 .31 需交付能力 & 当前进展

### 1.1、待交付的能力

- 云 claw Agent：Agent层相关能力，及配套链路打通。聚焦长程、复杂等适合云端任务的 Agent，以 A2A 的协议暴露给端侧蓝龙虾。
- 办公套件 Skills：PPT、Word、Excel（ps：创建这些类型的文件时，走云 claw）
- 云沙箱：可独立运行的沙箱运行时环境；以及基于沙箱的代码执行器 Skill
### 1.2、当前进展（5.08，进展 60%）

- 云 claw Agent：
  - 端云协同：畅通，已经和云网关、端侧打通基本问答链路。tool call、human feedback、多模态处理正在联调中
  - 技能平台：技能平台对接中-已与郑坤沟通推进
  - 记忆服务：挂起-记忆服务提供相关接口
  - 模型对接和审核对接：基于 OAI 协议对接玄机国内模型，支持快速切换不同模型；审核能力对接中，对接小 v 现有的审核能力。
![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/2vUnsgoO5ukg205lPh8AEMVvpzRq67lYg3_eZ-SBNbKDEtHHPKU2jBJ7B8_v22JT "image.png")

- 办公套件 Skills：
  Word / PPTX / XLSX 三类文件生成 Skill 均已在云端 Loop 跑通。端到端简单场景没问题；**端到端的复杂场景成功率仍偏低，有待调优**

  主要原因有以下问题分类：

    1、端侧应用沙箱Skill问题（幻觉，不遵循，误操作本地文件，传参错误等）。

    2、代码编写正确率问题（引号转义、语法错误）。

    3、防火墙问题（已解决）

- 独立运行沙箱：
  - 沙箱基础服务：测试&预发已经部署，容器和存储资源需求已经同步到基础平台袁鹏和王杰。沙箱sdk联调进行中
  - 沙箱网关能力：已经提供read/write/execute/run-code4个核心能力接口。上传接口、客户端session_id待开发对接。
  - tools/skill对接：已经对接到蓝龙虾和蓝心小v客户端，能够跑通ppt相关技能，成功率和稳定性较低，待优化效果。
  - 效果调优：端到端运行稳定性&效果调优待开始。
调优方案说明，以office相关技能为例：

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/CRMc5tWf4rtPaXFx3BHJVTfKYlTs4lDHxWX8cgVz_DiyoNQvlco0y842Av6teoDo "image.png")

### 1.3、后续计划

- P0：完善端 claw & 云 claw 的链路，确保 tool call、human feedback 等场景正常执行（5.08～5.09）
- P1：端到端推进 办公套件 Skills（办公套件 skills 均走云 claw 链路），确保交付效果。（5.11～5.14）
- P1：云端定时任务、心跳任务管理。（～5.30）
- P0：和端侧联调明星场景（～5.30）
- P2：云 claw 的工程化、稳定性、高可用、容灾等分布式建设（～5.30）
## 2、云 claw 整体能力架构

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/FwwnHWKaM7hiTRNGpmqhnBMKkcG6AV9_-xptrKQb7XVjN74SZuR8wehmjvzAdp2A "image.png")

### 2.1、架构概述

本工程整体采用以 **Agent Runtime 为核心、云网关作为统一入口、执行层作为能力底座、Context Engineering 作为上下文中枢、安全治理贯穿全链路** 的技术架构。整个系统面向复杂任务型智能体场景设计，既要支持普通的多轮对话，也要支持代码生成与执行、文档处理、浏览器操作、云端长任务、多 Agent 协作、工具调用、记忆沉淀、任务恢复以及安全受控执行等能力。从整体结构上看，系统可以概括为三层一环：

- 上层是 **云网关（姚利军负责）**，负责用户、设备、会话和工作区等外部请求的统一接入；
- 中间是 **智能体层 Agent Runtime（云侧，张硕负责）**，负责任务理解、上下文构建、Agent Loop 执行、工具选择、多 Agent 编排和状态管理；
- 底层是 **执行层（姚利军、张硕负责）**，负责真正完成代码执行、浏览器操作、MCP 工具调用、Skill 执行以及安全审核；
贯穿其中的是 **Agent Loop 闭环**，它让系统能够在“任务输入 → 上下文构建 → 模型推理 → 工具调用 → 结果检查 → 状态更新 → 记忆沉淀 → 继续执行或结束”的循环中持续推进复杂任务。

### 2.2、云网关层**（姚利军负责）**

系统最上层的云网关承担统一入口的角色。用户请求可以来自 UI、工作流、移动端、PC、Pad、手表等多种终端，也可以来自跨设备通信、个人工作区或第三方服务。云网关内部包含 UI Engine、接入管理、跨设备通信、流量管理、会话管理、安全校验和个人 Workspace 管理等模块。UI Engine 负责承载用户交互、卡片渲染、workflow 编排与任务状态展示；接入管理用于完成设备注册、设备发现以及多端接入；跨设备通信负责网络协议、交互协议和跨端调用；流量管理负责负载均衡、代理转发、灰度策略和熔断降级；会话管理负责会话读取、会话持久化、会话向量化和会话召回；安全校验负责接入鉴权、指令鉴权和安全审核；个人 Workspace 管理则负责跨设备文件同步、用户数据托管和 Agent 文件存储。通过这一层，系统可以将外部复杂、多样的请求统一收敛为标准化任务输入，并转发给智能体运行时。

### 2.3、**智能体层 Agent Runtime（云侧，张硕负责）**

中间层的 Agent Runtime 是整个架构的核心控制中枢，可以理解为系统的大脑。它负责接收来自云网关的请求，并将用户意图转化为可执行任务。Agent Runtime 内部包含记忆模块、中控工作区、Agent 状态管理、任务拆解与分发、Skills、Multi Agent System、Context Engineering、第三方 / 云方 Agent 接入等能力。

- 记忆模块：用于维护 [SOUL.md](http://SOUL.md)、[AGENT.md](http://AGENT.md)、长期记忆、短期记忆等信息，使 Agent 能够在多轮任务中保持连续性；
  - 记忆目前直接对接记忆服务的能力，**记忆服务提供记忆搜索、记忆写入的接口**，以保证模块间的正常协同。
- Workspace 用于组织用户数据、会话状态和动态 API 能力；
- Agent 状态管理负责维护上下文状态、模型状态数据、目标状态和事件状态，其中事件状态包括 Plan、ToDo、Progress、Result 等关键节点，保证任务执行过程可观测、可恢复、可追踪；
- 任务拆解与分发模块（暂未实现，后续通过多智能体的方式实现）负责将复杂目标拆解成多个子任务，并通过任务路由、工具路由和子 Agent 路由分配给不同执行单元；
- Skills 模块则封装高层业务能力，例如编辑技能、石墨技能、金数据技能、泛化技能等，使 Agent 不只是调用底层工具，而是可以直接复用更接近业务语义的能力。
在 Agent Runtime 中，多 Agent 系统（后续实现）采用典型的 **Supervisor + SubAgent** 协作模式。Supervisor 负责理解整体目标、制定任务计划、拆解子任务、分配执行角色、监听执行状态并聚合最终结果；SubAgent 则面向具体任务领域执行，例如代码 Agent、文档 Agent、数据 Agent、浏览器 Agent、图片 Agent、视频 Agent、Phone Agent、深度研究 Agent、教育 Agent、旅游 Agent 等。每个 SubAgent 可以绑定不同工具集合，具备相对独立的专业能力。通过这种模式，系统可以避免单一 Agent 承担过多职责，同时也便于后续扩展更多垂直领域 Agent，形成开放式智能体生态。

### 2.4、上下文管理模块

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/fA9WjJVYOU27QZ4ZCGpq2TtKSHxVEw_bjKOC84jtA7VyOvlaEHSkHsXP6_NRPr1M "image.png")

- 在保留消息时，会保留两部分消息
  - 最近几条 Assistant 消息，这部分消息离当前时间最近，因此不能剪裁。默认 3 条，可配置。
  - 保留第一条 user 消息之前的所有内容，这部分内容是 [SOLE.md](http://SOLE.md)、[Agent.md](http://Agent.md) 等消息，防止系统初始化人格/身份信息被误删，可以认为这部分是系统提示词消息。
- 只剪裁 ToolResult 的原因：
  - ToolResult 是工具返回的结果，往往只有这部分内容是非常大的。
- Soft Trim：原则是尽可能保留工具结果的关键信息，同时把它压缩成更短的文本。
  - 如果有图片的话，会将图片替换为 [image removed during context pruning]，说明**图片本身不会被继续保留，而是会降级成文字标记。**
  - 如果文字超长，会保留前 xxx 个字符以及后 xxx 个字符。最后拼接成 head ... tail。然后拼接一句 [Tool result trimmed: kept first ${headChars} chars and last ${tailChars} chars of ${rawLen} chars.]`
- Hard Clear：
  - 直接将 ToolResult 中的消息转变为 [Tool result removed during context pruning]
- 摘要生成阶段：
  - 真正生成摘要时，不是一次把所有消息 whole prompt 扔进去
  - 根据上下文窗口动态计算 chunk 大小
  - 分阶段 summarize
  - 必要时把 split turn 的 prefix 单独总结后再拼进去
- 摘要阶段任意步骤失败，就取消摘要。宁可不 compact，也不要 compact 出一个有缺失、会误导 agent 的坏摘要。
### 2.5、Sandbox模块、Skill执行（张硕、姚立军负责）

> 5.30 号之前，张硕负责沙箱、姚利军负责云侧 skill
> 5.30 号之后，张硕负责云侧 skill、姚利军负责沙箱
> 5.30 号提测后再进行工作交接，避免临时交接影响提测进度
