- TextToolParserProcessor 负责"文本工具解析需求"：BlueLM 需要从文本中解析工具调用

**处理逻辑**：
```
场景：EOS token 截���
  模型输出: "今天北京晴天<|endoftext|>"
  → EosFilter 检测到 <|endoftext|>
  → 截断为 "今天北京晴天"
  → yield StreamDone()

场景：模型控制标记过滤
  模型输出: "<|Function" + "CallBegin|>create_alarm"
  → MarkerFilter 检测到 <|FunctionCallBegin|>
  → 吞掉标记碎片
  → yield TextDelta("create_alarm")

场景：控制信号提取
  模型输出: "今天北京晴天<!@-end-@!>"
  → SpecialTokenExtractor 检测到 <!@-end-@!>
  → yield Signal(label="session_finished")
  → yield TextDelta("今天北京晴天")

场景：文本工具解析
  BlueLM 输出: "<tool_call>{"name": "create_alarm", "arguments": {"time": "08:00"}}</tool_call>"
  → TextToolParserProcessor 解析工具调用
  → yield ToolCallsDone(tool_calls=[ToolCallInfo(name="create_alarm", ...)])
```

### 2.2.2 为什么处理器可以"吞掉" event（真实原因）

**来源**：设计文档 - `docs/plans/2026-07-09-stream-pipeline-architecture.md`

**设计文档原文**：
```python
class EosFilter(StreamProcessor):
    async def process(self, upstream):
        async for event in upstream:
            if isinstance(event, TextDelta):
                if self.EOS_TOKEN in event.content:
                    # 吞掉 EOS token，不 yield
                    yield StreamDone()
                    return
            yield event
```

**详细解释**：
- 某些 event 不需要传递给下游
- EOS token（`<|endoftext|>`）不需要上屏显示
- 模型控制标记（`<|FunctionCallBegin|>`）不需要上屏显示
- 特殊 token（`<!@-end-@!>`）需要提取为 Signal，不传递原文本

**业务场景**：
```
场景：EOS token 吞掉
  模型输出: "今天北京晴天<|endoftext|>"
  → EosFilter 检测到 <|endoftext|>
  → 吞掉 EOS token，不 yield
  → yield StreamDone()
  → 流终止

如果 EOS token 不吞掉：
  → EOS token 上屏显示
  → 用户体验差
  → 用户投诉
```

### 2.2.3 为什么需要 ResultAssembler（真实原因）

**来源**：设计文档 - `docs/plans/2026-07-09-stream-pipeline-architecture.md`

**设计文档原文**：
```python
class ResultAssembler:
    """无条件累积所有 event，流结束后调用 result() 获取快照。"""
    
    def feed(self, event: PipelineEvent) -> None:
        """喂入一个 event，无条件累积。"""
    
    def result(self) -> InferenceResult:
        """产出不可变结果快照。"""
```

**详细解释**：
- 结果累积：流式处理过程中，需要累积所有 event
- 不可变快照：流结束后，产出不可变的结果快照
- 简化消费：消费方无需关心流式细节，直接使用结果快照

**业务场景**：
```
场景：结果累积
  流式处理:
    TextDelta("今天") → assembler.feed()
    TextDelta("北京") → assembler.feed()
    TextDelta("晴天") → assembler.feed()
    StreamDone() → assembler.feed()
  
  流结束:
    result = assembler.result()
    result.text = "今天北京晴天"
  
  消费方:
    → 直接使用 result.text
    → 无需关心流式细节
```

### 2.2.4 为什么需要 SseEmitter（真实原因）

**来源**：设计文档 - `docs/plans/2026-07-09-stream-pipeline-architecture.md`

**设计文档原文**：
```python
class SseEmitter:
    """展示过滤 + SSE 格式化。"""
    
    def emit(self, event: PipelineEvent) -> str | None:
        """尝试将 event 格式化为 SSE chunk。返回 None 表示不需要发送。"""
```

**详细解释**：
- 展示过滤：决定哪些 TextDelta 应该推给客户端
- SSE 格式化：将 event 格式化为 SSE 字符串
- 跳过前导空白：Flash 模型 think 残留的换行符不需要上屏

**业务场景**：
```
场景：跳过前导空白
  Flash 模型输出: "\n\n今天北京晴天"
  → SseEmitter 检测到前导空白
  → 跳过 "\n\n"
  → yield "event:text\ndata:{"text": "今天北京晴天"}\n\n"

如果前导空白不跳过：
  → 前导空白上屏显示
  → 用户体验差
  → 用户投诉
```

## 2.3 性能与质量原因

### 2.3.1 为什么需要 build_processors 工厂函数（真实原因）

**来源**：设计文档 - `docs/plans/2026-07-09-stream-pipeline-architecture.md`

**设计文档原文**：
```python
def build_processors(model) -> list[StreamProcessor]:
    """根据模型 profile 构建 processor 链。"""
    processors = [
        EosFilter(),
        MarkerFilter(),
        SpecialTokenExtractor(),
    ]
    
    # BlueLM text_parse 模式：需要从文本中解析工具调用
    if hasattr(model, '_tool_mode') and model._tool_mode == "text_parse":
        processors.append(TextToolParserProcessor())
    
    return processors
```

**详细解释**：
- 不同模型需要不同的处理器：BlueLM 需要 TextToolParserProcessor，其他模型不需要
- 灵活扩展：新增模型时，只需修改 build_processors，无需修改核心代码
- 可测试性：可以独立测试不同的处理器组合

**量化示例**：
```
Doubao-Seed-2.0-pro：
  processors = [EosFilter(), MarkerFilter(), SpecialTokenExtractor()]
  → 3 个处理器
  → 无需 TextToolParserProcessor

BlueLM-Qwen3.5：
  processors = [EosFilter(), MarkerFilter(), SpecialTokenExtractor(), TextToolParserProcessor()]
  → 4 个处理器
  → 需要 TextToolParserProcessor

如果硬编码处理器链：
  → 新增模型需要修改核心代码
  → 风险高
  → 难以扩展

使用工厂函数：
  → 新增模型只需修改 build_processors
  → 风险低
  → 易于扩展
```

### 2.3.2 为什么 Pipeline 只产结构化 event（真实原因）

**来源**：设计文档 - `docs/plans/2026-07-09-stream-pipeline-architecture.md`

**设计文档原文**：
```
Pipeline 只产结构化 event，SSE 格式化在 stage_infer 边界层完成。
```

**详细解释**：
- 职责分离：Pipeline 负责处理，SseEmitter 负责格式化
- 可测试性：Pipeline 可以独立测试，无需关心 SSE 格式
- 灵活性：未来可以支持其他输出格式（如 WebSocket）

**业务场景**：
```
场景：SSE 输出
  Pipeline 产出: TextDelta("今天北京晴天")
  → SseEmitter 格式化为 SSE
  → yield "event:text\ndata:{"text": "今天北京晴天"}\n\n"

场景：WebSocket 输出（未来扩展）
  Pipeline 产出: TextDelta("今天北京晴天")
  → WsEmitter 格式化为 WebSocket
  → yield {"type": "text", "content": "今天北京晴天"}

如果 Pipeline 内部做 SSE 格式化：
  → Pipeline 职责不单一
  → 难以测试
  → 难以扩展

Pipeline 只产结构化 event：
  → Pipeline 职责单一
  → 易于测试
  → 易于扩展
```

## 2.4 工程实现原因

### 2.4.1 为什么需要事件适配层（真实原因）

**来源**：代码实现 - `agent/pro/stream/processor.py`

**代码实现原文**：
```python
async def _adapt_source(self) -> AsyncGenerator[PipelineEvent, None]:
    """将 model 层 StreamEvent 适配为 pipeline 层 PipelineEvent。"""
    from model.stream_events import (
        TextDelta as MTextDelta,
        CotDelta as MCotDelta,
        ToolCallsDone as MToolCallsDone,
        StreamDone as MStreamDone,
        StreamError as MStreamError,
    )
    from agent.pro.stream.events import (
        TextDelta, CotDelta, ToolCallsDone, Signal, StreamDone, StreamError,
    )

    async for event in self._source:
        if isinstance(event, MTextDelta):
            yield TextDelta(content=event.content)
        elif isinstance(event, MCotDelta):
            yield CotDelta(content=event.content)
        # ...
```

**详细解释**：
- model 层 StreamEvent 与 pipeline 层 PipelineEvent 类型名相同但属于不同模块
- 事件适配层将 model 层 StreamEvent 适配为 pipeline 层 PipelineEvent
- 解耦 model 层和 pipeline 层，pipeline 内部不依赖 model 层类型

**处理逻辑**：
```
场景：事件适配
  model 层产出: MTextDelta(content="今天北京晴天")
  → 事件适配层适配为 PipelineEvent
  → pipeline 层接收: TextDelta(content="今天北京晴天")
  → pipeline 内部不依赖 model 层类型

如果无事件适配层：
  → pipeline 内部依赖 model 层类型
  → 耦合度高
  → 难以维护

有事件适配层：
  → pipeline 内部不依赖 model 层类型
  → 耦合度低
  → 易于维护
```

### 2.4.2 为什么需要旧协议兼容（真实原因）

**来源**：代码实现 - `agent/pro/stream/processor.py`

**代码实现原文**：
```python
else:
    # 旧协议 tuple 兼容：转为对应 event
    if isinstance(event, tuple):
        from model.state import ModelState, TokenType
        data, token_type, model_state = event
        if token_type == TokenType.TEXT:
            yield TextDelta(content=data[0])
        elif token_type == TokenType.COT:
            yield CotDelta(content=data[0])
        # ...
```

**详细解释**：
- 旧协议使用 tuple 格式：`(data, token_type, model_state)`
- 新协议使用 dataclass 格式：`TextDelta(content=...)`
- 事件适配层兼容旧协议，平滑迁移

**业务场景**：
```
场景：旧协议兼容
  旧模型产出: ("今天北京晴天", TokenType.TEXT, ModelState.NORMAL)
  → 事件适配层兼容旧协议
  → 转换为: TextDelta(content="今天北京晴天")
  → pipeline 层正常处理

如果无旧协议兼容：
  → 旧模型无法使用
  → 需要所有模型同时升级到新协议
  → 迁移成本高

有旧协议兼容：
  → 旧模型可以继续使用
  → 平滑迁移
  → 迁移成本低
```

## 2.5 业务价值原因

### 2.5.1 为什么流式处理管道值得体系化投入（真实原因）

**来源**：代码数据统计

**数据**：
```
优化前（god function）：
  → _stream_model_response 250+ 行
  → 6 种职责混杂在一起
  → 难以维护
  → 新增处理器需要修改核心代码，风险高

优化落地：commit 2026-07-09

优化后（Pipeline 架构）：
  → god function 拆解为 12 个职责单一的模块
  → 每个处理器职责单一
  → 易于维护