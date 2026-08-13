| **patch_configs** | operations/patches | Patch 规则 |
| **validator_configs** | validators | 验证器规则 |
| **model_config_override** | model_config | 模型配置覆盖 |

### 配置生命周期

| 阶段 | 行为 |
|---|---|
| **启动时 init_load** | fallback_loader() → 本地数据 → applier() |
| **运行时 on_change** | parser(raw) → validator(data) → applier(data) |
| **异常处理** | 任一步骤异常 → 保持旧状态 + logger.error |

### 声明式注册

```python
@managed_config("model_type_mapping")
def on_model_type_mapping(data:dict):
    model_registry.update_type_mapping(data)
```

---

## 🏗️ 基础设施（10+ 个组件）

### 日志系统

| 组件 | 说明 |
|---|---|
| **loguru** | 结构化日志 |
| **trace_id contextvar** | 请求级 trace_id 注入 |
| **StatCollector** | 埋点数据收集 |
| **stat_logger** | 统计日志落盘 |

### 认证工具

| 组件 | 说明 |
|---|---|
| **HMAC-SHA256 签名** | 玄机协议认证 |
| **Bearer Token** | OpenAI 协议认证 |

### 系统提示词构建

| 组件 | 说明 |
|---|---|
| **JoviContext** | 手机状态封装 |
| **PanelState** | 面板状态封装 |
| **phone_status_prompt_snippet** | 手机状态提示词 |
| **extra_info_prompt_snippet** | 额外信息提示词 |
| **CAR_SCENE_APP_IDS** | 车载场景识别 |

### 其他基础设施

| 组件 | 说明 |
|---|---|
| **recommend_intention** | 推荐位意图解析（1.0 → 2.0 → 3.0） |
| **image_intent_utils** | 图片上传引导检测 |
| **document_intent_utils** | 文档上传引导检测 |
| **reverse_geocode_utils** | 异步逆地理编码 |
| **body_context** | 请求体上下文封装 |
| **chat_history_utils** | 历史消息工具函数 |
| **chat_history_compactor** | 历史消息紧凑化 |

---

## 🎯 智能路由

### SmartRouteInfo 字段

| 字段 | 枚举类型 | 值域 | 说明 |
|---|---|---|---|
| **is_intent_specific** | IntentSpecific | clear/infer/lack/vague/err | 意图明确度 |
| **is_use_tool** | UseTool | single/para/seq/qa/chat/unsupported/pend | 工具调用类型 |
| **is_special_instruction** | SpecialInstruction | norm/short/cond | 指令类型 |
| **is_exe_success** | ExeSuccess | ok/abnormal | 执行反馈状态 |
| **post_type** | PostType | hit_unsupported/hit_multi_slot/hit_modify_task/hit_vector | 后处理触发类型 |

### 关键业务逻辑

| 条件 | 行为 |
|---|---|
| **is_use_tool=CHAT** | 清空工具请求，直接闲聊 |
| **is_use_tool=UNSUPPORTED/PEND** | 系统提示词追加拒识引导 |
| **need_on_screen + is_use_tool=SINGLE** | 强制中断推理，不再总结 |

---

## 🔧 推理干预层（Hooks）

### 两段式契约

| 段 | Context | 干预产物 | 集成点 |
|---|---|---|---|
| **PreInfer** | PreInferContext | 改 chat_history / 追加 system_prompt | _stage_prepare 推理前 |
| **PostInfer** | PostInferContext | 改 tool_call（如注入上屏指令） | _post_process_tool_results |

### 当前 Hook

| Hook | 段 | 功能 |
|---|---|---|
| **panel_stale** | PreInfer | 面板首轮 + 历史非空时清理过期历史 |
| **composite_output_instruct** | PostInfer | 多工具末条且非上屏时注入上屏指令 |

### 机制要点

| 特性 | 说明 |
|---|---|
| **自注册表** | register_pre/post 收集 hook |
| **异常隔离** | 单 hook 异常不影响其余 hook 与主流程 |
| **原地修改** | Context 的可变字段只能原地修改 |

---

## 📊 功能复杂度统计

### 代码复杂度 Top 5

| 文件 | 行数 | 模块 | 功能 |
|---|---|---|---|
| **xuanji/__init__.py** | 1,123 | model | XuanjiModel 多协议适配 |
| **validator.py** | 737 | tools | 三阶段验证框架 |
| **stage_infer.py** | 613 | agent | 推理阶段（最复杂） |
| **tool.py** | 417 | tools | 工具数据模型 + 调度 |
| **stage_prepare.py** | 353 | agent | 准备阶段 |

### 功能覆盖度

| 维度 | 覆盖情况 |
|---|---|
| **工具领域** | 13 个领域，148 个工具 |
| **模型协议** | 2 种协议（玄机、OpenAI） |
| **验证阶段** | 3 个阶段（逐工具、批量、配置驱动） |
| **运营系统** | 3 大系统（彩蛋、Patch、仲裁） |
| **压缩级别** | 4 级压缩（L1-L4） |
| **重试机制** | 3 套机制（验证器、空响应、流式安全） |

---

## 🎓 功能亮点总结

### 1. 工具系统

- **148 个工具**覆盖 13 个业务领域
- **三阶段验证**确保工具调用准确性
- **预处理/后处理**流水线完善
- **意图映射**支持 88 条规则

### 2. 运营能力

- **74 个 Patch**支持动态干预
- **4 个仲裁规则**解决工具共现冲突
- **彩蛋系统**支持关键词匹配触发
- **热更新**支持配置中心实时下发

### 3. 性能优化

- **Responses API 缓存**降低 TTFT 30-50%
- **Context Pipeline**四级压缩控制 token 预算
- **工具排序优化**提升 prompt cache 命中率
- **TTFT 分桶埋点**精准定位性能瓶颈

### 4. 架构设计

- **三阶段流水线**提升代码可维护性
- **TurnState 单一真值**避免状态不一致
- **推理干预层**支持定点干预
- **流式处理管道**统一处理模型输出

---

**统计时间**：2026-08-11  
**数据来源**：Git 仓库 + 代码分析  
**统计范围**：2026-02-28 ~ 2026-08-10
