# 50 · 调试指南

> 本文提供**症状 → 定位路径 → 常见根因**的速查表，与项目根 `ARCHITECTURE.md` 症状表互补——本文侧重"从 project_docs 视角如何路径追踪"，`ARCHITECTURE.md` 侧重"具体代码行号"。

## 1. 通用排查心法

1. **看事件流**：Claw 前端网络面板能看到六类事件顺序，缺哪一步就往哪一层查。
2. **看日志**：`app/utils/ctx_log.py` 附带 `context_id`；用 `grep ctx=xxx` 追踪一次会话。
3. **看 VFS**：产物有没有落？路径对不对？file_id 是否与索引里一致？
4. **看 MemorySaver**：多轮问题几乎都跟 `thread_id=context_id` 是否一致有关。
5. **二分定位**：主 Agent 出问题 → 先脱离 Claw 协议，直接 `await agent.stream(...)` 复现。

## 2. 症状速查表（简版）

| 症状 | 一眼定位 | 详细文档 |
|------|---------|---------|
| 前端一直转圈没 token | vivo/BlueClaw 网关问题；或 tool_use 卡住 | `11_module_llm.md` / `12_module_agent_core.md` TTFT |
| 简历生成失败 | `resume_export`/`html_to_pdf` 报错？WeasyPrint 缺字体？ | `30_data_flow_resume.md` Step 9 |
| 简历没记住上次改动 | context_id 变了 → MemorySaver 隔离 → thread 不共享 | `12_module_agent_core.md` §4.1 |
| AI 标记跨天丢失 | `marks/{pid}.json` 未持久化；或 person_id 变了 | `32_data_flow_ai_marks.md` |
| PDF 中文变方块 | 服务器缺 Noto CJK 字体；WeasyPrint 无法渲染 | `18_module_resume_pipeline.md` §7 |
| 简历 URL 变形 | 归一化第 3 层截断修复误伤 | `30_data_flow_resume.md` Step 6 |
| 语音无声 / 一直静默 | vivo 上行未建立；或 STT delta 从未收到 | `31_data_flow_voice.md` |
| 语音听不到面试官 | llm_delta 未回；或前端 TTS 未接 | `17_module_voice.md` §5 |
| 素材库越写越乱 | 缺少 source=user_input 判定；被 AI 覆盖 | `16_module_memory.md` §4.3 |
| 工具调用参数报错 | Pydantic 校验；LLM 拼参失败 | `14_module_tools.md` §4.4 |
| LangGraph 报 unmatched tool_call_id | 孤立 tool_calls 清理没生效 | `12_module_agent_core.md` §4.3 |
| 多副本部署下会话丢失 | MemorySaver 是进程内；无粘性会话 | `12_module_agent_core.md` §6 |
| vivo 全线 401 | 服务器时间偏移 ±5min | `11_module_llm.md` §6 |
| 前端下载文件 404 | file_id 对应路径已被移动/删除 | `15_module_vfs.md` §6 |

## 3. 事件流侦查表

Claw 前端把六类事件按顺序打印到控制台，可对照下表：

| 观察到 | 期望顺序 | 缺失/异常原因 |
|--------|---------|--------------|
| 有 tool_use，无 tool_result | LLM 决定调用了工具但工具卡死 | 工具死循环 / 外呼超时 |
| 有 token，无 final | 流式中断 | 网关断连 / _RECURSION_LIMIT 触顶 |
| 只有 final | 单次直接回复 | 正常（无需工具） |
| 无 llm_usage | 早期异常 | 检查 tool_error 是否先出现 |
| 一堆 tool_error | 权限 / 网络 / 参数 | 顺着 `error` 字段往上查 |

## 4. 分模块速查

### 4.1 Claw 协议
- 症状："消息发不出去 / envelope decode error"
- 检查：`app/claw_protocol/envelope.py` 版本是否与前端 SDK 匹配；抓 WebSocket 二进制看 magic byte

### 4.2 LLM
- 症状：延迟高
- 命令：`python -m app.llm.test_max_tokens`
- 检查：网关侧是否已 rate-limit；`MODEL_SOURCE` 与凭据是否匹配

### 4.3 Agent 核心
- 症状：多轮"记不住"
- 检查：日志中 `thread_id`；MemorySaver 是否被 shutdown 清空

### 4.4 Skills
- 症状：技能选错
- 检查：`_agent_tools_for(skill)` 白名单；`_loader.build_system_prompt` 拼装是否正确

### 4.5 Tools
- 症状：工具输出为空
- 定位：直接 pytest 单跑；对比 LLM 传参 vs 期望参数

### 4.6 VFS
- 症状：`404` / `403`
- 检查：`BLUECLAW_TOKEN`；用户命名空间路径 `users/{uid}/...` 是否正确

### 4.7 Memory
- 症状：素材/索引冲突
- 检查：`_vfs_json.py` 读改写窗口；单副本部署下几乎不会冲突

### 4.8 Voice
- 症状：STT 无输出
- 检查：前端音频编码（PCM/opus）是否与 vivo 期望匹配；分片大小

### 4.9 Resume Pipeline（离线）
- 症状：视觉解析失败
- 命令：`python run_parse.py <pdf> <name>` 单独复现
- 检查：`VIVO_APP_ID` / qwen-vl-plus 网关可用性

### 4.10 Templates
- 症状：渲染变形
- 命令：`python resume_templates/render_demo.py sidebar sample_data.json > out.html`
- 检查：Jinja2 转义；CSS 与 WeasyPrint 兼容性

## 5. 常见环境类错误

| 错误 | 根因 | 处理 |
|------|-----|------|
| `ModuleNotFoundError: weasyprint` | 未装 GTK3 / Cairo | Windows 装 GTK3 Runtime；Linux `apt install libpango-1.0-0 libcairo2 libgdk-pixbuf2.0-0` |
| `ImportError: fitz` | 未装 pymupdf | `pip install pymupdf` |
| `cv2` 缺失 | 未装 opencv | `pip install opencv-python-headless`（服务器建议 headless） |
| 中文乱码 | 服务器无 CJK 字体 | `apt install fonts-noto-cjk` |
| WebSocket 无法握手 | 反代未启用 WSS upgrade | Nginx / Traefik 配 `Upgrade: websocket` |

## 6. 一次典型的排查流程演示

**症状**：用户点"生成简历 PDF"，前端一直转圈，无 final。

1. **看事件流**：只有 `tool_use(resume_export.export_pdf)`，无 `tool_result` / `tool_error`。
2. **看日志**：定位到 `html_to_pdf` 内部 WeasyPrint 抛异常但被上层捕获。
3. **看代码路径**：`app/tools/resume_export/*.py` → `html_to_pdf` → 兜底 xhtml2pdf 也失败。
4. **看容器环境**：`ldd $(which weasyprint)` 或跑 `python -c "import weasyprint"` 发现 GTK3 缺失。
5. **修复**：安装依赖或用 Docker 镜像内置 GTK。
6. **回归**：单独跑 `python resume_templates/render_demo.py ... > x.html && weasyprint x.html x.pdf` 确认无错。

## 7. 相关文档

- 项目根 `ARCHITECTURE.md` — 更细的**运行手册**与**症状代码行号定位**
- `docs/bug_reports/` — 历史 bug 记录（真实案例）
- `02_architecture.md` — 建立整体调用链心智
- 各模块 `1x_module_*.md` — 模块内部细节

---

## ✅ 文档集完成

至此 `project_docs/` 文档集已覆盖：
- 总览 3 篇（overview / architecture / design_philosophy）
- 模块 11 篇（claw_protocol / llm / agent_core / skills / tools / vfs / memory / voice / resume_pipeline / messages / resume_templates）
- 数据流 3 篇（resume / voice / ai_marks）
- 约定 & 调试 2 篇（conventions / debugging_guide）
- 入口 2 篇（README / INDEX）

共 **21 篇文档**，可作为项目结构性知识的稳定基线。后续结构变更时同步更新对应文件即可。
