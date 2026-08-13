# 00 · 工作量总览

## 一句话概括

**11099826 是 Interview Agent 项目内工作量绝对第一（366 提交 / +108k 行 / 2126 文件）的核心贡献者**，独立主导了简历生成的完整业务链路：**上传解析 → AI 提取 → 归一化 → 侧边栏 pipeline → HTML/PDF/DOCX 渲染 → 模板矩阵 → AI 标记 → 场景扩展**。

---

## 核心数据卡片

| 维度 | 数值 | 说明 |
|:---|---:|:---|
| 总提交数 | **366** | 全项目 993 提交，占 36.9% |
| 时间跨度 | 66 天 | 2026-06-05 → 2026-08-10 |
| 代码增量 | +108,135 行 | 全项目 #1 |
| 涉及文件 | 2,126 | 全项目 #1 |
| 独立设计的包 | 2 个 | `resume_sidebar/`（35 文件）、`resume_docx/`（多子模块） |
| 独立设计的模板 | ≥6 套 | orange / grayheader / graybar / centeredblue / sidebar / card |

---

## 责任地图（自身范围内）

```
简历生成全链路
    │
    ├── [上传解析] resume_parser.py（23 次改动，Owner）
    │
    ├── [侧边栏 pipeline] resume_sidebar/（35 个文件，Owner）
    │     ├── pipeline.py (100 次 / 95.2% blame)
    │     ├── normalize.py (71 次 / 96.4% blame)
    │     ├── render_html.py (26 次)
    │     ├── ai_marks.py (21 次)
    │     ├── field_checkers/ (子包，5+ 文件)
    │     └── ...
    │
    ├── [DOCX/PDF 渲染] resume_docx/、resume_template_docx.py
    │     ├── _standard.py (31 次)
    │     ├── _sidebar.py (15 次)
    │     ├── _sections.py (15 次)
    │     └── _helpers.py (17 次)
    │
    ├── [模板矩阵] resume_templates/ (6+ 套 CSS+HTML)
    │
    ├── [Skill 层] resume_generator.md (46 次)、resume_opt_head.md (55 次)
    │
    ├── [素材库] memory/resume_index.py、master_profile 系列
    │
    └── [协作] agent_executor.py (43 次)、_system_prompt.md (Contributor)
```

---

## 阶段划分（10 个阶段）

| # | 阶段 | 时间 | 关键词 | 提交量级 |
|:---:|:---|:---:|:---|:---:|
| P1 | 基础搭建 | 06-05 → 06-11 | 上传解析 / 长连接 / doc·pdf 导出 | ~22 |
| P2 | 搜索能力 | 06-10 → 06-16 | JD 搜索 / RRF 融合排序 | ~10 |
| P3 | 多模板打通 | 06-16 → 06-30 | 双栏 / 原版样式 / 字体 | ~40 |
| P4 | 渲染全链路优化 | 06-29 | AI 标记 / 校园识别 / 排版折叠 | ~15 |
| P5 | 侧边栏+素材库 | 07-01 → 07-03 | Master Profile / 版本管理 / 真实性校验 | ~20 |
| P6 | 系统性升级 | 07-06 → 07-09 | 全面升级 / 排版偏好 / VFS 重构 | ~35 |
| P7 | 稳定性攻坚 | 07-08 → 07-13 | WebSocket 泄漏 / 长任务超时 | ~25 |
| P8 | STD2630 密集响应 | 07-09 → 07-11 | 专项测试快速修复 | ~15 |
| P9 | 三层防御 | 08-04 | Schema + 正则 + 归一化 | ~30 |
| P10 | scope 下沉+压缩+学术 CV | 08-08 → 08-10 | scope 检测下沉 / 两阶段压缩 / 学术字段 | ~50 |

---

## 能力标签（可对外展示）

| 标签 | 证据 |
|:---|:---|
| **业务主线独立 Owner** | 简历生成从 0 → 1 → N 的完整链路 |
| **包级重构能力** | 独立设计 `resume_sidebar/` 35 文件、`resume_docx/` 多子模块 |
| **模板架构设计** | 6+ 套模板矩阵 + 模板即数据模式 |
| **系统性设计方法论** | 三层防御范式（后被 yitong / 司棋复用） |
| **契约驱动开发** | AI 标记契约、字段真实性校验层 |
| **持续高强度输出** | 66 天日均 5.5 提交，W32 单周 110 提交 |
| **架构叙事担当** | `ARCHITECTURE.md` 39 次改动 |

---

## 相关文档

- [01_resume_parser.md](./01_resume_parser.md) — 上游解析入口
- [02_resume_sidebar_pipeline.md](./02_resume_sidebar_pipeline.md) — 侧边栏包
- [03_resume_docx_rendering.md](./03_resume_docx_rendering.md) — 渲染层
- [04_template_matrix.md](./04_template_matrix.md) — 模板矩阵
- [05_ai_marks_contract.md](./05_ai_marks_contract.md) — AI 标记
- [06_three_layer_defense.md](./06_three_layer_defense.md) — 三层防御
- [07_scope_downshift.md](./07_scope_downshift.md) — scope 下沉
- [08_master_profile_and_academic_cv.md](./08_master_profile_and_academic_cv.md) — 素材库与学术 CV
- [09_commit_timeline.md](./09_commit_timeline.md) — 完整时间线

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立总览 |
