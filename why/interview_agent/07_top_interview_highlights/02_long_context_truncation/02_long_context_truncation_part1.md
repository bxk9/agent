# LLM 长上下文裁剪：tool_call ↔ tool_response 配对保留策略 - 面试亮点

> **核心价值**：针对语音面试多轮对话撑爆 LLM 上下文的问题，设计并落地了"配对感知"的上下文裁剪策略——以 tool_call ↔ tool_response 为原子单位裁剪、优先保留最近对话与被引用产物，配合请求级 token 观测实现数据驱动的裁剪决策，保障了 20+ 轮语音面试的稳定性。

---

## 1. 核心概览（原文档保留部分）

### 1.1 一句话摘要

面对语音面试 20+ 轮对话把 LLM 上下文撑爆的问题，我以 **tool_call ↔ tool_response 配对为原子单位**做裁剪（绝不产生孤儿消息），按信息价值分优先级保留，并坚持"观测先行"——先建成请求级 token 统计，再用数据决定在哪裁、裁多少。

### 1.2 面试价值卡片

| 面向问题 | 我能讲什么 |
|:---|:---|
| **"多轮 Agent 的上下文怎么治理？"** | 配对感知裁剪 + 优先级保留的完整策略 |
| **"LLM API 的协议约束你了解多少？"** | tool_call_id 配对要求、孤儿消息的后果 |
| **"性能优化怎么入手？"** | 观测先行：token 统计三连修 → 数据驱动裁剪决策 |
| **"异步场景的状态管理"** | contextvar 跨线程失效 → 模块级 FIFO 字典的真实踩坑 |

**可回答的经典面试题**：
- LLM 多轮对话的上下文窗口管理策略有哪些？
- 流式/多轮场景如何做 token 成本监控？
- 有损操作（裁剪/压缩）如何保证可追溯？
- Python 异步与线程混合场景下上下文变量如何传递？

### 1.3 方案演进与关键决策

**演进时间线**（git 证据）：

```
阶段 1（08-04）：事故压力下的快速落地
  93a0dd7 + 224a3b0 "语音上下文裁剪"同日两提交（上线→发现问题→补一刀）
  1d3a318 "blueclaw_chat增加裁剪和日志"（裁剪与观测绑定）
      ↓
阶段 2（08-05）：观测体系建成
  ed1c3b8 每次请求结束打印 LLM/工具耗时与 Token 汇总
  124a5b1 修复 token 为 0 + 合并单条日志
  95bf297 改用模块级 FIFO 字典（contextvar 跨线程失效）
      ↓
阶段 3（08-06 起）：数据驱动调优
  08bcac0 观测上线次日即定位 150 分钟级事故
```

**关键决策 1：配对为原子单位，绝不产生孤儿**

LLM API 协议要求 tool_call 与 tool_response 按 tool_call_id 严格配对。裁剪必须整对移除——孤儿 tool_call 导致 API 400 或模型空转，孤儿 tool_response 导致 tool_call_id not found。

**关键决策 2：按信息价值分优先级保留**

P0 系统 prompt 永不裁 → P1 最近 N 轮完整对话 → P2 被后续引用的产物 → P3/P4 大而无用的历史配对优先裁。

**关键决策 3：观测先行，数据驱动**

没有 token 统计就不知道"20 轮后超了多少"，裁剪阈值只能靠猜。先建观测（三天连修三个 bug），再定策略。

**淘汰的方案**：

| 淘汰方案 | 淘汰原因 |
|:---|:---|
| **头部硬截断** | 大概率切断配对产生孤儿；`93a0dd7` 同日两提交说明首版裁剪上线即打补丁 |
| **全量摘要压缩** | 摘要要额外调 LLM，语音实时场景延迟不可接受；摘要丢细节，追问需要精确历史原文 |
| **换大窗口模型** | `874b360` 证明模型切换是可用性兜底不是容量方案；大窗口成本高延迟大，且有 lost-in-the-middle 效应 |

---

## 2. 项目背景与问题定义

### 2.1 业务场景

语音模拟面试的对话链路：

```
用户语音 → STT 转文本 → 主 Agent（携带完整对话历史）→ LLM
                              ↑
                    工具调用产物注入上下文：
                    - 简历内容（数千 token）
                    - 错题本（get_session_error_book）
                    - 面试经验文档（面经正文透传）
```

**上下文构成**：
1. 系统 prompt（面试官人设 + 出题策略 + 话术规则）
2. 20+ 轮对话历史（每轮含追问）
3. 多次工具调用的 tool_call + tool_response（简历、错题本、面经）

### 2.2 性能瓶颈分析

**上下文膨胀路径**（合理推断，基于提交时序）：

```
第 1-5 轮：上下文 ~4k token（正常）
第 6-10 轮：拉取简历 + 错题本 → tool_response 注入 → ~12k token
第 11-20 轮：对话累积 + 追问 → 逼近模型上下文上限
超限后果：请求直接失败 → 用户面试中途中断（最严重体验事故）
```

**关键洞察**：
- 语音场景是全系统最先触碰上下文上限的场景（轮次多 + 工具产物大 + 实时性要求高）
- 08-04 当天两次紧急提交"语音上下文裁剪"（`93a0dd7` + `224a3b0`）——典型的"上线 → 发现问题 → 紧急补一刀"节奏
- **浪费**：早期工具响应（如已消化过的简历原文）长期占据上下文，挤占有效空间

### 2.3 优化目标

**核心问题**：如何在上下文逼近上限时安全裁剪，既不超限又不破坏对话连贯？

**量化目标**：
- 20+ 轮语音面试不触发上下文超限
- 裁剪不产生 LLM API 报错（孤儿 tool_call/tool_response）
- 裁剪决策有数据支撑（token 观测先行）

---

## 3. 技术方案设计

### 3.1 核心思路

**配对感知的裁剪**：

```
上下文消息序列：
[system] [user1] [assistant1] [tool_call_A] [tool_response_A]
[user2] [assistant2(tool_call_B)] [tool_response_B] [user3] ...

裁剪原子单位 = 完整的配对：
  assistant(tool_call_X) + tool(tool_response_X) 必须同进同出

禁止产生：
  孤儿 tool_call（有调用无响应）→ API 400 或模型空转
  孤儿 tool_response（有响应无调用）→ tool_call_id not found 报错
```

**关键挑战**：
1. 如何保证裁剪不破坏配对？
2. 先裁哪一对？（裁剪优先级）
3. 裁多少？（数据驱动而非拍脑袋）

### 3.2 配对约束的来源

**LLM API 协议硬约束**（合理推断，行业常识）：

```
OpenAI 兼容协议要求：
assistant: tool_calls=[{id: "call_1", ...}]
tool: {tool_call_id: "call_1", content: "..."}   ← 必须紧跟且 id 对应

违反后果：
- 孤儿 tool_call → API 400，或模型"以为工具还在执行"而空转
- 孤儿 tool_response → tool_call_id not found
```

**项目内旁证**（真实）：`f13d71e`（11197109，"修复缓存命中过期链接透传导致文档 Agent 空转"）证明上下文中的无效引用数据确实会让下游空转——孤儿工具数据危害同源。

### 3.3 裁剪优先级规则表

**保留/裁剪规则表**（合理推断，基于业务场景）：

| 优先级 | 内容 | 处置 | 原因 |
|:---:|:---|:---|:---|
| P0 | 系统 prompt | 永不裁剪 | 人设与规则的根基 |
| P1 | 最近 N 轮完整对话 | 保留 | 对话连贯性（"你刚才说……"） |
| P2 | 产物被后续引用的配对 | 保留 | 简历内容被点评引用 |
| P3 | 大而无用的历史配对 | 优先裁剪 | 如已消化的文件上传响应 |
| P4 | 早期闲聊轮次 | 次优先裁剪 | 信息密度低 |

---

## 4. 核心实现细节

### 4.1 观测先行：token 统计体系

**实现背景**（真实，commit `ed1c3b8`、`124a5b1`、`95bf297`）：

```python
# 08-05 司棋建成的 token 观测（三次提交打磨）
# ed1c3b8: 每次请求结束时打印 LLM/工具耗时与 Token 汇总
# 124a5b1: token 汇总合并为单条日志 + 修复 token 为 0 的问题
# 95bf297: token 统计改用模块级 FIFO 字典，避免 contextvar 跨线程失效

# 关键设计：模块级 FIFO 字典（而非 contextvar）
_token_stats: OrderedDict = OrderedDict()  # key=request_id, FIFO 防内存泄漏
# 原因：本项目大量使用 run_in_executor，contextvar 跨线程会丢
```

**为什么观测必须先于裁剪**：
```
无观测时：不知道"语音 20 轮后 token 超了"→ 无从决定在哪裁、裁多少
有观测后：请求级 token 汇总 → 定位膨胀段 → 数据驱动裁剪
实证：08-05 观测上线，08-06 即修掉 150 分钟级事故（08bcac0）
```

### 4.2 配对裁剪算法

**算法骨架**（合理推断，基于配对约束的实现方案）：

```python
def truncate_context(messages: list, token_budget: int) -> list:
    """配对感知的上下文裁剪"""
    # 1. 识别所有配对：assistant(tool_calls) + 对应 tool response
    pairs = identify_tool_pairs(messages)  # 按 tool_call_id 匹配
    
    # 2. 计算当前总 token
    total = sum(count_tokens(m) for m in messages)
    if total <= token_budget:
        return messages  # 无需裁剪
    
    # 3. 按优先级选择可裁剪配对（P3/P4 优先）
    candidates = rank_by_priority(pairs, messages)
    
    # 4. 整对移除，直到满足预算
    for pair in candidates:
        messages.remove(pair.assistant_msg)   # tool_call 侧
        messages.remove(pair.tool_msg)        # tool_response 侧
        total -= pair.token_count
        if total <= token_budget:
            break
    
    # 5. 校验：裁剪后不得存在孤儿
    assert no_orphan_tool_messages(messages)
    return messages
```

**配对识别**：

```python
def identify_tool_pairs(messages):
    """按 tool_call_id 匹配 call 与 response"""
    pending = {}   # tool_call_id → assistant message
    pairs = []
    for m in messages:
        if m.role == "assistant" and m.tool_calls:
            for tc in m.tool_calls:
                pending[tc.id] = m
        elif m.role == "tool":
            if m.tool_call_id in pending:
                pairs.append(Pair(pending.pop(m.tool_call_id), m))
    # pending 中剩余的就是孤儿 tool_call —— 裁剪时必须整段处理
    return pairs
```

### 4.3 语音链路的落地

**真实提交**（yitong，08-04）：

```
93a0dd7 / 224a3b0 | 2026-08-04 | yitong | 语音上下文裁剪（同日两次提交）
1d3a318 / 85c32b6 | 2026-08-04 | yitong | blueclaw_chat增加裁剪和日志
```

**关键设计**："裁剪和日志"绑在同一个提交——裁剪必须伴随可观测：

```python
# 裁剪动作必须留痕（合理推断，对应"裁剪和日志"提交）
logger.info(f"context_truncate: removed {removed_pairs} tool pairs, "