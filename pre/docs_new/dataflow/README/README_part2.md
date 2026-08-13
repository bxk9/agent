| 彩蛋系统 | 异常 → 静默跳过 |
| Patch 系统 | 异常 → 静默跳过 |
| 仲裁系统 | 异常 → 静默跳过 |
| 预处理 | 异常 → 使用原始参数 |
| 后处理 | 异常 → 返回原始结果 |

---

## 6 性能优化路径

### 6.1 Responses API 缓存

**目标**：复用 KV Cache，减少重复计算

**路径**：
```
第 1 次推理（路径B）
    ↓
保存 response_id + prefix_hash
    ↓
第 2 次推理（路径A）
    ├─ 检查前缀一致性
    ├─ 只传 tool_results 增量
    └─ 复用 KV Cache
```

**收益**：减少 TTFT 30-50%

### 6.2 Context Pipeline 压缩

**目标**：控制 token 预算，避免超限

**路径**：
```
检查 token 数量
    ├─ 未超限 → 无需压缩
    └─ 超限
        ↓
    L1 结构化提取（信息损失最小）
        ├─ 满足预算 → 结束
        └─ 仍超限
            ↓
    L2 通用截断
        ├─ 满足预算 → 结束
        └─ 仍超限
            ↓
    L3 历史退化
        ├─ 满足预算 → 结束
        └─ 仍超限
            ↓
    L4 整轮丢弃（最终防线）
```

### 6.3 工具排序优化

**目标**：提升 LLM prompt cache 前缀稳定性

**路径**：
```
工具列表
    ↓
排序：高频工具（28个）→ 长定义工具（22个）→ 普通工具
    ↓
高频工具始终在前 → prompt 前缀稳定 → cache 命中率高
```

**收益**：减少 cache miss，降低 TTFT

### 6.4 TTFT 分桶埋点

**目标**：定位性能瓶颈

**分桶**：
```
A_preproc（预处理）：我方 CPU，可优化
B_net（网络首字节）：网络+网关+玄机 prefill
C_decode（解码首token）：模型解码，非我方开销
D_onscreen（上屏）：pipeline + emitter，我方开销
```

**分析**：
- A 段高 → 优化准备阶段逻辑
- B 段高 → 网络问题或玄机网关慢
- C 段高 → 模型解码慢（非我方问题）
- D 段高 → 优化 pipeline 处理器

---

## 附录：关键数据结构

### TurnState 字段分类

| 分类 | 字段 | 写入阶段 | 读取阶段 |
|---|---|---|---|
| 请求上下文 | query, chat_history, request_id | prepare | infer, finalize |
| 工具集 | tools, tool_list, patch_prompt_snippets | prepare | infer |
| 推理产出 | assist_content, tool_call_requests | infer | finalize |
| 控制信号 | should_stop, error | 任意 | 所有 |
| 埋点数据 | stat (StatCollector) | 各阶段 | finally |

### AgentContext 字段

| 字段 | 说明 | 生命周期 |
|---|---|---|
| history | MCP 对话历史 | 跨轮次 |
| tools | 本轮召回的工具键 | 单轮 |
| model | 使用的模型名 | 单轮 |
| model_type | 模型类型 | 单轮 |
| tool_count | 本 session 请求轮次数 | 跨轮次 |
| mcp_tools | 本 session 已调用的工具名 | 跨轮次 |
| extra_for_experiment | 实验性字段 | 跨轮次 |

---

**相关文档**：
- [整体架构文档](../architecture/README.md)
- [Agent 模块详解](../modules/agent.md)
- [Model 模块详解](../modules/model.md)
