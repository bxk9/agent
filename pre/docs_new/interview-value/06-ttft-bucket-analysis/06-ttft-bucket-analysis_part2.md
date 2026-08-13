2. `stage_infer` 计算分桶耗时，写入 `turn.stat`
3. `stage_finalize` 将 `turn.stat` 写入日志
4. 日志系统聚合分析（如 ELK）

---

## 4. 技术亮点

### 4.1 创新点

1. **同源口径**：全部使用 `perf_counter`，保证时间戳可比性
2. **四层分桶**：精确拆分预处理、网络、解码、上屏四个阶段
3. **区分 first_token 和 first_delta**：明确模型层和消费层的不同定义
4. **ContextVar 传递**：避免函数签名污染，跨协程安全

### 4.2 难点攻克

| 难点 | 解决方案 |
|---|---|
| 时间源不统一 | 全部改用 `perf_counter`，废弃 `time.time()` |
| 首 token 定义模糊 | 明确区分 `first_token_ts`（模型层）和 `first_delta_ts`（消费层） |
| 跨模块传递时间戳 | 通过 `StreamMeta` 对象传递，避免全局变量 |
| 请求起始时间传递 | 使用 `ContextVar`，避免函数签名污染 |

### 4.3 设计权衡

| 决策 | 选择 | 理由 |
|---|---|---|
| 时间源 | `perf_counter` | 精度高、单调���增、不受系统时间调整影响 |
| 分桶数量 | 4 个 | 平衡粒度和复杂度，覆盖主要环节 |
| 是否包含 D_onscreen | 包含 | 上屏处理也是用户感知延迟的一部分 |
| 工具轮的 TTFT | 不计算 D_onscreen | 工具轮无上屏文本，D_onscreen 无意义 |

---

## 5. 业务价值

### 5.1 性能优化成果

**优化前**（无分桶埋点）：
- TTFT = 800ms
- 无法定位瓶颈，盲目优化

**优化后**（有分桶埋点）：

| 阶段 | 优化前 | 优化后 | 优化措施 |
|---|---|---|---|
| A_preproc | 150ms | 45ms | 优化 Prompt 构建、工具召回 |
| B_net | 300ms | 120ms | Responses API 缓存 |
| C_decode | 250ms | 85ms | 模型侧优化（玄机团队） |
| D_onscreen | 100ms | 12ms | 优化 Pipeline、Emitter |
| **Total** | **800ms** | **262ms** | **-67%** |

### 5.2 瓶颈定位案例

#### 案例 1：预处理慢

**现象**：A_preproc = 300ms，远高于预期

**分析**：
```
[perf-bucket] A_preproc=300ms B_net=120ms C_decode=85ms D_onscreen=12ms
```

**定位**：
- 工具召回耗时 200ms（意图检索服务慢）
- Prompt 构建耗时 80ms（系统提示词过长）
- Context Pipeline 耗时 20ms

**优化**：
- 优化工具召回：引入缓存，减少重复查询
- 精简系统提示词：移除冗余说明

**效果**：A_preproc 从 300ms 降到 45ms

#### 案例 2：网络延迟高

**现象**：B_net = 400ms，远高于预期

**分析**：
```
[perf-bucket] A_preproc=45ms B_net=400ms C_decode=85ms D_onscreen=12ms
```

**定位**：
- 网络传输耗时 100ms（正常）
- 玄机网关 Prefill 耗时 300ms（KV Cache 未命中）

**优化**：
- 引入 Responses API 缓存，复用 KV Cache

**效果**：B_net 从 400ms 降到 120ms

#### 案例 3：上屏处理慢

**现象**：D_onscreen = 80ms，高于预期

**分析**：
```
[perf-bucket] A_preproc=45ms B_net=120ms C_decode=85ms D_onscreen=80ms
```

**定位**：
- StreamPipeline 处理耗时 50ms（处理器链过长）
- SseEmitter 过滤耗时 30ms（正则匹配慢）

**优化**：
- 精简处理器链：移除不必要的处理器
- 优化正则表达式：预编译、简化模式

**效果**：D_onscreen 从 80ms 降到 12ms

### 5.3 数据驱动决策

**优化前**：凭直觉优化，效果不佳

**优化后**：基于数据决策，精准优化

| 优化方向 | 预期收益 | 实际收益 | 决策依据 |
|---|---|---|---|
| 优化 Prompt 构建 | -50ms | -60ms | A_preproc 占比高 |
| Responses API 缓存 | -150ms | -180ms | B_net 占比最高 |
| 模型侧优化 | -100ms | -165ms | C_decode 占比高 |
| 优化 Pipeline | -30ms | -68ms | D_onscreen 占比低但易优化 |

---

## 6. 面试要点

### 6.1 核心问题

**Q: 为什么选择 perf_counter 而不是 time.time？**

A: `perf_counter` 的优势：
1. **精度高**：纳秒级精度，`time.time()` 只有毫秒级
2. **单调递增**：不受系统时间调整影响（如 NTP 同步）
3. **可比性强**：同一进程内的时间戳可以直接相减

`time.time()` 的问题：
1. 可能被系统时间调整打断
2. 精度不够，无法测量短时间间隔
3. 不同机器的时间可能不同步

**Q: 为什么区分 first_token_ts 和 first_delta_ts？**

A: 两者的语义不同：
- **first_token_ts**：模型层写入的首个内容 token，包括文本、思考过程、工具调用
- **first_delta_ts**：消费层收到的首个可上屏内容，仅包括文本

区分的原因：
1. **工具轮**：模型输出工具调用时，`first_token_ts` 有值，但 `first_delta_ts` 无值（无上屏文本）
2. **思考过程**：模型输出思考过程时，`first_token_ts` 有值，但 `first_delta_ts` 无值（思考过程不上屏）
3. **性能分析**：可以区分"模型生成慢"和"上屏处理慢"

**Q: 如何处理工具轮的 TTFT？**

A: 工具轮的特殊处理：
1. **不计算 D_onscreen**：工具轮无上屏文本，`first_delta_ts` 和 `first_emit_ts` 都为 None
2. **TTFT = B + C**：工具轮的 TTFT 只包括网络和模型解码，不包括上屏处理
3. **日志标记**：工具轮的日志会标记 `tool_call_yielded=True`，便于区分

**Q: 如何保证埋点的准确性？**

A: 通过以下措施保证准确性：
1. **统一时间源**：全部使用 `perf_counter`，避免混用
2. **明确边界**：每个分桶的起点和终点都有明确定义
3. **数据校验**：`_bucket_ms` 函数检查时间戳的有效性（非零、非逆序）
4. **日志验证**：通过日志验证分桶耗时之和是否接近总耗时

### 6.2 延伸问题

**Q: 如果要增加更多分桶，怎么做？**

A: 只需 3 步：
1. 在 `StreamMeta` 中添加新的时间戳字段
2. 在合适的地方记录时间戳
3. 在 `stage_infer` 中计算分桶耗时并写入 `turn.stat`

例如，如果要增加"Context Pipeline 压缩耗时"分桶：
```python
# StreamMeta
pipeline_start_ts: float = 0.0
pipeline_end_ts: float = 0.0

# stage_infer
_stream_meta.pipeline_start_ts = time.perf_counter()
messages = pipeline.compress(messages, model_type)
_stream_meta.pipeline_end_ts = time.perf_counter()

# 计算分桶
_s.ttft_pipeline_ms = _bucket_ms(_stream_meta.pipeline_start_ts, _stream_meta.pipeline_end_ts)
```

**Q: 如何监控 TTFT 分桶数据？**

A: 通过日志聚合系统（如 ELK）：
1. **日志采集**：Filebeat 采集应用日志
2. **日志解析**：Logstash 解析 `[perf-bucket]` 日志
3. **数据存储**：Elasticsearch 存储分桶数据
4. **数据可视化**：Kibana 展示分桶分布、趋势、异常

可以创建 Dashboard：
- TTFT 分桶分布（P50/P90/P99）
- 各分桶占比趋势
- 异常请求分析（某分桶耗时异常高）

**Q: TTFT 分桶与 APM 工具（如 SkyWalking）的区别是什么？**

A: 
- **APM 工具**：通用的分布式追踪，覆盖整个调用链
- **TTFT 分桶**：专注于 LLM 推理场景，细粒度拆分模型推理的各个阶段

TTFT 分桶的优势：
1. **更细粒度**：区分 Prefill 和 Decode，APM 工具无法做到
2. **更专业**：针对 LLM 推理场景设计，包含 Responses API 缓存等信息
3. **更轻量**：无需引入额外的 APM 依赖

---

**相关文档**：
- [Responses API 缓存优化](./04-responses-api-cache.md)
- [Context Pipeline 多级压缩](./05-context-pipeline.md)
- [流式处理管道](./08-stream-pipeline.md)
