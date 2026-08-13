# 01 · Agent Executor 主链

## 一句话概括

`app/agent_executor.py` 是全项目所有业务功能的**调度中枢**。司棋在该文件上有 47 次提交（该文件最活跃改动者），blame 占比 28.7%，是四人共治文件里最主要的**动态维护者**。

---

## 核心数据卡片

| 指标 | 数值 |
|:---|---:|
| 司棋提交数（该文件） | **47** |
| 该文件当前总行 | 1,961 |
| Blame 分布 | 11099826 40.3% / **司棋 28.7%** / yitong 18.0% / 陈乾 12.4% / 11197109 0.6% |
| 特征 | 四人共治，司棋是提交活跃度 #1 |

---

## 背景

Agent Executor 承担：
1. LLM 消息流的编排
2. 工具调用调度
3. artifact / statusUpdate 事件生成
4. 上下文管理（会话历史、metadata 透传）
5. 兜底与错误处理

任何业务方新增 skill / tool，都要在此接入。

---

## 时间线（司棋在 executor 上的关键提交）

| 日期 | Commit | 关键动作 |
|:---:|:---|:---|
| 06-10 | 增加全工具异步, 减少卡顿 | **异步化基座** |
| 06-11 | feat(memory): 支持 BlueClaw 透传 history（双轨兼容） | 历史注入 |
| 06-12 | fix(executor): 兼容 BlueClaw 平铺 file part，修复录音/文件 url 被丢弃 | 协议兼容 |
| 06-23 | feat: 用 INPUT_REQUIRED 锁定 task 防止主 Claw 切走 sub-agent | **锁设计** |
| 06-24 | feat(executor): NEED_MEMORY 场景不附加复述指令 | 场景细化 |
| 07-16 | feat(agent_executor): 文档Agent链接注入metadata.resources兜底传递 | Doc Agent 联动 |
| 07-21 | fix(format_document): 修复复合任务场景下文档Agent收到错误file_url | Doc Agent bug |
| 07-29 | fix(agent): 上下文超限时裁剪旧消息，防止模型返回空响应 | **上下文裁剪** |
| 07-30 | fix(agent): 上下文裁剪改为按字符数保留，避免一刀切丢光历史 | 裁剪优化 |
| 08-07 | fix: format_document pdf_tip 由 executor 直接拼接，不走 LLM 转发 | 确定性输出 |

---

## 方案 / 代码证据

### 5 大关键设计（司棋主导）

1. **全工具异步化**（06-10）：所有工具走 async 通道，避免阻塞
2. **INPUT_REQUIRED 锁**（06-23）：详见 [08_input_required_lock.md](./08_input_required_lock.md)
3. **BlueClaw history 双轨兼容**（06-11）：老/新协议同时接受
4. **上下文裁剪按字符数**（07-30）：详见 [06_context_truncation_and_token.md](./06_context_truncation_and_token.md)
5. **pdf_tip 直拼**（08-07）：确定性输出替代 LLM 幻觉

---

## 量化成果

| 维度 | 成果 |
|:---|:---|
| 支撑的业务方 | 简历（11099826）、语音（yitong）、复盘（陈乾）、VLM（11197109） |
| 稳定性 | 异步化 + 锁 + 裁剪 三层稳态设计 |
| 与 11099826 的分工 | 11099826 建立骨架（40% blame），司棋维护迭代（29% blame + 47 提交） |

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="司棋" -- app/agent_executor.py --pretty=format:"%ad|%s" --date=short
git blame --line-porcelain app/agent_executor.py | grep "^author " | sort | uniq -c | sort -rn
```
