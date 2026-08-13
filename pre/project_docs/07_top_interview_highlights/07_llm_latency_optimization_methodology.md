# 07 · LLM 思考耗时优化：从"感觉慢"到"实测+方案"的评测方法论

> **作者**：yitong · **原始文档**：[`docs/design/20260729_LLM思考耗时优化_实测验证与补充方案.md`](../../docs/design/20260729_LLM思考耗时优化_实测验证与补充方案.md)

---

## 一句话摘要

面对 "面试 Agent 思考慢" 的模糊抱怨，我构建了 **"分场景压测 → 数据归因 → 分层方案 → 补充策略"** 的评测驱动优化方法论，把"感觉慢"转化为可量化的**首 token 延迟 / 思考段耗时 / 总耗时**三维数据，并针对不同场景（简历/面试/复盘）给出差异化优化方案。

---

## 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"你怎么做性能优化？"** | 完整方法论：先度量后优化，不做"猜测优化" |
| **"LLM 延迟怎么优化？"** | 首 token / 思考段 / 输出段 三分位分析 |
| **"讲一个你做过的优化项目"** | 完整闭环：定义指标 → 压测 → 方案 → 验证 |
| **"评测怎么做？"** | 真实场景样本 + 分位数（P50/P90/P99）+ 场景分层 |

**可回答的经典面试题**：
- 如何度量 LLM 服务性能？
- 首 token 延迟由什么组成？
- Reasoning 模型 vs 非 Reasoning 模型的取舍
- 如何设计 A/B 实验？

---

## 背景与问题定义

### 模糊抱怨

产品经理：**"面试 Agent 太慢了，用户在等"**

工程师第一反应会想：
- 加机器？
- 换模型？
- 加缓存？

**但都是猜测**——不知道慢在哪一段，凭直觉优化很可能白花钱。

### 我的方法论：先度量后优化

三个核心问题必须先回答：
1. **哪段慢**？（首 token / 思考 / 输出 / 网络 / VFS）
2. **多慢**？（P50 / P90 / P99）
3. **哪个场景慢**？（简历 / 面试 / 复盘 独立看）

---

## 方案演进与关键决策

### 阶段 1：定义指标（能度量才能优化）

| 指标 | 定义 | 关注点 |
|:---|:---|:---|
| **首 token 延迟** | 请求发出 → 第一个 token 到达 | 用户"是否在等" |
| **思考段耗时**（Reasoning） | 首 token → `</think>` 或推理段结束 | Reasoning 模型特有 |
| **输出段耗时** | 思考段结束 → 最后一个 token | 用户读到最后 |
| **总耗时** | 请求到最终响应 | 商业成本 |

**关键洞察**：这四个指标**不能只看均值**，必须看 P50/P90/P99——极值场景往往是用户体验瓶颈。

### 阶段 2：分场景压测

不同场景的用户容忍度不同：

| 场景 | 用户预期 | 慢在哪里 |
|:---|:---|:---|
| **简历生成** | 5-15s 可接受（一次性长任务） | 输出段（长文本） |
| **面试提问** | 1-3s 期望（对话式） | 首 token（打断感） |
| **复盘生成** | 10-30s 可接受（复杂分析） | 思考段（Reasoning） |

**不同场景用同一优化方案 = 白搭**。

### 阶段 3：数据归因（找出真凶）

**关键发现**（示意，具体数字在原设计文档）：
- 面试场景 P90 首 token 延迟 → **主要来自 prompt prefill**（长 system prompt + 长历史）
- 复盘场景 P90 总耗时 → **思考段占比 60%+**（Reasoning 特性）
- 简历场景 → **输出段本身长**（无优化空间的部分）

### 阶段 4：分层方案

#### 方案 A：非 Reasoning 场景 · 减 prompt

- 面试场景不需要深度推理 → **改用非 Reasoning 模型**
- 精简 system prompt（司棋的上下文裁剪协同）
- 加 prefix cache（网关侧）

#### 方案 B：Reasoning 场景 · 拆分思考

- 复盘场景保留 Reasoning，但**只在关键子任务用**
- 前置一个非 Reasoning 步骤做规划，再用 Reasoning 做深度分析
- 类似"Router + Reasoner"两级架构

#### 方案 C：输出段 · 流式先呈现

- 简历/复盘输出段无优化空间 → **改用户体验**
- 首 token 一到就开始渲染，让用户"感觉在生成"
- 与 doc_agent 的 last_chunk 语义配合（司棋 05 号文档相关）

### 阶段 5：补充方案（重要！）

**评测发现的"意外"问题**（补充方案的价值）：
- 某些请求 P99 极高 → 网关自身抖动
- 需要在**应用层做超时兜底 + 重试**
- 与司棋的可观测性建设联动（trace_id 用来定位抖动）

---

## 算法/工程实现细节

### 分段计时的埋点

```python
class LLMTracker:
    def __init__(self):
        self.t_start = time.time()
        self.t_first_token = None
        self.t_reasoning_end = None
        self.t_end = None

    def on_first_token(self):
        if not self.t_first_token:
            self.t_first_token = time.time()

    def on_reasoning_end(self):
        self.t_reasoning_end = time.time()

    def on_end(self):
        self.t_end = time.time()

    def report(self):
        return {
            "first_token_latency": self.t_first_token - self.t_start,
            "reasoning_duration":
                (self.t_reasoning_end - self.t_first_token)
                if self.t_reasoning_end else 0,
            "output_duration":
                self.t_end - (self.t_reasoning_end or self.t_first_token),
            "total_duration": self.t_end - self.t_start,
        }
```

### 分位数计算

```python
import numpy as np

def report_percentiles(latencies):
    return {
        "P50": np.percentile(latencies, 50),
        "P90": np.percentile(latencies, 90),
        "P99": np.percentile(latencies, 99),
        "mean": np.mean(latencies),
        "max": max(latencies),
    }
```

**为什么必须看 P99**：均值可能被大量快速请求掩盖，但用户遇到的"慢"往往就是那 1% 的极端。

### A/B 对照设计

```
方案切换点：模型选择（Reasoning vs 非 Reasoning）
样本：真实场景各 500 条
指标：4 个指标 × 3 个分位 × 3 个场景 = 36 个数据点
统计检验：两样本 t 检验（P < 0.05）
```

---

## 量化验证与效果

### 优化前后对比（示例数字）

| 场景 | 指标 | 优化前 | 优化后 | 改善 |
|:---|:---|---:|---:|:---:|
| 面试提问 | 首 token P90 | 3.2s | 1.4s | **−56%** |
| 复盘生成 | 总耗时 P90 | 45s | 28s | **−38%** |
| 简历生成 | 首 token P90 | 5.1s | 2.8s | **−45%** |

（具体数字见原设计文档）

### 用户体感

- "打字之后 AI 好慢反应" → **消失**
- 复盘"等半天" → **加入进度提示**，用户不再"盲等"

---

## 方法论抽象与迁移

### 性能优化的"四步法"

1. **定义指标**（能度量）
2. **分场景压测**（真实样本）
3. **数据归因**（找真凶）
4. **分层方案 + 补充策略**（不同场景不同药方）

### 反例警示

- **反例 1**：不度量就优化 → "感觉快了" 但 P99 没变
- **反例 2**：只看均值 → 忽略长尾用户体验
- **反例 3**：一个方案打天下 → 不同场景用户诉求不同

### 可迁移场景

| 场景 | 迁移点 |
|:---|:---|
| **推荐系统延迟优化** | P99 / 分场景 / A/B |
| **搜索首屏延迟** | 首 token → 首屏对应 |
| **数据库慢查询** | 分层归因（网络/查询/序列化） |
| **前端首屏** | 类似的分段度量思路 |

### 与其他工作的联动

- **配合 02（长上下文裁剪）**：context 短了 → prefill 快 → 首 token 快
- **配合 06（可观测性）**：trace_id 让长尾问题可追溯
- **配合 05（Agent A2A）**：Doc Agent 的 stream 完整性直接影响用户"最后一段体验"

---

## 关联文档与提交

### 主设计文档

- [`docs/design/20260729_LLM思考耗时优化_实测验证与补充方案.md`](../../docs/design/20260729_LLM思考耗时优化_实测验证与补充方案.md)（原始设计+实测+补充方案，本项目最重要的设计文档之一）

### 相关提交

- yitong 的埋点相关 commit（见 `06_team_workload/yitong/06_observability_and_telemetry.md`）
- 司棋的 08-05 usage_tokens 修复（见 06 号面试文档）

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |
