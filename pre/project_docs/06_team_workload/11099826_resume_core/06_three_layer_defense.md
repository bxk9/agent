# 06 · 三层防御方法论（LLM Schema → 正则精度 → 归一化清洗）

## 一句话概括

11099826 在 08-04 一次提交中系统性提出的**三层防御范式**——用于对抗 LLM 输出不稳定：Schema 层约束、正则层兜底、归一化层清洗。是**项目级设计范式**，后被 yitong（错题本）、司棋（VFS）复用。

---

## 核心数据卡片

| 层级 | 关键文件 | 职责 |
|:---|:---|:---|
| **L1 Schema 层** | `resume_sidebar_constants.py` | LLM 输出契约（字段定义 + 中文说明） |
| **L2 正则层** | `field_checkers/regex_checkers.py` | 正则兜底提取 |
| **L3 归一化层** | `resume_sidebar/normalize.py`、`_normalize_jinja2_data` | 数据清洗 |

---

## 背景与问题

LLM 输出的三种典型异常：

1. **字段丢失**：Schema 未覆盖 → 无法约束 LLM 输出该字段
2. **字段错乱**：正则粗糙 → 兜底提取错位置内容
3. **数据不干净**：归一化不彻底 → CSS 撑破 / 类型混乱

单层修复只能解决单类问题，需要**三层同时对齐**。

---

## 时间线（08-04 单次提交产出）

**Commit（08-04）**：
> `改动汇总 Fix 1 — resume_sidebar_constants.py（LLM Schema 补字段）`
> 新增 portfolio 字段定义，附带中文说明（百度网盘/...）
> `_normalize_for_sidebar` 和 `_normalize_jinja2_data` 两个入口均调用，覆盖所有模板路径
> **根因修复路径：LLM Schema → 正则兜底精度 → 归一化清洗，三层防御对齐**

---

## 方案 / 代码证据

### 三层协作示意

```
用户简历
    │
    ▼
[LLM 提取]  ← L1 Schema 约束：明确告诉 LLM 输出什么字段
    │
    ▼
[结果检查] ← L2 正则兜底：LLM 漏掉时用正则从原文再提一次
    │
    ▼
[数据落库] ← L3 归一化清洗：类型转换、去空、CSS 安全
    │
    ▼
[渲染]
```

### 08-04 单日的三层修复示例

| 场景 | L1 修复 | L2 修复 | L3 修复 |
|:---|:---|:---|:---|
| portfolio 字段丢失 | 补 Schema 定义 | 增加正则回捞 | normalize 两入口调用 |
| basicInfo JSON 超宽 | — | — | 数组值类型转换 + CSS 兜底 |
| birth 字段格式 | — | — | 归一化统一格式 |
| 校园经历被分拆 | 白名单豁免 | Prompt 提取重构 | 归一化合并 |

### 方法论沉淀

- **三层并行修复**：不允许"只补 Prompt 不修 normalize"这种半吊子
- **两入口同步**：`_normalize_for_sidebar` 和 `_normalize_jinja2_data` 必须同时调用，避免模板路径遗漏

---

## 量化成果与外部复用

### 直接效果

| 指标 | 修复前 | 修复后 |
|:---|:---:|:---:|
| portfolio 字段可用性 | 静默丢失 | 稳定捕获 |
| basicInfo 超宽概率 | 高 | 归零 |
| 校园经历分拆 | 频繁 | 白名单豁免 |

### 被复用的域

- **yitong · 错题本**：三层防御 = 事前 Schema / 事中工具校验 / 事后 diff 补标（[详见](../../06_workload_showcase/03_error_book_system.md)）
- **司棋 · VFS**：三层头统一（X-Api-Key / X-User-Id / X-Trace-Id）+ dev/pre/prd 网络矩阵兜底
- **11197109 · VLM**：VLM 视觉 → OpenCV 兜底 → 纯文字降级

**结论**：11099826 首创的三层防御被项目主要贡献者集体复用，是**跨模块方法论**。

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git show $(git log --author="11099826" --grep="三层防御" --format=%H) --stat
git log --author="11099826" --pretty=format:"%ad|%s" --date=short | grep -i "防御\|schema\|normalize"
```
