## 1. 概述

Claude Code 通过两个内置工具实现联网信息获取：

| 工具 | 定位 | 一句话描述 |
| --- | --- | --- |
| **WebSearch** | 搜索未知信息 | 调用 Anthropic 服务端搜索能力，返回搜索结果摘要和链接 |
| **WebFetch** | 获取已知 URL 的内容 | 抓取指定网页，将 HTML 转为 Markdown，用 Haiku 小模型提取关键信息 |

两者的协作模式是**纯模型自主涌现**的——没有任何编排代码或提示词指导它们配合。模型在 agentic loop 中看到搜索结果里的 URL，自行决定是否需要用 WebFetch 深入获取内容。

---

## 2. WebSearch 工具：联网搜索

### 2.1 输入与输出

**输入**：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `query` | string（≥2字符） | 是 | 搜索关键词 |
| `allowed_domains` | string[] | 否 | 白名单：只返回这些域名的结果 |
| `blocked_domains` | string[] | 否 | 黑名单：排除这些域名（与白名单互斥） |

**输出**（返回给主模型的文本格式）：

```plaintext
Web search results for query: "React 19 new features"

React 19 introduces a new compiler, Server Components...（子模型生成的文字摘要）

Links: [{"title":"React 19 Blog","url":"https://react.dev/blog/react-19"}, ...]

REMINDER: You MUST include the sources above in your response to the user
using markdown hyperlinks.
```

### 2.2 搜索关键词是怎么来的

搜索词（query）**完全由主模型自主生成**，用户不参与构造过程。

例如，用户问"最新的 React 有什么新特性"，主模型可能生成：

```json
{ "name": "WebSearch", "input": { "query": "React 19 new features 2026" } }
```

模型在构造 query 时，受以下系统提示词引导：

| 引导内容 | 来源 | 作用 |
| --- | --- | --- |
| `"Use this tool for accessing information beyond Claude's knowledge cutoff"` | 工具描述 | 告诉模型何时该搜索 |
| `"The current month is April 2026. You MUST use this year when searching"` | 工具描述（动态注入当前月份） | 确保搜索词包含正确年份 |
| `"Assistant knowledge cutoff is August 2025"` | 系统提示词 | 让模型知道哪些信息在自己知识范围外 |
| `"Date: 2026-04-16"` | 系统提示词 | 提供当前日期的时间语境 |

### 2.3 搜索执行流水线

WebSearch 的执行不是简单地调一个搜索 API——它在内部启动了一个**微型 ReAct Agent**，让一个子模型自主规划和执行搜索。

#### 整体架构

```plaintext
用户提问 → 主模型生成 WebSearch({ query: "..." })
                         │
                         ▼
               WebSearchTool.call()
                         │
            ┌────────────┴────────────────────┐
            │  启动微型 ReAct Agent             │
            │                                  │
            │  角色: "搜索助手"                  │
            │  任务: "搜索: <query>"            │
            │  唯一装备: web_search 服务端工具    │
            │                                  │
            │  Agent 自主循环:                   │
            │    思考 → 搜索 → 观察结果           │
            │    → 再思考 → 再搜索(可选)          │
            │    → ... (最多8轮)                 │
            │    → 输出最终文字摘要               │
            └────────────┬────────────────────┘
                         │
                         ▼
              格式化为 tool_result 返回给主模型
              (文字摘要 + URL 链接列表)
```

可以把它理解为一个极简的 ReAct Agent：

- **系统提示**：`"You are an assistant for performing a web search tool use"`
- **用户消息**：`"Perform a web search for the query: React 19 new features"`
- **工具箱只有一件**：Anthropic 服务端的 `web_search` 工具（最多可调用 8 次）
- **无其他工具**：`tools: [web_search_20250305]`——这个 Agent 除了搜索什么也不能做

这个微型 Agent 会自主决定：搜几次、每次用什么搜索词、何时停止。例如面对 query "React 19 new features"，它可能：

```plaintext
[思考] 我需要搜索 React 19 的新特性
[搜索] web_search({ query: "React 19 new features" })
[观察] 得到 10 条结果，但没有关于 breaking changes 的信息
[思考] 用户可能也想知道 breaking changes，补充搜一次
[搜索] web_search({ query: "React 19 breaking changes migration" })
[观察] 得到 8 条结果，信息足够了
[输出] 综合两次搜索结果的文字摘要
```

#### 服务端搜索工具 `web_search_20250305`

`web_search` 是 Anthropic 提供的**闭源服务端工具**——与 BashTool 等客户端工具不同，客户端不需要执行任何操作，API 服务端收到调用后自动执行搜索并将结果嵌入响应流中返回。

**输入**——客户端注册工具时传入的参数：

```json
{
  "type": "web_search_20250305",
  "name": "web_search",
  "max_uses": 5,
  "allowed_domains": ["react.dev"],
  "blocked_domains": [],
  "user_location": { "type": "approximate", "country": "US" }
}
```

`max_uses` 限制单次请求的最大搜索次数（Claude Code 中硬编码为 8），`user_location` 可用于本地化搜索结果。

**输出**——以"Claude Shannon 的出生日期"为例，一次搜索的响应中包含以下 content blocks 序列：

```plaintext
text:                  "I'll search for when Claude Shannon was born."
server_tool_use:       { query: "claude shannon birth date" }
web_search_tool_result: [{ url, title, page_age, encrypted_content }, ...]
text + citations:      "Claude Shannon was born on April 30, 1916..."
                        cited_text: "Claude Elwood Shannon (April 30, 1916 – ...)"
```

每条搜索结果包含 `url`、`title`、`page_age`（页面更新时间）、`encrypted_content`（加密内容，用于多轮对话维持引用）。模型生成的回答文本会自动附带 `citations`，其中 `cited_text` 包含最多 150 字符的原文片段。

如果子模型决定搜多次，`server_tool_use → web_search_tool_result → text` 的模式会重复出现。搜索失败时返回错误对象（如 `{ error_code: "max_uses_exceeded" }`）而非结果数组。

**新版本 **`**web_search_20260209**`：支持**动态过滤**——子模型可以编写代码对搜索结果进行后处理，只保留相关内容，减少 token 消耗。需配合代码执行工具使用。Claude Code 源码中使用的仍是旧版 `web_search_20250305`。

#### 流式结果处理

客户端在流式接收过程中实时提取进度信息：

- 从部分 JSON 流中用正则提取搜索词 → 终端显示 `"Searching: React 19 features"`
- 收到搜索结果块时 → 终端显示 `"Found 10 results for 'React 19 features'"`

最终，所有 content blocks 被汇总，提取 `{title, url}` 对和文字摘要，格式化为 tool_result 返回给主模型。

---

## 3. WebFetch 工具：网页内容获取

### 3.1 输入与输出

**输入**：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `url` | string | 要抓取的网页地址 |
| `prompt` | string | 告诉工具要从页面中提取什么信息 |

例如：`WebFetch({ url: "https://react.dev/blog/react-19", prompt: "Extract all new features and breaking changes" })`

**输出**：经过 Haiku 小模型处理后的提取结果文本，或预批准域名的原始 Markdown 内容。

### 3.2 内容获取与提取流水线

```plaintext
URL + prompt
    ↓
[Cache hit?] → return cached            ← 15分钟TTL, 50MB上限
    ↓
[Fetch]                                  ← 自动HTTP→HTTPS, 60s超时, 10MB上限
    ↓
[HTML?] → Turndown → Markdown
    ↓
[Trusted + Content-Type: text/markdown + <100k?] → use directly
    ↓
[Otherwise] → small model extracts relevant info
    ↓
[Cache result]
    ↓
[Return to Claude]
```

几个关键环节：

**Cache**：相同 URL 在 15 分钟内重复访问直接走缓存，避免重复抓取和 Haiku 调用。

**Fetch**：HTTP 自动升级为 HTTPS。重定向仅在同主机内自动跟随（最多 10 跳），跨主机重定向不自动跟随——工具会返回提示信息，让模型自行决定是否用新 URL 重新调用。

**Trusted（预批准域名）**：约 80 个编程相关域名（如 `react.dev`、`docs.python.org`、`developer.mozilla.org`、`docs.aws.amazon.com`）无需用户确认即可访问。如果内容是 Markdown 且小于 10 万字符，直接返回原文，不经过 Haiku 处理。

**Small model extracts**：绝大多数情况下，抓取的网页会经过 Haiku 小模型二次处理——将截断到 10 万字符的 Markdown 内容 + 用户的 prompt 一起发给 Haiku，由它提取关键信息。例如一个 3 万字的技术文档，经 Haiku 处理后可能返回几百字的精炼摘要。

对于非预批准域名，还有版权保护限制：Haiku 的引用上限为 125 字符。

---

## 4. WebSearch 与 WebFetch 的协作

### 4.1 协作模式：纯模型自主涌现

两个工具之间**没有任何显式编排**：

- 无编排代码：两个工具模块完全独立，零交叉引用
- 无提示词引导：没有任何文本告诉模型"搜索之后要抓取"
- 唯一的桥梁是**数据格式**：WebSearch 结果中包含原始 URL，主模型看到后自行决定是否调用 WebFetch

### 4.2 完整示例

以用户提问"React 19 有哪些新特性？帮我详细介绍"为例：

**第 1 轮——搜索**：主模型判断该信息可能超出知识截止日期，调用 WebSearch

```plaintext
→ WebSearch({ query: "React 19 new features 2026" })
← 返回摘要 + Links: [{"title":"React 19 Blog","url":"https://react.dev/blog/react-19"}, ...]
```

**第 2 轮——深入获取**：主模型认为搜索摘要不够详细，看到 `react.dev`（预批准域名）的 URL，决定调用 WebFetch

```plaintext
→ WebFetch({
    url: "https://react.dev/blog/react-19",