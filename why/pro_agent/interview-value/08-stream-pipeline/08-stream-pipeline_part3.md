                    logger.info(f"[special_token_extractor] 提取到信号 label={label}")
                    signal_label = _SIGNAL_MAP.get(label, f"mcp:{label}")
                    yield Signal(label=signal_label)

                if token_str:
                    accumulated_text += token_str
                    yield type(event)(content=token_str)

            elif isinstance(event, (StreamDone, StreamError)):
                # 流结束：flush 状态机残留
                if state != SpecialTokenType.NOT_MATCH.value:
                    _, state, buffer, residual_label = _special_token_instance.match(
                        " ", state, buffer
                    )
                    if residual_label:
                        logger.info(f"[special_token_extractor] 流结束残留 label={residual_label}")
                        signal_label = _SIGNAL_MAP.get(residual_label, f"mcp:{residual_label}")
                        yield Signal(label=signal_label)

                # Tier 2 兜底：全文扫描
                if accumulated_text:
                    _, leaked_signals = strip_leaked_signals(accumulated_text)
                    if leaked_signals:
                        logger.warning(
                            f"[special_token_extractor] Tier2 兜底检测到泄漏信号 signals={leaked_signals}"
                        )
                        for sig in leaked_signals:
                            signal_label = _SIGNAL_MAP.get(sig, f"mcp:{sig}")
                            yield Signal(label=signal_label)

                yield event
            else:
                yield event
```

**关键设计**：
- 流式提取 `<!@-label-@!>` 控制信号，产出 Signal event + 干净 TextDelta
- 状态机处理跨 chunk 的特殊 token（buffer 累积）
- Tier 2 兜底：流结束时全文扫描，检测泄漏信号

### 4.7 TextToolParserProcessor（BlueLM text_parse 模式）

**实现位置**：`agent/pro/stream/processors/text_tool_parser.py`

```python
"""文本工具解析处理器：将 <tool_call>...</tool_call> 或 <seed:N>...</seed:N> 解析为 ToolCallsDone。

仅用于 tool_mode="text_parse" 的模型（如 BlueLM）。
其他模型不挂载此 processor。
"""
from collections.abc import AsyncGenerator

from model.stream_events import ToolCallInfo
from model.xuanji._tool_text_parser import TextToolParser as _TextToolParser
from agent.pro.stream.events import PipelineEvent, TextDelta, CotDelta, ToolCallsDone
from agent.pro.stream.processor import StreamProcessor


class TextToolParserProcessor(StreamProcessor):
    """将文本中的工具调用标记解析为结构化 ToolCallsDone event。"""

    async def process(
        self, upstream: AsyncGenerator[PipelineEvent, None]
    ) -> AsyncGenerator[PipelineEvent, None]:
        parser = _TextToolParser()

        async for event in upstream:
            if isinstance(event, TextDelta):
                output_text, tool_calls = parser.feed(event.content)
                if output_text:
                    yield TextDelta(content=output_text)
                if tool_calls:
                    yield ToolCallsDone(
                        tool_calls=[
                            ToolCallInfo(
                                id=tc.id,
                                name=tc.name,
                                arguments=tc.arguments,
                            )
                            for tc in tool_calls
                        ]
                    )
            else:
                yield event
```

**关键设计**：
- 仅用于 `tool_mode="text_parse"` 的模型（如 BlueLM）
- 将文本中的工具调用标记解析为结构化 ToolCallsDone event
- 其他模型不挂载此 processor

### 4.8 ResultAssembler + InferenceResult

**实现位置**：`agent/pro/stream/assembler.py`

```python
"""ResultAssembler：无条件累积 pipeline 事件，产出不可变 InferenceResult。"""
from __future__ import annotations
from dataclasses import dataclass, field

from model.stream_events import ToolCallInfo
from agent.pro.stream.events import (
    PipelineEvent, TextDelta, CotDelta, ToolCallsDone, Signal, StreamDone, StreamError,
)


@dataclass
class InferenceResult:
    """单次推理的不可变结果快照。"""
    text: str = ""
    cot_text: str = ""
    tool_calls: list[ToolCallInfo] = field(default_factory=list)
    thought_signature: str = ""
    signals: set[str] = field(default_factory=set)
    error: StreamError | None = None
    has_text: bool = False
    token_count: int = 0

    @property
    def session_finished(self) -> bool:
        return "session_finished" in self.signals

    @property
    def enable_voice(self) -> bool:
        return "enable_voice" in self.signals

    @property
    def mcp_tools(self) -> list[str]:
        """提取 mcp:xxx 信号中的工具名"""
        return [s.removeprefix("mcp:") for s in self.signals if s.startswith("mcp:")]

    @property
    def is_error(self) -> bool:
        return self.error is not None


class ResultAssembler:
    """无条件累积所有 event，流结束后调用 result() 获取快照。

    用法：
        assembler = ResultAssembler()
        async for event in pipeline:
            assembler.feed(event)
        result = assembler.result()
    """

    def __init__(self):
        self._text_parts: list[str] = []
        self._cot_parts: list[str] = []
        self._tool_calls: list[ToolCallInfo] = []
        self._thought_signature: str = ""
        self._signals: set[str] = set()
        self._error: StreamError | None = None
        self._token_count: int = 0
        self._has_text: bool = False

    def feed(self, event: PipelineEvent) -> None:
        """喂入一个 event，无条件累积。"""
        self._token_count += 1

        if isinstance(event, TextDelta):
            self._text_parts.append(event.content)
            if event.content.strip():
                self._has_text = True
        elif isinstance(event, CotDelta):
            self._cot_parts.append(event.content)
        elif isinstance(event, ToolCallsDone):
            self._tool_calls.extend(event.tool_calls)
            self._thought_signature = event.thought_signature
        elif isinstance(event, Signal):
            self._signals.add(event.label)
        elif isinstance(event, StreamError):
            self._error = event
        elif isinstance(event, StreamDone):
            pass  # 正常结束，无额外处理

    def result(self) -> InferenceResult:
        """产出不可变结果快照。"""
        return InferenceResult(
            text="".join(self._text_parts),
            cot_text="".join(self._cot_parts),
            tool_calls=list(self._tool_calls),
            thought_signature=self._thought_signature,
            signals=set(self._signals),
            error=self._error,
            has_text=self._has_text,
            token_count=self._token_count,
        )
```

**关键设计**：
- 无条件累积所有 event，流结束后调用 `result()` 获取快照
- InferenceResult 是不可变结果快照，提供便捷属性（session_finished、enable_voice、mcp_tools）
- 分离关注点：Pipeline 只产事件，ResultAssembler 负责累积

### 4.9 SseEmitter

**实现位置**：`agent/pro/stream/emitter.py`

```python
"""SSE 发射器：展示过滤 + 格式化。

职责：
1. 决定哪些 TextDelta 应该推给客户端（跳过前导空白等）
2. 格式化为 SSE 字符串
"""
import json

from agent.pro.stream.events import PipelineEvent, TextDelta


class SseEmitter:
    """展示过滤 + SSE 格式化。

    用法：
        emitter = SseEmitter()
        async for event in pipeline:
            chunk = emitter.emit(event)
            if chunk:
                yield chunk
    """

    def __init__(self):
        self._has_emitted: bool = False

    @property
    def has_emitted(self) -> bool:
        return self._has_emitted

    def emit(self, event: PipelineEvent) -> str | None:
        """尝试将 event 格式化为 SSE chunk。返回 None 表示不需要发送。"""
        if not isinstance(event, TextDelta):
            return None

        text = event.content
        if not text:
            return None

        # 尚未输出过有效文本时，跳过纯空白（flash 模型 think 残留的换行符）
        if not self._has_emitted and not text.strip():
            return None

        self._has_emitted = True
        return "event:text\ndata:" + json.dumps({"text": text}, ensure_ascii=False) + "\n\n"
```

**关键设计**：
- 展示过滤：跳过前导空白（flash 模型 think 残留的换行符）
- SSE 格式化：`event:text\ndata:{"text": "..."}\n\n`
- `has_emitted` 状态：用于 retry 循环内跨迭代保持

### 4.10 Pipeline 工厂函数

**实现位置**：`agent/pro/stream/__init__.py`

```python
from agent.pro.stream.processors import (
    EosFilter, MarkerFilter, SpecialTokenExtractor, TextToolParserProcessor,
)


def build_processors(model) -> list[StreamProcessor]:
    """根据模型 profile 构建 processor 链。

    Args:
        model: 模型实例（XuanjiModel 或 openai_model.Model）

    Returns:
        按执行顺序排列的 processor 列表
    """
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

**关键设计**：
- 根据模型 profile 动态构建 processor 链
- BlueLM text_parse 模式挂载 TextToolParserProcessor
- 其他模型只挂载基础三个 processor

### 4.11 边界 case 处理

**Case 1：EOS token 泄漏**
```
场景: 模型输出 "今天天气很好<|endoftext|>"
处理: EosFilter 检测到 <|endoftext|>，截断为 "今天天气很好"，yield StreamDone
结果: 客户端收到干净文本，流正常结束
```

**Case 2：模型控制标记碎片**
```
场景: 模型输出 "<|FunctionCallBegin|>create_alarm"
处理: MarkerFilter 吞掉 <|FunctionCallBegin|>，yield "create_alarm"