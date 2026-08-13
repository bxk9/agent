# 功能清单

> 本文档详细列出 pro_agent 项目实现的所有核心功能，展示业务价值和技术复杂度。

## 📊 功能概览

| 类别 | 功能数 | 说明 |
|---|---|---|
| **工具系统** | 148 个工具 | 覆盖 13 个业务领域 |
| **验证框架** | 3 个阶段 | Phase 1/2/3 三阶段验证 |
| **运营能力** | 3 大系统 | 彩蛋、Patch、仲裁 |
| **性能优化** | 4 项核心优化 | Responses API、Context Pipeline 等 |
| **模型适配** | 2 种协议 | 玄机协议、OpenAI 兼容协议 |
| **流式处理** | 4 个处理器 | StreamPipeline 处理器链 |
| **配置管理** | 6 个配置桥接 | 动态配置、热更新 |
| **基础设施** | 10+ 个组件 | 日志、认证、提示词等 |

---

## 🛠️ 工具系统（148 个工具）

### 工具领域分布

| 领域 | 工具数 | 代表工具 | 说明 |
|---|---|---|---|
| **system** | 62 | open_app, close_app, adjust_phone_settings | 系统级操作 |
| **phone** | 36 | make_phone_call, adjust_volume, find_phone | 手机通信与控制 |
| **alarm** | 9 | create_alarm, modify_alarm, search_alarm | 闹钟管理 |
| **image_query** | 7 | general_image_qa, image_text_translate | 图片问答与处理 |
| **media** | 7 | play_music, play_video, control_media_read | 媒体播放控制 |
| **travel** | 6 | perform_navigation, search_poi, call_taxi | 出行与导航 |
| **common** | 6 | knowledgeQA, snapshot_for_qa | 通用问答与截图 |
| **document** | 5 | document_qa, document_summary, document_creator | 文档处理 |
| **schedule** | 4 | create_schedule, search_schedule, modify_schedule | 日程管理 |
| **image_edit** | 3 | generate_images, generate_id_photo | 图片生成与编辑 |
| **weather** | 1 | weather_query, weather_forecast | 天气查询 |
| **print_agent** | 1 | printer_assistant | 打印机助手 |
| **visual_agent** | 1 | visual_agent | 视觉 Agent |

### 工具处理能力

| 能力 | 数量 | 说明 |
|---|---|---|
| **预处理 (pre_process)** | 10 个文件 | 参数校验、补全、转换 |
| **后处理 (post_process)** | 15 个文件 | 结果格式化、上屏指令注入 |
| **验证器 (validators)** | 9 个文件 | 工具调用合理性校验 |
| **Flash 专用处理** | 2 个目录 | Flash 模型专用 pre/post |
| **Pro 专用处理** | 2 个目录 | Pro 模型专用 pre/post |

### 意图映射

| 指标 | 数值 | 说明 |
|---|---|---|
| **意图映射条目** | 88 条 | 2.0 原子意图 → 3.0 工具 |
| **技能意图映射** | 独立索引 | 1.0 技能意图 → 2.0 原子意图 |
| **通用工具** | 1 个 | knowledgeQA（始终召回） |

### 工具排序策略

| 策略 | 工具数 | 说明 |
|---|---|---|
| **高频工具** | 28 个 | 置于最前，提升 prompt cache 命中率 |
| **长定义工具** | 22 个 | 定义超 3K 字符，排在高频之后 |
| **普通工具** | 98 个 | 按默认顺序排列 |

---

## ✅ 验证框架（三阶段）

### Phase 1：逐工具验证

| 验证器类型 | 说明 | 动作 |
|---|---|---|
| **RuleValidator** | 编码化规则验证器 | PASS/FIX/RETRY |
| **LLMValidator** | 轻量模型判断（5s 超时） | PASS/RETRY |
| **ConfigValidator** | JSON 配置驱动 | PASS/FIX/RETRY |

**当前验证器**：

| 验证器 | 工具 | 策略 |
|---|---|---|
| `adjust_phone_settings` | adjust_phone_settings | Flash 模型 setting_name 幻觉检测 → RETRY 降级 Pro |
| `document_context_check` | document_qa / document_summary | 上下文无文档标志 → RETRY |

### Phase 2：全局批量验证

| 验证器 | 说明 | 动作 |
|---|---|---|
| **GlobalValidator** | 跨工具一致性检查 | PASS/DROP |
| **Dry-run 模式** | 新规则观察期 | 只记日志不执行 |

### Phase 3：配置驱动验证器

| 特性 | 说明 |
|---|---|
| **声明式配置** | JSON 文件声明验证规则 |
| **热更新支持** | 通过 ManagedConfigBridge 热更新 |

### 重试机制

| 机制 | 触发条件 | 行为 | 防护 |
|---|---|---|---|
| **验证器 RETRY** | 验证器返回 RETRY + RetryHint | 回滚并重新推理 | tag 去重 + 全局闸门 + per-tag 闸门 |
| **空响应兜底** | Flash 静默退出 | 切换到 Pro 重推 | 独立计数器（最多 1 次） |
| **流式安全约束** | 已 yield 文本 token | 禁止回退 | 保护流式体验 |

---

## 🎭 运营能力（3 大系统）

### 彩蛋系统

| 组件 | 说明 |
|---|---|
| **EasterEggManager** | 单例模式，守护线程定时轮询远程规则 API |
| **匹配引擎** | 关键词精确匹配 + 设备类型过滤 + 版本范围过滤 |
| **工具注入器** | 将 trigger_easter_egg 工具注入候选池 |

**匹配维度**：
- 关键词（triggerContents）
- 设备类型（手机/平板/折叠屏/翻盖/眼镜）
- 设备列表（白名单/黑名单）
- 客户端版本范围
- 操作系统版本

**结果类型**：
- effect（特效）
- jump（跳转）
- text（定制文本）

### Patch 系统（74 个规则）

| 能力 | 说明 |
|---|---|
| **inject_tools** | 注入工具到候选池 |
| **remove_tools** | 从候选池移除工具 |
| **inject_settings** | 注入设置项 |
| **inject_system_prompt** | 追加系统提示词（≤200 字硬校验） |
| **disable_prompt_modules** | 禁用指定提示词模块 |
| **bypass_batch_validators** | 豁免指定批量验证器 |
| **target_model** | 切换到指定模型类型 |

**触发条件**：
- query_contains / query_equals / query_regex
- tools_contains
- model_type
- version_range
- custom_trigger（自定义触发器）

### 仲裁系统（4 个规则）

| 规则 | 触发条件 | 策略 |
|---|---|---|
| **alarm_schedule_arbitration** | create_alarm + create_schedule | 5 维度递减判断 |
| **volume_settings_arbitration** | adjust_volume + adjust_phone_settings | 调节音量 vs 跳转设置 |
| **alarm_delete_confirm** | show_alarm_card + operate_alarm | 闹钟删除/开关分流 |
| **alarm_modify_confirm** | show_alarm_card + modify_alarm | 闹钟修改分流 |
| **image_mock_qa** | flag image_mock_query | 图片工具选择策略 |

**触发维度**：
- trigger_tools（工具共现）
- trigger_flags（请求特征）

---

## ⚡ 性能优化（4 项核心优化）

### Responses API 缓存

| 路径 | 条件 | 行为 | 收益 |
|---|---|---|---|
| **A（缓存命中）** | 有 response_id + 前缀一致 + 有 tool 增量 | 只传 tool_results 增量 | TTFT 降低 30-50% |
| **B（首次缓存）** | 无 response_id + 缓存启用 | 用 Responses API 获取 response_id | 建立缓存 |
| **C（降级）** | 缓存不可用 | 走原始 stream 逻辑 | 兜底 |

**缓存一致性校验**：
- 前缀哈希（system_prompt + chat_history）
- tool 增量检测
- 模型切换检测
- 重试循环检测

### Context Pipeline（四级压缩）

| 级别 | 压缩器 | 策略 | 信息损失 |
|---|---|---|---|
| **L1** | StructuredResultCompressor | 声明式结构化字段提取 | 低 |
| **L2** | ToolResultTruncator | 按工具名通用截断 | 中 |
| **L3** | HistoryFader | 旧轮占位符替换 | 高 |
| **L4** | OldTurnDropper | 整轮丢弃（最终防线） | 最高 |

**配置**：
- 按 model_type 独立配置压缩参数
- Token 预算控制
- 压力驱动，逐级升级

### 工具排序优化

| 策略 | 说明 | 收益 |
|---|---|---|
| **高频工具前置** | 28 个高频工具始终在最前 | 提升 prompt cache 前缀稳定性 |
| **长定义工具次之** | 22 个长定义工具排在高频之后 | 减少 cache miss |

### TTFT 分桶埋点

| 分桶 | 含义 | 来源 |
|---|---|---|
| **A_preproc** | 预处理耗时 | 我方 CPU |
| **B_net** | 网络首字节 | 网络+网关+玄机 prefill |
| **C_decode** | 解码首 token | 模型解码 |
| **D_onscreen** | 上屏耗时 | pipeline + emitter |

**收益**：同源口径定位性能缺口，精准优化

---

## 🤖 模型适配（2 种协议）

### XuanjiModel（玄机网关）

| 协议 | 认证方式 | 工具调用解析 | 适用模型 |
|---|---|---|---|
| **openai** | Bearer Token | 标准 function_calls | Doubao-Seed-2.0-pro |
| **vivo** | HMAC-SHA256 签名 | 特殊 token / tool_calls_done | BlueLM 系列 |

**多协议适配**：
- profiles.json 配置化
- 前缀匹配模型名
- 自动选择协议分支

### 工具调用解析（三层兜底）

| 层级 | 路径 | 适用场景 |
|---|---|---|
| **标准路径** | finish_reason=tool_calls → toolCalls 字段 | OpenAI 协议原生支持 |
| **文本解析路径** | TextToolParser 从文本中提取 | BlueLM text_parse 模式 |
| **Vivo 协议路径** | tool_calls_done 事件 | Vivo 自研协议 |

### 特殊 Token 处理

| 组件 | 说明 |
|---|---|
| **SpecialToken 状态机** | 解析 `<!@-<label>-@!>` 格式 |
| **ModelMarkerFilter** | 过滤模型控制标记 |
| **跨 token 拆分处理** | 模糊前缀表检测未完成片段 |

---

## 🌊 流式处理（StreamPipeline）

### 处理器链

| 处理器 | 职责 |
|---|---|
| **EosFilter** | 过滤 EOS token（`<\|End\|>` 等） |
| **MarkerFilter** | 过滤模型控制标记（`<\|FunctionCallBegin\|>` 等） |
| **SpecialTokenExtractor** | 提取 `<!@-label-@!>` 格式的特殊标记 |
| **TextToolParserProcessor** | BlueLM text_parse 模式下从文本中解析工具调用 |

### 流式事件类型

| 事件 | 说明 |
|---|---|
| **TextDelta** | 文本增量 |
| **CotDelta** | 思考过程增量（不上屏） |
| **ToolCallsDone** | 工具调用完成（含 name/id/arguments/thought_signature） |
| **Signal** | 信号事件（session_finished / enable_voice / mcp:tool_name） |
| **StreamDone** | 流正常结束 |
| **StreamError** | 流错误（含 code/message） |

### SseEmitter

| 特性 | 说明 |
|---|---|
| **first_emit_ts** | 首次发射时间，用于 TTFT 分桶 |
| **has_emitted** | 是否已发射，用于流式安全约束 |
| **文本去重** | 重复上屏内容检测与截断 |

---

## ⚙️ 配置管理（6 个配置桥接）

### 动态配置桥接

| 配置键 | 子系统 | 说明 |
|---|---|---|
| **mcp_intention_mapping** | tool_store 构建 | 工具意图映射 |
| **model_type_mapping** | model_registry | 模型类型映射 |
| **system_prompt** | agent/pro/system | 系统提示词 |