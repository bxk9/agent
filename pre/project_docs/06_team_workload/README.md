# 06 团队工作量画像 · 目录

> **章节定位**：以 git 客观数据（提交数 / 增删行 / 文件热度 / commit message 时间线）为基础，为项目的每位主要贡献者绘制一份"可核验、可复盘、可对外展示"的工作量画像。风格延续 `docs/design/20260729_LLM思考耗时优化_实测验证与补充方案.md`：数据 → 时间线 → 方案 → 版本历史。
>
> **数据口径**：以 `git log --author="<name>"` 为唯一事实源。所有取数命令均在文末"取数口径"章节完整列出，任何人可原地复现。

---

## 团队构成与工作量分布（截至 2026-08-10）

| 排名 | 贡献者 | 提交数 | 起止 | 天数 | 增/删行 | 涉及文件 | 主战场 | 详细文档 |
|:---:|:---|---:|:---:|---:|:---:|---:|:---|:---|
| #1 | **11099826** | 381 | 06-05 → 08-10 | 66 | +108k / −22k | 2,126 | 简历生成 / 侧边栏 / DOCX·PDF 渲染 | [11099826_resume_core/](./11099826_resume_core/README.md) |
| #2 | **yitong** | 283 | 06-04 → 08-10 | 68 | +25k / −8k | 532 | 语音面试 / Prompt / 错题本 / 耗时优化 | [yitong/](./yitong/README.md) |
| #3 | **司棋（李司棋）** | 252 | 06-04 → 08-07 | 65 | +43k / −22k | 697 | Agent Executor / VFS / 文档 Agent / LLM 网关 | [siqi_agent_infra/](./siqi_agent_infra/README.md) |
| #4 | **陈乾** | 88 | 06-09 → 08-07 | 60 | +2k / −0.4k | 83 | 面试复盘 skill / ASR / review_report | [chenqian_review/](./chenqian_review/README.md) |
| #5 | **11197109** | 28 | 07-16 → 08-07 | 23 | +4.8k / −0.9k | 52 | VLM 视觉模型 / 头像提取 / 版式解析 | [11197109_vlm/](./11197109_vlm/README.md) |
| #6 | **陈妮** | 20 | 06-15 → 08-05 | 52 | +258 / −104 | 9 | 语音面试 Prompt / 出题策略 | [chenni_voice_prompt/](./chenni_voice_prompt/README.md) |
| #7 | **张梦宇** | 10 | 07-28 → 08-03 | 7 | +38 / −50 | 7 | 语音面试环境 / 安全合规 prompt | [zhangmengyu_voice_infra/](./zhangmengyu_voice_infra/README.md) |
| — | *团队协作矩阵* | — | — | — | — | — | 基于 `git blame` 的行级 Ownership 客观校验 | [07_ownership_matrix.md](./07_ownership_matrix.md) |

> 说明：本目录涵盖 **7 位主要贡献者**（包括本人 yitong 与其他 6 位），全部规格一致、平行排列。合计 7 人占该仓库 99% 提交量。

---

## 责任地图（Ownership Matrix）

按代码模块归属划分主要 Owner / Contributor：

| 代码域 | 关键路径 | Owner | Contributor |
|:---|:---|:---|:---|
| 简历渲染 | `app/tools/resume_*`、`resume_templates/`、`resume_docx/` | 11099826 | 11197109 |
| 简历侧边栏 pipeline | `app/tools/resume_sidebar/` | 11099826 | 11197109 |
| VLM 视觉/头像 | `resume_html_gen_code/`、头像提取链路 | 11197109 | 11099826 |
| Agent Executor 主链 | `app/agent_executor.py` | 司棋 | yitong / 11099826 / 陈乾 |
| VFS 云空间 | `app/vfs/` | 司棋 | 11099826 |
| 文档 Agent 桥接 | `app/tools/doc_agent_*` | 司棋 | — |
| LLM 网关 | `app/llm/blueclaw_chat.py`、`vivo_chat.py` | 司棋 | yitong |
| 语音面试主链 | `app/voice/interview_ws.py` | yitong | — |
| 语音面试 prompt | `app/voice/interview_prompts.py` | 陈妮 | 张梦宇 |
| 语音面试 skill | `app/skills/mock_interview_voice.md` | yitong | 陈妮 / 张梦宇 |
| 面试复盘 skill | `app/skills/interview_review.md`、`review_report_tool.py` | 陈乾 | — |
| ASR / 音频工具 | `app/tools/audio_tools.py` | 陈乾 | — |
| 错题本 | `app/tools/error_book.py`、`voice_error_book_judge.py` | yitong | — |
| 可观测性 | `app/utils/ctx_log.py`、埋点 | yitong | 司棋 |

---

## 文档阅读建议

- **想快速看每人做了什么**：先看每篇文档的"一句话概括 + 核心数据卡片"（首屏 30 秒）。
- **想按主题追溯**：参考"责任地图"，从模块反查 Owner。
- **想核验数字**：每篇文档末尾都附有"取数命令"，可原地跑 `git` 验证。
- **想看整体节奏**：见 [`yitong/10_commit_timeline.md`](./yitong/10_commit_timeline.md) 的 W1-W10 周历。

---

## 每人文档集统一规格

每位贡献者都拥有一个**独立子目录**，内含：

- `README.md`：目录入口 + 数据卡片 + 索引表
- `00_workload_overview.md`：工作量总览（责任地图 · 阶段划分 · 能力标签）
- `01 ~ 0N_*.md`：按主题划分的专题文档（每人 4-10 篇）
- `0N_commit_timeline.md`：完整提交时间线（按周精粹）

每篇专题文档采用**六段式结构**：
1. 一句话概括
2. 核心数据卡片
3. 背景 / 问题 / 时间线
4. 方案与代码证据
5. 量化成果 + 与团队协作
6. 版本历史 + 取数命令

---

## 全局取数口径（供任何人复现）

```bash
# 1. 全部贡献者排行
git shortlog -sne --all

# 2. 单人提交总数、起止日期
git log --author="<name>" --pretty=format:"%ad" --date=short | sort | awk 'NR==1{f=$0} {l=$0;c++} END{print c,f,l}'

# 3. 单人增删行、涉及文件总数
git log --author="<name>" --shortstat --pretty=format:"" | \
  awk '/files? changed/ {f+=$1; for(i=1;i<=NF;i++){if($i~/insertion/)i2+=$(i-1);if($i~/deletion/)d+=$(i-1)}} END{print f,i2,d}'

# 4. 单人高频文件 TOP 20
git log --author="<name>" --name-only --pretty=format: | \
  grep -v '^$' | sort | uniq -c | sort -rn | head -20

# 5. 单人月度节奏
git log --author="<name>" --pretty=format:"%ad" --date=format:"%Y-%m" | sort | uniq -c

# 6. 单人 commit 主题时间线（去重）
git log --author="<name>" --pretty=format:"%ad|%s" --date=short | awk -F'|' '!seen[$2]++'
```

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立团队工作量画像章节，覆盖 6 位主要贡献者（单文件版） |
| v2.0 | 2026-08-10 | 升级为**每人独立文档集**（子目录 + README + 多篇专题），规格全员对齐 |
| v3.0 | 2026-08-10 | 目录从 `07_team_workload/` 更名为 `06_team_workload/`；`06_workload_showcase/` 迁入并更名为 `yitong/`，7 位贡献者平行排列 |
