# 1.概述

- 联网搜索核心 ：**2 个标准化工具**** + ****框架级串并行调度**** + ****LLM 函数调用决策**

| web_search | 联网搜索引擎调用（Tavily/Serper/Google） | query  --- >  urls |
| --- | --- | --- |
| web_extract | 网页正文深度提取 | urls   --->    text |

- Hermes 对tool 和 skiil的边界定义

| 维度 | Tool（工具） | Skill（技能） |
| --- | --- | --- |
| **核心定位** | 原子化、可精确执行的底层执行单元 | 可复用的工作流 / 指令集 / 知识封装，上层编排层 |
| **实现方式** | 必须硬编码 Python 代码，内置 API 密钥管理、认证、异常处理、固定执行逻辑 | 纯 YAML+Markdown 指令文档，遵循 [agentskills.io](http://agentskills.io) 标准，无需硬编码，仅定义流程和规则 |
| **联网相关能力** | 唯一能实现 HTTP 请求、搜索引擎 API 调用、网页渲染 / 爬取 / 提取的执行入口，所有联网动作都在这里完成 | 本身无任何联网执行代码，仅能调度已有的搜索 Tool，告诉 LLM「什么时候搜、搜什么、怎么处理结果、下一步做什么」 |
| **运行依赖** | 可独立运行，无需任何 Skill 参与 | 完全依赖底层 Tool，没有对应 Tool，Skill 无法执行任何实际动作 |
| **搜索场景作用** | 完成「单次搜索 / 单次网页提取」的原子动作 | 把多次搜索 / 提取动作组合成完整工作流，实现复杂的自动化搜索任务 |

# 2. **web_search 工具**

## 2.1 工具Schema定义

定义了 OpenAI 格式的工具 Schema，是 LLM 能够调用该工具的核心基础。

```plaintext
WEB_SEARCH_SCHEMA = {
    "name": "web_search",
    "description": "Search the web for information on any topic. Returns up to 5 relevant results with titles, URLs, and descriptions.",
    "parameters": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "The search query to look up on the web"
            }
        },
        "required": ["query"]
    }
}
```

### 2.1.1 query如何生成

- **结论**：query 是大模型（LLM）**自主生成、自主优化**的。

在 Agent 启动时，系统会完成两个核心动作，给 LLM 划定 query 生成的边界：

- step1： **工具 Schema 注入**

`AIAgent`会从工具**注册表**中拉取`web_search`的完整 JSON Schema，把工具的能力、入参要求、使用场景、必填参数规则，全部注入到系统 Prompt 中，告诉 LLM：

1. 什么时候可以调用 web_search（实时信息、事实校验、知识盲区等场景）
2. 调用时必须传入一个字符串类型的`query`参数（limit可选，默认为5），这个参数是给搜索引擎的搜索关键词
3. 什么样的 query 是有效的（精准、无歧义、符合搜索引擎规则）
- step 2： **系统 Prompt 引导**

默认系统 Prompt 会明确约束 LLM 的 query 生成行为。

- step 3：** 参数校验与修复**

LLM 生成 query 后，`model_tools.py`的`handle_function_call`函数会做二次校验。

## 2.2 多搜索后端适配逻辑

### 2.2.1 后端类型

Hermes Agent 实现了**后端无关的统一搜索接口**，支持 4 类主流搜索后端，可通过配置自由切换：

| 后端类型 | 对应实现函数 | 核心特点 |
| --- | --- | --- |
| Parallel | `_parallel_search` | AI 原生搜索，支持 agentic/one-shot/fast 三种模式 |
| Firecrawl | 原生 client 调用 | 支持搜索、爬取、内容提取一体化，默认兼容后端 |
| Tavily | `_tavily_search` + `_normalize_tavily_search_results` | 专为 LLM 优化的搜索后端 |
| Exa | `_exa_search` | 基于语义的 AI 搜索，支持高亮片段提取 |

### 2.2.2 后端选择核心逻辑

- **config配置优先：** 优先读取`config.yaml`中`web.backend`配置项，明确指定后端
- **环境变量自动检测：**无配置时，通过环境变量自动检测（存在`PARALLEL_API_KEY`则用 Parallel，存在`FIRECRAWL_API_KEY`则用 Firecrawl）
- **后端兜底：** 兜底默认使用 Firecrawl 后端
- **自动降级：**非法配置自动降级到环境变量检测逻辑

## 2.3  web_search_tool 核心执行函数

搜索引擎入口，是所有网页操作的第一步，**只负责「找相关网页」，不深入读取网页内部内容**，输入搜索 query，返回多个匹配网页的标题、URL、摘要。

- 中断检查：校验是否有用户中断信号，支持中途取消搜索，避免无效资源占用
- 后端匹配：通过`_get_backend()`函数，读取配置 / 环境变量，匹配可用的搜索后端（Tavily/Exa/Firecrawl/Parallel）
- 分发执行：根据匹配的后端，调用对应搜索接口，传入 query 和 limit 参数
- 结果标准化：把不同后端的返回结果，统一转换成固定格式，过滤无效、重复信息
- 异常兜底：全链路异常捕获，返回标准化错误信息，不会导致 Agent 进程崩溃
- 出参格式：

```plaintext
{
  "success": true/false,
  "data": {
    "web": [
      {
        "title": "网页标题",
        "url": "网页链接",
        "description": "网页摘要/高亮匹配片段"
      }
    ]
  },
  "error": "错误信息（success=false时返回）"
}
```

# 3. web_extract 工具

## 3.1 核心实现

- 单网页定向深度内容提取，是 web_search 的后续动作，**解决「单个网页里的详细内容是什么」的问题**，输入目标 URL，返回网页的完整正文、标题、元数据。
- 内置智能摘要能力，过滤广告、导航栏等无效内容，精准提取核心信息。
- 唯一必填入参：`url`（目标网页的完整链接）
- 可选入参：`max_content_length`：最大内容长度限制，避免超长内容溢出上下文  `summarize`：是否开启智能摘要，默认开启，超长内容自动压缩
- 出参格式：

```plaintext
{
  "success": true/false,
  "data": {
    "url": "目标网页链接",
    "title": "网页标题",
    "content": "处理后的正文/智能摘要（Markdown格式）",
    "raw_content": "原始提取内容（未压缩）",
    "metadata": "网页元数据（发布时间、作者、站点等）",
    "summarized": true/false // 是否经过智能摘要压缩
  },
  "error": "错误信息（success=false时返回）"
}
```

## 3.2 安全校验 + 后端匹配 + 智能压缩

### 3.2.1 安全校验

SSRF 安全校验：拦截内网 IP、私有地址、本地回环地址的 URL，规避 SSRF 攻击风险

合规校验：检查目标网站的`robots.txt`协议，拦截禁止爬取的站点 / 页面

内容渲染提取：支持动态 JS 页面渲染，提取网页正文，自动过滤广告、导航、页脚、评论区等无效内容

### 3.2.2 后端匹配

后端匹配：和 web_search 共用同一套后端配置，调用对应后端的 scrape/extract 接口

### 3.2.3 智能压缩

智能摘要压缩：如果`summarize=True`且内容超过阈值，自动调用 **Gemini 3 Flash** 模型，把长内容压缩成结构化摘要，平均压缩比 90% 以上，严格控制 token 占用

格式标准化：把提取的内容转换成 Markdown 格式，适配 LLM 读取，保留标题、段落、列表等结构

# 4. web_crawl 工具 （未注册）

全站 / 多页面批量深度爬取，**解决「整个网站 / 多个关联页面的全量内容是什么」的问题**，输入起始 URL，自动发现站内关联链接，批量爬取整个网站的符合规则的页面，返回全量结构化内容，适合离线批量数据采集，不适合实时对话场景。

核心执行流程（批量采集）：

1. 前置安全与合规校验：同 web_extract，先做 SSRF 防护、robots 协议校验，拦截违规站点
2. 后端校验：仅支持 Firecrawl 和 Parallel 后端（Tavily/Exa 无原生全站爬取能力），不支持的后端直接返回错误
3. 爬取任务配置：把爬取深度、页面限制、路径黑白名单等参数，传入对应后端的 crawl 接口
4. 并行批量爬取：从起始 URL 出发，自动发现站内所有符合规则的链接，并行爬取所有页面
5. 内容标准化：统一每个页面的标题、URL、正文、元数据格式，过滤无效内容
6. 结果合并：把所有爬取成功的页面内容，合并成结构化数组返回
7. 异常容错：单页面爬取失败不中断整体任务，仅记录错误日志，保证批量任务的完整性
- 固定出参格式：

```
{
  "success": true/false,
  "data": {
    "crawled_pages": 10, // 实际爬取成功的页面数量
    "pages": [
      {
        "title": "页面标题",
        "url": "页面链接",
        "content": "页面正文",
        "metadata": "页面元数据"
      }
    ]
  },
  "error": "错误信息（success=false时返回）"
```

# 5.hermes联网搜索流程

## 5.1 单agent

### 5.1.1 链式协作

**核心链路**：`web_search` → `web_extract` → 二次`web_search` → 二次`web_extract` → ... → 结果整合

LLM 基于前一轮工具的执行结果，迭代优化搜索策略，完成多维度、深层次的信息采集与分析，适合需要层层深挖的复杂任务

### 5.1.2 并行联合调用

**核心链路**：单次 LLM 响应 → 并行调用多个`web_search`/`web_extract` → 结果合并 → 生成回答

同时执行多个独立的搜索 / 提取任务，无需串行等待，大幅缩短任务执行时间，适合多主体、多维度的信息对比场景。

对无依赖的并行安全工具，通过**ThreadPoolExecutor**创建线程池，并发执行多个工具调用，等待所有调用完成后统一处理结果

### 5.1.3 ProCode 批量协作

**核心链路**：LLM 生成 Python 执行脚本 → 脚本批量循环调用`web_search`+`web_extract` → 一次性返回全量结果

Hermes 基于`execute_code`工具实现的**程序化工具调用能力**，核心设计目标是让 LLM 生成 Python 脚本，通过沙箱 RPC 机制批量调用工具，把多步工具链压缩为**单次 LLM 交互**，进而实现批量联网搜索。
