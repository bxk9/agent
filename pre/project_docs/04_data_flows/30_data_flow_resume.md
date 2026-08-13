# 30 · 数据流 · 简历渲染 10 步主流水线

> 本流程是**在线**简历生成/优化的核心。离线视觉解析见 `18_module_resume_pipeline.md`。

## 全景图

```
用户输入
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 1  recent_resume_cache 命中检查                          │
│ Step 2  精简历史 + 合并局部指令                                │
│ Step 3  Schema 格式校验（Pydantic）                           │
│ Step 4  LLM 抽取 / 局部改写                                   │
│ Step 5  隐私清理（PII 脱敏可选）                               │
│ Step 6  字段归一化（日期/URL/技能同义词）                       │
│ Step 7  HTML 渲染（resume_templates/sidebar）                 │
│ Step 8  AI 标记扫描 <<<...>>>（持久化 + 前端高亮）             │
│ Step 9  PDF / Word 导出                                       │
│ Step 10 VFS 上传 + resume_index 追加 + master_profile 落库    │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
返回 file_id 列表（html/pdf/docx）
```

## Step 1 · 缓存命中

- **模块**：`app/utils/recent_resume_cache.py`
- **键**：`(user_id, context_id, hash(schema))`
- **命中**：直接返回上次产物 file_id，跳到 Step 10 的返回
- **未命中**：进入 Step 2

**设计动机**：同一会话反复微调时，跳过重复解析/渲染。

## Step 2 · 精简历史 + 合并局部指令

- **模块**：`app/tools/resume_scope.py`
- **动作**：
  1. 从 MemorySaver 拿完整历史；
  2. 只保留"简历相关"消息（工具轮次 + 用户局部指令）；
  3. **作用域裁剪**：若用户说"只改工作经历第 2 条第 3 点"，则只把该字段暴露给 LLM，其余字段"冻结"。

**防御目标**：防止 LLM 在被要求"改一处"时全篇重写。

## Step 3 · Schema 格式校验

- **模块**：`app/resume_pipeline/schema.py`（Pydantic）
- **动作**：
  - 若输入是历史 schema，直接 Pydantic parse → 若失败尝试自动修补必填字段；
  - 若输入是纯自然语言，进入 Step 4 让 LLM 抽取。

## Step 4 · LLM 抽取 / 局部改写

- **模块**：`app/skills/resume_generator.md` + `build_chat_model()`
- **模型**：默认 vivo `Doubao-Seed-1.6`（文本任务）
- **产物**：新的 schema（或局部字段的 diff）
- **两种模式**：
  - **抽取模式**：文本 → schema（新简历）
  - **改写模式**：schema + 指令 → 新 schema（迭代优化）

## Step 5 · 隐私清理（可选）

- **模块**：内嵌在 `resume_sidebar/pipeline.py`
- **动作**：手机号/邮箱/身份证的可选脱敏；由用户偏好开关控制
- **默认**：不脱敏（求职简历要求完整联系方式）

## Step 6 · 字段归一化

- **URL 三层守卫**（本步骤核心）：
  1. **占位符替换**：LLM 常输出 `[LinkedIn]` / `[个人网站]` 之类占位符，替换为空或已知真实值；
  2. **真实 URL 匹配**：与素材库/历史简历中的真实 URL 做匹配，能对上即替换；
  3. **截断 URL 修复**：LLM 可能输出 `https://github.com/...`（省略号），尝试补全或删除。
- **日期归一化**：`2023.7` / `2023年7月` / `Jul 2023` → 统一 `2023-07`
- **技能同义词**：`k8s` ↔ `Kubernetes`，`Node` ↔ `Node.js`

## Step 7 · HTML 渲染

- **模块**：`app/tools/resume_sidebar/` + `resume_templates/sidebar/`
- **动作**：
  1. 选定 density（tight / normal / loose）
  2. Jinja2 渲染 `template.html`
  3. 内联 CSS + 头像 data URI
- **产物**：一个自包含的 HTML 字符串

## Step 8 · AI 标记扫描

- **模块**：`memory/ai_marks_store.py`
- **动作**：
  1. 扫描 HTML/schema 中所有 `<<<...>>>` 段落；
  2. 提取 `{path, hint, source}` 元数据；
  3. 与上次持久化的 marks diff，更新到 VFS；
  4. 在最终 HTML 中给 `<<<...>>>` 加高亮 span（可 CSS 控制）。
- **持久化键**：`user_id → person_id`（`person_id` 由 basic.name 或用户传入决定）

**详见**：`32_data_flow_ai_marks.md`

## Step 9 · PDF / Word 导出

- **模块**：`app/tools/resume_export/`
- **PDF**：
  - 首选 WeasyPrint（Linux 服务端主力）
  - 失败兜底 xhtml2pdf
- **Word**：`app/tools/resume_docx/` 独立生成（不是 HTML → docx，而是从 schema 直接构造 python-docx）

## Step 10 · VFS 上传 + 索引 + 素材

- **模块**：`app/vfs/tools.py` + `memory/resume_index.py` + `memory/master_profile/`
- **动作**：
  1. `put_text` HTML / `put_bytes` PDF、DOCX 到 `users/{uid}/resume/v{N}/`
  2. `resume_index.append_version(uid, {file_ids, company, position, ...})`
  3. 若本次抽取产生了新的**事实型**素材（`source=user_input`），落 `master_profile`
- **产物 返回给前端**：`{"html_file_id": ..., "pdf_file_id": ..., "docx_file_id": ...}`

## 事件时间线（前端能看到什么）

```
tool_use   (resume_scope)            "分析优化范围..."
tool_result                          
tool_use   (master_profile_tool)     "调取素材库..."
tool_result
tool_use   (resume_template_sidebar) "生成简历..."
  token stream                       (Agent 附带解释)
tool_result                          {html_file_id}
tool_use   (resume_export.pdf)       "导出 PDF..."
tool_result                          {pdf_file_id}
final                                "已生成，包含 X 处 AI 标记待确认"
llm_usage
```

## 关键失败点与降级

| 失败点 | 降级 |
|--------|-----|
| LLM 抽取 JSON 解析失败 | 自动重试 1 次；仍失败 → tool_error，前端提示"再说一次" |
| WeasyPrint 崩溃 | 自动 xhtml2pdf 兜底；若都失败仅返回 HTML |
| VFS 上传失败 | tool_error；产物**不**入索引，保持一致性 |
| master_profile 更新失败 | 不阻塞主流程，只记 warning |
| AI 标记落库失败 | 不阻塞；前端仍能看到标记，只是跨轮不持久 |

## 相关文档

- `18_module_resume_pipeline.md` — 离线视觉解析（Step 0）
- `20_module_resume_templates.md` — 模板细节
- `32_data_flow_ai_marks.md` — AI 标记完整生命周期
- `16_module_memory.md` — 素材库闸门与可信度
