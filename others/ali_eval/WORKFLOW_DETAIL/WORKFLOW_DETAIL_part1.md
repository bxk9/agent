# search_eval 工作详解文档

> 本文档是对 `search_eval` 评测项目的完整技术解读，面向需要深入理解每个模块设计意图和实现细节的开发者。

---

## 一、项目背景

### 1.1 为什么需要这个评测

`interview_agent` 项目中有两套搜索方案可供选择：

| 方案 | 机制 | 特点 |
|------|------|------|
| **多引擎路由** | 调用 `search_engines.search()` 多引擎并发搜索 → RRF 融合排序 → LLM（Doubao-Seed-2.0-pro）总结生成答案 | 可控、可溯源、结构化引用 |
| **qwen3.6-agent** | qwen3.6 模型内置搜索能力，Agent 自主决定是否搜索、搜什么、搜几次 | 黑盒搜索、纯文本输出、部署简单 |

团队需要用数据回答：**在求职面试/简历优化场景下，哪套方案的答案质量更高、性能更好？** 这决定了后续产品的技术选型。

### 1.2 评测范围约束

- **单轮评测**：每条 query 只取第一轮回复，不涉及多轮对话
- **仅 D5 + D6**：只对比答案质量（D5）和性能鲁棒性（D6），不涉及 D1~D4（召回量、RankScore、时效性、URL 多样性），因为 qwen3.6-agent 返回纯文本无法获取结构化搜索结果
- **不做归一化**：两方案对比用原始值 + 统计检验，不做 min-max 归一化（2 方案归一化会极端化为 0 vs 100，结论失真）

---

## 二、数据集设计

### 2.1 三套数据集

| 文件 | 条数 | 用途 |
|------|:---:|------|
| `datasets/search_eval_queries_50.xlsx` | 50 | 冒烟测试，快速验证流程 |
| `datasets/search_eval_queries_100.xlsx` | 100 | 中等规模验证 |
| `datasets/search_eval_queries_300.xlsx` | 300 | 全量评测，得出可靠结论 |

50 条是 300 条的子集，100 条也应是 300 条的子集。

### 2.2 xlsx 列结构

数据集 xlsx 的列头为中文，代码通过 `COLUMN_MAP` 映射为内部字段：

| xlsx 列头 | 内部字段 | 说明 |
|-----------|---------|------|
| `ID` | `id` | 唯一标识 |
| `类别` | `category` | 简历优化 → `resume_opt` / 面试准备 → `interview_prep` |
| `用户Query` | `query` | 用户输入文本 |
| `目标公司` | `company` | 可为空 |
| `目标岗位` | `position` | 可为空 |
| `一级行业` | `industry` | 10 个行业 |
| `二级行业` | `sub_industry` | 细分行业 |
| `简历文件` | `resume_file` | 仅 `resume_opt` 类有值 |
| `搜索复杂度` | `search_complexity` | `single` / `multi` / `incremental` |
| `单轮预期产出` | `single_round_output` | 校验单轮可用性 |

### 2.3 数据配比

- 按 **场景**：简历优化 150 条 + 面试准备 150 条 = 300 条
- 按 **复杂度**：single 144 条 + multi 120 条 + incremental 36 条 = 300 条
- 按 **行业**：互联网/科技 60 条，金融/制造业/医疗等各 24~36 条，覆盖 10 个行业

---

## 三、流水线详解

### 3.1 整体架构

```
Phase 0          Phase 1a           Phase 1b          Phase 2        Phase 3
数据集加载  →  方案调用+答案采集  →  LLM Judge 评分  →  指标计算  →  报告生成
（纯本地）     （需 LLM/Agent API）  （需 LLM API）    （纯本地）    （纯本地）
                    │                    │
                    └── 采集与评分解耦 ──┘
                    P1a 只存原始答案
                    P1b 独立运行可重跑
```

**核心设计原则：采集与评分解耦**

Phase 1a 是最昂贵的阶段（调用外部 API 采集答案），应该一次跑完永久保留。Phase 1b 只调 LLM 做评分，成本低，当评分标准（prompt、维度、阈值）变化时可随时重跑而不需重新采集答案。

### 3.2 Phase 0：数据集加载

**文件**：`phase0_dataset.py`（145 行）

**流程**：
1. `load_dataset(filepath)` 读取 xlsx（通过 `common.read_xlsx`）
2. 逐行 `_parse_row()` 解析字段：中文列头 → 内部字段名，category 中文值 → `resume_opt`/`interview_prep`
3. `_validate_row()` 校验必填字段（query/category/industry/search_complexity/single_round_output）和有效值
4. 生成 `query_id`（格式 `q0001`）
5. `save_queries()` 输出 `queries.xlsx` 到运行目录

**关键设计**：
- 校验失败只 `log.warning` 不中断（容错策略，允许个别行有问题不阻塞整体）
- `id` 缺失时用行号兜底
- `category` 值不匹配映射表时 `.lower()` 兜底

### 3.3 Phase 1a：方案调用 + 答案采集

**文件**：`phase1a_collect.py`（169 行）

**流程**：
1. `run_phase1a()` 接收任务列表，按 `schemes` 参数决定跑哪些方案（默认 `["multi", "qwen"]`）
2. 对每个方案调用 `_collect_scheme()`，逐条 query 调用对应 caller
3. 每条结果构建为 P1a 行，`append_xlsx_rows()` 追加写入 `P1a_{scheme}.xlsx`

**P1a xlsx 列结构**（26 列）：

```
query_id, query, scheme, category, industry, sub_industry,
company, position, search_complexity,
answer, references, success, error,
elapsed_ms, server_ms, network_ms, ttft_ms, timestamp,
overall, accuracy, completeness, relevance, remark, scored_at
```

前 18 列由 Phase 1a 填充，后 6 列（scores）由 Phase 1b 填充。

**断点续跑机制**：
- 每条 query 采集前检查 `xlsx_has_row(xlsx_path, "query_id", query_id)`
- 已存在则跳过（`--force` 时先删除文件重来）
- 逐行追加写入，即使中途崩溃已采集数据不丢失

**multi 方案调用**（`callers/multi_engine_caller.py`，138 行）：

```python
# Step 1: 多引擎搜索
results = search(intent="通用", query=query, timeout=6.0)
# → 调用 app.tools.search_engines.search()，触发 volc 引擎

# Step 2: LLM 总结
prompt = SUMMARY_PROMPT.format(query, search_context, references)
llm = build_chat_model()  # Doubao-Seed-2.0-pro
answer = llm.invoke(prompt).content
```

- `_format_search_context()`：将搜索结果格式化为 `[1] 标题\n    内容[:300]` 的文本，最多 20 条
- `_extract_references()`：提取 Title/Url/SiteName/FusionScore（作为 AttributionScore）
- 搜索失败或 LLM 失败都有独立的 error 处理，不会崩溃

**qwen 方案调用**（`callers/qwen_agent_caller.py`，92 行）：

```python
# SSE 流式调用
rsp = requests.post(url, json=data, stream=True, timeout=120)
for line in rsp.iter_lines():
    if d.startswith("data:"):
        obj = json.loads(d[5:])
        full_text += obj.get("message") or ""
```

- `enable_thinking=True`：让模型充分思考后再搜索，答案质量更高但耗时更长
- 返回纯文本，无 references
- `server_ms` / `network_ms` 为 `None`（SSE 流式无法精确拆分）

### 3.4 Phase 1b：LLM Judge 评分

**文件**：`phase1b_score.py`（86 行）

**流程**：
1. 对 `multi` 和 `qwen` 两个方案分别处理
2. 读取 `P1a_{scheme}.xlsx`，逐行检查是否已有评分
3. answer 为空 → 标记 `overall=-1`，跳过 LLM 调用
4. answer 非空 → 调用 `judge.score_answer(query, answer)` 获取多维度评分
5. 将评分写回 xlsx 的 scores 列

**重跑策略**：
- `--force`：清空所有已有评分，全部重新打分
- 不带 `--force`：跳过已有有效评分（overall ≥ 0）的行
- 非有效数字（如空字符串）的行会被重新评分

**LLM Judge 模块**（`judge.py`，148 行）：

- 模型：`Doubao-Seed-2.0-pro`（文档中写的是 lite，代码实际用 pro）
- 温度：0.1（低温度保证评分一致性）
- 评分维度：overall / accuracy / completeness / relevance（各 0/1/2）+ remark
- Prompt 结构：评分标准 → 场景说明 → 输出格式 → 问题 → 回答 → 历史对话
- 重试：最多 2 次，指数退避（1s, 2s）
- 失败返回 `overall=-1`，不阻塞流水线

**评分标准核心**：
- 如果回答是"确认卡"或"追问"（如"请补充岗位级别"），overall 应为 0
- 重点关注：是否基于真实搜索信息（非编造）、是否针对具体公司/岗位、面试题/薪资数据是否合理

### 3.5 Phase 2：指标计算 + 统计检验

**文件**：`phase2_metrics.py`（491 行）

#### D5 答案质量指标（`_calc_d5_metrics`）

| 指标 | 计算方式 | 说明 |
|------|---------|------|
| 满意率 | `N(overall==2) / N_valid` | 完全正确的占比 |
| 不满意率 | `N(overall==0) / N_valid` | 完全翻车的占比 |
| 加权平均分 | `(2×N₂ + 1×N₁) / N_valid` | 范围 0~2 |
| 事实准确率 | `mean(accuracy) / 2` | 归一化到 0~1 |
| 完整度得分 | `mean(completeness) / 2` | 归一化到 0~1 |
| 相关性得分 | `mean(relevance) / 2` | 归一化到 0~1 |
| 单轮可用率 | `N(answer非空) / N_total` | 排除确认卡/追问 |
| 溯源覆盖率 | `count(AttributionScore≥0.5) / N_refs` | 仅 multi 可用 |
| 平均答案长度 | `mean(len(answer))` | 仅参考，不纳入对比 |

> `N_valid` = overall ≥ 0 的行数（排除评分失败 -1 和空值）

#### D6 性能指标（`_calc_d6_metrics`）

| 指标 | 计算方式 | 说明 |
|------|---------|------|
| 成功率 | `N(success) / N_total` | success 字段为 True |
| 超时率 | `N(elapsed_ms ≥ 阈值) / N_total` | qwen 阈值 120s，multi 阈值 60s |
| P50/P95/P99 耗时 | `percentile(elapsed_ms, p)` | 线性插值百分位 |
| 耗时标准差 | `stdev(elapsed_ms)` | 延迟稳定性 |

#### 胜率计算（`_calc_win_rate`）

1. 按 `query_id` 配对两方案的 overall 评分
2. 对每个共同 query_id：multi > qwen → 胜，= → 平，< → 败
3. 胜率 = `N_win / N_common`
4. Mann-Whitney U 检验（依赖 scipy，未安装则跳过）
5. Cliff's delta 效应量（自有实现，不依赖外部库）

#### 判定结论（`_make_conclusion`）

```
if p < 0.05:
    if multi 在胜率+满意率+准确率均领先 → "多引擎路由胜出"
    elif qwen 在三项均领先 → "qwen3.6-agent 胜出"
    else → "各有优劣"
else:
    → "无显著差异"
```

#### 分场景统计

- 按 `category`（简历优化 / 面试准备）
- 按 `industry`（10 个行业）
- 按 `search_complexity`（single / multi / incremental）

每个分组分别计算 D5 指标，输出到独立 Sheet。

#### 输出文件

`P2_metrics.xlsx` 包含 6 个 Sheet：
1. **总览**：所有指标对比 + p 值 + 显著性 + 判定结论