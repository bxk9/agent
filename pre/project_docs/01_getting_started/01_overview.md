# 01 · 项目总览

## 1. 一句话定位

**Interview Agent** 是一个面向求职/面试/学习复盘场景的 AI Agent 后端服务：以 **Claw 云网关**作为协议入口、**LangGraph ReAct** 作为大脑、**vivo AI 网关 / BlueClaw / Google / OpenAI** 作为模型底座、**BlueClaw VFS** 作为存储底座，向前端提供三大核心技能。

## 2. 三大核心技能

| 技能 | 触发方式 | 主要产物 |
|------|---------|---------|
| **简历优化 / 生成** | 用户上传简历 或 "帮我优化简历" | HTML / PDF / Word；素材库；简历索引 |
| **模拟面试** | 文字聊天 / 语音双工 | 面试问答记录；错题本；错题复习计划 |
| **面试复盘** | 面试结束后触发 | 结构化复盘报告 + 索引 |

三大技能共享同一套 Agent 主循环、同一套记忆（thread_id = context_id）、同一套 VFS，只在 **Skill 提示词** 和 **暴露的工具子集** 上有差异。

## 3. 顶层特性

- **协议**：Claw V2 = **JSON-RPC 2.0** 承载于 **Protobuf Envelope**，通过 WebSocket `/blueclaw/core` 单端口多路复用；同时对内提供 `/ws/interview`（语音）和 `/voice` H5 页面。
- **Agent 框架**：LangGraph `create_react_agent` + `MemorySaver` 内存 checkpointer；`thread_id = context_id` 让**同一 A2A 上下文的所有请求共享记忆**。
- **多模型可切换**：`MODEL_SOURCE=vivo|blueclaw|google|openai` 环境变量热切；vivo 走 HMAC-SHA256 鉴权。
- **Skill 即 Markdown**：`app/skills/*.md` 是唯一权威 prompt 源；改产品体感 = 改 md，不需要重启逻辑代码。
- **工具即函数**：30+ `@tool` 装饰函数，`app/tools/` 每个业务能力一个模块，可独立单测。
- **VFS 中心化**：全部产物落 BlueClaw VFS，用户中心化路径 `users/{uid}/...`；`file_id` 是跨模块引用的唯一凭据。
- **事件流**：Agent 以 SSE 风格向上流出 `token / tool_use / tool_result / tool_error / final / llm_usage` 六类事件。
- **多层防御**：URL 三层保护（占位符→真实 URL→截断修复）、AI 标记 `<<<...>>>` 跨轮持久化、素材可信度闸门（user_input/ai_generated/deprecated）。

## 4. 技术栈

| 层 | 技术 |
|----|------|
| 语言 | Python 3.10+（推荐 3.11） |
| Web | FastAPI + Uvicorn / Starlette WebSocket |
| Agent | LangGraph + LangChain-Core |
| 校验 | Pydantic v2 |
| 协议 | Protobuf（Envelope）+ 自实现 JSON-RPC 层 |
| 模型 | vivo AI 网关（HMAC）/ BlueClaw / Google Gemini / OpenAI |
| 存储 | BlueClaw VFS（HTTP API） |
| 渲染 | Jinja2 + WeasyPrint（PDF 首选）/ xhtml2pdf（兜底）/ python-docx |
| 图像 | Pillow / OpenCV / PyMuPDF（简历头像抠取） |
| 语音 | 浏览器 MediaRecorder → 后端 WSS → vivo /chat/stream |

## 5. 目录结构（顶层）

```
interview_agent/
├── app/                        主应用（后端）
│   ├── main.py                 FastAPI 入口（/blueclaw/core, /ws/interview, /voice, /health）
│   ├── agent.py                InterviewAgent 主循环（stream 事件流）
│   ├── agent_executor.py       A2A / Claw 协议适配
│   ├── claw_protocol/          JSON-RPC over Envelope 协议层
│   ├── llm/                    LLM 工厂（vivo / blueclaw / google / openai）
│   ├── skills/                 *.md — 每个技能一个 Prompt 文件
│   ├── tools/                  @tool 工具函数（30+）
│   │   ├── resume_sidebar/     侧栏简历渲染子系统
│   │   ├── resume_docx/        Word 简历渲染子系统
│   │   └── resume_export/      HTML → PDF / DOCX 导出
│   ├── vfs/                    BlueClaw VFS 抽象
│   ├── voice/                  语音面试实时链路
│   ├── resume_pipeline/        简历上游离线解析管线（独立工具链）
│   └── utils/                  日志、缓存等横切工具
│
├── memory/                     持久化存储层（VFS 之上的业务索引）
│   ├── resume_index.py         简历版本索引
│   ├── ai_marks_store.py       AI 标记跨轮存储
│   ├── error_book_index.py     错题本索引
│   ├── review_report_index.py  面试复盘索引
│   └── master_profile/         素材库（事实源）
│
├── resume_templates/           6 套 HTML 简历模板 + Jinja2 渲染入口
│   ├── sidebar/                侧栏版（默认）
│   ├── orange/  grayheader/  centeredblue/  graybar/  card/
│   └── render_demo.py          离线渲染入口
│
├── messages/                   FlatBuffers .fbs + 生成产物
├── resume_html_gen_code/       上游视觉解析工具（qwen-vl 双次调用）
├── data/                       样例简历、样例 profile
├── logger/                     日志配置
├── test/                       测试用例
├── dev_tools/                  开发脚手架
├── web/                        前端 H5 页面
│
├── docs/                       变更类文档（bug / analysis / api / issues / security）
├── project_docs/               ← 本目录：结构类项目文档集
├── README.md                   项目根 README
└── ARCHITECTURE.md             运行手册（症状速查表）
```

## 6. 快速上手命令

```bash
# 1. 安装依赖
pip install -r requirements.txt

# 2. 配置 .env（关键项）
MODEL_SOURCE=vivo
VIVO_APP_ID=xxx
VIVO_APP_KEY=xxx
BLUECLAW_BASE_URL=...
BLUECLAW_TOKEN=...

# 3. 启动
python -m app
# 或
uvicorn app.main:app --host 0.0.0.0 --port 8000

# 4. 健康检查
curl http://localhost:8000/health
```

## 7. 三大对外端点

| 端点 | 协议 | 用途 |
|------|------|------|
| `/blueclaw/core` | WebSocket + Envelope + JSON-RPC | **主 Agent 入口**（三大技能） |
| `/ws/interview` | WebSocket（二进制 + JSON） | 语音面试实时链路 |
| `/voice` | HTTP GET | 语音面试 H5 页面 |
| `/health` | HTTP GET | 健康检查 |

## 8. 阅读下一站

- `02_architecture.md` — 建立整体架构心智
- `03_design_philosophy.md` — 理解为何如此设计
