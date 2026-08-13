# Tests 测试体系详解

> 本文档详细描述 pro_agent 的测试体系，包括批量评测、评估框架、脚本测试和测试数据管理。

## 目录

1. [测试体系概述](#1-测试体系概述)
2. [批量评测框架](#2-批量评测框架)
3. [评估框架](#3-评估框架)
4. [脚本测试](#4-脚本测试)
5. [测试数据管理](#5-测试数据管理)
6. [测试配置](#6-测试配置)

---

## 1 测试体系概述

### 1.1 测试层次

pro_agent 的测试体系分为四个层次：

| 层次 | 目录 | 说明 |
|---|---|---|
| **批量评测** | `tests/batch/` | 端到端批量测试，覆盖完整请求流程 |
| **评估框架** | `tests/eval/` | 评估指标、比较器、报告生成 |
| **脚本测试** | `tests/scripts/` | 针对特定模块/功能的独立测试脚本 |
| **测试数据** | `tests/data/` | 测试用例数据（Excel/JSONL） |

### 1.2 测试结构

```
tests/
├── batch/                   # 批量评测框架
│   ├── cases/               # 测试用例（JSONL 格式）
│   │   └── example_cases.jsonl
│   ├── runner.py            # 批量测试运行器
│   ├── chat_batch_test.py   # 聊天批量测试
│   ├── alarm_eval_pipeline.py # 闹钟评测流水线
│   └── parse_response.py    # 响应解析
├── eval/                    # 评估框架
│   ├── comparators.py       # 比较器（精确/模糊/LLM Judge）
│   ├── metrics.py           # 评估指标（准确率/召回率/F1）
│   ├── reporter.py          # 报告生成
│   └── utils.py             # 评估工具函数
├── scripts/                 # 脚本测试
│   ├── test_agent_helpers.py
│   ├── test_body_context.py
│   ├── test_config_layered_merge.py
│   ├── test_context_pipeline.py
│   ├── test_infer_hooks.py
│   ├── test_responses_api.py
│   ├── test_stream_pipeline.py
│   ├── test_xuanji_models.py
│   └── ...
├── configs/                 # 测试配置
│   ├── slot_comparison_config.yaml
│   └── system_settings_slot_comparison_config.yaml
├── data/                    # 测试数据
│   ├── alarm_test_v4.xlsx
│   └── printer_assistant_full_test.xlsx
├── convert_legacy_excel.py  # 旧版 Excel 转换工具
└── README.md
```

---

## 2 批量评测框架

### 2.1 运行器（runner.py）

批量评测的核心运行器，负责：

1. 加载测试用例（JSONL/Excel）
2. 并发调用 `/mock/chat` 或 `/stream/chat` 端点
3. 收集响应结果
4. 调用评估框架计算指标
5. 生成评测报告

### 2.2 测试用例格式

**JSONL 格式**（`tests/batch/cases/`）：

```jsonl
{"query": "定一个早上八点的闹钟", "expected_tools": ["create_alarm"], "expected_args": {"raw_datetime": "08:00"}}
{"query": "今天天气怎么样", "expected_tools": ["weather_query"], "expected_args": {}}
{"query": "你好", "expected_tools": [], "expected_text_contains": "你好"}
```

### 2.3 闹钟评测流水线

**文件**：`tests/batch/alarm_eval_pipeline.py`

专门针对闹钟工具的评测流水线：

1. 发送闹钟相关查询
2. 解析工具调用参数
3. 与期望参数对比（时间、重复规则等）
4. 计算槽位准确率

### 2.4 聊天批量测试

**文件**：`tests/batch/chat_batch_test.py`

通用聊天场景的批量测试：

1. 加载测试用例
2. 并发调用 API
3. 验证工具选择正确性
4. 验证文本回复质量

---

## 3 评估框架

### 3.1 比较器（comparators.py）

| 比较器 | 说明 |
|---|---|
| `ExactComparator` | 精确匹配（字符串完全一致） |
| `FuzzyComparator` | 模糊匹配（包含/相似度） |
| `SlotComparator` | 槽位比较（工具参数逐字段对比） |
| `LLMJudgeComparator` | LLM Judge（用轻量模型判断回复质量） |

### 3.2 评估指标（metrics.py）

| 指标 | 说明 |
|---|---|
| `accuracy` | 准确率（工具选择正确率） |
| `slot_accuracy` | 槽位准确率（参数正确率） |
| `recall` | 召回率（应调用工具时是否正确调用） |
| `f1` | F1 分数（准确率和召回率的调和平均） |
| `ttft_p50/p90` | 首字时间分位数 |

### 3.3 报告生成（reporter.py）

生成评测报告，包含：

- 总体指标汇总
- 按工具/场景分类的细粒度指标
- 失败用例详情
- TTFT 分布统计

---

## 4 脚本测试

### 4.1 模块级测试

| 脚本 | 测试目标 |
|---|---|
| `test_agent_helpers.py` | Agent 辅助函数 |
| `test_body_context.py` | BodyContext 请求体上下文 |
| `test_config_layered_merge.py` | 配置分层合并 |
| `test_context_pipeline.py` | Context Pipeline 压缩 |
| `test_infer_hooks.py` | 推理干预层 Hook |
| `test_responses_api.py` | Responses API 缓存 |
| `test_stream_pipeline.py` | 流式处理管道 |
| `test_stream_meta_finalize.py` | StreamMeta 终止里程碑 |
| `test_xuanji_models.py` | XuanjiModel 多协议 |
| `test_openai_model_meta.py` | OpenAI 模型元数据 |
| `test_bluelm_direct.py` | BlueLM 直连测试 |

### 4.2 调试脚本

| 脚本 | 用途 |
|---|---|
| `debug_llm_judge.py` | 调试 LLM Judge 评估 |
| `dump_openai_raw_sse.py` | 导出 OpenAI 协议原始 SSE |
| `dump_vivo_raw_sse.py` | 导出 Vivo 协议原始 SSE |
| `probe_consecutive_user.py` | 探测连续 user 消息场景 |
| `verify_usage_capture.py` | 验证 usage 提取 |

### 4.3 运行方式

```bash
# 运行单个测试脚本
python tests/scripts/test_context_pipeline.py

# 运行批量评测
python tests/batch/runner.py --cases tests/batch/cases/example_cases.jsonl

# 运行闹钟评测
python tests/batch/alarm_eval_pipeline.py --data tests/data/alarm_test_v4.xlsx
```

---

## 5 测试数据管理

### 5.1 数据格式

| 格式 | 文件 | 用途 |
|---|---|---|
| JSONL | `cases/*.jsonl` | 批量评测用例 |
| Excel | `data/*.xlsx` | 领域专项测试数据 |
| YAML | `configs/*.yaml` | 槽位比较配置 |

### 5.2 旧版数据转换

**文件**：`tests/convert_legacy_excel.py`

将旧版 Excel 测试数据转换为新版 JSONL 格式。

### 5.3 测试数据构造原则

1. **覆盖度**：覆盖所有工具、各种边界场景
2. **可重复性**：测试结果可重复验证
3. **分层管理**：按领域/场景分类管理
4. **版本控制**：测试数据纳入版本管理

---

## 6 测试配置

### 6.1 槽位比较配置

**文件**：`tests/configs/slot_comparison_config.yaml`

定义工具参数的比较规则：

```yaml
create_alarm:
  slots:
    raw_datetime:
      comparator: fuzzy
      tolerance: 5min
    repeat_rule:
      comparator: exact
```

### 6.2 系统设置槽位配置

**文件**：`tests/configs/system_settings_slot_comparison_config.yaml`

专门针对 `adjust_phone_settings` 工具的槽位比较配置。

---

**相关文档**：
- [Agent 模块详解](./agent.md)
- [Tools 模块详解](./tools.md)
- [数据流文档](../dataflow/README.md)
