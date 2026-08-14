                return {"overall": -1, "accuracy": -1, "completeness": -1, "relevance": -1, "remark": f"打分失败: {e}"}
    
    return {"overall": -1, "accuracy": -1, "completeness": -1, "relevance": -1, "remark": "重试耗尽"}
```

**优势**：
- 无外部依赖，直接复用主项目的 LLM 配置（`VIVO_APP_ID`/`VIVO_APP_KEY`）
- 可定制评分标准（针对简历优化/面试准备场景）
- 响应速度快（单次 LLM 调用 ~2-3 秒，300 条 × 2 方案 ≈ 30-60 分钟）
- 评分逻辑透明（prompt 可控）
- 低温度（0.1）保证评分一致性

#### qwen3.6-agent 调用方式

基于项目已有的测试代码（`test/search/test_raw_qwen3.py` 和 `test/search/test_qwen3_web_search.py`）：

```python
import requests, uuid, json, os, time
from app.llm.vivo_chat import _gen_sign_headers

APP_ID = os.environ.get("VIVO_APP_ID", "3319785895")
APP_KEY = os.environ.get("VIVO_APP_KEY", "...")
DOMAIN = os.environ.get("VIVO_DOMAIN", "chatgpt-api-pre.vmic.xyz")
MODEL = "qwen3.6-agent"

def call_qwen_agent(query: str, system_prompt: str = "") -> dict:
    """调用 qwen3.6-agent，返回 {answer, elapsed_ms, server_ms, error}"""
    params = {"requestId": str(uuid.uuid4())}
    data = {
        "sessionId": str(uuid.uuid4()),
        "provider": "vivo",
        "model": MODEL,
        "incremental": True,
        "messages": [
            {"content": system_prompt or "你是求职面试助手，擅长搜索和整理面试信息", "role": "system"},
            {"content": query, "role": "user"}
        ],
        "extra": {"chat_template_kwargs": {"enable_thinking": True}}
    }
    headers = _gen_sign_headers(APP_ID, APP_KEY, "POST", "/chatgpt/completions/stream", params)
    url = f"http://{DOMAIN}/chatgpt/completions/stream"
    
    t0 = time.time()
    full_text = ""
    error = None
    try:
        rsp = requests.post(url, json=data, headers=headers, params=params, stream=True, timeout=120)
        for line in rsp.iter_lines():
            if not line:
                continue
            d = line.decode("utf-8", "replace")
            if d.startswith("data:"):
                try:
                    obj = json.loads(d[5:])
                    t = obj.get("message") or ""
                    if t:
                        full_text += t
                except:
                    pass
        elapsed_ms = (time.time() - t0) * 1000
    except Exception as e:
        error = str(e)
        elapsed_ms = (time.time() - t0) * 1000
    
    return {
        "answer": full_text,
        "elapsed_ms": elapsed_ms,
        "server_ms": None,   # SSE 流式，无法精确拆分服务端耗时
        "network_ms": None,  # 同上
        "error": error
    }
```

**注意**：
- qwen3.6-agent 是 SSE 流式接口，默认 `enable_thinking=True` 让模型充分思考后再搜索，提高答案质量；若耗时过长可改为 `False` 跳过思考过程
- 模型返回的是纯文本，无结构化 references
- `server_ms` 无法精确拆分（SSE 流式），D6 中该项指标可能不可用，权重可分配给其他 D6 指标

#### 多引擎路由调用方式

**直接调用内部函数，不走 HTTP**。当前项目没有 `/api/v1/research/stream` 评测端点，评测脚本直接调用项目内部的搜索 + LLM 函数，模拟 Agent 的搜索链路：

```python
"""eval/qwen_vs_multi/callers/multi_engine_caller.py - 多引擎路由方案调用"""
import time
from app.tools.search_engines import search, SCENE_ENGINE_MAP
from app.llm.vivo_chat import VivoCustomChat

# 使用"通用"意图，触发 volc 引擎搜索（SCENE_ENGINE_MAP["通用"] = ["volc"]）
# 如需更广召回，可改用 _DEFAULT_ENGINES = ["volc", "baidu"]
SEARCH_INTENT = "通用"
LLM_MODEL = "Doubao-Seed-2.0-lite"

SUMMARY_PROMPT = """你是一个专业的求职面试助手。请根据以下搜索结果，回答用户的问题。

要求：
1. 回答应基于搜索结果中的真实信息，不要编造
2. 如果有多个来源，综合不同来源的信息
3. 回答应针对用户的具体问题，提供有用的建议

## 用户问题
{query}

## 搜索结果
{search_context}

## 参考来源
{references}

请生成回答："""

def call_multi_engine(query: str) -> dict:
    """调用多引擎路由方案，返回 {answer, references, elapsed_ms, search_ms, llm_ms, error}"""
    t0 = time.time()
    
    # Step 1: 多引擎搜索 + RRF 融合
    results = search(intent=SEARCH_INTENT, query=query, timeout=6.0)
    search_ms = (time.time() - t0) * 1000
    
    # 格式化搜索结果为 LLM 友好文本
    search_context = _format_search_context(results)
    references = _extract_references(results)
    
    # Step 2: LLM 基于搜索结果生成答案
    t_llm0 = time.time()
    prompt = SUMMARY_PROMPT.format(query=query, search_context=search_context, references=references)
    llm = VivoCustomChat(model=LLM_MODEL, temperature=0.1)
    answer = llm.invoke(prompt).content
    llm_ms = (time.time() - t_llm0) * 1000
    
    elapsed_ms = (time.time() - t0) * 1000
    return {
        "answer": answer,
        "references": references,
        "elapsed_ms": elapsed_ms,
        "search_ms": search_ms,
        "llm_ms": llm_ms,
        "error": None,
    }
```

**与真实用户使用方式的差异**：

| 差异点 | 评测调用 | 实际用户 | 影响评估 |
|--------|---------|---------|:---:|
| 搜索入口 | 直接调 `search(intent="通用", ...)` | Agent 根据 context 判定意图后调 `smart_search()` | 🟢 搜索链路一致 |
| 引擎范围 | intent="通用" → `["volc"]` | 按场景路由表选择 1~2 个引擎 | 🟡 评测比实际略窄，可调为 `_DEFAULT_ENGINES` |
| LLM 总结 | 直接调 `VivoCustomChat.invoke()` | Agent 框架内调 LLM | 🟢 模型相同，prompt 可对齐 |
| 多轮对话 | 单轮，无 history | 多轮，有上下文 | 🟡 评测无上下文，可能影响完整性 |
| 工具链 | 跳过 Agent 工具调用链 | Agent 可能先调简历解析/JD 提取等工具 | 🟡 评测缺少前置工具上下文 |

> **设计说明**：评测目标是衡量"多引擎搜索 + LLM 总结"这个核心链路的答案质量，因此跳过 Agent 的多轮对话和工具链是合理的简化。评测结果反映的是搜索链路的底层能力，而非 Agent 框架的完整表现。

### 4.5 Phase 2：指标计算 + 统计检验

```
输入: P1a_multi.xlsx 和 P1a_qwen.xlsx（scores 列已填充）
处理:
  1. 加载两个 xlsx 文件（跳过 overall 列为空的条目）
  2. 计算 D5 指标（满意率/不满意率/加权平均分/胜率/准确率/完整度/相关性/溯源覆盖率/单轮可用率）
  3. 计算 D6 指标（成功率/超时率/耗时 P50/P95/标准差）
  4. 统计检验（Mann-Whitney U + 效应量）
  5. 分场景统计（category / industry / complexity）
  6. 输出多维度对比表 + 判定结论
输出: P2_metrics.xlsx（多 Sheet，结构见 4.8 节）
```

### 4.6 Phase 3：报告生成

```
输入: P2_metrics.xlsx
处理:
  1. 生成 PNG 图表（matplotlib）
  2. 生成 xlsx 报告（openpyxl 多 Sheet，合并 P2 指标 + 明细 + 图表）
  3. 生成 HTML 交互仪表盘（pyecharts / echarts）
输出: report/ 下三种格式报告
```

### 4.7 目录结构

```
eval_run_qwen_vs_multi_{timestamp}/
├── manifest.json                       # 运行元信息（JSON 格式，仅此一个）
├── queries.xlsx                        # Phase 0: 评测任务清单
│
├── P1a_multi.xlsx                      # Phase 1a: 多引擎路由方案原始答案
│   │                                   # 每行一条 query，含 answer + references + timing
│   │                                   # scores 列为空，Phase 1b 运行后填充
│
├── P1a_qwen.xlsx                       # Phase 1a: qwen3.6-agent 方案原始答案
│   │                                   # 每行一条 query，含 answer + timing（无 references）
│   │                                   # scores 列为空，Phase 1b 运行后填充
│   │                                   # ⚠️ 评分标准变化后，可 --phase 1b --force 重跑
│
├── P2_metrics.xlsx                     # Phase 2: 指标计算（多 Sheet）
│   ├── Sheet「总览」                    # 多维度对比表 + 判定结论 + 统计检验
│   ├── Sheet「D5_质量对比」              # D5 指标原始值
│   ├── Sheet「D6_性能对比」              # D6 指标原始值
│   ├── Sheet「分场景」                  # 按 category 分组
│   ├── Sheet「分行业」                  # 按 industry 分组
│   └── Sheet「分复杂度」                # 按 search_complexity 分组
│
└── report/                             # Phase 3: 最终报告
    ├── charts/
    │   ├── D5_satisfaction_bar.png
    │   ├── D5_weighted_avg_bar.png
    │   ├── D5_category_heatmap.png
    │   ├── D5_industry_heatmap.png
    │   ├── D5_complexity_grouped_bar.png
    │   ├── D6_latency_comparison.png
    │   ├── D6_reliability_bar.png
    │   ├── D6_latency_distribution.png
    │   ├── CS_radar.png
    │   └── CS_summary_bar.png
    ├── eval_report.xlsx                # 最终 xlsx 报告（合并 P1a 明细 + P2 指标）
    └── eval_dashboard.html
```

### 4.8 关键 xlsx 数据结构

#### P1a xlsx 列结构（P1a_multi.xlsx 和 P1a_qwen.xlsx 共用）

| 列名 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `query_id` | str | `q0001` | 唯一标识 |
| `query` | str | `帮我把简历改成适合字节跳动算法工程师的` | 原始用户 query |
| `scheme` | str | `multi` / `qwen` | 方案标识 |
| `category` | str | `resume_opt` | 场景类别 |
| `industry` | str | `互联网/科技` | 一级行业 |
| `sub_industry` | str | `互联网` | 二级行业 |
| `company` | str | `字节跳动` | 目标公司 |
| `position` | str | `算法工程师` | 目标岗位 |
| `search_complexity` | str | `single` | 搜索复杂度 |
| `answer` | str | `基于字节跳动算法工程师 JD 的分析...` | 方案回答全文 |