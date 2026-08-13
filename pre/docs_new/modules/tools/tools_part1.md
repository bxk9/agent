# Tools 模块详解

> 本文档详细描述 tools 模块的架构设计、工具注册机制、预处理/后处理流水线、三阶段验证框架和 MCP 工具定义。

## 目录

1. [模块概述](#1-模块概述)
2. [设计理念](#2-设计理念)
3. [核心组件](#3-核心组件)
4. [工具数据模型](#4-工具数据模型)
5. [工具注册与热更新](#5-工具注册与热更新)
6. [预处理流水线](#6-预处理流水线)
7. [后处理流水线](#7-后处理流水线)
8. [三阶段验证框架](#8-三阶段验证框架)
9. [MCP 工具定义](#9-mcp-工具定义)
10. [接口说明](#10-接口说明)

---

## 1 模块概述

### 1.1 模块定位

tools 模块是 pro_agent 的工具管理层，负责：

- **工具注册**：管理工具名 → Tool 对象的映射，支持原子替换
- **意图索引**：管理意图名 → 工具名列表的映射
- **预处理**：工具参数校验、补全、转换
- **后处理**：工具结果注入上屏指令、设置响应类型
- **验证**：三阶段验证框架（逐工具/批量/配置驱动）

### 1.2 模块结构

```
tools/
├── __init__.py
├── tool.py                    # Tool 数据模型 + pre/post/validate 调度
├── tool_registry.py           # ToolRegistry + IntentionIndex 类型化注册表
├── tool_builder.py            # 工具构建器
├── tool_request.py            # ToolCallRequest 数据结构
├── tool_response.py           # ToolCallResponse + 响应类型枚举
├── tool_category.py           # 工具分类枚举
├── tool_process_context.py    # ToolProcessContext（含 extras 正交信号通道）
├── tool_register_factory.py   # 装饰器工厂：注册 pre/post_process
├── validator.py               # 三阶段验证框架核心逻辑（~737行）
├── mock_query_defaults.py     # Mock query 默认参数
└── mcp/
    ├── mcp_definitions/       # 各领域工具 JSON Schema 定义
    │   ├── alarm/             # 闹钟（7 工具）
    │   ├── weather/           # 天气（1 工具）
    │   ├── schedule/          # 日程（4 工具）
    │   ├── travel/            # 出行（16 工具）
    │   ├── phone/             # 手机通信（12 工具）
    │   ├── media/             # 媒体（7 工具）
    │   ├── document/          # 文档（2 工具）
    │   ├── image_edit/        # 图片编辑（3 工具）
    │   ├── image_query/       # 图片查询（7 工具）
    │   ├── system/            # 系统（40+ 工具）
    │   ├── common/            # 通用（7 工具）
    │   └── visual_agent/      # 视觉 Agent（1 工具）
    ├── pre_process/           # 工具参数预处理
    │   ├── alarm.py, weather.py, schedule.py, ...
    │   ├── flash/             # Flash 模型专用
    │   └── pro/               # Pro 模型专用
    ├── post_process/          # 工具结果后处理
    │   ├── alarm.py, weather.py, schedule.py, ...
    │   ├── flash/             # Flash 模型专用
    │   └── pro/               # Pro 模型专用
    ├── validators/            # 验证器实现
    │   ├── _global/           # 全局批量验证器（Phase 2）
    │   ├── adjust_phone_settings.py
    │   ├── document_context_check.py
    │   ├── config_loader.py   # JSON 配置加载器
    │   ├── configs/           # 声明式验证规则 JSON
    │   └── prompts/           # LLM 验证器提示词模板
    └── mcp_viewer.py          # 工具定义查看器
```

---

## 2 设计理念

### 2.1 类型化注册表 + 原子替换

使用 `ToolRegistry` 和 `IntentionIndex` 替代裸 dict，提供类型安全和原子替换能力。

```python
class ToolRegistry:
    def replace(self, new_data):  # 原子替换（热更新用）
    def update(self, data):       # 增量更新（启动初始化用）
```

### 2.2 预处理与验证严格分离

| 层 | 职责 | 异常策略 |
|---|---|---|
| **pre_process** | 无条件变换（参数补全/规范化） | 异常降级为使用原始参数 |
| **validate** | 有条件决策（PASS/FIX/RETRY/DROP） | 异常降级为 PASS |
| **post_process** | 锦上添花（注入上屏指令） | 异常降级为返回原始结果 |

### 2.3 装饰器驱动的注册模式

通过装饰器自动注册预处理/后处理函数，无需手动维护注册表。

```python
@register_tool_pre_process(key="create_alarm")
async def alarm_preprocess(function_name, arguments, ctx):
    # 参数处理逻辑
    return function_name, arguments
```

### 2.4 模型类型分发

每个工具支持通用/Flash/Pro 三种处理器，按 model_type 自动选择。

```python
tool.resolve_pre_process(model_type)
    → pro_pre_process or flash_pre_process or pre_process
```

---

## 3 核心组件

### 3.1 Tool 数据模型

**文件**：`tools/tool.py`

```python
class Tool(BaseModel):
    original_names: list[str]           # 映射的 2.0 意图名
    definition: dict | None             # 工具 JSON Schema 定义
    pre_process: Callable | None        # 通用预处理
    flash_pre_process: Callable | None  # Flash 专用预处理
    pro_pre_process: Callable | None    # Pro 专用预处理
    post_process: Callable | None       # 通用后处理
    flash_post_process: Callable | None # Flash 专用后处理
    pro_post_process: Callable | None   # Pro 专用后处理
    validators: list[Any]               # 验证器列表
    related_tools: list[str]            # 关联工具（自动展开）
    extra_system_prompt: str            # 工具专属额外系统提示词
    type: int                           # 工具类型（0=MCP, 1=Agent）
```

### 3.2 ToolRegistry（工具注册表）

**文件**：`tools/tool_registry.py`

```python
class ToolRegistry:
    """工具名 → Tool 对象的注册表"""
    def __getitem__(self, key) -> Tool
    def get(self, key, default=None) -> Tool | None
    def replace(self, new_data:dict[str, Tool])  # 原子替换
    def update(self, data: dict[str, Tool])        # 增量更新
```

### 3.3 IntentionIndex（意图索引）

```python
class IntentionIndex:
    """意图名 → 工具名列表的索引"""
    def __getitem__(self, key) -> list[str]
    def replace(self, new_data: dict[str, list[str]])
    def update(self, data: dict[str, list[str]])
```

### 3.4 全局单例

```python
tool_store = ToolRegistry()                          # 工具名 → Tool
intention_tool_index = IntentionIndex(               # 意图名 → 工具名列表
    {"common_tools": ["knowledgeQA"]}
)
skill_intent_to_atom_index = IntentionIndex({})      # 1.0 技能意图 → 2.0 原子意图
```

### 3.5 工具排序策略

```python
high_freq_tools: set[str]  # 28 个高频工具，置于最前
long_tools: set[str]       # 22 个长定义工具，排在高频之后
```

**排序目的**：提升 LLM prompt cache 前缀稳定性，减少缓存失效。

---

## 4 工具数据模型

### 4.1 ToolCallRequest

**文件**：`tools/tool_request.py`

```python
class ToolCallRequest(BaseModel):
    tool_name: str       # 工具名
    tool_args: dict      # 工具参数
```

### 4.2 ToolCallResponse

**文件**：`tools/tool_response.py`

```python
class ToolCallResponse(BaseModel):
    content: str                          # 工具执行结果
    response_type: int                    # 响应类型
    response_text: str = ""               # 上屏文本
    output_instruct: str = ""             # 输出指令
    # ...

class ToolCallResponseType(IntEnum):
    NORMAL = 0           # 普通响应，继续模型推理
    STREAM_ON_USER = 1   # 结果已流式上屏，不需模型总结
    INTERACT = 2         # 需要用户干预选择
    EXIT = 3             # 提前退出会话
```

### 4.3 ToolProcessContext

**文件**：`tools/tool_process_context.py`

```python
class ToolProcessContext:
    query: str                    # 用户查询
    chat_history: list            # 对话历史
    agent_context: dict           # 请求体
    tool_results: list            # 工具执行结果
    model_type: str               # 模型类型
    smart_route_info: SmartRouteInfo  # 智能路由
    extras: dict                  # 正交信号通道（如 easter_egg_matched）
```

---

## 5 工具注册与热更新

### 5.1 启动时注册流程

```
init_app()
    ├─ _build_mcp_mapping()
    │   ├─ 读取 mapping_simple.json → 构建 ToolRegistry
    │   ├─ 读取 mcp_definitions/ JSON → 挂载 Tool.definition
    │   └─ 预注册彩蛋工具占位 Tool
    ├─ register_tool()
    │   ├─ 扫描 pre_process/*.py → @register_tool_pre_process 装饰器执行
    │   ├─ 扫描 pre_process/flash/*.py / pre_process/pro/*.py
    │   ├─ 扫描 post_process/*.py / post_process/flash/*.py / post_process/pro/*.py
    │   └─ 加载 validators/configs/ → 声明式验证器注册
    └─ 注册配置变更回调
```

### 5.2 热更新流程

```
VivoConfigManager 轮询 → mcp_intention_mapping 变更
    → reload_mcp_mapping() 回调（_mcp_mapping_lock 保护）
        1. 构建临时新字典 new_intentions
        2. register_tool(mcp_intentions=new_intentions) 挂载处理函数
        3. tool_store.replace(new_intentions)  ← 原子替换
        4. intention_tool_index.replace(new_mcps)  ← 原子替换
```

### 5.3 装饰器工厂

**文件**：`tools/tool_register_factory.py`

```python
@register_tool_pre_process(key="create_alarm", related_tools=["search_alarm"])
async def alarm_preprocess(function_name, arguments, ctx: ToolProcessContext):
    # 参数校验、补全、转换
    return function_name, arguments

@register_tool_post_process(key="create_alarm")
async def alarm_postprocess(function_name, arguments,
                            tool_call_response: ToolCallResponse, ctx):
    # 注入 output_instruct，设置 response_type
    return tool_call_response
```

---

## 6 预处理流水线

### 6.1 调度逻辑

```python