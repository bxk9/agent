# 20 · 模块 · 简历 HTML 模板体系 `resume_templates/`

## 1. 模块定位

`resume_templates/` 是简历渲染的**表现层**：6 套精心设计的 HTML/CSS 模板 + Jinja2 骨架 + 离线渲染 demo。它是**纯前端资产**，Python 侧只做变量注入，不含业务逻辑。

一句话：**Schema 进，HTML 出**。

## 2. 目录结构

```
resume_templates/
├── sidebar/                   侧栏版（默认，Agent 主流水线首选）
│   ├── sections/              分节子模板（basic / experiences / projects / edu / skills）
│   ├── style.css              CSS（使用 CSS 变量提供三档排版）
│   └── template.html          Jinja2 骨架，include sections/*
├── orange/                    橙色主题（活泼、互联网）
├── grayheader/                灰底 header（正式、金融/国企）
├── centeredblue/              蓝色居中（学术/校招）
├── graybar/                   灰色分栏（简洁）
├── card/                      卡片式（作品集向）
│
├── _preview/                  预览截图（*.html，供设计/QA 快看）
│   ├── sidebar.html / orange.html / ...
│
├── render_demo.py             离线渲染入口（CLI + Python API）
├── resume_schema_full.json    完整 schema 参考
├── sample_data.json           样例数据（供 render_demo 快跑）
└── README.md
```

## 3. 六套模板一览

| 模板 | 定位 | 典型场景 |
|------|------|---------|
| `sidebar` | 左侧栏 + 右主体（默认） | 通用互联网/技术岗，Agent 主线 |
| `orange` | 顶部橙色条 + 卡片 | 互联网/创意 |
| `grayheader` | 灰色 header + 双栏 | 金融/国企/正式 |
| `centeredblue` | 居中蓝色标题 | 校招/学术 |
| `graybar` | 侧灰竖条 | 极简、快速阅读 |
| `card` | 卡片堆叠 | 作品集向 |

每套模板都遵守相同的 `resume_schema_full.json`，因此**同一份数据**可平铺渲染 6 套。

## 4. 对外契约

### 4.1 Schema

- 单一权威：`resume_schema_full.json`（也是 `app/resume_pipeline/schema.py` 的对齐参考）
- 主要字段：
  - `basic{name, avatar, contacts[], summary}`
  - `experiences[]`、`projects[]`、`education[]`、`skills[]`
  - `organizations[]`（社会组织/协会/志愿）
  - `custom_sections[]`（自定义章节，可选）

### 4.2 Jinja2 变量注入

```python
from jinja2 import Environment, FileSystemLoader

env = Environment(loader=FileSystemLoader("resume_templates/sidebar"))
tpl = env.get_template("template.html")
html = tpl.render(**schema)
```

约定：
- 顶层键即 Jinja 变量名；
- 每个 `sections/*.html` 只依赖顶层键，**不做**跨节引用；
- 头像用 `{{ basic.avatar }}`（data URI）或链路 B 的 `{{AVATAR}}` 占位符（上游 HTML）。

### 4.3 CLI

```bash
cd resume_templates
python render_demo.py sidebar sample_data.json > out.html
```

## 5. 核心设计理念（模块级）

1. **模板与数据严格分离**  
   Jinja2 只做**变量替换 + 分支循环**，不写任何"业务判断"。改样式绝不改 schema。

2. **6 套模板同一数据源**  
   `resume_schema_full.json` 是**唯一契约**。任何新增字段必须在这里加，同时更新 6 套模板的对应 section（可选：不改就不显示）。

3. **CSS 变量提供三档排版**  
   在 `style.css` 顶部定义 `--gap-tight / --gap-normal / --gap-loose` 等变量，Agent 可根据"内容多少"选择"紧凑/常规/舒展"档位，同一模板生成不同密度。

4. **Sections 独立可 include**  
   每节独立 `sections/xxx.html`，便于：
   - 单节复用；
   - Agent 局部渲染（例如"只改经历"时只重跑 experiences 段）；
   - 前端在线编辑器潜在拆分。

5. **纯前端资产，无 Python 依赖**  
   `resume_templates/` 里除 `render_demo.py` 是 CLI 辅助工具外，其余全部是 HTML/CSS/JSON。它可以独立打包给设计师查看。

6. **头像双通道**  
   - 主流水线（链路 A）：模板中 `<img src="{{ basic.avatar }}">`（data URI）
   - 上游还原（链路 B）：模板中留 `{{AVATAR}}` 文本占位符，由 `resume_pipeline/pipeline.py::inject_avatar_into_html` 后处理替换

## 6. 典型调用链

在线主流水线（简化）：

```
agent (resume_generator)
  → tool resume_template_sidebar.render(schema, density="normal")
       → jinja2 render(resume_templates/sidebar/template.html, **schema)
       → CSS 变量注入 density
  → HTML
  → tool resume_export.export_pdf
       → html_to_pdf → PDF
  → VFS put → file_id
  → memory.resume_index.append
```

离线 pipeline：

```
python -m app.resume_pipeline.pipeline <name>
  → schema
  → render_all_templates(schema)  # 遍历 4 套模板
       → results/final/<name>__<tpl>.html/.pdf
  → 链路 B（原版式）
       → inject_avatar_into_html(rebuilt_html)
       → results/final/<name>__rebuilt.html/.pdf
```

## 7. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增第 7 套模板 | 新建 `resume_templates/xxx/`，含 `template.html` + `style.css` + `sections/`；在 `render_all_templates` 白名单登记 |
| 新增字段 | 改 `resume_schema_full.json` + `app/resume_pipeline/schema.py`（Pydantic）+ 6 套模板 sections 更新 |
| CSS 变量新增档位 | 在 6 套 `style.css` 顶部统一新增；Agent 侧公开 `density` 参数 |
| 换字体 | 全部通过 `style.css` 的 `@font-face` 引入；WeasyPrint 需要**服务器端**存在字体文件 |

**易踩坑**：
- Jinja2 与前端框架的 `{{ }}` 冲突：如果模板需要真的输出 `{{ }}` 字面量，用 `{% raw %}{% endraw %}` 包裹。
- CSS `float` / `flex` 在 WeasyPrint 支持有差异，改版式要跑一遍 PDF 兜底验证。
- 头像 data URI 会让 HTML 变大（几百 KB），页面卡顿场景请压缩到 240px。

## 8. 与其他模块的关系

| 模块 | 关系 |
|------|-----|
| `app/tools/resume_sidebar/` | 在线主流水线的门面，最终 render `sidebar` 模板 |
| `app/resume_pipeline/pipeline.py` | 离线批量渲染，跨 4 套模板 |
| `app/tools/resume_export/` | 拿 HTML 生 PDF（WeasyPrint / xhtml2pdf） |
| `app/resume_pipeline/schema.py` | Pydantic schema，与本目录 `resume_schema_full.json` 对齐 |
