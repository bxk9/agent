# 陈乾 · 面试复盘工作量展示（chenqian_review）

## 一句话概括

陈乾（88 提交）主导 **面试复盘全链路**：从 ASR 音频转写接入、复盘 Skill 提示词工程、复盘报告 HTML 渲染，到跨会话报告索引、音频链接治理，是**"面试复盘"业务线的技术负责人**。

---

## 文档索引

| # | 文档 | 主题 |
|:---:|:---|:---|
| [00](./00_workload_overview.md) | 工作量总览 | 责任地图 · 阶段划分 · 能力标签 |
| [01](./01_review_skill_prompt.md) | 复盘 Skill 提示词工程 | 全覆盖 · 数字铁律 · 硬闸 |
| [02](./02_asr_audio_integration.md) | ASR & 音频链路 | 转写工具 · mime 白名单 · 超时兜底 |
| [03](./03_review_html_render.md) | 复盘报告 HTML 渲染 | 视觉分区 · 移动端自适应 · 序号溢出 |
| [04](./04_report_index_layer.md) | 跨会话报告索引 | save/query_review_report · VFS 上传 |
| [05](./05_audio_url_governance.md) | 音频 URL 域名治理 | public 短链 · 内网 vfs · 环境变量开关 |
| [06](./06_review_delivery_guard.md) | 交付前拦截与自检 | 逐题全覆盖 · 漏题记录 |
| [07](./07_commit_timeline.md) | 完整提交时间线 | W23-W32 按周精粹 |

---

## 关键数据

- **总提交**：88
- **主要活跃期**：2026-06-09 ~ 2026-08-07（约 9 周）
- **核心文件域**：
  - `app/agents/*/skills/*.md`（复盘 Skill）
  - `app/tools/asr*.py`（音频转写）
  - `app/tools/save_review_report.py` / `query_review_reports.py`（报告管理）
  - `app/agents/*/executor.py`（音频 URL 提取）

## 三大特色

1. **提示词工程深度**：单文件 Skill 迭代 15+ 次，"数字铁律""硬闸""同音变体"等原创约束
2. **HTML 端到端**：从模型输出到卡片渲染的全链路视觉治理
3. **音频链接治理**：本地路径拦截、mime 白名单、public / vfs 双域名切换

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |
