- **日程快捷方式**：客户端已通过 `extra.schedules` 给出确定性日程信息时，跳过模型推理直接下发工具调用

### 4.2 阶段 2：推理阶段（_stage_infer）

**文件**：`agent/pro/stage_infer.py`（613 行）

**执行流程**：

```
1. 从 TurnState 读取输入
2. Mock query 场景切换到 pro
3. 构建系统提示词（base + patch snippets + arbitration prompts）
4. 工具列表排序（高频 → 长定义 → 普通）
5. 初始化 RetryController
6. Responses API 可用性判定
7. 推理-校验-重试循环（while True）：
   7.1 构建消息列表
   7.2 Responses API 缓存判断（路径A/B/C）
   7.3 StreamPipeline 消费循环
   7.4 流结束处理
   7.5 空响应兜底
   7.6 工具验证（Phase 1 逐工具）
   7.7 工具验证（Phase 2 批量）
8. 写入 TurnState
9. Responses API 缓存保存
10. TTFT 分桶埋点
```

**Responses API 三条路径**：

| 路径 | 条件 | 行为 |
|---|---|---|
| **A** | 有 response_id + 前缀一致 + 有 tool 增量 | 只传 tool_results 增量 + previous_response_id |
| **B** | 无 response_id + 缓存启用 | 用 Responses API 获取 response_id |
| **C** | 缓存不可用 | 走原始 stream 逻辑 |

**降级策略**：
- 路径A/B 失败时降级到路径C（仅在未产出文本时）
- 前缀不一致时降级（历史压缩导致前缀变化）
- 无 tool 增量时降级（非工具回调续推）

**TTFT 分桶**：

| 分桶 | 含义 | 来源 |
|---|---|---|
| A_preproc | 预处理耗时 | 我方 CPU |
| B_net | 网络首字节 | 网络+网关+玄机 prefill |
| C_decode | 解码首 token | 模型解码 |
| D_onscreen | 上屏耗时 | pipeline + emitter |

### 4.3 阶段 3：收尾阶段（_stage_finalize）

**文件**：`agent/pro/stage_finalize.py`（141 行）

**执行流程**：

```
1. 从 TurnState 读取产出
2. 上屏合并（STREAM_ON_USER 工具结果合并到 assist_content）
3. Session 去重（mcp_history 去重）
4. 推荐位信号计算（图片/文档上传引导检测）
5. 上下文更新（写回 AgentContext）
6. SSE 下发（event:tool / event:end）
```

**SSE 事件类型**：

| 事件 | 说明 |
|---|---|
| `event:text` | 模型生成的文本 token |
| `event:tool` | 工具调用请求（JSON 数组） |
| `event:end` | 会话状态更新（含 context、request_end 等） |
| `event:error` | 错误信息 |

---

## 5 推理干预层

### 5.1 两段式契约

| 段 | Context | 干预产物 | 集成点 |
|---|---|---|---|
| **PreInfer** | `PreInferContext` | 改 `chat_history` / 追加 `system_prompt` | `_stage_prepare` 推理前 |
| **PostInfer** | `PostInferContext` | 改 `tool_call`（如注入上屏指令） | `_post_process_tool_results` |

### 5.2 机制要点

- **自注册表**：`register_pre/post` 收集 hook，`run_pre/post_hooks` 按注册顺序遍历
- **异常隔离**：单 hook 异常不影响其余 hook 与主流程
- **原地修改约定**：Context 的可变字段只能原地修改（`ctx.chat_history[:] = [...]`），不得整体重新赋值

### 5.3 当前 Hook

| Hook | 段 | 功能 |
|---|---|---|
| `panel_stale` | PreInfer | 面板首轮 + 历史非空时清理过期历史 |
| `composite_output_instruct` | PostInfer | 多工具末条且非上屏时注入上屏指令 |

### 5.4 设计边界

hook 层只承载 **patches 机制够不到的推理前/后产物**：

| 干预类型 | 归属 | 原因 |
|---|---|---|
| 改 `chat_history` | hook | owner 是主流程本身 |
| 改 `tool_call` | hook | owner 是主流程本身 |
| 工具集增删 | patches | owner 是 `_resolve_tools` + patches |

---

## 6 流式处理管道

### 6.1 架构设计

```
模型输出 (AsyncGenerator)
    ↓
StreamPipeline
    ├── EosFilter          # 过滤 EOS token
    ├── MarkerFilter       # 过滤模型控制标记
    ├── SpecialTokenExtractor  # 提取特殊 token
    └── TextToolParserProcessor  # 文本中解析工具调用（BlueLM text_parse 模式）
    ↓
SseEmitter (SSE 格式化)
    ↓
yield SSE 事件
```

### 6.2 流式事件类型

| 事件 | 说明 |
|---|---|
| `TextDelta` | 文本增量 |
| `CotDelta` | 思考过程增量（不上屏） |
| `ToolCallsDone` | 工具调用完成（含 name/id/arguments/thought_signature） |
| `Signal` | 信号事件（session_finished / enable_voice / mcp:tool_name） |
| `StreamDone` | 流结束 |
| `StreamError` | 流错误（含 code/message） |

### 6.3 处理器链

| 处理器 | 职责 |
|---|---|
| `EosFilter` | 过滤 EOS token（`<|End|>` 等） |
| `MarkerFilter` | 过滤模型控制标记（`<|FunctionCallBegin|>` 等） |
| `SpecialTokenExtractor` | 提取 `<!@-label-@!>` 格式的特殊标记 |
| `TextToolParserProcessor` | BlueLM text_parse 模式下从文本中解析工具调用 |

### 6.4 SseEmitter

**职责**：将流式事件格式化为 SSE 协议输出

**关键特性**：
- 记录 `first_emit_ts`（首次发射时间），用于 TTFT 分桶
- 记录 `has_emitted`（是否已发射），用于流式安全约束
- 支持文本去重和缓冲区管理

---

## 7 接口说明

### 7.1 HostAgent 接口

```python
class HostAgent:
    def __init__(self, model: Model):
        """初始化 HostAgent，持有 ModelSession"""

    async def process(
        self, body: dict, context: AgentContext
    ) -> AsyncGenerator[str, None]:
        """单轮编排主入口，yield SSE 事件字符串"""
```

### 7.2 阶段函数接口

```python
async def _stage_prepare(
    turn: TurnState, session: ModelSession,
    body: dict, context: AgentContext,
) -> None

async def _stage_infer(
    turn: TurnState, session: ModelSession,
    body: dict, context: AgentContext,
) -> AsyncGenerator[str, None]

async def _stage_finalize(
    turn: TurnState, body: dict, context: AgentContext,
) -> AsyncGenerator[str, None]
```

### 7.3 Hook 注册接口

```python
@register_pre_hook
def my_pre_hook(ctx: PreInferContext):
    """推理前干预"""
    pass

@register_post_hook
def my_post_hook(ctx: PostInferContext):
    """推理后干预"""
    pass
```

---

**相关文档**：
- [Model 模块详解](./model.md)
- [Tools 模块详解](./tools.md)
- [数据流文档](../dataflow/README.md)
