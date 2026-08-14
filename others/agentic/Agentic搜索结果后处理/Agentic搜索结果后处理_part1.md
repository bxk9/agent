**日期**: 2026-04-20

**修改函数**: `tools/search_postprocess.py`

**参考内容**: `Open Claw search-layer/SKILL.md` v2.2 — OpenClaw意图感知多源检索协议

---

## **一、概述**

### **1.1 背景**

在 Vivo DeepAgents 深度研究 Agent 中，搜索引擎（火山联网搜索 + 百度搜索）返回的原始结果存在以下问题：

- **质量参差不齐**：低质量域名、黑名单站点混杂其中
- **排序不合理**：原始排序未考虑用户查询意图，新闻类查询可能排出过时结果
- **信息冗余**：大量结果全部展示会消耗 LLM 的上下文窗口，降低回答质量
- **缺乏置信度标识**：LLM 无法区分权威来源和普通来源

### **1.2 目标**

后处理模块的目标是：在搜索结果送入 LLM 生成回答之前，通过OpenClaw的 **意图感知的加权评分 + 分级知识合成**，让高质量、高相关的信息排在前面，并以结构化格式呈现给 LLM，从而提升最终回答的准确性和可信度。

### **1.3 架构**

```
用户提问
    ↓
┌─────────────────────────────────────────────────┐
│  main.py — LangGraph ReAct Agent                │
│    ↓ Agent 决策调用 ai_search 工具              │
│    ↓                                             │
│  ai_search.parallel_web_search()                │
│    ├─ 火山搜索 (ThreadPool 并行)                │
│    └─ 百度搜索 (ThreadPool 并行)                │
│    ↓ 去重后的原始搜索结果                        │
│    ↓                                             │
│  ai_search.formatted_knowledge()  ← 转发层      │
│    ↓ 注入 BLACKLIST_DOMAINS                      │
│    ↓                                             │
│  ┌─────────────────────────────────────────┐    │
│  │  search_postprocess.formatted_knowledge │    │
│  │  ┌───────────────────────────────────┐  │    │
│  │  │ Step 1: 意图分类                  │  │    │
│  │  │ Step 2: 黑名单过滤               │  │    │
│  │  │ Step 3: 意图加权评分 + 排序      │  │    │
│  │  │ Step 4: 分级知识合成             │  │    │
│  │  └───────────────────────────────────┘  │    │
│  └─────────────────────────────────────────┘    │
│    ↓ 结构化知识文本                              │
│    ↓                                             │
│  LLM 基于知识文本生成最终回答                    │
└─────────────────────────────────────────────────┘
    ↓
用户收到流式回答 + 参考链接
```

---

## **二、函数接口**

### **2.1 函数**

```python
# tools/search_postprocess.py
def formatted_knowledge(
    query,                    # str 或 List[str]，用户查询词（可能是搜索关键词列表）
    search_results,           # List[dict]，原始搜索结果
    idx,                      # int，参考资料起始编号（支持多轮累加）
    session_id,               # str，会话追踪 ID
    blacklist_domains=None,   # Optional[List[str]]，黑名单域名
) -> str                      # 返回格式化的知识文本
​
```

## **三、处理流程详解**

### **Step 1: 意图分类（Intent Classification）**

#### **3.1.1 原理**

不同类型的用户查询对搜索结果的质量维度要求不同：

- **新闻查询** → 新鲜度最重要（权重 0.6）
- **事实查询** → 权威性最重要（权重 0.5）
- **对比查询** → 关键词覆盖最重要（权重 0.4）

因此需要先判断查询意图，再决定评分权重。

#### **3.1.2 实现代码**

```python
# 意图类型 → (w_keyword, w_freshness, w_authority)
INTENT_WEIGHTS = {
    "factual":     (0.3, 0.2, 0.5),   # 权威优先
    "status":      (0.2, 0.5, 0.3),   # 新鲜度优先
    "comparison":  (0.4, 0.2, 0.4),   # 关键词+权威并重
    "tutorial":    (0.3, 0.2, 0.5),   # 权威优先
    "exploratory": (0.3, 0.2, 0.5),   # 默认均衡
    "news":        (0.2, 0.6, 0.2),   # 新鲜度最高
    "resource":    (0.5, 0.1, 0.4),   # 关键词优先
}
```

#### **3.1.3 分类算法**

采用**正则信号词匹配**，按优先级从高到低扫描：

| **优先级** | **意图** | **关键词（中文）** | **关键词（英文）** |
| --- | --- | --- | --- |
| 1 | News | 新闻、本周、今天、近期 | this week, news, announcement |
| 2 | Status | 最新、进展、现状、动态 | latest, update, status |
| 3 | Comparison | 对比、区别、比较、和…哪个好 | vs, versus, difference |
| 4 | Tutorial | 怎么做、如何、教程、步骤 | how to, tutorial, guide, step |
| 5 | Resource | 官网、官方、文档、下载 | GitHub, documentation, official |
| 6 | Factual | 什么是、是什么、定义、是谁 | what is, define, who is |
| 7 | Exploratory | 深入、了解、生态、概况 | overview, about, explore |

**匹配规则**：

1. 从优先级 1 开始扫描，**首个命中即返回**
2. 多个类型匹配时选最具体的（优先级高的排前面）
3. 无任何匹配 → 默认 `exploratory`

**代码实现**：

```python
def classify_intent(query: str) -> str:
    if not query:
        return "exploratory"
    q = query.lower()
    for intent, patterns in _INTENT_SIGNALS:
        for pat in patterns:
            if re.search(pat, q, re.IGNORECASE):
                return intent
    return "exploratory"
```

#### **3.1.4 示例**

| **用户查询** | **匹配信号词** | **判定意图** | **权重分配** |
| --- | --- | --- | --- |
| "最新张雪峰的新闻" | "最新" → status, "新闻" → news | **news**（优先级更高） | kw=0.2, fresh=0.6, auth=0.2 |
| "vivo X200 和 iPhone 16 哪个好" | "哪个好" → comparison | **comparison** | kw=0.4, fresh=0.2, auth=0.4 |
| "什么是大语言模型" | "什么是" → factual | **factual** | kw=0.3, fresh=0.2, auth=0.5 |
| "Python 异步编程教程" | "教程" → tutorial | **tutorial** | kw=0.3, fresh=0.2, auth=0.5 |
| "量子计算" | 无匹配 | **exploratory** | kw=0.3, fresh=0.2, auth=0.5 |

---

### **Step 2: 黑名单过滤(自己收集的)**

#### **3.2.1 原理**

某些域名的内容质量极差或包含误导信息，需要在评分前直接过滤。

#### **3.2.2 当前黑名单**

```python
BLACKLIST_DOMAINS = [
    "zuzuche.com",
    "https://www.gafei.com",
    "https://www.zhujiage.com.cn/post/312157.html"
]
```

---

### **Step 3: 意图加权评分**

#### **3.3.1 评分公式**

```
score = w_keyword × keyword_match + w_freshness × freshness_score + w_authority × authority_score
```

其中 `(w_keyword, w_freshness, w_authority)` 由 Step 1 的意图分类决定，三个权重之和为 1.0。

#### **3.3.2 关键词匹配分（keyword_match）**

**范围**: 0.0 - 1.0

**算法**：计算查询关键词在标题+正文中的覆盖率。

```python
def _keyword_match_score(query_words: list, title: str, content: str) -> float:
    if not query_words:
        return 0.5
    text = (title + " " + content).lower()
    matched = sum(1 for w in query_words if w.lower() in text)
    return matched / len(query_words)
```

**关键词提取策略**：

- 若 `query` 是列表（如 `["vivo X200 评测", "vivo X200 配置"]`）：
  - 按空格拆分每个子查询，过滤长度 ≤1 的词
  - 同时将每个完整子查询作为关键词（覆盖中文连续匹配）
- 若 `query` 是字符串：
  - 按空格拆分 + 将整体作为关键词
- 最后去重

**示例**：

```
query = ["最新张雪峰新闻", "张雪峰 最近动态"]
→ query_words = ["最新张雪峰新闻", "张雪峰", "最近动态", "最近", "动态"]
​
结果标题 = "张雪峰回应高考志愿争议"
结果正文 = "近日张雪峰在直播中回应了..."
​
匹配: "张雪峰"✓, "最新张雪峰新闻"✗, "最近动态"✗, "最近"✗, "动态"✗
→ keyword_match = 1/5 = 0.2
```

#### **3.3.3 新鲜度分（freshness_score）**

**范围**: 0.0 - 1.0

**算法**：基于发布时间与当前时间的差值，分级打分。

| **时间差** | **分数** | **含义** |
| --- | --- | --- |
| ≤ 1 天 | 1.0 | 极新 |
| ≤ 7 天 | 0.9 | 很新 |
| ≤ 30 天 | 0.7 | 较新 |
| ≤ 90 天 | 0.5 | 一般 |
| ≤ 365 天 | 0.3 | 较旧 |
| > 365 天 | 0.1 | 很旧 |
| 无日期 | 0.5 | 默认中间值 |

**时间格式兼容**：支持 `%Y-%m-%dT%H:%M:%S`、`%Y-%m-%d %H:%M:%S`、`%Y-%m-%d` 等格式，自动去除时区后缀。

```python
def _freshness_score(publish_time_str: str) -> float:
    if not publish_time_str:
        return 0.5
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d", ...):
        try:
            pub_dt = datetime.strptime(cleaned_str, fmt)
            break
        except ValueError:
            continue
    days_ago = (datetime.now() - pub_dt).days
    # 分级返回
```

#### **3.3.4 权威度分（authority_score）**

**范围**: 0.0 - 1.0

**数据来源**：`search-layer/references/authority-domains.json`

##### **四级域名分类**

| **等级** | **分数** | **代表域名** | **说明** |
| --- | --- | --- | --- |
| **Tier 1** | 1.0 | github.com, stackoverflow.com, wikipedia.org, developer.mozilla.org, arxiv.org | 官方文档、权威平台 |