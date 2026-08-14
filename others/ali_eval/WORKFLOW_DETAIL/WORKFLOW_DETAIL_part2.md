2. **D5_质量对比**：D5 指标原始值
3. **D6_性能对比**：D6 指标原始值
4. **分场景**：按 category 分组
5. **分行业**：按 industry 分组
6. **分复杂度**：按 search_complexity 分组

### 3.6 Phase 3：报告生成

**文件**：`phase3_report.py`（510 行）

#### PNG 图表（matplotlib）

| 图表 | 文件名 | 内容 |
|------|--------|------|
| 满意度柱状图 | `D5_satisfaction_bar.png` | 满意率/不满意率/加权平均分 |
| 分维度柱状图 | `D5_weighted_avg_bar.png` | 事实准确率/完整度/相关性 |
| 延迟对比柱状图 | `D6_latency_bar.png` | P50/P95/P99 耗时 |
| 可靠性柱状图 | `D6_reliability_bar.png` | 成功率/超时率 |
| 综合雷达图 | `CS_radar.png` | 5 个 D5 子指标 |

- 中文字体自动检测（WenQuanYi/Noto/SimHei 等），找不到则用 DejaVu Sans
- matplotlib 未安装时优雅降级，跳过图表生成
- 配色：多引擎路由 = `#4472C4`（蓝），qwen3.6-agent = `#ED7D31`（橙）

#### xlsx 报告（`eval_report.xlsx`）

合并 P2 指标 + P1a 明细 + 分歧 Case：
- 复制 P2_metrics.xlsx 的所有 Sheet
- 复制 P1a_multi.xlsx → `明细_multi` Sheet
- 复制 P1a_qwen.xlsx → `明细_qwen` Sheet
- 新增 `分歧Case` Sheet：两方案 overall 差异 ≥1 的 query 列表

#### HTML 仪表盘（`eval_dashboard.html`）

- 纯静态 HTML + 内嵌 JSON 数据 + 原生 JS 渲染表格
- 展示总览指标表 + 嵌入 PNG 图表
- 无需后端服务��可直接用浏览器打开

---

## 四、CLI 命令详解

**文件**：`cli.py`（257 行）

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--input` | 数据集 xlsx 路径 | `datasets/search_eval_queries_300.xlsx` |
| `--limit` | 限制评测条数 | 不限制 |
| `--phase` | 只跑指定阶段（0/1a/1b/2/3） | 全流程 |
| `--schemes` | 只跑指定方案（multi,qwen） | 全部 |
| `--force` | 强制重跑 | False |
| `--resume` | 断点续跑（latest 或路径） | - |
| `--run-dir` | 指定运行目录 | - |
| `--concurrency` | 并发数（保留参数，当前串行） | 4 |

### 运行目录确定逻辑

```
--resume latest → 查找 runs/ 下最新的 qwen_vs_multi_* 目录
--resume <path> → 使用指定路径
--run-dir <path> → 使用指定路径
都不指定 → make_run_dir() 创建新目录
```

### Phase 编排

```python
phase=None → _run_full_pipeline()：Phase 0→1a→1b→2→3 全跑
phase="0"  → _run_phase0()
phase="1a" → _run_phase1a()（自动检查 queries.xlsx 是否存在，不存在先跑 Phase 0）
phase="1b" → _run_phase1b()
phase="2"  → _run_phase2()
phase="3"  → _run_phase3()
```

---

## 五、common.py 工具函数详解

**文件**：`common.py`（197 行）

| 函数 | 用途 |
|------|------|
| `setup_logging()` | 配置 `search_eval` 专用 logger |
| `now_iso()` | ISO 时间戳（`2026-07-30T14:30:00`） |
| `run_timestamp()` | 运行目录时间戳（`20260730_143000`） |
| `make_run_dir()` | 创建 `runs/qwen_vs_multi_{timestamp}/` |
| `read_xlsx()` | 读取 xlsx → `list[dict]`（第一行为表头） |
| `write_xlsx()` | `list[dict]` → xlsx（自动推断列名或指定 headers） |
| `append_xlsx_rows()` | 向已有 xlsx 追加行（不存在则创建） |
| `xlsx_has_row()` | 检查某列是否已有特定值（断点续跑用） |
| `xlsx_row_count()` | 返回数据行数 |
| `write_manifest()` | 写入 manifest.json |

**xlsx 读写特点**：
- dict/list 类型值自动 `json.dumps` 序列化
- `read_xlsx` 使用 `read_only=True, data_only=True` 模式（只读、取计算值）
- 表头为 None 的列自动命名为 `col_{i}`

---

## 六、测试体系

**目录**：`tests/`（7 个测试文件）

| 文件 | 内容 |
|------|------|
| `test_common.py` | xlsx 读写、目录管理 |
| `test_phase0_dataset.py` | 数据集加载、校验 |
| `test_phase1a_collect.py` | 答案采集（mock caller） |
| `test_phase1b_score.py` | LLM 评分（mock judge） |
| `test_phase2_metrics.py` | 指标计算正确性 |
| `test_phase3_report.py` | 报告生成 |
| `test_full_pipeline.py` | **全流程集成测试**（mock 所有外部服务） |

`test_full_pipeline.py` 是最核心的测试（294 行），覆盖：
- 5 条 query 全流程跑通（Phase 0→3）
- 部分调用失败场景（第 3 条超时）
- 只跑单方案（只 multi 不 qwen）
- 断点续跑（第二次运行跳过已完成）

所有外部调用均通过 `@patch` mock，测试不需要真实 API。

---

## 七、指标体系完整说明

### 7.1 为什么用 0/1/2 而非 1~10

- 0/1/2 粒度刚好（不行/还行/好），评判标准一致性好
- 业务含义清晰：0=翻车，1=有瑕疵，2=满意
- 参考 LMSYS Chatbot Arena（1~5）和项目现有 task A（0/1/2）的实践

### 7.2 为什么输出多维度而非仅总分

一个"1 分"可能掩盖不同问题——是事实错误还是遗漏？多维度能精确定位方案强弱项，且不增加额外 LLM 调用成本（同一次调用输出更丰富 JSON）。

### 7.3 胜率为什么重要

满意率是"绝对值"，胜率是"相对值"。两方案满意率可能接近（如 0.65 vs 0.62），但胜率揭示"在大多数 query 上谁更好"。胜率 + 满意率合看才能完整判断优劣。

### 7.4 为什么不做 min-max 归一化

只有 2 个方案时，min-max 会把任何微小差异极端化为 0 vs 100。例如满意率 0.65 vs 0.58 → 归一化后 100 vs 0，结论完全失真。正确做法：原始值 + 统计检验。

### 7.5 统计检验说明

| 检验方法 | 用途 | 依赖 |
|---------|------|------|
| Mann-Whitney U | 两方案 overall 评分的非参数检验（不假设正态分布） | scipy |
| Cliff's delta | 效应量，判断差异的实际意义（非统计显著性） | 自有实现 |
| Wilcoxon | 分场景配对检验（方案文档提及，代码未实现） | scipy |

Cliff's delta 解释：

| |delta| | 含义 |
|---------|------|
| < 0.2 | 可忽略 |
| 0.2 ~ 0.5 | 小效应 |
| 0.5 ~ 0.8 | 中效应 |
| ≥ 0.8 | 大效应 |

---

## 八、代码与设计文档的差异清单

| 项 | 文档描述 | 实际代码 | 影响 |
|----|---------|---------|------|
| Judge 模型 | `Doubao-Seed-2.0-lite` | `Doubao-Seed-2.0-pro` | pro 比 lite 更强但更慢/更贵 |
| 多引擎 LLM 模型 | `Doubao-Seed-2.0-lite` | `Doubao-Seed-2.0-pro` | 同上 |
| 多引擎 LLM 调用 | `VivoCustomChat(model=...)` | `build_chat_model()` + 环境变量 | 调用方式不同但效果类似 |
| 并发 | concurrency ≤ 4 | 串行执行，参数未生效 | 300 条全跑耗时更长 |
| Wilcoxon 分场景检验 | 方案中有描述 | 代码未实现 | 分场景缺少配对检验 |
| 可复用指标详解中的归一化 | min-max + 加权 + S/A/B/C 等级 | 整体方案 v1.4 已去掉，代码也不做 | 以整体方案为准（不做归一化） |
| `ttft_ms`（首字节耗时） | 方案中提及作为性能指标 | 代码中列存在但始终为空 | 未实际采集 |

---

## 九、历史运行分析

`runs/` 目录下有 8 个运行目录，均为 2026-07-30 下午的调试产物：

| 目录 | P1a_multi | P1a_qwen | P2_metrics | report | 推断用途 |
|------|:---:|:---:|:---:|:---:|------|
| `154952` | ✅ | ✅ | ❌ | ❌ | 初次尝试 |
| `155317` | ✅ | ❌ | ❌ | ❌ | 只跑 multi |
| `155401` | ✅ | ❌ | ❌ | ❌ | 同上 |
| `155748` | ✅ | ❌ | ❌ | ❌ | 同上 |
| `160244` | ✅ | ❌ | ✅ | ✅ | multi 单方案完整流程 |
| `161012` | ✅ | ✅ | ✅ | ✅ | 双方案完整流程（早期小规模） |
| `164339` | ❌ | ❌ | ❌ | ❌ | 空目录 |
| `164410` | ✅ | ❌ | ✅ | ✅ | **最新 run**，multi 300 条，缺 qwen |

最新 run `164410` 的 `manifest.json` 显示 `num_tasks: 300`，`P1a_multi.xlsx` 已有 300 条数据，但缺少 `P1a_qwen.xlsx`。推测 qwen 方案采集因 API 问题或超时未完成。

---

## 十、后续优化建议

### 短期（完成评测）

1. **补完 qwen 采集**：`--resume runs/qwen_vs_multi_20260730_164410 --phase 1a --schemes qwen`
2. **运行评分 + 指标 + 报告**：`--phase 1b` → `--phase 2` → `--phase 3`
3. **人工抽检**：打开 `eval_report.xlsx` 的"分歧Case"Sheet，抽查 ≥20 条
4. **与团队评审结论**

### 中期（提升评测质量）

5. **实现并发**：当前串行执行，300 条 × 2 方案耗时较长。可用 `concurrent.futures.ThreadPoolExecutor` 实现 `--concurrency` 参数
6. **采集 ttft_ms**：qwen 的 SSE 流式可以记录首字节时间，对性能评估有价值
7. **实现 Wilcoxon 分场景检验**：方案中设计了但代码未实现
8. **LLM Judge 偏差缓解**：考虑盲评（不告知方案名称）、随机化回答顺序

### 长期（扩展评测）

9. **增加变体方案**：测试"路由策略版"（按意图/场景选择引擎子集）vs "全引擎并发版"
10. **多轮对话评测**：当前仅单轮，可扩展多轮场景
11. **成本维度**：记录 token 消耗，增加"性价比"指标（质量/token 或 质量/耗时）
12. **V2 排序评测**：如果 LLM Judge 一致率 <80%，引入权威模型横向对比
