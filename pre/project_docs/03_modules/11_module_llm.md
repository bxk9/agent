# 11 · 模块 · LLM 工厂 `app/llm/`

## 1. 模块定位

LLM 层是一个**薄工厂**：向上返回统一的 LangChain `BaseChatModel`；向下屏蔽 vivo/BlueClaw/Google/OpenAI 四家网关的鉴权、SSE、参数差异。Agent 层只关心"我拿到了一个可以 `invoke / stream` 的模型"，不关心它来自哪家。

## 2. 文件清单

| 文件 | 职责 |
|------|------|
| `__init__.py` | 工厂函数 `build_chat_model(model_source, model_name, **kwargs)`；按 `MODEL_SOURCE` 环境变量分派 |
| `vivo_chat.py` | `VivoCustomChat`（LangChain ChatModel 子类）+ `VivoConfig`；实现 HMAC-SHA256 鉴权、SSE 流式解析 |
| `blueclaw_chat.py` | BlueClaw 云网关 ChatModel 实现 |
| `test_max_tokens.py` | 离线诊断脚本：探测某模型的实际 max_tokens 上限；仅本地执行 |
| `大模型调用SSE接口文档.md` | vivo SSE 协议参考（外部对接方给的原始文档） |

Google / OpenAI 直接复用 `langchain-google-genai` / `langchain-openai` 官方封装，不落额外文件。

## 3. 对外契约

```python
from app.llm import build_chat_model

llm = build_chat_model(
    model_source="vivo",          # or "blueclaw" / "google" / "openai"
    model_name="Doubao-Seed-1.6", # 各家不同
    temperature=0.3,
    max_tokens=4096,
    # 各厂扩展参数以 kwargs 透传
)

# 返回值必须支持：
llm.invoke(messages)          # 同步
async for chunk in llm.astream(messages):  # 流式
    ...
llm.bind_tools([...])         # 工具绑定（Agent 依赖此接口）
```

### 环境变量约定

| 变量 | 用途 |
|------|------|
| `MODEL_SOURCE` | `vivo` / `blueclaw` / `google` / `openai` |
| `VIVO_APP_ID` / `VIVO_APP_KEY` | vivo HMAC 凭据 |
| `VIVO_TEXT_MODEL` | vivo 默认模型名（简历解析用 `Doubao-Seed-1.6`） |
| `BLUECLAW_BASE_URL` / `BLUECLAW_TOKEN` | BlueClaw 网关 |
| `GOOGLE_API_KEY` / `OPENAI_API_KEY` | 直接对接原生 SDK |

## 4. 核心设计理念（模块级）

1. **零侵入 LangChain 生态**  
   返回值一定是 `BaseChatModel` 子类，Agent 才能用 `create_react_agent` / `bind_tools` 而不改一行。

2. **HMAC 鉴权本地化**  
   vivo 的鉴权算法比较特殊（AppID + AppKey + timestamp + nonce → HMAC-SHA256 → 放 header），全部收敛在 `VivoConfig._sign()` 中；对外无感知。

3. **SSE 手工解析**  
   vivo SSE 与 OpenAI 兼容格式**有差异**（事件命名、`data:` 层次、终止符），因此手工写解析器，不复用 `openai` SDK。

4. **不做重试**  
   重试策略由**调用方**（Agent 或工具）决定。原因：不同场景对失败的容忍度不同（简历生成愿意重试；对话流式则不希望悄悄卡住）。

5. **诊断脚本单独存在**  
   `test_max_tokens.py` 不进入生产链路，只是给工程师快速验证"当前网关到底允许我发多长"。

## 5. 典型调用链

```
Agent.stream(...)
  ↓
llm = build_chat_model(source, model_name, **kw)
  ↓
llm.bind_tools([tool1, tool2, ...])
  ↓
LangGraph create_react_agent 内部：
  → llm.astream(messages)
      ├─ vivo_chat.VivoCustomChat._astream()
      │    → aiohttp.ClientSession.post(vivo_url, headers={sign}, json={payload}, stream=True)
      │    → 逐 chunk 解析 SSE → yield AIMessageChunk
      └─ 或走 blueclaw / google / openai 分支
```

工具解析器场景（简历上游）：

```
resume_pipeline.extractor
  ↓
build_chat_model("vivo", VIVO_TEXT_MODEL)  # Doubao-Seed-1.6
  ↓
llm.invoke([SystemMessage("你是简历抽取器…"), HumanMessage(raw_txt)])
  ↓
JSON parse → Pydantic schema
```

## 6. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增第五家网关 | 新增 `xxx_chat.py`，在 `__init__.build_chat_model` 加分支；对外契约（返回 BaseChatModel）不变 |
| 需要新参数（如 `top_p`） | 通过 `**kwargs` 透传到各家实现；不要往工厂签名硬加字段 |
| 遇到 429/超时 | **不在** LLM 层重试，由 Agent 层根据业务决定：面试对话失败可提示"网络抖动"，简历解析可自动重试 3 次 |

**易踩坑**：
- vivo HMAC 对**时间偏移**敏感（±5 分钟），线上机器时间不同步会全线失败——已在 `50_debugging_guide.md` 收录。
- `max_tokens` 超过网关上限时不同家表现不同：vivo 会截断、OpenAI 会 400、Google 会静默。需要业务侧确保参数合理。
- 流式模式下**取消**：调用方 `async for` 提前 break 时，务必让底层 `aiohttp` 连接释放；`VivoCustomChat` 已在 `_astream` 用 `try/finally` 关闭。

## 7. 与 Agent 的接口边界

- Agent 只调 `build_chat_model()` 与 `llm.bind_tools([...])`；
- Agent 不感知 `MODEL_SOURCE`；
- 换模型 = 改环境变量 + 重启，**代码零改动**。
