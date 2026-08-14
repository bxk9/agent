**情感滑动窗口**: 维护最近 10 轮的情感标签序列，用于:
- 检测情绪突变 → 辅助场景切换判断
- 追踪情绪趋势 → 影响回应语气
- 长期情绪基线 → 更新 L3

### 3.2 话题意图识别模块

**核心改进**: 原方案只有一级意图，在超长对话中不够用。改为 **3~5 级树形意图体系**。

```
L1 一级 (大类, 7个)
 └─ L2 二级 (子类, 每L1下3~10个)
     └─ L3 三级 (具体, 每L2下2~8个)
         └─ L4 四级 (动作, 可选)
             └─ L5 五级 (参数, 可选)
```

**L1 类目**:

| 代码 | 名称 | 说明 |
|------|------|------|
| CHAT | 闲聊 | 无明确目的 |
| EMOTION | 情感倾诉 | 表达/处理情绪 |
| CONSULT | 咨询建议 | 寻求信息或建议 |
| TASK | 任务执行 | 要求完成操作 |
| RECALL | 记忆召回 | 主动提及历史 |
| META | 元对话 | 关于对话本身 |
| ROLEPLAY | 角色扮演 | 角色互动 |

**意图输出格式**:

```json
{
    "intent_path": "EMOTION.VENT.WORK.PRESSURE",
    "levels": {
        "L1": {"label": "EMOTION",  "conf": 0.92},
        "L2": {"label": "VENT",     "conf": 0.85},
        "L3": {"label": "WORK",     "conf": 0.78},
        "L4": {"label": "PRESSURE", "conf": 0.71}
    },
    "is_scene_switch": false,
    "related_scene_id": "scene_20260408_101500_emotion_work",
    "requires_memory_recall": true
}
```

> 完整意图树定义见 [intent_classification.md](./intent_classification.md)

---

## 4. 记忆管理层

> 详细设计: [memory_management.md](./memory_management.md)

### 4.1 L1: 工作记忆 (Working Memory)

```
┌─────────────────────────────────────────────────┐
│ L1 工作记忆                                      │
│                                                  │
│ 形式: 最近 N 轮对话原文 (N=10~20, 可配置)         │
│ 存储: 内存 (不落盘)                               │
│ 更新: 每轮追加, FIFO 淘汰                         │
│ 作用: 保证近期对话的细节完整性                     │
│                                                  │
│ 数据结构:                                         │
│ [                                                │
│   {turn:198, role:"user",      msg:"...", ts:""} │
│   {turn:198, role:"assistant", msg:"...", ts:""} │
│   ...最近 N 轮...                                │
│ ]                                                │
└─────────────────────────────────────────────────┘
```

### 4.2 L2: 情景记忆 (Episodic Memory)

**核心特征**: 以 **场景 (Scene)** 为组织单元，以 **时间戳** 命名。

**场景生命周期**:
```
创建 ──→ 活跃 ──→ 暂停 ──→ 关闭
              ↑       │
              └─恢复──┘
```

**场景命名**: `scene_{YYYYMMDD}_{HHmmss}_{topic_tag}`

**存储目录**:
```
memories/
├── {user_id}/
│   ├── long_term.json              ← L3
│   ├── scene_index.json            ← 场景检索索引
│   ├── scenes/
│   │   ├── scene_20260408_101500_emotion_work.json
│   │   ├── scene_20260408_113000_chat_hobby.json
│   │   └── ...
│   └── session_log/
│       └── session_20260408.jsonl  ← 原始对话日志
```

**10 轮压缩机制**:

```
触发条件:
  主触发: 当前场景累积 >= 10 轮未压缩对话
  副触发: 场景切换时, 强制压缩剩余 (不足10轮也压缩)

压缩流程:
  10轮原文 → 关键信息提取 → 去冗余 → 结构化摘要 → 写入场景文件

压缩产物:
  {
    "round_id": "compress_003",
    "turns": [40,41,42,43,44],
    "summary": "用户讨论了...",
    "key_facts": ["事实1", "事实2"],
    "emotional_arc": "frustrated -> calm",
    "compressed_at": "2026-04-08T10:35:00"
  }
```

### 4.3 L3: 长期记忆 (Long-term Memory)

**结构**: 按维度分类的 KV 存储

```
profile:      姓名/年龄/职业/所在地
preferences:  沟通风格/爱好/饮食偏好
relationships: 提到的人物及关系
events:       重要事件 (附带时间和状态)
emotional_baseline: 长期情绪基线
```

每个 KV 都带 `confidence` 和 `source_turn`，用于冲突解决。

### 4.4 记忆检索与融合

**检索深度按需分级**:

| 当前状态 | 检索层 | 说明 |
|---------|--------|------|
| 普通闲聊 | L1 | 只需工作记忆 |
| 话题延续 | L1 + 当前 L2 | 补充当前场景摘要 |
| 话题回溯 | L1 + 多个 L2 | 跨场景检索 |
| 显式记忆询问 | L1 + L2 + L3 | 全层级 |

**L2 检索算法** (加权多维评分):

```
final_score = 0.35 * intent_similarity
            + 0.30 * keyword_overlap
            + 0.20 * time_decay
            + 0.15 * emotion_relevance
```

> 完整检索算法见 [memory_recall_threshold.md](./memory_recall_threshold.md)

---

## 5. System Prompt 动态组装

> 详细设计: [prompt_assembly.md](./prompt_assembly.md)

### 5.1 Prompt 结构 (6 个 Block)

```
┌─────────────────────────────────────────────────┐
│ Block 1: 角色设定 (固定)                         │
│ Block 2: L3 长期记忆 (动态)                      │
│ Block 3: L2 场景摘要 (动态, 受软阈值控制)         │
│ Block 4: 情感状态追踪 (动态)                     │
│ Block 5: 记忆提及指引 (动态, 受软阈值控制)        │
│ Block 6: 回复策略指引 (动态)                     │
├─────────────────────────────────────────────────┤
│ Messages: L1 工作记忆原文 (最近 N 轮)            │
└─────────────────────────────────────────────────┘
```

### 5.2 Token 预算 (默认 8K 上下文)

| Block | 默认 Token | 说明 |
|-------|-----------|------|
| Block 1 角色设定 | 500 | 固定 |
| Block 2 长期记忆 | 800 | 动态 |
| Block 3 场景摘要 | 1200 | 受阈值控制，不注入时归还 |
| Block 4 情感追踪 | 200 | 动态 |
| Block 5 记忆指引 | 300 | 受阈值控制，不注入时归还 |
| Block 6 回复策略 | 200 | 动态 |
| Messages 工作记忆 | 4800 | 弹性，接收归还的预算 |

---

## 6. LLM 推理层

### 6.1 推理参数按意图动态调整

| 意图 L1 | temperature | 理由 |
|---------|-------------|------|
| CHAT | 0.85 | 闲聊需要多样性 |
| EMOTION | 0.70 | 情感需要稳定 |
| CONSULT | 0.50 | 建议需要准确 |
| TASK | 0.30 | 任务需要精确 |
| RECALL | 0.40 | 记忆需要准确 |
| ROLEPLAY | 0.90 | 角色需要创造 |

---

## 7. 后处理层

### 7.1 记忆提取与更新

每轮结束后执行:

```
(user_msg, response)
        │
        ▼
┌───────────────────────┐
│ 1. L3 新信息检测       │  ← LLM/规则提取用户画像新信息
│    有 → 冲突检测 → merge│
│    无 → skip           │
├───────────────────────┤
│ 2. L1 窗口更新         │  ← 追加当前轮, FIFO 淘汰
├───────────────────────┤
│ 3. L2 压缩检查         │  ← 累积 >= 10 轮 ? 压缩 : skip
├───────────────────────┤
│ 4. 情感序列更新        │  ← 追加情感标签, 计算趋势
└───────────────────────┘
```

### 7.2 L3 冲突解决策略

| 冲突类型 | 策略 | 示例 |
|---------|------|------|
| 无冲突 | 直接写入 | 首次提到姓名 |
| 补充型 | 合并追加 | 新增一个爱好 |
| 矛盾型 | 新值覆盖, 旧值降低置信度 | 从北京搬到上海 |

---

## 8. 关键机制索引

| 机制 | 所在文档 | 核心问题 |
|------|---------|---------| 
| 3~5 级意图识别 | [intent_classification.md](./intent_classification.md) | 如何准确分类超长对话中的用户意图 |
| 场景化记忆 + 10 轮压缩 | [memory_management.md](./memory_management.md) | 如何高效存储和组织 200+ 轮的对话记忆 |
| 软阈值记忆注入 | [memory_recall_threshold.md](./memory_recall_threshold.md) | 什么时候该/不该在回复中提及历史记忆 |
| 动态 Prompt 组装 | [prompt_assembly.md](./prompt_assembly.md) | 如何在有限 Token 内最优组合各层信息 |
| 200 轮 badcase 评估 | [evaluation.md](./evaluation.md) | 如何量化记忆系统的效果 |

---

## 9. 子文档索引

| # | 文档 | 路径 | 内容 |
|---|------|------|------|
| 1 | 意图分类 | [intent_classification.md](./intent_classification.md) | 完整意图树、分级识别算法、场景关联 |
| 2 | 记忆管理 | [memory_management.md](./memory_management.md) | L1/L2/L3 详细设计、场景管理、压缩算法、存储格式 |
| 3 | 召回与阈值 | [memory_recall_threshold.md](./memory_recall_threshold.md) | 检索算法、软阈值评分、注入策略 |
| 4 | Prompt 组装 | [prompt_assembly.md](./prompt_assembly.md) | 6 Block 模板、Token 预算、动态生成逻辑 |
| 5 | 评估方案 | [evaluation.md](./evaluation.md) | badcase 设计、A/B 实验、7 维指标 |

---

## 10. 术语表

| 术语 | 定义 |
|------|------|
| Scene (场景) | 围绕特定话题的连续对话段，L2 记忆的基本组织单元 |
| Compression Round | 每 10 轮对话的摘要压缩产物 |
| Working Memory Window | L1 中保留的最近 N 轮原始对话 |
| Soft Threshold (软阈值) | 0.6 分，超过时建议在回复中注入记忆 |
| Hard Threshold (硬阈值) | 0.85 分，超过时强制在回复中注入记忆 |
| Memory Mention | 在回复中自然引用历史记忆信息 |
| Scene Switch | 从一个话题场景转换到另一个 |
| Intent Tree | 多级意图分类的树形结构 |