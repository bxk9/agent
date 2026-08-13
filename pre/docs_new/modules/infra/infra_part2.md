**文件**：`infra/recommend_intention.py`

1.0 技能意图 → 2.0 原子意图 → 3.0 工具候选，支持两级匹配：
- **L1 精确匹配**：技能意图 → 原子意图 → 工具
- **L2 domain 降级**：技能意图 → domain → 工具

### 8.2 上传引导检测

| 文件 | 功能 |
|---|---|
| `image_intent_utils.py` | 检测模型是否在引导用户上传图片 |
| `document_intent_utils.py` | 检测模型是否在引导用户上传文档 |

### 8.3 逆地理编码

**文件**：`infra/reverse_geocode_utils.py`

```python
async def reverse_geocode(longitude, latitude, trace_id) -> tuple[bool, str, str, str]:
    """异步经纬度逆地理编码，返回 (ok, province, city, county)"""
```

### 8.4 BodyContext

**文件**：`infra/body_context.py`

统一封装请求体的访问，提供类型安全的属性访问：

```python
class BodyContext:
    panel_state: PanelStateEnum
    is_panel_first: bool
    longitude: float
    latitude: float
    has_schedule_context: bool
    schedule: dict
    # ...
```

### 8.5 历史消息处理

| 文件 | 功能 |
|---|---|
| `chat_history_utils.py` | 历史消息解析（提取 tool_call 参数） |
| `chat_history_compactor.py` | 历史消息紧凑化 |

---

## 9 接口说明

### 9.1 Context Pipeline

```python
from infra.context_pipeline import ContextPipeline

pipeline = ContextPipeline(config)
compressed_messages = pipeline.compress(messages, model_type="pro")
```

### 9.2 日志使用

```python
from infra.logger import logger, trace_id_ctx_var

trace_id_ctx_var.set("your_trace_id")
logger.info("处理请求")
logger.error(f"异常: {e}")
```

### 9.3 系统提示词

```python
from infra.extra_system_prompt_utils import (
    phone_status_prompt_snippet,
    extra_info_prompt_snippet,
    JoviContext,
)

jovi_ctx = JoviContext(body)
snippet = phone_status_prompt_snippet(jovi_ctx)
```

---

**相关文档**：
- [Agent 模块详解](./agent.md)
- [Model 模块详解](./model.md)
- [Config 模块详解](./config.md)
