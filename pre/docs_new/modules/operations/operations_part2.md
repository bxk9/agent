| `alarm_modify_confirm` | show_alarm_card + modify_alarm | 闹钟修改操作与展示卡片的分流 |
| `image_mock_qa` | flag `image_mock_query` | 用户仅上传图片未输入文字时的图片工具选择策略 |

### 5.7 注入位置

system prompt 拼接末尾，紧接 Query Patch 片段之后：

```python
built_system_prompt = _build_system_prompt(...)
if turn.patch_prompt_snippets:
    built_system_prompt += "\n" + "\n".join(turn.patch_prompt_snippets)
_arbitration_prompts = collect_arbitration_prompts(turn.tools, _request_flags)
if _arbitration_prompts:
    built_system_prompt += "\n" + "\n".join(_arbitration_prompts)
```

---

## 6 三大系统协作

### 6.1 执行顺序

```
_stage_prepare:
    1. 彩蛋匹配 + 注入（match_easter_egg → inject_easter_egg_tool）
    2. Patch 匹配 + 注入（query_patch_match → apply_tool_patches）

_stage_infer:
    3. 仲裁注入（collect_arbitration_prompts）
```

### 6.2 与 Patch 系统的分工

| | Patch | Arbitration |
|---|---|---|
| **定位** | 按请求特征动态增删工具、追加**轻量**引导 | 能力重叠工具的**产品策略**仲裁 |
| **策略正文** | 内联 `inject_system_prompt`，**≤200 字硬校验** | `prompt_file` 外置 MD，无长度限制 |
| **判据** | 需要改工具集 / 短提示 | 需要成篇策略正文 |

**原则**：长策略正文一律投 arbitration。不要为长文放宽 patch 的 200 字上限。

### 6.3 与 Hook 系统的边界

| 干预类型 | 归属 | 原因 |
|---|---|---|
| 改 `chat_history` | hook | owner 是主流程本身 |
| 改 `tool_call` | hook | owner 是主流程本身 |
| 工具集增删 | patches | owner 是 `_resolve_tools` + patches |

---

## 7 接口说明

### 7.1 彩蛋系统

```python
from operations.easter_egg import (
    match_easter_egg,
    inject_easter_egg_tool,
    EASTER_EGG_MATCHED_KEY,
)

# 匹配彩蛋
matched_egg = match_easter_egg(query, body)

# 注入工具
if matched_egg:
    inject_easter_egg_tool(matched_egg, tools, tool_list)
    extras[EASTER_EGG_MATCHED_KEY] = matched_egg
```

### 7.2 Patch 系统

```python
from operations.patches import (
    query_patch_match,
    apply_tool_patches,
    collect_injected_tools,
    collect_injected_settings,
    collect_injected_prompts,
)

# 匹配 Patch
patch_results = query_patch_match(query, tools, body)

# 应用补丁
if patch_results:
    injected_tools = collect_injected_tools(patch_results)
    tools.extend(injected_tools)
    tool_list = apply_tool_patches(tool_list, patch_results)
    prompts = collect_injected_prompts(patch_results)
```

### 7.3 仲裁系统

```python
from operations.arbitration import collect_arbitration_prompts

# 收集仲裁提示词
arbitration_prompts = collect_arbitration_prompts(
    tool_names=tools,
    request_flags={"image_mock_query"} if is_image_mock else set()
)

# 注入到 system_prompt
if arbitration_prompts:
    system_prompt += "\n" + "\n".join(arbitration_prompts)
```

---

**相关文档**：
- [Agent 模块详解](./agent.md)
- [Tools 模块详解](./tools.md)
- [Config 模块详解](./config.md)
