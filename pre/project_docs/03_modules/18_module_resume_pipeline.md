# 18 · 模块 · 简历上游解析管线 `app/resume_pipeline/` + `resume_html_gen_code/`

## 1. 模块定位

上游解析管线是**离线工具链**：把用户上传的简历 PDF/图片，通过视觉大模型转成**结构化 schema** + **视觉还原 HTML** + **头像图**。主 Agent 在线路径**不**触发这条管线（延迟太高），而是等它的产物落 VFS 后再消费。

一句话：**离线做重活，在线只消费**。

## 2. 全链路总览

```
简历图片 / PDF
    │
    ▼  [上游] resume_html_gen_code/resume_html_gen/run_parse.py
          qwen3-vl-plus × 2  (视觉 LLM)
          ├─ results/txt/<name>.txt        纯文字
          ├─ results/html/<name>.html      视觉还原 HTML（含 {{AVATAR}} 占位）
          └─ results/avatar/<name>.png     头像（PDF 嵌入图 / 人脸检测）
    │
    ▼  [中间层] app/resume_pipeline
          extract_resume_schema(raw_text, force_llm=True)
          ├─ vivo 文本 LLM（默认 Doubao-Seed-1.6）从 txt 抽严格 schema
          ├─ Pydantic 校验/补字段
          └─ inject_avatar_into_schema()  头像写入 basic.avatar (data URI)
    │
    ├─► 链路 A：render_all_templates(schema)
    │       resume_templates/{orange, grayheader, centeredblue, graybar}
    │       → final/<name>__<tpl>.html + .pdf  （4×2 份）
    │
    └─► 链路 B：inject_avatar_into_html(rebuilt_html)
            → final/<name>__rebuilt.html + .pdf  （保持原版式）
```

PDF 由 `app/tools/resume_export.html_to_pdf` 渲染（WeasyPrint 首选，xhtml2pdf 兜底）。

## 3. 文件清单

### 3.1 上游视觉解析（`resume_html_gen_code/resume_html_gen/`）

| 文件 | 职责 |
|------|------|
| `run_parse.py` | 入口：调 qwen-vl 两次（TXT + HTML）、抠头像 |
| `avatar_extractor.py` | PDF 优先抠嵌入图；否则 OpenCV 人脸检测扩边裁剪 |
| `optimize_avatar()` | resize 240px、autocontrast、可选圆形蒙版、输出 data URI |

### 3.2 中间层（`app/resume_pipeline/`）

| 文件 | 职责 |
|------|------|
| `schema.py` | Pydantic 严格 schema（含 organizations、experiences、projects、education、basic 等） |
| `extractor.py` | txt → schema（文本 LLM）+ 头像注入 |
| `pipeline.py` | 串联两条链路、HTML+PDF 落盘、CLI 入口 |

## 4. 对外契约

### CLI

```powershell
# 1. 上游视觉解析
cd resume_html_gen_code/resume_html_gen
python run_parse.py <resume.pdf|png> <name>
# 产物：results/{txt,html,avatar}/<name>.*

# 2. 端到端 pipeline
cd interview_agent
python -m app.resume_pipeline.pipeline <name>
# 可选：--no-pdf 只出 HTML
# 产物（results/final/）：
#   <name>__schema.json
#   <name>__<tpl>.html/.pdf  链路 A × 4 模板
#   <name>__rebuilt.html/.pdf 链路 B 原版式
```

### Python API

```python
from app.resume_pipeline.extractor import extract_resume_schema
from app.resume_pipeline.pipeline import run_pipeline

schema = extract_resume_schema(raw_text=txt, force_llm=True)
run_pipeline(name="alice", schema=schema, avatar_path="...", no_pdf=False)
```

## 5. 核心设计理念（模块级）

1. **双次视觉调用换准确率**  
   - 第一次让 qwen-vl 输出**纯文字**（用于结构化抽取）；
   - 第二次让 qwen-vl 输出**HTML**（用于原版式还原）。
   - 两个任务分开，各自优化 prompt，比一次多任务准确率高。

2. **中间层用文本 LLM 而非视觉 LLM**  
   文本 LLM（Doubao-Seed-1.6）在**长文本抽取**上更稳、更便宜；把视觉 LLM 只用于"看图"。

3. **Pydantic 严格 schema 是灵魂**  
   `schema.py` 的字段就是**在线渲染**的输入契约；一处定义、多处消费（extractor、templates、tools）。

4. **头像三级兜底**  
   PDF 嵌入图 → OpenCV 人脸检测 → 兜底占位图。任何一个失败不阻塞主流程。

5. **链路 A / B 双轨**  
   - **A 模板化**：满足"求职版式规范"（面向 HR、投递用），输出 6 套精心设计的模板；
   - **B 原版式**：保留用户上传时的排版（面向自我修改、复盘），只补真实头像。
   - 用户可选任一或全部。

6. **离线可批量、可重跑**  
   `run_parse.py` + `pipeline.py` 都是幂等 CLI；批处理只需外层脚本。

## 6. 典型调用链

```
用户上传 PDF
  → 前端上传到 VFS → 拿到 file_id
  → 触发离线任务（例如 celery / 手动 CLI）：
       download file_id → results/raw/<name>.pdf
       run_parse.py <pdf> <name>
       python -m app.resume_pipeline.pipeline <name>
       upload results/final/* to VFS (users/{uid}/resume/vN/)
       memory.resume_index.append_version(uid, {file_ids...})
  → 主 Agent 下次会话通过 resume_memory_tool 三级命中拿到最新版本
```

## 7. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增模板 | 在 `resume_templates/xxx/` 新建；在 `render_all_templates` 白名单登记 |
| 视觉模型迁移 | 只改 `run_parse.py` 的调用；schema 与下游不受影响 |
| 抽取失败率高 | 优化 `extractor.py` 的 system prompt；必要时加二次校验（Pydantic 报错则重跑） |
| 数据不含头像 | `optimize_avatar` 会返回默认占位图，模板中占位符仍有效 |

**易踩坑**：
- WeasyPrint 依赖系统字体，若 Linux 缺少中文字体（Noto CJK）会出乱码方块——见 `50_debugging_guide.md`。
- Windows 下 WeasyPrint 需要 GTK3 运行时；如未安装，pipeline 会自动降级到 xhtml2pdf。
- 头像 data URI 会显著增大 HTML 体积（几百 KB），批量导出注意磁盘。

## 8. 与在线主 Agent 的边界

| 维度 | 离线管线 | 在线 Agent |
|------|--------|-----------|
| 触发 | CLI / 后台任务 | WebSocket 消息 |
| 输入 | PDF/图片 | schema / 局部指令 |
| 视觉 LLM | qwen3-vl-plus × 2 | 不使用 |
| 产物 | schema.json + HTML + PDF | 索引更新 + 局部改写 |
| 时延 | 数十秒 | 秒级 |

在线路径只做**局部优化 + 重新渲染**（`resume_sidebar/` 子系统 + `resume_export`），完整重解析走离线。

## 9. 依赖

```
pip install requests pillow pymupdf opencv-python pydantic jinja2 langchain-core python-dotenv weasyprint
```

关键环境变量：
- `VIVO_APP_ID` / `VIVO_APP_KEY`
- 可选：`VIVO_TEXT_MODEL`（默认 `Doubao-Seed-1.6`）
