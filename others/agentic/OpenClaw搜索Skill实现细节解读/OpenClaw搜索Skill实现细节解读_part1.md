OpenClaw 作为面向 AI 智能体的扩展能力平台，其搜索类能力分为**内置 Web 搜索工具**（主仓库核心能力）和**扩展搜索 Skill**（社区 / 第三方插件化能力）两大体系，以下是详细的实现细节拆解：

## 一、核心定位：搜索能力在 OpenClaw 中的角色

搜索能力是 OpenClaw 智能体突破模型训练数据截止期、获取外部实时 / 动态信息的核心入口，它通过标准化的 Skill/Tool 接口，将外部搜索服务封装为智能体可直接调用的原子能力，同时内置了大量优化逻辑来提升搜索结果的质量和可用性 。

---

## 二、主仓库内置：Web 搜索工具（web_search）实现

这是 OpenClaw 主仓库内置的核心搜索能力，属于 Pi SDK 嵌入层的轻量级 HTTP 工具，区别于浏览器自动化工具，它直接通过 HTTP 请求调用搜索 API，具备轻量、高并发的特性 。

### 1. 插件化 Provider 架构

内置搜索工具采用了可扩展的 Provider 架构，支持对接多种搜索后端，而非绑定单一服务，目前已支持的 Provider 包括：

| Provider | 能力特点 | 鉴权方式 | 适用场景 |
| --- | --- | --- | --- |
| Brave Search | 结构化摘要、支持区域 / 语言 / 时间过滤、llm-context 优化模式 | BRAVE_API_KEY | 默认通用搜索，免费 Tier 可用 |
| DuckDuckGo | 无密钥、隐私优先 | 无 | 无 API 密钥时的降级 fallback |
| Exa | 神经 + 关键词混合搜索、支持内容提取 | EXA_API_KEY | 学术 / 技术文档深度检索 |
| Tavily | LLM 优化结果、内置内容提取、域名过滤 | TAVILY_API_KEY | AI 助手专属搜索，结果更适配大模型输入 |
| Perplexity Sonar | 多引擎聚合、支持域白名单 / 黑名单 | PERPLEXITY_API_KEY | 复杂研究类搜索 |
| Gemini/Grok/Kimi | 内置搜索 grounding，AI 合成答案 + 引用 | 对应模型 API 密钥 | 模型原生搜索增强 |
| SearXNG | 自托管元搜索、聚合 70 + 引擎 | 无（自托管实例） | 隐私优先、完全可控的本地搜索 |

内置支持:Brave Search/DuckDuckGo/Exa/Tavily/Perplexity Sonar/Gemini/Grok/Kimi/SearXNG

#### Provider 自动检测逻辑

当用户未显式指定 Provider 时，系统会按照优先级自动检测已配置的 API 密钥，选择第一个可用的 Provider，优先级顺序为： `Brave → Gemini → Grok → Kimi → Perplexity → Firecrawl → Tavily` 如果所有密钥都不存在，则降级到 Brave 并提示用户配置密钥 。

### 2. 完整的搜索执行流水线

内置搜索工具的执行分为 7 个核心阶段：

#### 阶段 1：查询预处理与改写

在调用搜索 API 之前，系统会对用户的自然语言查询进行自动优化：

- **关键词提取**：从自然语言问题中提取核心搜索关键词，优化查询的匹配度
- **缩写展开**：自动展开行业 / 技术缩写，避免搜索歧义
- **时效性过滤**：自动识别查询的时效性需求（如 "最新"、"近期"），自动添加时间过滤参数
- **参数标准化**：将通用参数转换为对应 Provider 的 API 参数格式，屏蔽不同 API 的参数差异

#### 阶段 2：搜索 API 调用

根据选中的 Provider，封装对应的 API 请求：

- 统一的请求超时控制（默认 30 秒，可配置）
- 自动重试机制：针对 transient 错误（如网络波动、5xx 错误）进行最多 2 次重试
- 速率限制：内置用户级和全局的请求速率限制，避免触发 API 服务商的限流
  - 全局默认：30 次搜索 / 分钟、60 次页面抓取 / 分钟
  - 用户级默认：5 次搜索 / 分钟

#### 阶段 3：结果标准化处理

不同 Provider 返回的结果格式差异很大，系统会将其统一转换为标准化的结果格式，每个结果包含：

```
interface SearchResult {
  title: string;       // 结果标题
  url: string;         // 结果链接
  snippet: string;     // 摘要文本
  published_date?: string; // 发布时间
  score?: number;      // 相关性评分
  source: string;      // 来源域名
}
```

#### 阶段 4：来源多样性过滤

为了避免单一来源的信息偏差，系统会对结果进行多样性过滤：

- 配置项：`minDomains: 3`（最少来自 3 个不同域名）、`maxResultsPerDomain: 3`（单个域名最多 3 条结果）
- 自动过滤重复域名的低质量结果，保证结果来源的多样性

#### 阶段 5：内容提取（可选）

当智能体需要深入阅读某个搜索结果时，会自动调用配套的`web_fetch`能力进行页面内容提取：

1. **DOM 解析**：解析页面 HTML 结构
2. **正文识别**：使用 Readability 算法识别正文区域，过滤导航栏、广告、侧边栏等无关内容
3. **格式转换**：将 HTML 转换为干净的 Markdown 格式，适配大模型的输入
4. **长度截断**：自动截断过长的内容，同时保留最相关的核心部分，默认最大内容长度 5000 字符
5. **降级处理**：对于反爬站点（如微信、知乎），自动降级到 MinerU 等第三方解析服务

#### 阶段 6：缓存机制

为了减少重复请求、提升响应速度，内置了两级缓存：

#### 阶段 7：安全与合规过滤

在结果返回给智能体之前，会进行安全过滤：

- **域名过滤**：支持配置黑名单域名，屏蔽恶意、钓鱼站点
- **内容过滤**：对结果内容进行安全检查，过滤不当内容
- **注入防护**：对查询参数进行转义，防止 API 查询注入攻击

### 3. 多轮搜索能力

针对复杂问题，单次搜索往往无法获取足够信息，系统支持智能体发起多轮搜索：

- 配置项：`maxRounds: 3`（最多 3 轮搜索）、`maxTotalResults: 30`（最多返回 30 条总结果）
- 流程：先进行广泛搜索获取初步信息，再根据初步结果细化查询，进行深入的针对性搜索，逐步收敛到问题的答案

---

## 三、扩展搜索 Skill：深度搜索（search-layer）实现

[https://github.com/blessonism/openclaw-skills/blob/main/search-layer/SKILL.md](https://github.com/blessonism/openclaw-skills/blob/main/search-layer/SKILL.md)

[https://github.com/blessonism/openclaw-search-skills](https://github.com/blessonism/openclaw-search-skills)

这是 OpenClaw 生态中最流行的第三方深度搜索 Skill，主要面向复杂研究类场景，提供多源聚合搜索能力，也是很多用户口中的 "OpenClaw 搜索 Skill" 的常见实现 。

### 1. 整体架构

```
github-explorer（上层应用）
├── search-layer（多源搜索层）
│   ├── Exa 搜索源
│   ├── Tavily 搜索源
│   ├── Grok 搜索源
│   └── 内置Brave搜索源（复用OpenClaw内置能力）
├── content-extract（智能内容提取）
│   └── mineru-extract（反爬站点降级解析）
└── OpenClaw 内置工具
```

### 2. 核心实现细节

#### 多源并行搜索

在 Deep 模式下，会同时调用 Exa、Tavily、Grok 三个搜索源，并行执行搜索，然后对结果进行聚合：

- 避免单一搜索源的结果偏差
- 最大化结果的覆盖范围
- 自动处理不同源的结果格式差异

#### 意图感知的结果评分

这是该 Skill 最核心的优化点，它会先对查询进行意图分类，然后根据不同的意图调整结果的评分权重：

- **7 种查询意图**：factual（事实类）、status（状态类）、comparison（对比类）、tutorial（教程类）、exploratory（探索类）、news（新闻类）、resource（资源类）
- **动态评分公式**：
  - 新闻类意图：提升新鲜度权重`w_freshness`
  - 教程类意图：提升权威域名权重`w_authority`
  - 事实类意图：提升关键词匹配权重`w_keyword`

#### 域名权威评分

内置了四级域名权威评分表，包含 60 + 常见域名的权重配置，同时支持通配符模式匹配：

- 比如 stackoverflow、github、官方文档域名会获得更高的权重
- 低质量、内容农场类域名会被降低权重

#### 智能降级机制

当某个搜索源的 API 密钥未配置或者调用失败时，系统会自动降级到其他可用的搜索源，保证搜索流程不中断：

- 比如 Grok 密钥缺失时，自动降级为 Exa+Tavily 双源搜索
- 所有付费源都不可用时，自动降级到内置的 Brave 搜索

#### 多查询并行支持

支持同时执行多个子查询，比如对比类查询时，会同时搜索 "A 的优势" 和 "B 的优势"，然后聚合结果，提升对比类问题的搜索效率 。

---

## 五、端到端完整流程：从用户输入到答案返回

### 流程总览图

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/OhP8DFrKo3PoA8lXZb0lY0ITQjqiG2PnWHsnE18fAnB8wOSs0-878EnbABMkfnf1 "image.png")

### 步骤 1：用户输入与 Skill 能力注入

1. 用户在对话中输入自然语言查询，例如：`"2026年最新的主流RAG框架对比，哪个效果最好？"`
2. OpenClaw 运行时首先完成 Skill 注入：调用内置的`formatSkillsForPrompt`方法，将当前环境中可用的 Skill（包括`web_search`）的能力描述、触发条件、使用方式进行 XML 格式化后，注入到给大模型的系统提示词中，注入的内容示例：

这一步是为了让大模型明确感知到当前有搜索能力可用，以及该能力的适用场景和调用方式，是 Skill 触发的基础 。

### 步骤 2：大模型意图识别与工具调用决策

1. 大模型结合注入了 Skill 信息的系统提示词、用户的原始查询，进行多维度意图分析：
  1. 时效性判断：该问题询问 2026 年的最新框架，超出了模型的训练数据截止期（通常为 2025 年中），无法仅凭自身知识回答
  2. 场景匹配：符合`web_search`Skill 的触发条件 "需要实时外部信息"
  3. 需求拆解：识别出用户需要的是框架对比、效果评测，而非简单的事实查询
2. 大模型生成标准化的 Function Call 请求，完全遵循 OpenAI Function Call 的标准格式，保证兼容性：

### 步骤 3：搜索工具初始化与前置检查
