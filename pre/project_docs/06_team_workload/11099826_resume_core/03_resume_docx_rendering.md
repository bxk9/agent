# 03 · DOCX / PDF 双引擎渲染层

## 一句话概括

11099826 独立设计的 `resume_docx/` 包 + `resume_template_docx.py` + PDF 渲染子模块，把简历从 HTML 稳定输出为**可编辑 Word 与打印级 PDF**——这是 C 端用户最终收到的产物。

---

## 核心数据卡片

| 文件 | 修改次数 | 归属 |
|:---|---:|:---|
| `resume_template_sidebar.py` | 34 | Owner |
| `resume_template_docx.py` | 31 | Owner |
| `resume_docx/_standard.py` | 31 | Owner |
| `resume_docx/_helpers.py` | 17 | Owner |
| `resume_docx/_sidebar.py` | 15 | Owner |
| `resume_docx/_sections.py` | 15 | Owner |
| `resume_sidebar/pdf_render.py` | 9 | Owner |
| `resume_sidebar/html_to_word.py` | 9 | Owner |
| `resume_sidebar/html_to_word_rebuilt.py` | 10 | Owner |

---

## 背景与问题

Word 与 PDF 是两条独立渲染路径，各有陷阱：

- **Word**：python-docx 手动拼装样式，容易与 HTML 对齐失败（时间字段换行、加粗不一致、bullet 样式）
- **PDF**：weasyprint / xhtml2pdf 引擎差异，字体加载失败会 fallback
- **两者一致性**：用户预期"Word 和 PDF 看起来一样"，但技术栈天然不同

---

## 时间线

| 日期 | Commit | 关键动作 |
|:---:|:---|:---|
| 06-11 | feat ：测试简历预览图、导出pdf | PDF 首次接入 |
| 06-11 | feat: 1、建立长连接；2、增加导出doc功能 | Word 接入 |
| 06-15 | 兼容版式，导出doc文件 | 多版式支持 |
| 06-16 | feat(resume): 简历文件解析 + 原版样式导出 + 多模板 Word 优化 | 大版本 |
| 06-30 | fix: 双栏简历模板多项优化与Word版对齐 | Word/PDF 对齐 |
| 07-06 | fix: 修复简历导出长任务 WebSocket 超时断开，并并行化 Word 生成 | **并行化** |
| **07-10** | **refactor(resume): 将简历模板模块拆分为 resume_docx 包** | **独立成包** |
| 07-10 | pdf导出去掉None，保持word和pdf加粗一致 | 一致性 |
| 07-10 | two-col 单条 li 跨栏占满整行 | 兼容 weasyprint/xhtml2pdf |
| 08-03 | 行宽度，根据字数调整表格 | 自适应 |
| 08-03 | 修复表格时间 / 项目表格宽度自适应 | 长尾 |
| 08-03 | 消除空行 / 修复重叠 | 精雕 |
| 08-07 | jpdf 和 word 渲染的内容保持一致 | 一致性 |
| 08-08 | AI 标记色红色→紫色，PDF/Word两阶段压缩，模块间距压缩 | 大版本 |

---

## 方案 / 代码证据

### resume_docx 包分层

```
resume_docx/
├── _standard.py    ← 通用能力（31 次改动，最活跃）
├── _helpers.py     ← 辅助函数（17 次）
├── _sidebar.py     ← 侧边栏模板专属（15 次）
└── _sections.py    ← 章节渲染（15 次）
```

### 双引擎一致性设计

| 问题 | 解法 |
|:---|:---|
| Word 加粗与 PDF 不一致 | pdf 导出去 None + 加粗规则统一（07-10） |
| 双栏 li 单条时右侧空白 | `:only-child` CSS2 伪类（07-10） |
| 长任务 WebSocket 超时 | Word 生成并行化（07-06） |
| 时间字段换行 | `naming.py` + 表格宽度自适应（08-03） |
| Word 模板损坏 | 兜底渲染（08-07 `fix: 模块顺序重排算法修复 + Word 模板损坏兜底`） |

### 压缩到一页（08-08 → 08-09）

- Commit：`AI 标记色红色→紫色，PDF/Word两阶段压缩，模块间距压缩，scope兜底`
- 后续：`feat: 压缩到一页精准控制 + auto_compress默认False`
- 关键：**两阶段压缩 = 模块间距 + 内容精简**，两条独立通道，都可控

---

## 量化成果与协作面

| 维度 | 成果 |
|:---|:---|
| Word 引擎 | python-docx 手工方案（`resume_docx/` 包） |
| Word 兜底引擎 | LibreOffice 方案（`html_to_docx_libreoffice.py`，11197109 主导） |
| PDF 引擎 | weasyprint + xhtml2pdf 双兼容 |
| 一致性目标 | Word ↔ PDF 视觉对齐（多次修复达成） |
| 精雕次数 | 8 月单月表格/空行/重叠 10+ 次修复 |

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="11099826" --name-only --pretty=format: | \
  grep "resume_docx\|resume_template_docx\|pdf_render\|html_to_word" | \
  sort | uniq -c | sort -rn
```
