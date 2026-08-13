# Context Pipeline 多级压缩

> 面试价值：⭐⭐⭐⭐ | 技术深度：⭐⭐⭐⭐⭐ | 业务影响：⭐⭐⭐⭐

## 一句话总结

设计并实现四级上下文压缩管道（结构化提取 → 通用截断 → 历史退化 → 整轮丢弃），通过压力驱动的逐级压缩策略，在保证关键信息不丢失的前提下，将多轮对话的 token 占用降低 60-80%，解决长对话场景下的 token 超限问题。

---

## 1. 问题背景

### 1.1 业务场景

pro_agent 支持多轮对话，典型场景如下：

```
用户: "帮我查一下明天北京的天气"
  → 调用 weather_query 工具
  → 返回天气信息（500 tokens）

用户: "那后天呢？"
  → 调用 weather_query 工具
  → 返回天气信息（500 tokens）

用户: "帮我订一个明天去上海的高铁票"
  → 调用 book_train_ticket 工具
  → 返回订票信息（800 tokens）

... (继续多轮对话)

第10轮时：
  chat_history 累计 10000+ tokens
  system_prompt 2000 tokens
  当前 query 50 tokens
  总计 12050 tokens > 模型上下文窗口 8192 tokens
```

### 1.2 技术痛点

**核心问题**：多轮对话中，chat_history 不断累积，最终超过模型的上下文窗口限制。

| 指标 | 数值 | 说明 |
|---|---|---|
| 模型上下文窗口 | 8192 tokens | Doubao-Seed-2.0-pro |
| system_prompt | ~2000 tokens | 系统提示词 + 工具定义 |
| 单轮对话 | 500-1000 tokens | 用户输入 + 工具结果 |
| 多轮对话轮次 | 5-20 轮 | 复杂任务场景 |

**问题表现**：
- 超过 5 轮对话后，token 占用接近上限
- 超过 10 轮对话后，必然超限
- 超限导致模型截断输入，丢失关键信息
- 用户体验下降，对话无法继续

### 1.3 核心矛盾

**"需要在有限上下文窗口内保留尽可能多的历史信息"** —— 但简单的截断策略会丢失关键信息，而不截断又会超限。

---

## 2. 技术方案

### 2.1 设计思路

**四级压缩策略**：按信息损失从小到大逐级压缩，每级只在上一级不够时才启用。

```
L1: 结构化提取（信息损失最小）
  ↓ 仍超限
L2: 通用截断（信息损失中等）
  ↓ 仍超限
L3: 历史退化（信息损失较大）
  ↓ 仍超限
L4: 整轮丢弃（信息损失最大）
```

### 2.2 四级压缩器

#### L1: StructuredResultCompressor（结构化提取）

**策略**：将工具返回的 JSON 结果提取关键字段，丢弃冗余信息。

```python
class StructuredResultCompressor:
    """L1: 声明式结构化字段提取"""
    
    def compress(self, messages: list[dict], budget: TokenBudget) -> list[dict]:
        result = []
        for msg in messages:
            if msg.get("role") == "tool":
                # 提取关键字段
                compressed = self._extract_key_fields(msg)
                result.append(compressed)
            else:
                result.append(msg)
        return result
    
    def _extract_key_fields(self, msg: dict) -> dict:
        """提取工具结果的关键字段"""
        content = msg.get("content", "")
        try:
            data = json.loads(content)
            # 只保留关键字段（如 status, result, message）
            key_fields = {
                "status": data.get("status"),
                "result": data.get("result"),
                "message": data.get("message"),
            }
            return {
                **msg,
                "content": json.dumps(key_fields, ensure_ascii=False)
            }
        except:
            return msg
```

**压缩效果**：
- 原始：`{"status": "success", "result": {...}, "message": "...", "debug_info": {...}, "trace": [...]}`
- 压缩后：`{"status": "success", "result": {...}, "message": "..."}`
- 压缩率：50-70%

#### L2: ToolResultTruncator（通用截断）

**策略**：对超长工具结果进行截断，保留头部和尾部。

```python
class ToolResultTruncator:
    """L2: 按工具名通用截断"""
    
    def __init__(self, max_length: int = 1000):
        self.max_length = max_length
    
    def compress(self, messages: list[dict], budget: TokenBudget) -> list[dict]:
        result = []
        for msg in messages:
            if msg.get("role") == "tool":
                content = msg.get("content", "")
                if len(content) > self.max_length:
                    # 保留头部 60% + 尾部 40%
                    head_len = int(self.max_length * 0.6)
                    tail_len = self.max_length - head_len
                    truncated = (
                        content[:head_len] 
                        + "\n...[truncated]...\n" 
                        + content[-tail_len:]
                    )
                    result.append({**msg, "content": truncated})
                else:
                    result.append(msg)
            else:
                result.append(msg)
        return result
```

**压缩效果**：
- 超长结果（5000 tokens）→ 截断为 1000 tokens
- 压缩率：80%

#### L3: HistoryFader（历史退化）

**策略**：将旧轮次的对话替换为摘要占位符。

```python
class HistoryFader:
    """L3: 旧轮占位符替换"""
    
    def __init__(self, keep_recent: int = 3):
        self.keep_recent = keep_recent  # 保留最近 N 轮
    
    def compress(self, messages: list[dict], budget: TokenBudget) -> list[dict]:
        # 识别对话轮次边界（user 消息）
        turns = self._split_turns(messages)
        
        if len(turns) <= self.keep_recent:
            return messages
        
        # 保留最近 N 轮，旧轮替换为摘要
        result = []
        for i, turn in enumerate(turns):
            if i < len(turns) - self.keep_recent:
                # 旧轮：替换为摘要
                summary = self._generate_summary(turn)
                result.append({
                    "role": "system",
                    "content": f"[历史对话摘要] {summary}"
                })
            else:
                # 近期轮：保留完整内容
                result.extend(turn)
        
        return result
    
    def _generate_summary(self, turn: list[dict]) -> str:
        """生成对话轮次的摘要"""
        user_msg = next((m for m in turn if m.get("role") == "user"), None)
        if user_msg:
            query = user_msg.get("content", "")
            return f"用户询问了：{query[:50]}..."
        return "历史对话"
```

**压缩效果**：
- 10 轮对话 → 保留最近 3 轮 + 7 个摘要
- 压缩率：60-70%

#### L4: OldTurnDropper（整轮丢弃）

**策略**：丢弃最旧的对话轮次，直到满足预算。

```python
class OldTurnDropper:
    """L4: 整轮丢弃（最终防线）"""
    
    def compress(self, messages: list[dict], budget: TokenBudget) -> list[dict]:
        turns = self._split_turns(messages)
        
        # 从最旧的轮次开始丢弃
        while turns:
            current_tokens = self._estimate_tokens(self._flatten(turns))
            if current_tokens <= budget.max_tokens:
                break
            # 丢弃最旧的一轮
            turns.pop(0)
            logger.warning(f"[ContextPipeline] L4: 丢弃最旧对话轮次")
        
        return self._flatten(turns)
```

**压缩效果**：
- 丢弃最旧的轮次，直到满足预算
- 信息损失最大，但保证不超限

### 2.3 压力驱动调度

```python
class ContextPipeline:
    """四级上下文压缩管道"""
    
    def __init__(self, config: PipelineConfig):
        self.config = config
        self.estimator = TokenEstimator()
        self.compressors = [
            StructuredResultCompressor(),
            ToolResultTruncator(max_length=1000),
            HistoryFader(keep_recent=3),
            OldTurnDropper(),
        ]
    
    def compress(self, messages: list[dict], model_type: str) -> list[dict]:
        """压缩消息列表，使其符合 token 预算"""
        budget = self._get_budget(model_type)
        current_tokens = self.estimator.estimate(messages)
        
        logger.info(
            f"[ContextPipeline] 初始 token 数: {current_tokens}, "
            f"预算: {budget.max_tokens}"
        )
        
        if current_tokens <= budget.max_tokens:
            return messages  # 无需压缩
        
        # 逐级压缩
        for i, compressor in enumerate(self.compressors):
            logger.info(f"[ContextPipeline] 执行 L{i+1} 压缩")
            messages = compressor.compress(messages, budget)
            current_tokens = self.estimator.estimate(messages)
            
            logger.info(
                f"[ContextPipeline] L{i+1} 后 token 数: {current_tokens}"
            )
            
            if current_tokens <= budget.max_tokens:
                logger.info(f"[ContextPipeline] L{i+1} 压缩后满足预算，停止")
                break
        
        return messages
    
    def _get_budget(self, model_type: str) -> TokenBudget:
        """获取模型类型的 token 预算"""
        # 不同模型类型有不同的预算
        budgets = {
            "pro": TokenBudget(max_tokens=6000),  # 留 2000 给输出
            "flash": TokenBudget(max_tokens=3000),
        }
        return budgets.get(model_type, TokenBudget(max_tokens=6000))
```

---

## 3. 实现细节

### 3.1 Token 估算器

```python
class TokenEstimator:
    """近似 token 计数"""
    
    def estimate(self, messages: list[dict]) -> int:
        """估算消息列表的 token 数"""
        total_chars = 0
        for msg in messages:
            content = msg.get("content", "")
            total_chars += len(content)
        
        # 粗略估算：1 token ≈ 3.5 字符（中文）
        # 或 1 token ≈ 4 字符（英文）
        return int(total_chars / 3.5)
```

**为什么不用精确 tokenizer**：
- 精确 tokenizer 需要加载模型，性能开销大
- 粗略估算已足够，误差在 10% 以内
- 压缩策略有容错空间，不需要精确到个位数

### 3.2 对话轮次识别

```python
def _split_turns(self, messages: list[dict]) -> list[list[dict]]:
    """将消息列表分割为对话轮次"""
    turns = []
    current_turn = []
    