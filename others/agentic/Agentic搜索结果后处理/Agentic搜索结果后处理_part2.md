| **Tier 2** | 0.8 | news.ycombinator.com, reddit.com, dev.to, openai.com, huggingface.co | 高质量社区 |
| **Tier 3** | 0.6 | medium.com, zhihu.com, juejin.cn, techcrunch.com, infoq.com | 内容平台 |
| **Tier 4** | 0.4 | 其他所有域名 | 默认分 |

_AUTHORITY_CACHE : {'[github.com](http://github.com)': 1.0, '[gitlab.com](http://gitlab.com)': 1.0, '[stackoverflow.com](http://stackoverflow.com)': 1.0, '[wikipedia.org](http://wikipedia.org)': 1.0, '[arxiv.org](http://arxiv.org)': 1.0, '[docs.python.org](http://docs.python.org)': 1.0, '[docs.rs](http://docs.rs)': 1.0, '[doc.rust-lang.org](http://doc.rust-lang.org)': 1.0, '[developer.mozilla.org](http://developer.mozilla.org)': 1.0, '[developer.apple.com](http://developer.apple.com)': 1.0, '[developer.android.com](http://developer.android.com)': 1.0, '[cloud.google.com](http://cloud.google.com)': 0.8, '[docs.aws.amazon.com](http://docs.aws.amazon.com)': 1.0, '[learn.microsoft.com](http://learn.microsoft.com)': 1.0, '[react.dev](http://react.dev)': 1.0, '[vuejs.org](http://vuejs.org)': 1.0, '[nodejs.org](http://nodejs.org)': 1.0, '[go.dev](http://go.dev)': 1.0, '[kotlinlang.org](http://kotlinlang.org)': 1.0, '[typescriptlang.org](http://typescriptlang.org)': 1.0, '[swift.org](http://swift.org)': 1.0, '[docs.docker.com](http://docs.docker.com)': 1.0, '[kubernetes.io](http://kubernetes.io)': 1.0, '[www.rust-lang.org](http://www.rust-lang.org)': 1.0, '[rust-lang.org](http://rust-lang.org)': 1.0, '[tc39.es](http://tc39.es)': 1.0, '[www.w3.org](http://www.w3.org)': 1.0, '[datatracker.ietf.org](http://datatracker.ietf.org)': 1.0, '[peps.python.org](http://peps.python.org)': 1.0, '[crates.io](http://crates.io)': 1.0, '[pypi.org](http://pypi.org)': 1.0, '[npmjs.com](http://npmjs.com)': 1.0, '[pkg.go.dev](http://pkg.go.dev)': 1.0, '[news.ycombinator.com](http://news.ycombinator.com)': 0.8, '[lobste.rs](http://lobste.rs)': 0.8, '[stackexchange.com](http://stackexchange.com)': 0.8, '[serverfault.com](http://serverfault.com)': 0.8, '[superuser.com](http://superuser.com)': 0.8, '[askubuntu.com](http://askubuntu.com)': 0.8, '[reddit.com](http://reddit.com)': 0.8, '[dev.to](http://dev.to)': 0.8, '[css-tricks.com](http://css-tricks.com)': 0.8, '[smashingmagazine.com](http://smashingmagazine.com)': 0.8, '[web.dev](http://web.dev)': 0.8, '[blog.cloudflare.com](http://blog.cloudflare.com)': 0.8, '[engineering.fb.com](http://engineering.fb.com)': 0.8, '[netflixtechblog.com](http://netflixtechblog.com)': 0.8, '[aws.amazon.com](http://aws.amazon.com)': 0.8, '[openai.com](http://openai.com)': 0.8, '[anthropic.com](http://anthropic.com)': 0.8, '[huggingface.co](http://huggingface.co)': 0.8, '[papers.nips.cc](http://papers.nips.cc)': 0.8, '[aclanthology.org](http://aclanthology.org)': 0.8, '[distill.pub](http://distill.pub)': 0.8, '[medium.com](http://medium.com)': 0.6, '[towardsdatascience.com](http://towardsdatascience.com)': 0.6, '[freecodecamp.org](http://freecodecamp.org)': 0.6, '[baeldung.com](http://baeldung.com)': 0.6, '[digitalocean.com](http://digitalocean.com)': 0.6, '[tutorialspoint.com](http://tutorialspoint.com)': 0.6, '[geeksforgeeks.org](http://geeksforgeeks.org)': 0.6, '[realpython.com](http://realpython.com)': 0.6, '[hackernoon.com](http://hackernoon.com)': 0.6, '[infoq.com](http://infoq.com)': 0.6, '[thenewstack.io](http://thenewstack.io)': 0.6, '[techcrunch.com](http://techcrunch.com)': 0.6, '[arstechnica.com](http://arstechnica.com)': 0.6, '[theverge.com](http://theverge.com)': 0.6, '[wired.com](http://wired.com)': 0.6, '[36kr.com](http://36kr.com)': 0.6, '[sspai.com](http://sspai.com)': 0.6, '[juejin.cn](http://juejin.cn)': 0.6, '[segmentfault.com](http://segmentfault.com)': 0.6, '[cnblogs.com](http://cnblogs.com)': 0.6, '[zhihu.com](http://zhihu.com)': 0.6}

##### **模式规则（Pattern Rules）**

除精确域名匹配外，还支持通配符模式：

| **模式** | **分数** | **说明** |
| --- | --- | --- |
| `docs.*` | 0.9 | 任何 docs. 开头的子域名（通常是官方文档） |
| `*.github.io` | 0.7 | GitHub Pages 项目站点 |
| `blog.*` | 0.6 | 官方技术博客 |
| `*.edu` | 0.8 | 教育机构 |
| `*.gov` | 0.8 | 政府网站 |

##### **匹配优先级**

```
1. 精确匹配（如 github.com）
2. 去 www 后匹配（如 www.github.com → github.com）
3. 后缀匹配（如 docs.python.org → python.org 命中 Tier 1）
4. 模式规则匹配（如 docs.spring.io 命中 docs.* 模式）
5. 均未命中 → 返回 Tier 4 默认分 0.4
```

#### **3.3.5 综合评分示例**

以 **新闻意图** 查询 "最新张雪峰的新闻" 为例：

| **结果** | **keyword** | **freshness** | **authority** | **综合分** |
| --- | --- | --- | --- | --- |
| 张雪峰直播回应（zhihu.com, 1天前） | 0.4 | 1.0 | 0.6 | 0.2×0.4 + 0.6×1.0 + 0.2×0.6 = **0.80** |
| 张雪峰学历观点（baidu.com, 30天前） | 0.3 | 0.7 | 0.4 | 0.2×0.3 + 0.6×0.7 + 0.2×0.4 = **0.56** |
| 高考志愿填报指南（edu.cn, 365天前） | 0.1 | 0.3 | 0.8 | 0.2×0.1 + 0.6×0.3 + 0.2×0.8 = **0.36** |

排序后：知乎新鲜结果排第一 → 百度较新结果排第二 → 旧教育站排第三。

#### **3.3.5 降序排序**

```python
scored_results = [(score_result(res, query_words, intent), res) for res in filtered_results]
scored_results.sort(key=lambda x: x[0], reverse=True)  # 降序
```

---

### **Step 4: 分级知识合成**

根据过滤+评分后的结果数量，选择不同的输出策略，核心目标是 **在有限的 LLM 上下文窗口内最大化信息价值**。

**最多取50条知识**

#### **3.4.1 小结果集（≤5 条）**

**策略**：逐条完整展示，每条附带评分和权威标签。

**输出格式**：

```
[意图: news | 共 3 条结果，按相关性排序]
​
【参考资料1】 综合评分:0.80 ⭐权威
标题：张雪峰直播回应高考志愿争议
正文：（完整正文内容）
发布时间：2026-04-19
链接：https://zhihu.com/...
---
【参考资料2】 综合评分:0.56
标题：张雪峰近期学历观点汇总
正文：（完整正文内容）
发布时间：2026-03-20
链接：https://baidu.com/...
---
```

**权威标签规则**：域名权威分 ≥ 0.8 时显示 `⭐权威`。

#### **3.4.2 中结果集（6-15 条）**

**策略**：高分结果完整展示（≥ 0.6 分），低分结果仅展示标题 + 前 200 字摘要。

**输出格式**：

```
[意图: status | 共 12 条结果，按相关性排序，高相关(≥0.6)详细展示，低相关精简展示]
​
【参考资料1】 综合评分:0.85 ⭐权威
标题：...
正文：（完整正文）
发布时间：...
链接：...
---
【参考资料8】 评分:0.45
标题：...
摘要：（前200字截断）
链接：...
---
```

**设计意图**：减少低质量内容对 LLM 上下文的占用，同时保留其标题供 LLM 判断是否需要更多信息。

#### **3.4.3 大结果集（16+ 条）**

**策略**：Top 10 详细展示 + 其余精简为一行标题摘要 + 尾部概览提示。

**输出格式**：

```
[意图: exploratory | 共 28 条结果，展示 Top 10 详细 + 其余精简]
​
【参考资料1】 综合评分:0.92 ⭐权威
标题：...
正文：（完整正文）
...
---
【参考资料11】 评分:0.48
量子计算最新进展 | https://example.com/...
摘要：（前150字截断）
---
​
[共检索到 28 条结果，以上按意图「exploratory」加权评分排序，高分结果优先展示。请基于以上信息综合分析并回答用户问题。]
```

#### **3.4.4 分级阈值汇总**

| **结果数** | **高分展示** | **低分展示** | **Top N** | **尾部提示** |
| --- | --- | --- | --- | --- |
| ≤ 5 | 全部完整 | — | — | 无 |
| 6-15 | 评分 ≥ 0.6 完整 | 标题+200字摘要 | — | 无 |
| 16+ | Top 10 完整 | 标题+150字摘要 | 10 | 有概览提示 |

---

## **四、外部依赖**

### **4.1 权威域名配置文件**

**路径**: `search-layer/references/authority-domains.json`

```json
{
  "tier1": { "score": 1.0, "domains": ["github.com", "stackoverflow.com", ...] },
  "tier2": { "score": 0.8, "domains": ["news.ycombinator.com", "dev.to", ...] },
  "tier3": { "score": 0.6, "domains": ["medium.com", "zhihu.com", ...] },
  "tier4_default_score": 0.4,
  "pattern_rules": [
    {"pattern": "docs.*", "score": 0.9},
    {"pattern": "*.github.io", "score": 0.7},
    {"pattern": "*.edu", "score": 0.8}
  ]
}
```

**维护方式**：直接编辑 JSON 文件即可，模块首次调用时加载并缓存，重启服务生效。

---

## **七、完整处理流程图**

```
                    ┌──────────────────┐
                    │   原始搜索结果    │
                    │                  │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │  Step 1: 意图分类 │
                    │  classify_intent  │
                    │  输入: query      │
                    │  输出: intent     │
                    │  (7种意图之一)    │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │  提取查询关键词   │
                    │  query → words   │
                    │  (空格拆分+去重) │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ Step 2: 黑名单   │
                    │ 过滤命中域名     │
                    │ (子串匹配)       │
                    └────────┬─────────┘