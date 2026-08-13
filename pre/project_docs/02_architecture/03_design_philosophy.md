# 03 · 整体设计理念

> 本文档梳理 Interview Agent 项目在**整体架构层面**的 10 条核心设计原则。它们回答"为什么这样分层、这样组织"。模块级的具体权衡放在各自 `1x_module_*.md` 的"核心设计理念"章节。

---

## 原则 1 · 协议与业务解耦

**取舍**：不把 A2A/Claw 协议知识渗透进 Agent 主循环。

- 协议层 `app/claw_protocol/` 只负责 **Envelope ↔ JSON-RPC ↔ Python dict** 的翻译；
- `agent_executor.py` 是**唯一**知道协议细节的业务侧文件，向下暴露纯 Python 事件流；
- `agent.py` 完全不感知"我正在被什么协议驱动"，可以被脚本 / 单测 / 未来的 REST 接口直接复用。

**收益**：
1. 换协议只改一层（例如未来接入纯 REST 或 gRPC）；
2. 单测 Agent 时不需要拉起 WebSocket；
3. 语音链路 `interview_ws.py` 走独立协议但复用相同的 LLM/Skill 抽象。

---

## 原则 2 · Skill 即 Markdown（Prompt as Code but not Code）

**取舍**：把技能定义放在 `app/skills/*.md`，用 `_loader.py` 扫描组装。

- 一个 `.md` = 一个 Skill；文件名即技能名；改产品体感 = 改文件；
- `_system_prompt.md` + `_product_contract.md` 是**所有技能**共同前缀，收敛"角色/硬约束"；
- 技能间的差异用**暴露工具子集**+**独立 md**表达，避免 if-else 堆积。

**收益**：
1. 产品/运营可直接改 prompt，不动 Python；
2. Prompt 版本可 diff、可回滚（git）；
3. 新增技能只需一个 md 文件 + 一次工具子集配置。

---

## 原则 3 · 工具即函数（Tool as Pure Function）

**取舍**：每个业务能力封装为 `@tool` 装饰的**纯 Python 函数**。

- 输入用 Pydantic 声明；
- 输出返回结构化 JSON（供 LLM 消费）；
- 副作用（写 VFS、写索引）**由工具自身完成**，不下沉给 Agent；
- 每个工具**可脱离 LangGraph 单测**。

**收益**：
1. LLM 决定"用不用"，工程师决定"怎么用"，边界清晰；
2. 单测友好 —— `pytest test/tools/xxx.py` 不需要真实 LLM；
3. 复杂子系统（如 `resume_sidebar/`）可以是一个内部包，工具只作为**门面**（Facade）。

---

## 原则 4 · 记忆双轨制

**取舍**：短期记忆走 LangGraph MemorySaver，长期记忆走 VFS 索引。

| 维度 | 短期（MemorySaver） | 长期（memory/*） |
|------|------------------|-----------------|
| 键 | `thread_id = context_id` | `user_id` |
| 生命周期 | 进程内、会话内 | 跨天、跨设备 |
| 数据 | 完整消息历史 | 简历索引 / 素材库 / AI 标记 / 错题 |
| 载体 | 内存 dict | BlueClaw VFS JSON |

**收益**：
1. 会话内低延迟、高保真；
2. 会话间只保留"事实"，不带脏上下文；
3. 若换 Agent 实现，只需重放 VFS 索引即可"记得"用户。

---

## 原则 5 · VFS 中心化，`file_id` 是通用语言

**取舍**：所有产物（简历 HTML/PDF、报告、录音、头像）都落 BlueClaw VFS，跨模块引用一律用 `file_id`。

- 路径统一为 `users/{uid}/<domain>/<version>/<filename>`；
- 前端拿到 `file_id` 后调 VFS 下载即可，**Agent 不当二传手**；
- 索引 JSON 只存 `file_id` + 元数据，不存原文。

**收益**：
1. 大文件不进入 LLM 上下文；
2. 前后端解耦：文件下载路径独立于 Agent WebSocket；
3. 天然多设备同步（用户中心化路径）。

---

## 原则 6 · 事件流是稳定契约

**取舍**：Agent 向上只承诺六类事件（`token / tool_use / tool_result / tool_error / final / llm_usage`）。

- 内部 LangGraph 结构可以随意演进；
- 六类事件的**语义**必须保持稳定；
- 前端渲染策略基于事件语义，不依赖 payload 具体字段名。

**收益**：
1. Agent 内部可以自由重构 / 加节点 / 换 checkpointer；
2. 未来加"计划事件（plan）""确认事件（ask_confirm）"是加法，不是破坏。

---

## 原则 7 · 多层防御（Defense in Depth）

**取舍**：对高风险产出（简历中的 URL、AI 幻觉字段）建立多层守卫。

- **URL 三层**：占位符替换 → 真实 URL 匹配 → 截断 URL 修复；
- **AI 标记**：LLM 补全的可疑字段用 `<<<...>>>` 包裹，跨轮持久化，前端高亮；
- **素材可信度闸门**：`source ∈ {user_input, ai_generated, deprecated}`，渲染优先 `user_input`；
- **上下文裁剪**：`_MAX_MEMORY_CHARS=50000`；
- **孤立 tool_calls 清理 / 幽灵回显防护**：防止 LangGraph 状态污染。

**收益**：即使 LLM 抽风，产物也在可控边界内，用户能一眼看到"哪里可疑"。

---

## 原则 8 · 上游解析与在线渲染分离

**取舍**：把"从 PDF/图片提取结构化数据"的重活放到**离线工具链** `resume_pipeline/` 和 `resume_html_gen_code/`。

- 在线主 Agent 只处理**已经结构化的 schema**；
- 视觉解析（qwen-vl 双次调用）、头像抠取（OpenCV/PyMuPDF）都放在离线；
- 在线渲染路径尽量确定性（Jinja2 + 6 套模板）。

**收益**：
1. 主链路延迟可控；
2. 视觉模型的失败不会阻塞聊天；
3. 离线管线可批量、可重跑。

---

## 原则 9 · 单端口多路复用 vs 独立链路

**取舍**：主 Agent 走 `/blueclaw/core`（Claw 协议），语音走 `/ws/interview`（独立协议）。

- **不强行**把语音塞进 Claw 协议 —— 语音数据面（PCM/opus 二进制流 + 低延迟往返）与文字控制面差异太大；
- 但**共享同一个 FastAPI 进程**，方便部署；
- 通过 `_build_voice_session_data` 让语音会话能读到主 Agent 的历史与简历。

**收益**：单进程部署 + 通道各得其所。

---

## 原则 10 · 保守增量 & 显式取舍

**取舍**：项目在多处显式选择**保守**而非"最漂亮"。

- 上下文裁剪用**字符数**而非 token 数：牺牲精度换实现简单与鲁棒；
- PDF 渲染用 WeasyPrint 首选 + xhtml2pdf 兜底：牺牲极致美观换 Linux 兼容与部署简单；
- MemorySaver 用内存实现：进程重启会丢，但换来零依赖启动 —— 需要跨进程时再升级；
- Agent `_RECURSION_LIMIT = 25`：宁可打断，不要死循环烧钱；
- `_TOOL_RESULT_PREVIEW = 4000` 截断：宁可截断，不要塞爆上下文。

**收益**：每一个"限制"都是可解释的、可调的、易于线上排查的。

---

## 反模式清单（我们主动避免的做法）

| 反模式 | 我们不这么做 | 原因 |
|--------|-------------|------|
| Agent 主循环调协议 send | 由 `agent_executor` 适配 | 违反原则 1 |
| Prompt 硬编码在 Python | 都放 `skills/*.md` | 违反原则 2 |
| 工具直接返回大 blob 给 LLM | 落 VFS，返回 `file_id` | 违反原则 3、5 |
| 用 SQL 数据库存索引 | 用 VFS JSON | 减少依赖 |
| 让前端拼简历 HTML | 后端 Jinja2 渲染 + 6 套模板 | 保证品质与一致性 |
| 让 LLM 自由输出 URL | 三层守卫 | 违反原则 7 |

---

## 阅读下一站

各模块具体的"该模块层面的设计权衡"，见对应 `1x_module_*.md` 的第 4 节。
