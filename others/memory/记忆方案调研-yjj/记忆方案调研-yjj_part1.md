## 一、基本算法发展历史

主要参考**: **_https: // openreview. net/ forum? id= Sk7pwmLuAY _以其对记忆算法发展进行总结。

### 1.1隐式记忆

隐式记忆主要指嵌入在预训练Transformer内部参数中的知识，涵盖其记忆、联想检索和上下文推理的能力。近期的研究主要探索了解释、操作和重新配置这种潜在记忆的方法。

**Transformer -> Tansformer-XL -> compressive Tranformer**

### 1.2显式记忆

显式记忆主要涉及外部存储和检索组件，旨在通过动态、可查询的知识表示（如文本语料库、密集向量和基于图的结构）来增强模型输出，从而实现与信息源的可扩展和可更新交互。

### 1.3Agent记忆

引入Agent去促进长期规划、自我一致性和多智能体系统中的协作行为，与具身智能和交互式AI相关。

## 二、业界行情

## 三、新的发展方向

## 四、疑问思考：

1.闲聊场景下，若用户进行200轮及以上的场景下，如何还能有更好的共情能力？

---

# Q1业内最新发布

| **时间** | **厂商** | **产品** | **核心突破** | 相关链接 |
| --- | --- | --- | --- | --- |
| **2026年1月** | Moonshot AI | **Kimi K2.5** | 1万亿参数MoE，Agent Swarm并行100个子代理 | [https://www.kimi.com/blog/kimi-k2-5.html](https://www.kimi.com/blog/kimi-k2-5.html)<br>[arXiv:2602.02276](https://arxiv.org/abs/2602.02276) |
| **2026年2月5日** | **OpenAI** | **GPT-5.3-Codex** | 专用编码Agent，比5.2快25%，支持并行任务 | [https://github.com/openai/codex](https://github.com/openai/codex) |
| **2026年2月11日** | 智谱AI | **GLM-5** | 744B参数MoE，智能体工程(Agentic Engineering)专用 | [https://github.com/zai-org/GLM-5](https://github.com/zai-org/GLM-5)<br>[arXiv:2602.15763](https://arxiv.org/abs/2602.15763) |
| **2026年2月13日** | MiniMax | **M2.5** | 全球首个Agent原生设计生产级模型 | [https://www.minimax.io/news/minimax-m2](https://www.minimax.io/news/minimax-m2)<br>（相关报告还未完全发发布完或者直接在官方博客进行补档） |
| **2026年2月19日** | **Google** | **Gemini 3.1 Pro** | 2倍推理性能，100万token上下文 | [https://arxiv.org/html/2603.09652v2](https://arxiv.org/html/2603.09652v2)<br>（只看到3 pro的 未找到3.1 pro 官方博客无网址无法观看） |
| **2026年2月** | **Anthropic** | **Claude Opus 4.6 / Sonnet 4.6** | 100万token上下文，企业级Agent能力 | [https://www-cdn.anthropic.com/c788cbc0a3da9135112f97cdf6dcd06f2c16cee2.pdf](https://www-cdn.anthropic.com/c788cbc0a3da9135112f97cdf6dcd06f2c16cee2.pdf) |
| **2026年2月** | 阶跃星辰 | **Step 3.5 Flash** | 196B参数(激活11B)，MTP-3加速，端侧优化 | [https://github.com/stepfun-ai](https://github.com/stepfun-ai)<br>[arXiv:2602.10604](https://arxiv.org/abs/2602.10604) |
| **2026年3月** | Meta | **Llama 4 Maverick/Scout** | 10M token上下文，原生多模态，完全开源 | [https://www.llama.com/docs/model-cards-and-prompt-formats/llama4/](https://www.llama.com/docs/model-cards-and-prompt-formats/llama4/)<br>[https://github.com/meta-llama/llama-models](https://github.com/meta-llama/llama-models) |
| **2026年3月24日** | Ai2 | **MolmoWeb** | 开源Web Agent，4B/8B参数，对标闭源系统 | [https://github.com/allenai/molmo](https://github.com/allenai/molmo) |
| **2026年4月(预定)** | 腾讯 | **混元3.0** | 从"大模型"向"强智能体"跃迁 |  |

---

## **一、Moonshot AI - Kimi K2.5（2026年1月）**

### **核心突破**

Kimi K2.5是Moonshot AI于2026年1月发布的旗舰模型，采用**1万亿参数MoE架构**，在推理时仅激活32B参数，实现了超大规模参数与高效推理的平衡。

### **技术规格**

| **指标** | **参数** |
| --- | --- |
| 总参数量 | 1 Trillion (MoE) |
| 激活参数量 | 32 Billion |
| 上下文长度 | 256K tokens |
| 训练数据 | 15万亿混合视觉/文本tokens |
| 量化支持 | 原生INT4 |
| 模型大小 | ~600GB (INT4量化后) |
| 许可证 | MIT (带归属条款) |

### **Agent Swarm架构**

Kimi K2.5提供四种运行模式：

- **K2.5 Instant**：快速响应模式
- **K2.5 Thinking**：扩展推理模式
- **K2.5 Agent**：单智能体工具增强执行
- **K2.5 Agent Swarm (Beta)**：并行多智能体编排，支持同时运行100个子代理

### **原生多模态设计**

与传统模型不同，Kimi K2.5从底层设计即为原生多模态架构，而非后期添加视觉能力。这种架构决策消除了视觉与文本能力之间的传统权衡，使两者能够同步提升

## **二、OpenAI - GPT-5.3-Codex（2026年2月5日）**

### **核心突破**

GPT-5.3-Codex是OpenAI专为编码场景优化的专用模型，相比GPT-5.2速度提升25%，支持并行任务处理。GitHub已将其确立为首个长期支持(LTS)模型，承诺从2026年2月5日至2027年2月4日提供12个月的稳定服务

### **技术特性**

- **专用编码Agent**：针对软件工程任务深度优化
- **速度提升**：比GPT-5.2快25%
- **并行任务支持**：可同时处理多个编码任务
- **128K上下文**：支持大型代码库的全局理解

#### **核心特性：**

**1. 性能突破**

- 比GPT-5.2-Codex（2025年12月发布）**快25%**，token消耗更少
- 首次在网络安全领域达到"High"评级
- 支持**多任务并行处理**——可同时运行多个Agent处理不同任务

**2. 产品形态对比**

| **特性** | **GPT-5.3-Codex** | **GitHub Copilot Pro+** | **Claude Code (Opus 4)** |
| --- | --- | --- | --- |
| Agent类型 | 云端沙盒Agent | IDE+编码Agent | 终端Agent |
| 并行任务 | ✅ 支持多任务 | ✅ 通过Agent支持 | ❌ 单线程 |
| GitHub集成 | ✅ PR/issue/审查 | ✅ 原生 | ⚠️ 需MCP |
| 实时干预 | ✅ 支持 | ⚠️ 有限 | ✅ 交互终端 |
| 价格 | $20/月 | $39/月 | $20/月 |

**3. 关键局限**

- **无API访问**：目前仅通过ChatGPT Plus/Pro提供
- 通用模型仍是GPT-5.2，5.3为Codex专用版本

### **实时编码变体：Codex-Spark**

OpenAI还发布了**GPT-5.3-Codex-Spark**研究预览版，专为实时代码迭代设计

- **生成速度**：超过1,000 tokens/秒（在低延迟硬件上）
- **合作伙伴**：与Cerebras合作实现超低延迟推理
- **目标**：提供类似"响应式结对编程"的体验，而非传统的"生成-粘贴"工具

### **企业级承诺**

- 成为GitHub Copilot的默认基础模型
- 1倍高级请求单位乘数
- 企业客户代码生存率显著高于前代模型

## **三、智谱AI - GLM-5（2026年2月11日）**

### **核心突破**

GLM-5是智谱AI推出的744B参数开源MoE模型，采用**智能体工程(Agentic Engineering)**专用设计，在软件工程任务上达到与Claude Opus相当的性能，但成本仅为1/6

### **技术规格**

采用"Slime"框架结合异步Agent强化学习，MoE FLOP利用率超过75%（行业平均40-50%）

| **指标** | **GLM-5** | **前代GLM-4.5** |
| --- | --- | --- |
| 总参数量 | **744B** (754B报道) | 355B |
| 激活参数(MoE) | 40B | 32B |
| 预训练数据 | 28.5T tokens | 23T tokens |
| 上下文窗口 | **200K tokens** | 128K tokens |
| 最大输出 | 128K tokens | 32K tokens |
| 许可证 | **MIT开源** | MIT |

#### **Agent能力突破：**

**1. 基准测试表现**

- **SWE-bench Verified**: 77.8%（开源模型最佳）
- **BrowseComp**: 62.0%
- 价格仅为Claude Opus 4.5的**1/15到1/23**

**2. 智能体工程(Agentic Engineering)**

- 不再是被动的代码生成工具，具备**完整工程思维能力**
- 可自主进行**项目规划、架构设计、长期维护**
- 支持多智能体协作，将软件开发周期从**周缩短至小时**

**3. 市场反应**

- 发布前以"Pony Alpha"代号在OpenRouter登顶热度榜
- 身份揭晓后智谱AI股价单日暴涨26%，一周涨幅约70%

### **架构创新**

GLM-5采用细粒度MoE路由策略

- **专家专业化**：
  - 代码生成专家（解释器工作流）
  - 数学推理专家（计算链）
  - API结构化专家（JSON/模式生成）
  - 语言路由专家（意图分类）
- **原生工具集成**：
  - 控制Token：`[TOOL_CALL]`、`[RESULT]`、`[EXECUTE]`
  - 结构化输出模式：约束解码确保JSON语法正确
  - 注意力分区：隔离工具I/O与推理链
  - 状态检查点：跨轮次核心记忆保持

### **性能基准**

| **基准测试** | **得分** |
| --- | --- |
| SWE-bench Verified | 77.8% |
| AIME 2025 | 84-92.7% |
| MATH | 88-97.4% |
| HumanEval | 97.0% |
| GPQA | 68.2-86% |
| MMLU | 85-88% |

### **四、MiniMax - M2.5（2026年2月13日）**

### **核心突破**

MiniMax M2.5定位为**全球首个Agent原生设计生产级模型**，采用230B参数MoE架构，在SWE-Bench Verified上达到80.2%，超越Claude Opus 4.6

### **技术规格**

| **指标** | **参数** |
| --- | --- |
| 总参数量 | 230 Billion (MoE) |
| 激活参数量 | 10 Billion |
| 上下文窗口 | 128K tokens |
| 推理吞吐量 | 100+ tokens/秒 |
| 运行成本 | $1/小时 (100 tok/s) |

#### **核心定位：**

**1. Agent原生架构**

- 不同于其他模型"后期添加Agent能力"，M2.5从底层为Agent场景设计
- **编程与智能体性能直接对标Claude Opus 4.6**
- 性价比极高：**1万美元可让4个AI Agent连续工作一整年**

**2. 全模态能力**

- 覆盖**视频、语音、音乐**全模态模型
- 海螺2.3视频模型（2025年10月发布）：支持角色运动、视觉质量提升
- Speech 2.6语音模型：超低延迟，支持40+语言，已生成超2亿小时语音内容

**3. 应用场景**

- AI智能体开发
- 自动化工作流
- 企业级Agent应用
- 编程辅助

### **Agent原生架构**

M2.5专为Agent任务设计，具备"原生规范行为"

- **架构师级规划**：编码前主动解构架构和功能规划
- **全栈开发**：前端、后端、数据库一体化支持
- **Vibe Coding**：自然语言到可执行系统设计的转换

### **训练方法论：Forge框架**

- **Agent原生RL框架**：训练引擎与Agent解耦
- **40倍训练加速**：通过异步调度和树状样本合并
- **CISPO算法**：确保MoE模型在大规模RL训练中的稳定性