└─────────────────────────────────────────────────────────────────────┘
```

**核心设计原则：采集与评分解耦**

| 阶段 | 依赖外部服务 | 产出 | 可重跑 |
|------|:---:|------|:---:|
| Phase 1a 答案采集 | ✅ LLM API + Agent API | 原始答案（`answer` 文本） | 成本高，尽量不重跑 |
| Phase 1b LLM 评分 | ✅ LLM API | 评分结果（scores 列） | 成本低，评分标准变化后可随时重跑 |
| Phase 2 指标计算 | ❌ | 统计指标 | 纯本地，秒级 |
| Phase 3 报告生成 | ❌ | PNG/xlsx/HTML | 纯本地，秒级 |

> **为什么这样设计**：如果评分标准（prompt、维度、阈值）之后发生变化，只需要重跑 Phase 1b（LLM 评分），不需要重新调用外部服务采集答案。Phase 1a 是最昂贵、最不可控的阶段，应尽量一次跑完永久保留。

### 4.2 Phase 0：数据集加载

```
输入: 数据集 xlsx 文件（50 / 100 / 300 条）
处理:
  1. 使用 openpyxl 读取 xlsx（read_only=True, data_only=True）
  2. 按列映射解析字段（见 2.2 节）
  3. 校验字段完整性（query / category / industry / search_complexity / single_round_output）
  4. 生成评测任务清单，落盘 queries.xlsx
输出: 评测任务清单 + 元信息 + queries.xlsx
```

**列映射代码**（内联在 `phase0_dataset.py` 中）：

```python
# 数据集 xlsx 列头 → 内部字段名
COLUMN_MAP = {
    "id":                    "ID",
    "category":              "类别",
    "query":                 "用户Query",
    "company":               "目标公司",
    "position":              "目标岗位",
    "industry":              "一级行业",
    "sub_industry":          "二级行业",
    "resume_file":           "简历文件",
    "search_trigger":        "搜索触发要素",
    "expected_search_types": "预期搜索类型",
    "expected_tool_chain":   "预期工具链",
    "search_complexity":     "搜索复杂度",
    "single_round_output":   "单轮预期产出",
}
```

**注意**：
- 与现有 `eval/phase0_dataset.py` 的列映射不同（旧版针对"智能路由-二期-评测集.xlsx"），需要新建独立的 `qwen_vs_multi/phase0_dataset.py`
- `category` 值为 `"简历优化"` / `"面试准备"`，读取后映射为 `resume_opt` / `interview_prep`
- 无历史对话字段（单轮评测），`history` 固定为空列表
- 不需要 NLU 标注（`intents_field` / `is_realtime` / `wenfa_intent` 在此场景不适用）

### 4.3 Phase 1a：方案调用 + 答案采集（不含评分）

```
输入: Phase 0 任务清单（queries.xlsx）
处理:
  for each query:
    1. 调用多引擎路由方案（直接调用内部函数，不走 HTTP）
       - Step 1: 调用 search_engines.search(intent="通用", query) 搜索引擎 → RRF 融合
       - Step 2: 调用 LLM (Doubao-Seed-2.0-lite) 基于搜索结果 + prompt 生成最终答案
       - 采集 answer + references + timing（仅采集，不评分）
       - 逐行追加写入: P1a_multi.xlsx
    
    2. 调用 qwen3.6-agent 方案（走 vivo 内部 Agent API，SSE 流式）
       - 采集 answer + timing（无 references，qwen3.6-agent 返回纯文本）
       - 逐行追加写入: P1a_qwen.xlsx

并发控制:
  - 多引擎路由: concurrency ≤ 4（受限于 LLM API QPS）
  - qwen3.6-agent: concurrency ≤ 4（受限于 Agent API QPS）
  - 两条线路可并行跑（互不依赖）

超时设置:
  - 多引擎路由: 搜索 6s + LLM 总结 30s，总超时 60s
  - qwen3.6-agent: 120s（SSE 流式）

断点续跑:
  - 检查 xlsx 中已有 query_id 的行，跳过已完成的
  - --force 强制重跑（清空已有数据）

输出格式: 每行一条 query，列结构见 4.8 节
```

### 4.4 Phase 1b：LLM Judge 评分（独立阶段，可随时重跑）

```
输入: P1a_multi.xlsx 和 P1a_qwen.xlsx
处理:
  for each row in P1a_multi.xlsx and P1a_qwen.xlsx:
    1. 读取 answer 文本
    2. 调用 judge.score_answer() 获取多维度评分
    3. 将 scores 各维度写入对应列（overall/accuracy/completeness/relevance/remark/scored_at）
    
并发控制:
  - concurrency ≤ 8（纯 LLM 调用，无复杂依赖）

重跑策略:
  - --phase 1b --force 强制重新评分（清空 scores 列）
  - 评分标准（prompt/维度）变化后，只需重跑此阶段
  - P1a 答案数据永久保留，不受评分变化影响
```

> **P1a xlsx 列结构**：详见 [4.8 节](#48-关键-xlsx-数据结构)。
> 
> **设计要点**：`scored_at` 列记录评分时间戳，方便追踪"这是哪一版评分标准打的"。Phase 2 读取 P1a xlsx 时，如果 `overall` 列为空，跳过该行（不参与指标计算）。
> **人工检查友好**：xlsx 格式可直接在 Excel/WPS 中打开，按列筛选、排序、透视，方便人工抽查和汇报。

#### 打分模块设计（自建，不依赖外部评测服务）

**为什么不复用 `normal_acc_tool`**：

| 问题 | 说明 |
|------|------|
| 无法 import | `normal_acc_tool.py` 依赖 `pandas`/`tqdm` 等不在当前项目中的库 |
| 外部服务 | `rag-auto-eval-acc-v2` 是 `vivo_deepagents` 项目的评测服务，设计场景是"知识问答自动化评测"，非面试/简历场景 |
| 响应慢 | 实测 5~10 秒/条（内部调用多个参考模型），300 条 × 2 方案 ≈ 50~100 分钟 |
| 不可控 | 评分逻辑黑盒，无法针对简历优化/面试准备场景定制评分标准 |

**正确方案：自建 LLM Judge 打分模块**

调用主项目已有的 LLM（`Doubao-Seed-2.0-lite`），用 prompt 方式做 0/1/2 评分。实现文件：`eval/qwen_vs_multi/judge.py`

```python
"""eval/qwen_vs_multi/judge.py - LLM Judge 打分模块"""
import os, json, time
from app.llm.vivo_chat import _gen_sign_headers
import requests

# 复用主项目 LLM 配置
APP_ID = os.environ.get("VIVO_APP_ID")
APP_KEY = os.environ.get("VIVO_APP_KEY")
DOMAIN = os.environ.get("VIVO_DOMAIN", "chatgpt-api-pre.vmic.xyz")
JUDGE_MODEL = "Doubao-Seed-2.0-lite"  # 轻量模型，够用且快

SCORING_PROMPT = """你是一个专业的答案质量评测员，专精于求职面试/简历优化场景。请从以下四个维度对"回答"进行评分。

## 评分标准（每个维度 0/1/2 分）

### overall（综合评分）
- **2 分**：答案准确完整，覆盖了问题的所有核心要点，无明显事实错误或遗漏
- **1 分**：部分正确，但有小错、遗漏次要信息，或表述不够准确
- **0 分**：大错、漏答核心问题、幻觉、完全无关

### accuracy（事实准确性）
- **2 分**：所有事实、数据、公司/岗位信息均准确，有合理依据
- **1 分**：大部分准确，但个别数据或细节存疑（如薪资范围偏旧、面试题不典型）
- **0 分**：有明显编造、幻觉、张冠李戴（如把 A 公司的面试题说成 B 公司的）

### completeness（覆盖完整度）
- **2 分**：完整覆盖了 query 的所有核心子问题，无遗漏
- **1 分**：覆盖了主要问题，但遗漏了次要子问题或用户隐含关注点
- **0 分**：只回答了问题的一小部分，或完全偏题

### relevance（相关性）
- **2 分**：回答紧扣 query，针对具体公司/岗位/场景，无冗余或偏题内容
- **1 分**：大部分相关，但包含少量泛泛而谈或不直接相关的内容
- **0 分**：答非所问，或回答的是另一个问题

## 评测场景说明
这是求职面试/简历优化场景，请重点关注：
1. 回答是否基于真实的搜索信息（而非凭空编造）
2. 回答是否针对具体公司/岗位（而非泛泛而谈）
3. 回答中的面试题/面经/薪资数据是否合理
4. 如果回答是"确认卡"或"追问"（如"请补充岗位级别"），overall 应为 0，且在各维度标注原因

## 输出格式
请严格输出以下 JSON，不要包含其他内容：
{"overall": <0|1|2>, "accuracy": <0|1|2>, "completeness": <0|1|2>, "relevance": <0|1|2>, "remark": "<简短理由，不超过150字>"}

## 问题
{query}

## 回答
{answer}

## 历史对话
{history}
"""

def score_answer(query: str, answer: str, history: str = "", max_retry: int = 2) -> dict:
    """调用 LLM 对单条回答多维度打分，返回 {
        "overall": int, "accuracy": int, "completeness": int, "relevance": int, "remark": str
    }"""
    prompt = SCORING_PROMPT.format(query=query, answer=answer, history=history or "无")
    
    params = {"requestId": str(__import__('uuid').uuid4())}
    data = {
        "model": JUDGE_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "stream": False,
        "temperature": 0.1,  # 低温度保证评分一致性
    }
    headers = _gen_sign_headers(APP_ID, APP_KEY, "POST", "/chat/completions", params)
    headers["X-AI-GATEWAY-PROTOCOL"] = "openai"
    url = f"http://{DOMAIN}/chat/completions"
    
    for attempt in range(max_retry + 1):
        try:
            r = requests.post(url, json=data, headers=headers, params=params, timeout=30)
            if r.status_code == 200:
                resp = r.json()
                content = resp["choices"][0]["message"]["content"]
                content = content.strip()
                if content.startswith("```"):
                    content = content.split("\n", 1)[1].rsplit("\n", 1)[0]
                result = json.loads(content)
                overall = int(result.get("overall", -1))
                if overall in (0, 1, 2):
                    return {
                        "overall": overall,
                        "accuracy": int(result.get("accuracy", -1)),
                        "completeness": int(result.get("completeness", -1)),
                        "relevance": int(result.get("relevance", -1)),
                        "remark": result.get("remark", ""),
                    }
            if attempt < max_retry:
                time.sleep(1 * (attempt + 1))
        except Exception as e:
            if attempt < max_retry:
                time.sleep(1 * (attempt + 1))
            else: