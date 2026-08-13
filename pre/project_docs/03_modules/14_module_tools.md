# 14 · 模块 · 工具集 `app/tools/`

## 1. 模块定位

工具层是 Agent 的"手脚"。每个工具是一个 `@tool` 装饰的 Python 函数，声明输入 Schema、返回结构化 JSON、可能自带副作用（写 VFS、写索引、发外呼）。LLM 通过 tool_calls 触发，Agent 负责调度与事件回推。

一句话：**LLM 决定用不用，工具决定怎么做**。

## 2. 工具全景（按业务域分组）

### 2.1 简历生成 / 优化 域

| 工具 / 子包 | 职责 |
|-----------|------|
| `resume_parser.py` | 解析用户上传的简历（PDF/Word → HTML）；本地路径或 `file_id` 输入 |
| `resume_scope.py` | **作用域保护**：局部优化时只暴露指定字段，其余冻结，防止 LLM 越界改动 |
| `resume_memory_tool.py` | 历史简历查询、三级命中（精确/模糊/兜底）、分组视图 |
| `master_profile_tool.py` | 素材库读写：沉淀事实 + 拉取可用素材（详见 `16_module_memory.md`） |
| `jd_extractor.py` | 从 JD 文本抽取岗位/公司/技能要求 |
| `resume_sidebar/`（子包） | 侧栏版简历 HTML 渲染核心（含 pipeline、prompt 拼装） |
| `resume_template_sidebar.py` | 兼容层：re-export `resume_sidebar/` 全部符号 |
| `resume_sidebar_constants.py` / `resume_sidebar_prompts.py` | sidebar 渲染的 Prompt 和关键词 |
| `resume_docx/`（子包） | Word (`.docx`) 渲染核心 |
| `resume_template_docx.py` | 兼容层：re-export `resume_docx/` |
| `resume_export/`（子包） | Markdown → HTML → PDF → VFS 全链路（含 `html_to_pdf` WeasyPrint/xhtml2pdf 兜底） |
| `company_type_detector.py` | 公司类型识别（国企/外企/互联网/…） |

### 2.2 面试 / 复盘 域

| 工具 | 职责 |
|------|------|
| `interview_search.py` | 面试题检索（走搜索引擎聚合） |
| `market_insight.py` | 市场薪资 / 职位洞察 |
| `error_book.py` | 错题本落盘 + 渲染 HTML |
| `voice_error_book_judge.py` | 语音面试轮次是否记入错题本的判定 |
| `voice_record_tool.py` | 语音面试逐题问答记录提取（TXT/Markdown） |
| `review_tool.py` | 错题复习：艾宾浩斯曲线抽题 + 逐日计划 |
| `review_report_tool.py` | 面试复盘报告生成、落 VFS、检索 |
| `review_report_check.py` | 面试复盘报告结构校验（Schema/字段） |

### 2.3 检索 / 外呼 域

| 工具 | 职责 |
|------|------|
| `search_engines.py` | **统一搜索网关**：多引擎管理 + RRF 融合排序 |
| `volc_search.py` | 火山搜索适配器 |
| `doc_agent_tool.py` | 调用远端文档 Agent 做排版/翻译/格式转换（**只做格式，不改内容**） |
| `doc_agent_client.py` | A2A WebSocket 客户端，复用 `claw_protocol` envelope 编解码 |
| `audio_tools.py` | 语音 STT / TTS |

### 2.4 基础设施域

| 工具 | 职责 |
|------|------|
| `datetime_tool.py` | 服务器当前时间（LLM 不知道"今天"，必须靠此工具） |
| `auth_util.py` | HMAC 签名头生成 |
| `skill_loader_tool.py` | 动态 skill 加载（让 LLM 在运行时切换或声明 skill） |
| `text_quality.py` | 文本质量检测（R74 乱码检测等） |

## 3. 对外契约（工具的一般形态）

```python
from langchain_core.tools import tool
from pydantic import BaseModel, Field

class ExtractArgs(BaseModel):
    jd_text: str = Field(..., description="JD 原文")

@tool("jd_extractor", args_schema=ExtractArgs)
def jd_extractor(jd_text: str) -> dict:
    """从 JD 文本提取岗位/公司/技能要求。"""
    ...
    return {
        "job_title": "...",
        "company": "...",
        "required_skills": [...],
        # 结构化 JSON，供 LLM 直接消费
    }
```

**返回值原则**：
1. 一定是 JSON 可序列化的 dict / list / str；
2. 大对象（>4000 chars）应落 VFS 返回 `file_id`，不直接塞回 LLM；
3. 错误应 `raise` 或返回 `{"error": "..."}`，由 Agent 转成 `tool_error` 事件。

## 4. 核心设计理念（模块级）

1. **纯函数 + 副作用显式化**  
   工具函数是"入口 → 出口"的纯函数；副作用（写 VFS、外呼）在函数体内**同步完成**，不通过全局变量隐式传递。

2. **门面（Facade）+ 内部子包**  
   复杂工具（如简历渲染）把主逻辑放子包（`resume_sidebar/`、`resume_docx/`、`resume_export/`），根目录仅保留一个薄门面模块（`resume_template_sidebar.py`），便于：
   - 门面级向后兼容（re-export）；
   - 内部大重构不影响 tool 声明。

3. **每工具可脱离 Agent 单测**  
   工具不依赖 LangGraph runtime，`pytest test/tools/xxx.py` 直接调用即可，MOCK LLM 时也不需要拉 Agent。

4. **参数 Pydantic 校验前置**  
   在函数入口就校验，把"LLM 传参乱码"挡在业务外。

5. **工具白名单按 Skill 隔离**  
   避免 LLM 在错误场景选到错误工具（例如面试场景不应看到 `resume_export`）。

## 5. 典型调用链

以"简历导出 PDF"为例：

```
LLM 判定 → tool_use(resume_export.export_pdf, {html_file_id, template})
  ↓
Agent 分发 → tools.resume_export.export_pdf(...)
  ↓
    1. 从 VFS 下载 html
    2. html_to_pdf(html)      ← weasyprint → 失败则 xhtml2pdf
    3. 上传 pdf 到 VFS         ← 得到 pdf_file_id
    4. 更新 resume_index      ← memory.resume_index.append(...)
    5. return {"pdf_file_id": ..., "vfs_uri": ...}
  ↓
Agent 发 tool_result 事件（预览截断 4000 chars）→ 前端展示"简历 PDF 已生成" 卡片
```

## 6. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增工具 | 在 `app/tools/` 新建 `.py`，用 `@tool` 装饰；在 `agent._agent_tools_for(skill)` 相应 skill 加入白名单 |
| 工具产物很大 | 先落 VFS 再返回 `file_id`；不要直接返回 base64 大对象 |
| 工具需要 LLM | 调用 `build_chat_model()`；不要在工具内递归调用主 Agent |
| 工具需要外呼 | 走 `auth_util.py` 签名 + `aiohttp`；异常统一 raise，Agent 会转 `tool_error` |
| 工具需要长时间 | ≤5s 同步；更长应异步任务化并返回 `task_id`（目前主链路无此需求） |

**易踩坑**：
- 工具函数**必须**有 docstring，LLM 依赖 docstring 决定调用；docstring 里要说清"何时用、参数含义、返回结构"。
- 工具名跨 Skill 唯一——避免 LLM 混淆。
- Pydantic v2 与 v1 的 Field 语法不同，本项目全用 v2。

## 7. 与其他模块的边界

| 依赖方向 | 说明 |
|---------|------|
| tools → vfs | 通过 `app.vfs.tools`（有些工具直接用 `vfs.client`） |
| tools → memory | 索引读写、素材库、AI 标记 |
| tools → llm | 需要 LLM 子任务时调 `build_chat_model()` |
| tools ← agent | 被 LangGraph 通过工具白名单调用 |
| tools ← skills | 白名单在 md 里描述、在 Python 里注册 |
