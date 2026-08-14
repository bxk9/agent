# 1 Agentic 引入的原因和效果：

## 1.1 问题分布暴露->需要agentic（待补充产品定义+技术分析）

# 2 问答工具接入中控3.0方案

## 2.1  3.0现状-暂时只有简单问答链路

  - 中控3.0架构 [https://docs.vivo.xyz/s/Ee37sQAA](https://docs.vivo.xyz/s/Ee37sQAA) 邀请您加入文档协作【中控3.0-【算法】-设计方案】
    - [https://docs.vivo.xyz/s/8h2Nq6BS](https://docs.vivo.xyz/s/8h2Nq6BS) 邀请您加入文档协作【智能路由分流标准_v1.0】

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/ONu1JPeCEgDpfZ0MAMbzn4ZLw-xpW1C3Bu-QR-IYMCrFzVChjGmSa9CSVNacO7Cz "image.png")

    - 当前问答接入的方案：当前按照工具的方式接入，提供AI搜索和纯检索接口

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/8UqIKLg5s3iLh1zI1DU-VLIp-NdVStciaPZbUH2JiKqZQreMYWZfK5s6LDRwWeJN "image.png")

  - 3.0评测结果：[https://docs.vivo.xyz/s/BoeELsD9](https://docs.vivo.xyz/s/BoeELsD9)

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/qUlNGb3OeE0FTFfHqR89IDUImtCpPB_IJgZ8ML4BI7EDeYdHpfA67OWYX33uaQvz "image.png")

# 3 前沿进展：

- 框架前沿进展： claude code 使用sub-agent这种架构， open claw/hermes核心采用主agent调用工具的架构
- 智能路由的前沿进展： OpenAI利用对话类型&任务复杂度&工具需求&及显性的用户意图，来路由用户问答问题
- web搜的前沿进展：做法上可参考open claw/claude code/hermes， 产品上可参考grok

### **联网搜索方案优化方向汇总:**

<table>
<tr>
<th>**优化点**</th>
<th>**具体类别**</th>
<th></th>
<th>**具体策略**</th>
<th>能解决什么问题</th>
<th>是否已用（已用，待用，不适合</th>
<th>**方案来源**</th>
</tr>
<tr>
<td rowspan="3">**一、 架构**</td>
<td>`ReAct`** 机制**</td>
<td>x</td>
<td>大模型在每轮操作后，自主判断当前收集的信息是否已足够回答用户问题。若足够则输出答案并结束，否则继续调用工具。</td>
<td></td>
<td>已用</td>
<td>Open Claw, Claude Code, Hermes</td>
</tr>
<tr>
<td>**子 Agent 协同架构**</td>
<td>1</td>
<td>采用“中控主模型 + 搜索子 Agent”模式。主模型负责整体规划，派生专门的子 Agent(专业/快速) 仅负责执行搜索任务（如最多允许8轮迭代）。</td>
<td></td>
<td>待用</td>
<td>Claude Code</td>
</tr>
<tr>
<td>**硬性兜底机制**</td>
<td>x</td>
<td>在框架层设置硬性终止条件或降级规则，防止大模型陷入无限循环。</td>
<td>系统稳定性</td>
<td>已用</td>
<td>Hermes</td>
</tr>
<tr>
<td rowspan="3">**二、 搜索前**</td>
<td>**缓存提速**</td>
<td>x</td>
<td>1. **查询缓存**：命中历史相同 Query 直接返回。<br>2. **会话复用**：同会话或跨会话中，复用已有的搜索结果和历史信息。</td>
<td>降低成本, 提高响应速度</td>
<td>不适合(适合搜索团队)</td>
<td>Open Claw, Hermes</td>
</tr>
<tr>
<td>**动态 Prompt 注入**</td>
<td>x</td>
<td>在系统提示词中动态注入当前时间（如年月）、模型知识截止日期以及工具的 Schema 定义。</td>
<td>帮助模型明确“何时需要搜索”以及“搜索的时效性边界”。</td>
<td>已用</td>
<td>Claude Code, Hermes</td>
</tr>
<tr>
<td>**智能分类与路由**</td>
<td>x</td>
<td>在搜索前对用户的 Query 进行意图分类（如：事实类、探索类）。根据意图调整后续搜索源的选择和结果评分权重（如事实类更看重权威性,新闻类更重视时效）。</td>
<td>搜索策略更贴合用户真实需求<br>搜索结果匹配度更好</td>
<td>已用</td>
<td>Open Claw</td>
</tr>
<tr>
<td rowspan="3">**三、 搜索中（改写）**</td>
<td>**复杂问题拆解**</td>
<td>1</td>
<td>针对多维度、复杂的原始问题，基于当前的“信息缺口”，将其拆分为多个独立、聚焦的子 Query。</td>
<td rowspan="3">扩大搜索面/搜索效果</td>
<td>已用</td>
<td>Claude Code, Hermes</td>
</tr>
<tr>
<td>**查询词智能扩展**</td>
<td>1</td>
<td>1. 提取核心关键词并展开缩写。<br>2. 自动扩展同义词。<br>3. **中英双语优化**：针对中文技术问题，自动生成英文变体进行检索。</td>
<td>已用</td>
<td>Open Claw</td>
</tr>
<tr>
<td>**结果验证与迭代重试**</td>
<td>1</td>
<td>若搜索工具返回空数据或不完整结果，强制要求模型调整 Query 或更换策略重新搜索，严禁直接放弃或编造（幻觉）。</td>
<td>已用</td>
<td>Hermes</td>
</tr>
<tr>
<td rowspan="3">**四、 搜索中（执行）**</td>
<td>**搜索源智能降级**</td>
<td>1</td>
<td>搜索后端配置多个数据源。当某个搜索源调用失败或超时，系统自动无缝降级到其他可用源。</td>
<td rowspan="3">避免简单任务过度消耗资源，同时保证复杂任务有足够的搜索能力支持。</td>
<td>已用</td>
<td>Open Claw, Hermes</td>
</tr>
<tr>
<td>**多源并行检索**</td>
<td>1</td>
<td>同时向多个搜索引擎或数据源发起并发请求,同时调用多个差异化搜索源。</td>
<td>已用</td>
<td>Open Claw</td>
</tr>
<tr>
<td>**搜索源管理**</td>
<td>1</td>
<td>1.系统内置支持多种主流与前沿搜索源<br>2.通过搜索源的启用或弃用来匹配当前任务的复杂度。</td>
<td>已用</td>
<td>Open Claw, Hermes</td>
</tr>
<tr>
<td rowspan="5">**五、 搜索后处理**</td>
<td>**多维结果打分排序**</td>
<td>1</td>
<td>1.建立评分公式：`综合得分 = 关键词匹配度 + 时效性得分 + 权威性得分`，对搜索结果进行重排。<br>2.内置了四级域名权威评分表</td>
<td rowspan="3">非常精细的知识后处理策略,提高知识的有效利用率</td>
<td>已用</td>
<td>Open Claw</td>
</tr>
<tr>
<td>**知识合成与处理**</td>
<td>1</td>
<td>根据结果数量动态调整总结策略：<br>1. 按主题聚合信息，而非按来源罗列。<br>2. 遇到不同来源信息冲突时，进行**显性标注**并给出置信度。<br>3. 规范输出格式：先给答案，再列出引用来源（URL、标题）。</td>
<td>已用简单实现(有优化空间)</td>
<td>Open Claw, Claude Code</td>
</tr>
<tr>
<td>**安全过滤**</td>
<td>1</td>
<td>**域名过滤**：支持配置黑名单域名，屏蔽恶意、钓鱼站点<br>**内容过滤**：对结果内容进行安全检查，过滤不当内容<br>**注入防护**：对查询参数进行转义，防止 API 查询注入攻击</td>
<td>已用简单实现(有优化空间)</td>
<td>Open Claw</td>
</tr>
<tr>
<td>**深度抓取与引用追踪**</td>
<td>x</td>
<td>1. **深度阅读**：主模型可根据摘要，调用 `webfetch` 等工具抓取特定网页的全文。<br>2. **特定链接追踪**：识别到 GitHub Issue/PR 等高价值链接时，自动触发追踪。</td>
<td>解决搜索摘要信息量不足的问题</td>
<td>待用</td>
<td>Open Claw, Claude Code</td>
</tr>
<tr>
<td>**记忆与技能沉淀**</td>
<td>x</td>
<td>1. **核心记忆**：提取并保存环境事实、用户偏好等。<br>2. **技能沉淀**：将本次成功的复杂多步搜索/工具调用流程，固化为可复用的 `Skill` 文件。</td>
<td>越用越聪明</td>
<td>待用</td>
<td>Hermes</td>
</tr>
</table>

三家Agent（Open Claw、Claude Code、Hermes）的具体搜索策略如下:

<table>
<tr>
<td></td>
<td></td>
<td>react</td>
<td>搜索前</td>
<td colspan="3">搜索中</td>
<td>搜索后 </td>
</tr>
<tr>
<td></td>
<td></td>
<td></td>
<td></td>
<td>改写</td>
<td>搜索处理</td>
<td>搜索源</td>
<td></td>
</tr>
<tr>
<td>Open Claw</td>
<td>@李司棋</td>
<td>大模型react, 判断当前的结果是否足够回答用户的原始问题</td>
<td>1、意图分类, 确定搜索策略, 先对查询进行意图分类，然后根据不同的意图调整结果的评分权重 如**Factual 意图, 更注重‘权威’**<br>2、**缓存命中检查, **大幅提升响应速度</td>
<td>关键词提取<br>缩写展开<br>时效性过滤<br>参数标准化<br>**同义词自动扩展**<br>**中文技术查询**：同时生成英文变体<br>按意图扩展查询词</td>
<td>**1、智能降级机制**<br>当某个搜索源的调用失败时，系统会自动降级到其他可用的搜索源，保证搜索流程不中断：<br>2、**多源并行检索**<br>3、**引用追踪:**当搜索结果中包含 GitHub issue/PR 链接，且意图为 Status 或 Exploratory 时，自动触发引用追踪。</td>
<td>1、内置支持:Brave Search/DuckDuckGo/Exa/Tavily/Perplexity Sonar/Gemini/Grok/Kimi/SearXNG<br>2、扩展SKILL 支持同时调用 Exa、Tavily、Grok 三个搜索源</td>
<td>**结果****加权****排序: **四级域名权威评分表<br>score = w_keyword × keyword_match + w_freshness × freshness_score + w_authority × authority_score<br>**缓存机制**<br>**知识合成:**根据结果数量选择合成策略：<br>先给答案，再列来源<br>按主题聚合，不按来源聚合<br>冲突信息显性标注<br>置信度</td>
</tr>
<tr>
<td>Claude Code </td>
<td>@李海天</td>
<td>中控大模型自主判断是否需要调用工具，无需调用工具则总结输出回答</td>
<td>搜索词生成prompt：<br>来自搜索工具描述——告诉模型何时该搜索、动态注入当前月份<br>来自中控大模型sp——当前日期、中控大模型预训练知识截止日期</td>
<td>由子agent根据当前信息缺口确定单步搜索词<br>闭源搜索工具web_search_20260209内部可能有进一步搜索词拆解</td>
<td>采用**子agent形式**，派生出由opus/haiku驱动的搜索agent，仅可调用搜索工具web_search_20260209<br>子agent**遵循react模式**，最多进行8轮搜索</td>
<td>Claude闭源联网搜索API，逆向研究发现搜索结果和brave相似度高</td>
<td>搜索子agent向中控大模型返回：<br>搜索结果摘要<br>引用列表（url、标题、引文片段）<br>中控大模型可根据需要**对部分url展开深入探索**，调用webfetch工具抓取网页全文深入阅读</td>
</tr>
<tr>
<td>Hermes</td>
<td>@陈妮</td>