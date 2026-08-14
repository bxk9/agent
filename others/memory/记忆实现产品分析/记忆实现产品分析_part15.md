  - **LongMemEval**：面向多会话更新与时间推理的长记忆评测。（[链接](https://www.emergentmind.com/topics/longmemeval#:~:text=LongMemEval%20comprises%20500%20meticulously%20curated,2024)）
  - **WikiHop/MultiHopQA**：尽管不是对话记忆，但可测试模型从多个文档检索事实（适配深研场景）。
  - **NarrativeQA 或其他阅读理解**：用于评估对长文本中细节和跨段落信息的回忆能力。

对于**闲聊场景**，首选 LoCoMo、LongMemEval 这类对话历史敏感的基准，通过模拟对话流程和实时检索考核系统；场景偏“连续对话+个性化”。**深度研究场景**（例如科研助手），可偏重文档检索基准和百科式问答，使用 WikiHop、MultiHopQA 等衡量系统整合分散信息的能力。同时应调整基准任务规模：在聊天场景，限制查询长度和检索候选；在深研场景，则可允许更长检索延时和更大知识库规模。

## **记忆框架**

主流开源**记忆增强框架**有：

  - **OpenClaw**（个人AI助手框架）：以插件形式支持记忆功能，提供 memory-core、memory-lancedb 等记忆系统。它的 memory-core 将记忆存为可读 Markdown 并用 SQLite 索引，memory-lancedb 用外部向量数据库检索，最新 memory-lancedb-pro 结合交叉编码再排序提升检索质量。
  - **OpenClaw-Memory (agent-memory)**：PyPI 上的插件，集成层次化存储（身份/活动/潜出/归档）。支持自动捕获会话上下文、动态检索等，说明中提到“身份”“活动”“浮出”等层次结构组织（例如“身份”层存储核心自我信息；“活动”层存储近期任务；“浮出”层按需检索相关记忆；“归档”层长期积累）。（[链接](https://github.com/volcengine/OpenViking)）
  - **memU / memUBot**：面向企业的记忆系统，提供比 OpenClaw 更强的语义索引和多用户方案。memU 以语义向量检索替代 Markdown 文档，支持自动flush和智能上下文过滤，公开为开源项目（见仓库）。memUBot 则是基于 memU 的企业级助手产品。
  - **OpenViking**：字节跳动开源的上下文数据库，将记忆、知识和工具映射到虚拟文件系统层级，支持分层摘要、递归目录检索等。例如它把用户和资源上下文组织在 `viking://` 虚拟目录下，对上下文检索实现“锁定目录再深入查找”的策略，大幅降低检索冗余。
  - **其他**：还有如 MemMachine 等研究性插件（未开源）、个别商业 Memory API（如开放AI 的 Pinecone 集成教程）等，但免费开源中以上为主流。

### **框架比较**

对比了关键特性（示例如下）：

| **框架** | **特点** | **适用场景** | **部署难度** | **文档/示例** |
| --- | --- | --- | --- | --- |
| **LoCoMo** (基准) | 对话式长记忆评测集 | 对话系统、助手 | N/A (数据) | GitHub、论文文档 |
| **EverMemBench** (基准) | 多方协作记忆评测集 | 企业协作、社交 | N/A | arXiv |
| **LongMemEval** (基准) | 多轮聊天记忆评测 | 个人助手、客服 | N/A | 官网/文档 |
| **OpenClaw** (框架) | 本地助手框架，支持插件记忆 | 个人/小团队助手 | ★★☆☆☆ | GitHub、社区指南 |
| **agent-memory** (插件) | 分层存储、自动捕获 | OpenClaw 扩展 | ★★☆☆☆ | PyPI 文档 |
| **memU/memUBot** (框架) | 向量语义检索、多用户 | 团队/企业助手 | ★★★★☆ | GitHub（需注册） |
| **OpenViking** (框架) | 虚拟文件系统上下文管理 | 任务自动化、高级代理 | ★★★★☆ | GitHub |

### **搭建指南摘要**

搭建这些系统一般需以下步骤：如使用 OpenClaw Agent，只需按其文档 `npm install openclaw`，并执行 `openclaw hooks enable memory-core` 等即可。agent-memory 插件可通过 `pip install openclaw-memory` 安装，并执行 `agent-memory setup openclaw` 配置。LoCoMo/EverMemBench 数据集可从相应开源库下载（如 Snap 的 LOCOMO GitHub）。硬件要求与使用场景有关：个人部署可用普通服务器或云实例，企业级系统则需配置向量数据库或文档存储等。部署难度方面，OpenClaw 社区提供较多模板和示例，memU 需额外学习其企业配置，OpenViking 目前更偏研究性，需一定开发能力。

## 其他厂商和模型

- **苹果 Siri/Assistant**：苹果官方尚未针对2026发布新的LLM，仅持续升级Siri功能。Siri目前暂未内置长期记忆，更多依赖本地上下文与Apple ID信息。
- **其他国产**：华为麦芒OS 5.0、小米MIMO（ColorOS 16）等不断强化助手记忆服务（如小布记忆），但主要集中于系统行为记录和定向推荐，非直接大模型记忆实现（可参见小米ColorOS的记忆搜索、问答）。

### 横向对比表

以下表格汇总了各厂商/模型的关键参数与特性（若无公开数据标“未公开”）。由于厂商披露有限，表中部分数据或能力根据官方报道推断。

| **厂商/模型** | **模型规模** | **记忆存储容量** | **检索/生成混合** | **隐私策略** | **移动端部署** | **延迟 & 吞吐** | **能耗优化** | **数据来源** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| OpenAI ChatGPT | 未公开（大型GPT系列） | 用户可控，基于云端知识库 | 主要生成（隐式参考检索） | 用户可关闭记忆 | 云端 Only | 云服务数百ms级 | 大规模GPU并行 | [https://openai.com/zh-Hans-CN/index/memory-and-new-controls-for-chatgpt/#:~:text=%E6%82%A8%E5%8F%AF%E4%BB%A5%E9%9A%8F%E6%97%B6%E5%85%B3%E9%97%AD%E8%AE%B0%E5%BF%86%E5%8A%9F%E8%83%BD%EF%BC%88%E2%80%9C%E8%AE%BE%E7%BD%AE%E2%80%9D%20](https://openai.com/zh-Hans-CN/index/memory-and-new-controls-for-chatgpt/#:~:text=%E6%82%A8%E5%8F%AF%E4%BB%A5%E9%9A%8F%E6%97%B6%E5%85%B3%E9%97%AD%E8%AE%B0%E5%BF%86%E5%8A%9F%E8%83%BD%EF%BC%88%E2%80%9C%E8%AE%BE%E7%BD%AE%E2%80%9D%20) |
| Anthropic Claude | 未公开 | 多个任务知识库（无限制） | 检索增强生成 | 企业合规（知识库隔离） | 云端 Only | 未公开 | 云端部署 | [https://36kr.com/p/3646147182595974#:~:text=%E7%9F%A5%E8%AF%86%E5%BA%93%E5%86%85%E9%83%A8%E6%8C%87%E4%BB%A4](https://36kr.com/p/3646147182595974#:~:text=%E7%9F%A5%E8%AF%86%E5%BA%93%E5%86%85%E9%83%A8%E6%8C%87%E4%BB%A4) |
| Google Gemini | ~数百亿（Gemini 3） | 访问Gmail/Photos等私人数据 | 强检索+生成 | 默认关闭，用户授权 | 云端 Only | 数百ms | 数据中心优化 | [https://blog.google/innovation-and-ai/products/gemini-app/personal-intelligence/#:~:text=Personal%20Intelligence%20securely%20connects%20information,to%20be%20simple%20and%20secure](https://blog.google/innovation-and-ai/products/gemini-app/personal-intelligence/#:~:text=Personal%20Intelligence%20securely%20connects%20information,to%20be%20simple%20and%20secure)<br>[https://fortune.com/2026/01/14/google-gemini-ai-personal-assistant-gmail-photos-youtube-history-personal-intelligence/#:~:text=Google%20%20is%20launching%20a,data%20and%20surface%20proactive%20insights](https://fortune.com/2026/01/14/google-gemini-ai-personal-assistant-gmail-photos-youtube-history-personal-intelligence/#:~:text=Google%20%20is%20launching%20a,data%20and%20surface%20proactive%20insights) |
| Kimi K2.5（MoE+Visual） | MoE 专家网络 + 256K 上下文窗口 | 上下文缓存（外部记忆） | 无显式检索（用片段输入上下文） |  |  |  |  |  |
| DeepSeek V3.x | MoE + DSA（稀疏自注意力） | 上下文缓存 + KV 压缩（MLA） | 无显式检索 |  |  |  |  |  |
| Engram（记忆网络）记忆搭建框架 | MoE + Engram 条件记忆 | 固定 N-gram 嵌入表（静态记忆） | O(1) 哈希查找（多头哈希）<br>稀疏哈希表（散列表+嵌入矩阵） |  |  |  |  |  |
| 百度文心5.0 | 2.4万亿参数 | 无（短期上下文128K） | 生成为主 | 法规合规（云存储） | 云端 Only | 未公开 | <3%激活MoE | [https://ernie.baidu.com/blog/zh/posts/ernie5.0/#:~:text=,Tokens%20Prediction%EF%BC%89%20%E4%BB%BB%E5%8A%A1%E8%BF%9B%E8%A1%8C%E7%AB%AF%E5%88%B0%E7%AB%AF%E4%BC%98%E5%8C%96%E3%80%82%20%2A%20%E5%85%A8%E6%A8%A1%E6%80%81%E8%83%BD%E5%8A%9B%EF%BC%9A%E5%BD%BB%E5%BA%95%E6%B6%88%E8%9E%8D%E6%A8%A1%E6%80%81%E5%A3%81%E5%9E%92%EF%BC%8C%E5%AE%9E%E7%8E%B0%E8%B7%A8%E6%A8%A1%E6%80%81%E7%90%86%E8%A7%A3%E4%B8%8E%E7%94%9F%E6%88%90%E7%9A%84%E6%97%A0%E7%BC%9D%E8%A1%94%E6%8E%A5%E3%80%82](https://ernie.baidu.com/blog/zh/posts/ernie5.0/#:~:text=,Tokens%20Prediction%EF%BC%89%20%E4%BB%BB%E5%8A%A1%E8%BF%9B%E8%A1%8C%E7%AB%AF%E5%88%B0%E7%AB%AF%E4%BC%98%E5%8C%96%E3%80%82%20%2A%20%E5%85%A8%E6%A8%A1%E6%80%81%E8%83%BD%E5%8A%9B%EF%BC%9A%E5%BD%BB%E5%BA%95%E6%B6%88%E8%9E%8D%E6%A8%A1%E6%80%81%E5%A3%81%E5%9E%92%EF%BC%8C%E5%AE%9E%E7%8E%B0%E8%B7%A8%E6%A8%A1%E6%80%81%E7%90%86%E8%A7%A3%E4%B8%8E%E7%94%9F%E6%88%90%E7%9A%84%E6%97%A0%E7%BC%9D%E8%A1%94%E6%8E%A5%E3%80%82) |
| 阿里RynnBrain | 30B MoE（激活3B） | 隐式时空记忆 | 生成为主 | 未披露 | 主要云端/机器人平台 | 未公开 | MoE稀疏激活 | [https://finance.sina.cn/stock/jdts/2026-02-10/detail-inhmiaep8572760.d.html?vt=4#:~:text=RynnBrain%E5%9C%A8Qwen3,5%E3%80%81%E8%8B%B1%E4%BC%9F%E8%BE%BE%20Cosmos%20Reason%202%E7%AD%89%E5%85%B7%E8%BA%AB%E9%A1%B6%E5%B0%96%E6%A8%A1%E5%9E%8B%E3%80%82](https://finance.sina.cn/stock/jdts/2026-02-10/detail-inhmiaep8572760.d.html?vt=4#:~:text=RynnBrain%E5%9C%A8Qwen3,5%E3%80%81%E8%8B%B1%E4%BC%9F%E8%BE%BE%20Cosmos%20Reason%202%E7%AD%89%E5%85%B7%E8%BA%AB%E9%A1%B6%E5%B0%96%E6%A8%A1%E5%9E%8B%E3%80%82) |
| 阿里Polar Memory | N/A（云端引擎） | PB级跨会话记忆 | 检索为主 | 用户可控，企业策略 | 云端 Only | 响应时间↓30% | 向量+KG缓存 | [https://help.aliyun.com/zh/polardb/polardb-for-mysql/polardb-agent-memory#:~:text=%E6%88%91%E7%9A%84%E6%94%B6%E8%97%8F](https://help.aliyun.com/zh/polardb/polardb-for-mysql/polardb-agent-memory#:~:text=%E6%88%91%E7%9A%84%E6%94%B6%E8%97%8F) |