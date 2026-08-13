# 02 · resume_sidebar 包 pipeline 独立设计

## 一句话概括

**11099826 独立设计并实现的 35 文件包**，是简历生成链路的中枢——从"一次性渲染"演进为"流式 pipeline + 侧边栏交互 + 字段可校验"。在 `pipeline.py` 与 `normalize.py` 两个核心文件上分别占 **95.2% / 96.4%** 的 blame，是**几乎完全独占的**代码域。

---

## 核心数据卡片

| 指标 | 数值 |
|:---|---:|
| 包内文件数 | **35+** |
| 累计提交（该包） | 400+ 次改动 |
| pipeline.py 修改 | 100 次（该文件最多） |
| normalize.py 修改 | 71 次（该文件最多） |
| pipeline.py blame | **11099826 95.2%** |
| normalize.py blame | **11099826 96.4%** |
| 拆分事件 | 2026-07-01 独立成包 |

### 包内文件热力（TOP 20）

| 修改次数 | 文件 |
|---:|:---|
| 100 | `pipeline.py` |
| 71 | `normalize.py` |
| 26 | `render_html.py` |
| 21 | `ai_marks.py` |
| 20 | `resume_sidebar_constants.py`（上级同名文件） |
| 10 | `html_to_word_rebuilt.py` |
| 9 | `resume_sidebar_prompts.py`、`pdf_render.py`、`naming.py`、`html_to_word.py`、`ai_marks_diff.py` |
| 8 | `i18n.py` |
| 7 | `validate.py` |
| 6 | `field_checkers/regex_checkers.py`、`extract_translate.py`、`dom_manipulator.py` |
| 5 | `field_checkers/school_checker.py`、`company_checker.py` |
| 4 | `prompt.py` |
| 3 | `sensitive.py`、`markdown_scope.py`、`layout_tiers.py`、`extractor.py`、`__init__.py` |
| 2 | `README.md`、`ARCHITECTURE.md`、`fidelity_check.py`、`fact_store.py`、`field_checkers/timeline_checker.py`、`registry.py` |

---

## 背景与问题

早期 `resume_template_sidebar.py`（34 次改动的老单文件）承载了太多职责：解析归一化、模板渲染、AI 标记、字段校验全部揉在一起，边界不清、重构受阻。

---

## 时间线

| 日期 | Commit | 关键动作 |
|:---:|:---|:---|
| **07-01** | `feat: 素材库(Master Profile) + 历史简历版本管理 + resume_sidebar 包拆分` | **包正式独立** |
| 07-02 | `feat(resume): 新增字段真实性校验层 + 模板文件化 + 缓存支持排版维度` | 加入 `field_checkers/` |
| 07-03 | `feat: 简历侧边栏功能增强、模板封面支持及记忆系统优化` | 增强 |
| 07-06 | `feat(resume): 简历系统全面升级` | 大版本 |
| 07-08 | `feat: 简历侧边栏管线重构 + CSS变量化 + 日志过滤` | 管线重构 |
| 07-09 | `feat: 简历卡片模板扩展、文本乱码检测、AI数字标记规则强化及VFS重构` | 多域联动 |
| 08-04 | `改动汇总 Fix 1 — resume_sidebar_constants.py（LLM Schema 补字段）...三层防御对���` | **三层防御** |
| 08-08 | `refactor: scope检测逻辑迁移到工具层` | scope 下沉 |
| 08-08 | `feat: LLM scope意图分类兜底` | LLM 兜底 |
| 08-09 | `feat: 压缩到一页精准控制 + auto_compress默认False + Markdown模块顺序推导` | 压缩控制 |

---

## 方案 / 代码证据

### 包内子模块职责

```
resume_sidebar/
├── pipeline.py          ← 主管线：编排所有步骤
├── normalize.py         ← 字段归一化 & Schema 对齐
├── extractor.py         ← LLM 提取入口
├── extract_translate.py ← 中英翻译层
├── prompt.py            ← 提取 Prompt
├── validate.py          ← 顶层校验
├── field_checkers/      ← 字段级校验子包
│   ├── school_checker.py       学校白名单
│   ├── company_checker.py      公司白名单
│   ├── regex_checkers.py       正则库
│   ├── timeline_checker.py     时间轴校验
│   ├── university_whitelist.py 数据源
│   └── registry.py             注册中心
├── fidelity_check.py    ← 事实性校验（防幻觉）
├── fact_store.py        ← 事实缓存
├── ai_marks.py          ← AI 标记生成
├── ai_marks_diff.py     ← AI 标记差异计算
├── mark_tools.py        ← 标记工具
├── markdown_scope.py    ← Markdown 作用域
├── layout_tiers.py      ← 排版层级
├── dom_manipulator.py   ← DOM 操作
├── render_html.py       ← HTML 渲染
├── pdf_render.py        ← PDF 渲染
├── html_to_word.py      ← HTML → Word 转换
├── html_to_word_rebuilt.py ← 重建版
├── html_to_docx_libreoffice.py ← LibreOffice 方案（11197109 主导）
├── naming.py            ← 文件命名规则
├── i18n.py              ← 国际化
├── sensitive.py         ← 敏感信息过滤
├── language_detector.py ← 语言检测
└── registry.py          ← 注册中心
```

### 关键设计模式

1. **管线化**：`pipeline.py` 编排 20+ 步骤，每步一函数，可插拔
2. **字段级校验**：`field_checkers/` 每类字段一 checker，通过 `registry.py` 注册
3. **事实性防幻觉**：`fidelity_check.py` + `fact_store.py` 双层
4. **AI 标记契约**：`ai_marks.py` + `ai_marks_diff.py` 支持增量差异

---

## 量化成果与协作面

- 独立成包后，2 个月内演进出 35+ 个文件，是**项目最大的单包**
- 11099826 在 pipeline / normalize 两大核心文件上占 **95%+ blame**，是**几乎完全独占**的域
- 与 11197109 在 `html_to_docx_libreoffice.py` 上形成互补协作

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="11099826" --name-only --pretty=format: | \
  grep "resume_sidebar" | sort | uniq -c | sort -rn

git blame --line-porcelain app/tools/resume_sidebar/pipeline.py | \
  grep "^author " | sort | uniq -c | sort -rn
```
