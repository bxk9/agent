    - 变换 event 内容后 yield
    - 吞掉不需要的 event（不 yield）
    - 从一个 event 产出多个 event（yield 多次）
    """

    @abstractmethod
    async def process(
        self, upstream: AsyncGenerator[PipelineEvent, None]
    ) -> AsyncGenerator[PipelineEvent, None]:
        ...
        yield  # type: ignore  # 标记为 async generator
```

**关键设计**：
- AsyncGenerator 链式组合：每个处理器消费上游，产出下游
- 灵活的 event 处理：透传、变换、吞掉、一对多
- 抽象基类强制实现 `process()` 方法

### 4.3 StreamPipeline 容器

**实现位置**：`agent/pro/stream/processor.py`

```python
class StreamPipeline:
    """Pipeline 容器：将 model 原始事件流经过 processor 链处理后产出最终事件流。

    用法：
        pipeline = StreamPipeline(
            source=model.stream(messages, request_id, trace_id, tools),
            processors=[EosFilter(), MarkerFilter(), SpecialTokenExtractor()],
        )
        async for event in pipeline:
            assembler.feed(event)
    """

    def __init__(
        self,
        source: AsyncGenerator[StreamEvent, None],
        processors: list[StreamProcessor],
    ):
        self._source = source
        self._processors = processors

    async def _adapt_source(self) -> AsyncGenerator[PipelineEvent, None]:
        """将 model 层 StreamEvent 适配为 pipeline 层 PipelineEvent。

        model.stream_events 与 pipeline.events 类型名相同但属于不同模块，
        此处做一次显式转换，使 pipeline 内部不依赖 model 层类型。
        """
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
            elif isinstance(event, MToolCallsDone):
                yield ToolCallsDone(
                    tool_calls=event.tool_calls,
                    thought_signature=event.thought_signature,
                )
            elif isinstance(event, MStreamDone):
                yield StreamDone()
            elif isinstance(event, MStreamError):
                yield StreamError(code=event.code, message=event.message)
            else:
                # 旧协议 tuple 兼容：转为对应 event
                if isinstance(event, tuple):
                    from model.state import ModelState, TokenType
                    data, token_type, model_state = event
                    if token_type == TokenType.TEXT:
                        yield TextDelta(content=data[0])
                    elif token_type == TokenType.COT:
                        yield CotDelta(content=data[0])
                    elif token_type == TokenType.TOOL_FUNC_ARGS:
                        from model.stream_events import ToolCallInfo
                        yield ToolCallsDone(
                            tool_calls=[
                                ToolCallInfo(
                                    id=tc.get("id", ""),
                                    name=tc.get("name", ""),
                                    arguments=tc.get("arguments", ""),
                                    thought_signature=tc.get("thoughtSignature", ""),
                                )
                                for tc in data[0]
                            ]
                        )
                    elif model_state == ModelState.ERROR:
                        code = data.get("code", 503) if isinstance(data, dict) else 503
                        msg = data.get("message", "模型返回异常状态") if isinstance(data, dict) else "模型返回异常状态"
                        yield StreamError(code=code, message=msg)
                    elif model_state == ModelState.FINISH:
                        yield StreamDone()
                    # TOOL_CALL_FINISH / TOOL_FUNC / TOOL_ARGS 忽略（旧协议残留）

    async def __aiter__(self) -> AsyncGenerator[PipelineEvent, None]:
        stream = self._adapt_source()
        for proc in self._processors:
            stream = proc.process(stream)
        async for event in stream:
            yield event
```

**关键设计**：
- 事件适配层：将 model 层 StreamEvent 适配为 pipeline 层 PipelineEvent
- 旧协议兼容：支持 tuple 格式的旧协议
- 处理器链式组合：`stream = proc.process(stream)` 实现链式处理

### 4.4 EosFilter Processor

**实现位置**：`agent/pro/stream/processors/eos_filter.py`

```python
"""EOS token 截断处理器：检测并截断模型泄漏的 <|endoftext|>。"""
from collections.abc import AsyncGenerator

from infra.logger import logger
from agent.pro.stream.events import PipelineEvent, TextDelta, CotDelta, StreamDone
from agent.pro.stream.processor import StreamProcessor


class EosFilter(StreamProcessor):
    """检测 <|endoftext|> 泄漏，截断文本并终止流。"""

    EOS_TOKEN = "<|endoftext|>"

    async def process(
        self, upstream: AsyncGenerator[PipelineEvent, None]
    ) -> AsyncGenerator[PipelineEvent, None]:
        async for event in upstream:
            if isinstance(event, (TextDelta, CotDelta)):
                if self.EOS_TOKEN in event.content:
                    clean = event.content[:event.content.index(self.EOS_TOKEN)]
                    logger.info(f"[eos_filter] 检测到 <|endoftext|>，截断 clean={clean!r}")
                    if clean:
                        yield type(event)(content=clean)
                    yield StreamDone()
                    return
                yield event
            else:
                yield event
```

**关键设计**：
- 检测 `<|endoftext|>` 泄漏，截断文本并终止流
- 截断后保留干净部分，yield StreamDone 终止流
- 只处理 TextDelta 和 CotDelta，其他 event 透传

### 4.5 MarkerFilter Processor

**实现位置**：`agent/pro/stream/processors/marker_filter.py`

```python
"""模型控制标记过滤器：吞掉 <|FunctionCallBegin|> 等标记碎片。"""
from collections.abc import AsyncGenerator

from infra.special_token_utils import ModelMarkerFilter as _ModelMarkerFilter
from infra.special_token_utils import model_marker_filter_markers, model_marker_filter_skip_until
from agent.pro.stream.events import PipelineEvent, TextDelta, CotDelta
from agent.pro.stream.processor import StreamProcessor


class MarkerFilter(StreamProcessor):
    """复用 infra.special_token_utils.ModelMarkerFilter 的流式标记过滤逻辑。

    只处理 TextDelta/CotDelta，其他 event 透传。
    过滤后若文本为空则不 yield（标记碎片被吞掉）。
    """

    def __init__(self, markers=None, skip_until=None):
        self._markers = markers or model_marker_filter_markers
        self._skip_until = skip_until or model_marker_filter_skip_until

    async def process(
        self, upstream: AsyncGenerator[PipelineEvent, None]
    ) -> AsyncGenerator[PipelineEvent, None]:
        _filter = _ModelMarkerFilter(self._markers, self._skip_until)

        async for event in upstream:
            if isinstance(event, (TextDelta, CotDelta)):
                filtered, _ = _filter.feed(event.content)
                if filtered:
                    yield type(event)(content=filtered)
                # 若 filtered 为空，标记碎片被吞掉，不 yield
            else:
                # 流结束时 flush 残留
                if hasattr(event, '__class__') and event.__class__.__name__ in ('StreamDone', 'StreamError'):
                    remainder = _filter.flush()
                    if remainder:
                        yield TextDelta(content=remainder)
                yield event
```

**关键设计**：
- 复用 `infra.special_token_utils.ModelMarkerFilter` 的流式标记过滤逻辑
- 过滤后若文本为空则不 yield（标记碎片被吞掉）
- 流结束时 flush 残留，避免丢失数据

### 4.6 SpecialTokenExtractor Processor

**实现位置**：`agent/pro/stream/processors/special_token_extractor.py`

```python
"""控制信号提取器：从文本流中提取 <!@-xxx-@!> 格式的控制信号。"""
from collections.abc import AsyncGenerator

from infra.logger import logger
from infra.special_token_utils import (
    special_token as _special_token_instance,
    SpecialTokenType,
    normalize_special_token,
    strip_leaked_signals,
)
from agent.pro.stream.events import PipelineEvent, TextDelta, CotDelta, Signal, StreamDone, StreamError
from agent.pro.stream.processor import StreamProcessor


# 信号 label 到 Signal.label 的映射
_SIGNAL_MAP = {
    "end": "session_finished",
    "已完成": "session_finished",
    "已展现": "session_finished",
    "WAIT_INPUT": "enable_voice",
}


class SpecialTokenExtractor(StreamProcessor):
    """流式提取 <!@-label-@!> 控制信号，产出 Signal event + 干净 TextDelta。

    处理逻辑：
    1. 对每个 TextDelta/CotDelta 做 normalize → special_token.match()
    2. 匹配到 label 时 yield Signal(label)
    3. 剩余干净文本 yield 为 TextDelta/CotDelta
    4. 流结束时做 Tier 2 兜底（理论上不应触发）
    """

    async def process(
        self, upstream: AsyncGenerator[PipelineEvent, None]
    ) -> AsyncGenerator[PipelineEvent, None]:
        state = SpecialTokenType.NOT_MATCH.value
        buffer = ""
        accumulated_text = ""  # 用于 Tier 2 兜底

        async for event in upstream:
            if isinstance(event, (TextDelta, CotDelta)):
                normalized = normalize_special_token(event.content)
                token_str, state, buffer, label = _special_token_instance.match(
                    normalized, state, buffer
                )

                if label: