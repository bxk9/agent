# Infra 基础设施模块详解

> 本文档详细描述 infra 模块的架构设计、Context Pipeline 多级压缩、日志系统、认证工具和系统提示词构建。

## 目录

1. [模块概述](#1-模块概述)
2. [设计理念](#2-设计理念)
3. [Context Pipeline](#3-context-pipeline)
4. [日志系统](#4-日志系统)
5. [认证工具](#5-认证工具)
6. [特殊 Token 处理](#6-特殊-token-处理)
7. [系统提示词构建](#7-系统提示词构建)
8. [其他基础设施](#8-其他基础设施)
9. [接口说明](#9-接口说明)

---

## 1 模块概述

### 1.1 模块定位

infra 模块是 pro_agent 的基础设施层，提供跨模块复用的通用能力：

- **Context Pipeline**：四级上下文压缩管道，控制 token 预算
- **日志系统**：loguru 结构化日志 + trace_id contextvar
- **认证工具**：玄机协议 HMAC-SHA256 签名
- **特殊 Token 处理**：SpecialToken 状态机、ModelMarkerFilter
- **系统提示词构建**：动态系统提示词片段（时间/地理/场景）
- **推荐位意图**：1.0 技能意图 → 3.0 工具候选短路
- **上传引导检测**：图片/文档上传引导信号检测

### 1.2 模块结构

```
infra/
├── __init__.py
├── context_pipeline/          # 四级上下文压缩管道
│   ├── __init__.py
│   ├── protocol.py            # TokenBudget + Compressor Protocol
│   ├── pipeline.py            # ContextPipeline 调度器
│   ├── token_estimator.py     # 近似 token 计数
│   └── compressors/           # 四级压缩器实现
│       ├── structured_result_compressor.py  # L1：结构化字段提取
│       ├── tool_result_truncator.py         # L2：按工具名通用截断
│       ├── history_fader.py                 # L3：旧轮占位符替换
│       └── old_turn_dropper.py              # L4：整轮丢弃
├── logger.py                  # loguru 日志 + trace_id contextvar
├── stat_logger.py             # 统计日志（埋点落盘）
├── stat_collector.py          # StatCollector 埋点数据收集
├── auth_utils.py              # HMAC-SHA256 签名
├── special_token_utils.py     # SpecialToken 状态机 + ModelMarkerFilter
├── body_context.py            # BodyContext 请求体上下文
├── chat_history_utils.py      # 历史消息工具函数
├── chat_history_compactor.py  # 历史消息紧凑化
├── extra_system_prompt_utils.py # 动态系统提示词片段
├── recommend_intention.py     # 推荐位意图解析
├── image_intent_utils.py      # 图片上传引导检测
├── document_intent_utils.py   # 文档上传引导检测
├── reverse_geocode_utils.py   # 异步逆地理编码
├── fileio.py                  # 文件读写工具
└── string_utils.py            # 字符串工具函数
```

---

## 2 设计理念

### 2.1 压力驱动的多级压缩

Context Pipeline 采用四级压缩策略，按压力逐级升级：

```
L1 结构化提取 → L2 通用截断 → L3 历史退化 → L4 整轮丢弃
（信息损失最小）                    （信息损失最大）
```

每级压缩器只在上一级不够用时才启用，最小化信息损失。

### 2.2 零业务依赖

infra 层的模块尽量零业务依赖，只依赖标准库和其他 infra 模块。例如 `auth_utils.py` 只依赖 `hashlib` 和 `time`。

### 2.3 ContextVar 注入

使用 Python `contextvars` 注入 trace_id 和请求起始时间，避免在函数签名中传递。

---

## 3 Context Pipeline

### 3.1 架构设计

```
ContextPipeline
    ├── TokenBudget（token 预算配置）
    ├── Compressor Protocol（压缩器协议）
    │   ├── L1: StructuredResultCompressor（结构化字段提取）
    │   ├── L2: ToolResultTruncator（按工具名通用截断）
    │   ├── L3: HistoryFader（旧轮占位符替换）
    │   └── L4: OldTurnDropper（整轮丢弃）
    └── TokenEstimator（近似 token 计数）
```

### 3.2 压缩器协议

```python
class Compressor(Protocol):
    def compress(self, messages: list[dict], budget: TokenBudget) -> list[dict]:
        """压缩消息列表，使其符合 token 预算"""
        ...
```

### 3.3 四级压缩器

| 级别 | 压缩器 | 策略 | 信息损失 |
|---|---|---|---|
| **L1** | StructuredResultCompressor | 声明式结构化字段提取（只保留关键字段） | 低 |
| **L2** | ToolResultTruncator | 按工具名通用截断（超长内容截断） | 中 |
| **L3** | HistoryFader | 旧轮占位符替换（旧对话替换为摘要） | 高 |
| **L4** | OldTurnDropper | 整轮丢弃（最终防线，丢弃最旧的轮次） | 最高 |

### 3.4 调度逻辑

```python
class ContextPipeline:
    def compress(self, messages, model_type):
        budget = self.get_budget(model_type)
        current_tokens = self.estimator.estimate(messages)

        if current_tokens <= budget.max_tokens:
            return messages  # 无需压缩

        for compressor in self.compressors:
            messages = compressor.compress(messages, budget)
            current_tokens = self.estimator.estimate(messages)
            if current_tokens <= budget.max_tokens:
                break  # 已满足预算

        return messages
```

### 3.5 Token 估算

```python
class TokenEstimator:
    def estimate(self, messages: list[dict]) -> int:
        """近似 token 计数（字符数 / 3.5）"""
```

---

## 4 日志系统

### 4.1 loguru 配置

**文件**：`infra/logger.py`

```python
from loguru import logger
import contextvars

trace_id_ctx_var = contextvars.ContextVar("trace_id", default="")
req_start_ctx_var = contextvars.ContextVar("req_start", default=0)
```

### 4.2 trace_id 注入

通过 `contextvars` 注入 trace_id，所有日志自动携带：

```python
trace_id_ctx_var.set(body.get("trace_id", ""))
logger.info(f"处理请求 query={query}")
# 输出：2026-08-11 10:00:00 | INFO | 处理请求 query=... | trace_id=xxx
```

### 4.3 统计日志

**文件**：`infra/stat_logger.py`

```python
def build_trace_data(turn: TurnState, body: dict, context) -> dict:
    """从 TurnState 构建埋点数据"""

def write_stat_log(data:dict):
    """写入统计日志（落盘到 ES/文件）"""
```

### 4.4 StatCollector

**文件**：`infra/stat_collector.py`

```python
@dataclass
class StatCollector:
    # 时间戳
    prepare_start: float = 0
    prepare_end: float = 0
    infer_start: float = 0
    infer_end: float = 0
    finalize_start: float = 0
    finalize_end: float = 0

    # 模型指标
    model_name: str = ""
    input_tokens: int = 0
    output_tokens: int = 0
    cached_tokens: int = 0
    ttft_ms: int = -1
    cost_ms: int = 0

    # TTFT 分桶
    ttft_a_preproc_ms: float | None = None
    ttft_b_net_ms: float | None = None
    ttft_c_decode_ms: float | None = None
    ttft_d_onscreen_ms: float | None = None
    ttft_total_ms: float | None = None

    # 业务指标
    candidate_tools: list = field(default_factory=list)
    patches: list = field(default_factory=list)
    validators: list = field(default_factory=list)
    tool_exec_status: list = field(default_factory=list)
```

---

## 5 认证工具

### 5.1 HMAC-SHA256 签名

**文件**：`infra/auth_utils.py`

```python
def build_sign_headers(app_id, app_key, method, uri, params) -> dict:
    """构建玄机协议 HMAC-SHA256 签名请求头"""
    timestamp = str(int(time.time()))
    nonce = str(uuid.uuid4())
    sign_str = f"{method}\n{uri}\n{timestamp}\n{nonce}\n{json.dumps(params)}"
    signature = hmac.new(
        app_key.encode(), sign_str.encode(), hashlib.sha256
    ).hexdigest()
    return {
        "X-App-Id": app_id,
        "X-Timestamp": timestamp,
        "X-Nonce": nonce,
        "X-Signature": signature,
    }
```

### 5.2 Bearer Token

```python
def build_bearer_token(app_id, app_key) -> str:
    """构建 Bearer Token（OpenAI 协议）"""
```

---

## 6 特殊 Token 处理

### 6.1 SpecialToken 状态机

**文件**：`infra/special_token_utils.py`

解析 `<!@-<label>-@!>` 格式的特殊标记：

| 标记 | 含义 |
|---|---|
| `<!@-end-@!>` | 会话结束，设置 `session_finished=True` |
| `<!@-WAIT_INPUT-@!>` | 需要用户输入，设置 `enable_voice=True` |
| `<!@-<tool_name>-@!>` | 模型触发的工具名（记录到 mcp_tools） |

### 6.2 ModelMarkerFilter

过滤模型控制标记，防止其直接输出给用户：

| 标记 | 格式 |
|---|---|
| `<\|FunctionCallBegin\|>` / `<\|FunctionCallEnd\|>` | Doubao 格式 |
| `<tool_call>` / `</tool_call>` | BlueLM 格式 |
| `<\|End\|>` | EOS token 碎片兜底 |

### 6.3 跨 token 拆分处理

结束符变体（如 `-@>` / `- @ ! >`）可能被切分到多个 token。通过模糊前缀表检测未完成片段，等待后续 token 拼接后再判定。

---

## 7 系统提示词构建

### 7.1 动态提示词片段

**文件**：`infra/extra_system_prompt_utils.py`

| 组件 | 说明 |
|---|---|
| `JoviContext` | 统一封装 `context['extra']['extras']['jovi']` 的访问 |
| `PanelState` | 面板状态封装 |
| `get_fronted_app()` | 获取当前前台 App 信息 |
| `phone_status_prompt_snippet()` | 手机状态提示词（锁屏、阅读等 6 个字段） |
| `extra_info_prompt_snippet()` | 额外信息提示词 |
| `CAR_SCENE_APP_IDS` | 车载场景 app_id 集合 |

### 7.2 提示词模块体系

系统提示词由多个模块拼接而成：

```
base_prompt（基础提示词）
    + time_prompt（时间/日期/农历）
    + phone_status_prompt（手机状态）
    + panel_state_prompt（面板状态）
    + car_scene_prompt（车载场景）
    + tool_extra_prompts（工具专属提示词）
    + patch_prompts（Patch 注入的提示词）
    + arbitration_prompts（仲裁策略提示词）
```

### 7.3 模块禁用机制

通过 `disable_prompt_modules` 集合（由 Patch 声明式控制），可以禁用特定的提示词模块：

```python
built_system_prompt = _build_system_prompt(
    body, model_type=model_type,
    disable_modules=turn.disable_prompt_modules,
)
```

---

## 8 其他基础设施

### 8.1 推荐位意图解析
