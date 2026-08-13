# 张梦宇 · 语音基础设施工作量展示

## 一句话概括

张梦宇（10 提交）主导 **语音面试基础设施与安全合规**——环境配置、默认启动、对话检索修复、安全合规 prompt 等，是**语音链路稳定运行的基石**。

---

## 文档索引

| # | 文档 | 主题 |
|:---:|:---|:---|
| [00](./00_workload_overview.md) | 工作量总览 | 责任地图 · 阶段划分 · 能力标签 |
| [01](./01_voice_env_launch.md) | 环境配置与默认启动 | feature/voice-demo 分支 · 默认面试类型 |
| [02](./02_dialogue_query_fix.md) | 对话检索修复 | find_dialogues_by_context_id 过滤 · 复盘答案错误 |
| [03](./03_safety_and_role.md) | 安全合规与角色定位 | 拒绝非面试请求 · prompt 调整 |
| [04](./04_commit_timeline.md) | 完整提交时间线 | W30-W31 |

---

## 关键数据

- **总提交**：10
- **主要活跃期**：2026-07-28 ~ 2026-08-03（约 1 周高密度）
- **核心文件域**：
  - `app/agents/voice_interview/*.py`（Agent 主链）
  - `app/tools/find_dialogues.py`（对话检索）
  - `app/agents/voice_interview/prompts/safety.py`（安全 prompt）
  - `.env` / 配置文件

## 三大特色

1. **短周期高价值**：1 周内完成配置、bug 修复、安全合规三大件
2. **业务闭环意识**：修复的 bug（context_id 过滤）直接影响复盘答案正确性
3. **合规能力**：安全 prompt + 角色定位约束

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |
