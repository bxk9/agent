# 40 · 关键约定

> 本文汇总跨模块共享的**命名、路径、id、字段**约定。任何新代码请**先**读本文再动。

## 1. 标识符 · IDs

| ID | 语义 | 来源 | 用法 |
|----|-----|------|-----|
| `user_id` | 用户唯一标识 | Claw 网关下发（前端传入） | 一切用户数据路径前缀 |
| `context_id` | A2A 会话上下文 | Claw 协议 | = LangGraph `thread_id`，MemorySaver 键 |
| `session_id` | 语音会话 | 前端生成 / 后端接受 | `/ws/interview` 参数；VFS `voice_sessions/{sid}` |
| `person_id` | AI 标记的"目标画像" | 由 basic.name 归一或前端传 | `marks/{pid}.json` |
| `file_id` | VFS 内容引用 | `vfs.file_id.to_file_id(path)` | 跨模块引用、前端下载凭据 |
| `task_id` | 单次 JSON-RPC 请求 | Claw `TaskStore` 分配 | 取消/追踪，进程内 |

**硬约束**：
- `user_id` 必现于所有持久化路径；不允许"游客"匿名数据落 VFS。
- `context_id` 与 `session_id` 是**不同概念**，不要复用同一变量。

## 2. VFS 路径规范

统一入口：`vfs.namespace.build_user_path(uid, domain, version, name)`

```
users/{uid}/
  resume/
    v{N}/                          version=int，单调递增
      raw.pdf                      原始上传（可选）
      parsed.txt / parsed.html     离线管线产物
      schema.json                  中间层
      final_sidebar.html/pdf       在线主流水线产物
      final_docx.docx
      final_rebuilt.html/pdf       原版式（链路 B）
  resume_index.json                简历版本索引
  master_profile.json              素材库
  marks/{person_id}.json           AI 标记
  error_book/
    index.json
    q_{qid}.json                   qid 由错题工具生成
  review_reports/
    index.json
    r_{rid}.html
  voice_sessions/
    s_{sid}/
      record.txt / record.md
      audio_{i}.pcm                可选
```

**禁止**：
- 用 `user_name` 中文当路径（可能含空格/特殊字符）
- 跨用户共用同一 file_id（若需共享请复制到 `shared/`）
- 直接 `vfs.client.put_bytes(任意路径)`——**必须**过 `namespace.build_user_path`

## 3. Schema 字段规范

简历 schema 权威定义：`resume_templates/resume_schema_full.json` + `app/resume_pipeline/schema.py`（Pydantic）。

| 字段 | 类型 | 备注 |
|------|-----|------|
| `basic.name` | str | 必填 |
| `basic.avatar` | data URI or "" | 头像；空字符串表示无 |
| `basic.contacts[]` | list | `{type, value}` type ∈ phone/email/wechat/site/... |
| `basic.summary` | str | 一段话自评（可选） |
| `experiences[]` | list | `{company, position, from, to, bullets[], organization?}` |
| `projects[]` | list | `{name, role, from, to, bullets[], links[]}` |
| `education[]` | list | `{school, degree, major, from, to, ...}` |
| `skills[]` | list | `{group, items[]}` 或简单字符串数组 |
| `organizations[]` | list | 社会组织/协会/志愿 |
| `custom_sections[]` | list | `{title, items[]}` 自由段 |

**日期格式**：统一 `YYYY-MM` 字符串；`"至今"` / `"Present"` 均归一化为 `null` 或字面 `"至今"`（模板层判定）。

**URL 字段**：必须以 `http://` 或 `https://` 开头；相对路径视为非法（会被 Step 6 归一化清除）。

## 4. 素材可信度枚举

`memory/master_profile/` 中每条 fact 都有 `source` 字段：

| 值 | 含义 | 渲染优先级 | 可否被 AI 覆盖 |
|----|-----|-----------|--------------|
| `user_input` | 用户明确说过 | 最高 | ❌ |
| `ai_generated` | LLM 推测 | 中 | ✅（会带 `<<<>>>`） |
| `deprecated` | 已废弃 | 不展示 | — |

## 5. 事件类型（Agent 对外）

**唯一稳定集合**（六类），详见 `12_module_agent_core.md`：
```
token | tool_use | tool_result | tool_error | final | llm_usage
```

**语音链路事件**（独立集合，详见 `31_data_flow_voice.md`）：
```
session_started | stt_delta | llm_delta | error | session_ended
```

跨模块**不复用**事件名。

## 6. 命名规范

| 类别 | 规范 | 示例 |
|-----|-----|-----|
| Python 模块 | 小写下划线 | `resume_export.py` |
| Python 类 | 大驼峰 | `InterviewAgent` |
| 常量 | 全大写 | `_MAX_MEMORY_CHARS` |
| 内部符号 | `_` 前缀 | `_agent_tools_for(...)` |
| Skill md 文件 | 全局片段 `_` 前缀，独立技能无前缀 | `_system_prompt.md`, `resume_generator.md` |
| VFS domain | 单数小写 | `resume`, `error_book`, `review_reports` |
| file_id | opaque 字符串 | 不要在业务代码里 parse 结构 |

## 7. 环境变量清单

| 变量 | 必填 | 默认 | 说明 |
|-----|------|-----|------|
| `MODEL_SOURCE` | ✅ | `vivo` | `vivo` / `blueclaw` / `google` / `openai` |
| `VIVO_APP_ID` | vivo 时 | — | HMAC AppID |
| `VIVO_APP_KEY` | vivo 时 | — | HMAC AppKey |
| `VIVO_TEXT_MODEL` | — | `Doubao-Seed-1.6` | 文本模型名 |
| `BLUECLAW_BASE_URL` | ✅ | — | VFS + BlueClaw 网关基址 |
| `BLUECLAW_TOKEN` | ✅ | — | VFS/网关鉴权 |
| `GOOGLE_API_KEY` | google 时 | — | — |
| `OPENAI_API_KEY` | openai 时 | — | — |
| `PORT` | — | 8000 | Uvicorn 端口 |
| `LOG_LEVEL` | — | `INFO` | 日志级别 |

## 8. 编码规范速记

- Python ≥ 3.10，全程 async/await（LangGraph、FastAPI、HTTP 客户端）
- 类型注解**必写**（尤其对外 API）；内部 helper 可省略
- Pydantic v2；不用 v1 语法
- 长字符串（Prompt）走 `.md` 文件；短片段可用 f-string
- 日志：`logger.info/warning/error`；不要 `print`
- 异常：业务异常上报为 `tool_error` 事件；系统异常直接 raise，由 FastAPI 顶层捕获
- 不 catch 后静默：至少 `logger.exception(...)`

## 9. 常用调试命令速记

（完整清单见 `50_debugging_guide.md`）

```bash
# 启动
python -m app
# 或 uvicorn app.main:app --reload --port 8000

# 探测 vivo 网关
python -m app.llm.test_max_tokens

# 简历离线管线
python -m app.resume_pipeline.pipeline <name>

# 模板离线渲染
python resume_templates/render_demo.py sidebar resume_templates/sample_data.json > out.html

# 语音本地测试
python -m app.voice.test_voice_ws
```

## 10. 加新东西前必做检查

新增**模块**：
- [ ] 是否放在合适的 `app/xxx/` 或独立顶层目录
- [ ] 是否写 README（长度不限，至少列文件职责）
- [ ] 是否更新 `01_overview.md` 与 `02_architecture.md`

新增**工具**：
- [ ] `@tool` docstring 明确"何时用/入参/出参"
- [ ] Pydantic 参数校验
- [ ] `agent._agent_tools_for(skill)` 白名单登记
- [ ] 是否有单测

新增**Skill**：
- [ ] `skills/xxx.md` 描述完整
- [ ] 决定共享哪些全局片段（`_system_prompt.md` / `_product_contract.md`）
- [ ] 工具白名单配好
- [ ] 冒烟测试通过（送一条典型 query 观察事件流）

新增**VFS 路径**：
- [ ] 归属哪个 domain
- [ ] 是否更新本文档第 2 节
- [ ] 有无删除/覆盖时的风险
