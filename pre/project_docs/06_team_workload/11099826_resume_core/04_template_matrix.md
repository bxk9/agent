# 04 · 模板矩阵（≥6 套模板独立设计）

## 一句话概括

11099826 独立设计并维护的**≥6 套简历模板体系**，采用"模板即数据"模式（HTML + CSS + section 片段），支持用户按风格自由切换。

---

## 核心数据卡片

| 模板 | style.css 改动 | template.html 改动 | section 片段 |
|:---|---:|---:|:---:|
| **orange** | 27 | 13 | projects/work/internship 各 11-12 |
| **grayheader** | 26 | 14 | 同上 |
| **graybar** | 24 | 14 | 同上 |
| **centeredblue** | 24 | 14 | 同上 |
| **sidebar** | 15 | — | — |
| **card** | 15 | — | — |

**信号**：4 套主模板 CSS 累计 **101 次改动**，是长期精雕的产物。

---

## 背景与问题

早期只有单一模板，用户风格需求多样化：
- IT 风格 vs 传统风格
- 双栏 vs 单栏
- 有头像 vs 无头像
- 中文 vs 英文
- 校招 vs 社招 vs 学术 CV

---

## 时间线

| 日期 | 事件 |
|:---:|:---|
| 06-11 | 首套模板 + PDF/Word 导出 |
| 06-16 | 原版样式导出 + 多模板 Word 优化 |
| 06-29 | 校园活动识别 + 排版折叠 |
| 06-30 | 双栏简历模板多项优化与 Word 版对齐 |
| 07-01 | 简历模板排版及侧边栏渲染重构 |
| 07-02 | 模板文件化（HTML/CSS 独立） |
| 07-09 | STD2630 需求：IT 风格通用模板 + 封面首页 |
| 07-09 | 简历卡片模板扩展（card 模板） |
| 07-10 | 双栏 `:only-child` 兼容修复 |
| 07-13 | fix: 修复 Jinja2 单栏模板 section_order 未注入导致正文内容全部消失 |
| 08-04 | 项目模板样式优化 + 校园经历分拆修复 |
| 08-08 | 模块间距压缩 + AI 标记色红→紫 |
| 08-09 | Markdown 模块顺序推导 |
| 08-10 | 学术 CV 字段（research_interests / teaching_experience / grants / ...） |

---

## 方案 / 代码证据

### 模板目录结构

```
resume_templates/
├── orange/                  ← 橙色主题
│   ├── style.css
│   ├── template.html
│   └── sections/
│       ├── projects.html
│       ├── work.html
│       └── internship.html
├── grayheader/              ← 灰头
├── graybar/                 ← 灰条
├── centeredblue/            ← 蓝色居中
├── sidebar/                 ← 侧边栏样式
└── card/                    ← 卡片式
```

### 关键设计

1. **CSS 变量化**（07-08）：主题色 / 字号 / 行距 / 边距 / bullet 全部走 CSS 变量，支持用户自定义
2. **section 片段化**：每个模块（work / projects / internship）独立 HTML 片段，可复用可裁剪
3. **Jinja2 双栏兜底**：section_order 未注入时正文不会全部消失（07-13 修复）
4. **两阶段压缩**：模块间距 + 内容精简，都是 CSS + Python 协同

---

## 量化成果

| 维度 | 数值 |
|:---|:---|
| 模板套数 | 6+ |
| 4 主模板累计 CSS 改动 | 101 次 |
| 支持的用户偏好维度 | 主题色 / 字体 / 字号 / 行距 / 页边距 / bullet / 模块顺序 |
| 支持的场景 | 校招 / 社招 / 学术 CV / 双栏 / 单栏 / 有头像 / 无头像 |

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="11099826" --name-only --pretty=format: | \
  grep "resume_templates/" | sort | uniq -c | sort -rn | head -30
```
