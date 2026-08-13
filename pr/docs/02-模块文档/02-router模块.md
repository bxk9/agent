# Router 模块详细文档

## 1. 模块概述

### 1.1 模块职责
Router 模块是项目的核心路由引擎，负责：
- **请求处理**：接收用户query和工具列表
- **并发调度**：并行执行向量搜索和模型推理
- **结果融合**：整合多路结果，生成最终分类
- **短路优化**：基于SGLang早停机制降低延迟
- **后处理**：应用业务规则和跨维度绑定

### 1.2 文件结构
```
router/
├── router.py      # 旧版路由器（已废弃）
└── router_v2.py   # 新版路由器（当前使用）
```

## 2. Router 类详解

### 2.1 类初始化

```python
class Router:
    def __init__(self):
        self.intent_def_dict = {}      # 工具定义字典
        self.intent_slot_dict = {}     # 工具槽位定义
        self.intent_domain = {}        # 工具所属领域
        self.entropy_score = float(os.getenv('entropy_score', '0.8'))
        self._load_tool_data()         # 加载工具数据
        self.copilot_env = 'v1'
        self.if_gui = False
        self.special_flag = 1
```

**初始化流程**：
1. 创建工具定义相关的字典
2. 从环境变量读取熵分数阈值
3. 调用 `_load_tool_data()` 加载Excel工具定义
4. 初始化环境相关参数

### 2.2 工具数据加载

```python
def _load_tool_data(self):
    """加载工具定义的Excel数据"""
    try:
        app_env = os.environ.get("APP_ENV", "dev")
        if app_env == 'prd':
            df_tool = pd.read_excel(
                './config/atom_intents_router-prd.xlsx',
                sheet_name='最新定义'
            )
        else:
            df_tool = pd.read_excel(
                './config/atom_intents_router.xlsx',
                sheet_name='最新定义'
            )
        
        # 加载GUI工具定义
        with open("./config/gui.json", "r", encoding="utf-8") as f:
            gui = json.load(f)
        
        # 构建工具字典
        for _, row in df_tool.iterrows():
            intent_key = row['tool_name']
            self.intent_domain[intent_key] = str(row['domain'])
            self.intent_def_dict[intent_key] = str(row['content']).replace('&#10;', '\n')
            self.intent_slot_dict[intent_key] = str(row['slot']).replace('&#10;', '\n')
        
        # 添加GUI交互工具
        self.intent_domain['simulate_user_interaction'] = 'system'
        self.intent_def_dict['simulate_user_interaction'] = str(gui['content']).replace('&#10;', '\n')
        self.intent_slot_dict['simulate_user_interaction'] = str(gui['slot']).replace('&#10;', '\n')
        
        logger.info("工具定义数据加载完成。")
    except Exception as e:
        logger.error(f"加载工具数据失败: {e}")
```

**数据加载策略**：
1. **环境适配**：生产环境使用独立的Excel文件
2. **HTML实体解码**：将 `&#10;` 转换为换行符
3. **GUI工具**：从JSON文件加载GUI交互工具定义
4. **异常处理**：加载失败记录日志，不影响服务启动

### 2.3 主入口方法 search

```python
async def search(
    self,
    trace_id,
    query,
    tools,
    tools_history,
    chat_history=None,
    top_k=10,
    max_score=0.95,
    min_score=0.8,
    request_id='',
    session_id='',
    need_dispatch=False,
    copilot_env='v1',
    base_url='',
    extra={...}
):
    """路由主入口"""
    # 1. 设置追踪ID
    trace_id_ctx_var.set(trace_id)
    self.base_url = base_url
    self.copilot_env = copilot_env
    
    # 2. 检查GUI环境
    if_gui = True if check_extra(extra) else False
    self.if_gui = if_gui
    
    # 3. 截断历史对话（保留最近6轮）
    chat_history = (chat_history or [])[-6:]
    
    # 4. 提取工具列表
    tools_result = self._extract_tools(tools, tools_history)
    
    # 5. 构建查询和工具内容
    query_content = self._build_query(query, chat_history, trace_id)
    tools_content = self._build_tools_content(tools_result, tools_history, trace_id)
    
    # 6. 并发执行
    try:
        coroutines = [
            self._vector_search_task(query, trace_id, top_k, max_score, min_score),
            self._get_router_result(query, query_content, tools_content, trace_id),
        ]
        
        if need_dispatch:
            dispatch_tools = [
                {"domain": self.intent_domain.get(i, i)}
                for i in (tools_result + tools_history)
            ]
            coroutines.append(self.dispatch(query=query, tools=dispatch_tools))
        
        results = await asyncio.gather(*coroutines, return_exceptions=True)
        
        # 7. 结果处理
        # ... (详见下文)
        
    except Exception as e:
        logger.error(f"query:{query} 出错；原因：{e}")
        traceback.print_exc()
        return _make_result_dict(task_type="complex", fill="err")
```

**核心流程**：
1. **参数预处理**：设置追踪ID、检查环境、截断历史
2. **工具提取**：从请求参数中提取有效工具
3. **内容构建**：构建模型输入的query和工具定义
4. **并发执行**：并行执行向量搜索和模型推理
5. **结果融合**：整合多路结果，应用后处理规则

## 3. 核心方法详解

### 3.1 工具提取 _extract_tools

```python
def _extract_tools(self, tools, tools_history):
    """从请求参数中提取有效的工具名称列表"""
    # 过滤 chattingAndQA 和 shortcut_condition
    EXCLUDED_KEYS = {'chattingAndQA', 'shortcut_condition'}
    filtered = [item for item in tools if item.get('key') not in EXCLUDED_KEYS]
    
    # 展开 function_name 字段
    tool_names = [name for item in filtered for name in item.get('function_name', [])]
    
    # 白名单过滤（通过 global_intention_mcps）
    EXCLUDED_TOOLS = {
        "confirm_close_alarm",
        "file_agent_allow_upload",
        "show_alarm_card",
        "shortcut_condition",
        "diagnose_phone_issue",
        "simulate_user_interaction"
    }
    result = [
        fn for item in filtered 
        for fn in global_intention_mcps.get(item['key'], []) 
        if fn not in EXCLUDED_TOOLS
    ]
    
    # 工具融合
    result = self._fuse_tools(result)
    return result
```

**处理流程**：
1. **过滤排除工具**：移除闲聊和条件指令工具
2. **展开工具列表**：从 `function_name` 字段提取具体工具名
3. **白名单过滤**：通过 `global_intention_mcps` 映射过滤
4. **排除特定工具**：移除不需要路由的工具
5. **工具融合**：将相关工具融合为单一工具

### 3.2 工具融合 _fuse_tools

```python
def _fuse_tools(self, tool_names):
    """按 TOOL_FUSION_RULES 融合工具"""
    TOOL_FUSION_RULES = [
        # 示例：将图片翻译和图片问答融合
        ({"mage_text_translate", "general_image_qa"}, "general_image_qa"),
    ]
    
    tool_names = list(tool_names)
    for trigger_set, fused_name in TOOL_FUSION_RULES:
        tool_set = set(tool_names)
        if trigger_set.issubset(tool_set):
            # 移除原工具，追加融合名
            tool_names = [t for t in tool_names if t not in trigger_set]
            tool_names.append(fused_name)
    return tool_names
```

**融合策略**：
- 当多个相关工具同时出现时，融合为单一工具
- 简化模型决策，减少工具数量
- 支持自定义融合规则

### 3.3 查询构建 _build_query

```python
def _build_query(self, query, chat_history, trace_id):
    """构建包含历史对话的完整查询文本"""
    histories = []
    for i in range(0, len(chat_history), 2):
        histories.append(f"user:{chat_history[i]['content']}")
        if i + 1 < len(chat_history):
            histories.append(f"assistant:{chat_history[i + 1]['content']}")
        else:
            histories.append("assistant: NULL")
    
    if not histories:
        history_str = '\n历史对话:[]\n'
    else:
        history_str = '\n' + "历史对话:\n" + "\n".join(histories) + '\n'
    
    # 逐级截断策略
    truncation_steps = [
        # (pattern, indices_gen, max_len, wrapper, log_msg)
        (r'assistant:(.*)', lambda h: range(1, len(h), 2), _HISTORY_TRUNCATE_FIRST,
         "<|im_start|>assistant:{}<|im_end|>", "assistant回复截断至500"),
        (r'assistant:(.*)', lambda h: range(1, len(h), 2), _HISTORY_TRUNCATE_SECOND,
         "<|im_start|>assistant:{}<|im_end|>", "assistant回复截断至100"),
        (r'user:(.*)', lambda h: range(0, len(h), 2), _QUERY_TRUNCATE_LEN,
         "user:{}", "user内容截断至1000"),
    ]
    
    for pattern, idx_fn, max_len, wrapper, msg in truncation_steps:
        if len(history_str) <= _HISTORY_MAX_LEN:
            break
        logger.info(f"history_str长度过长，{msg}")
        self._truncate_by_pattern(histories, pattern, idx_fn(histories), max_len, wrapper)
        history_str = "历史对话:\n" + "\n".join(histories)
    
    llm_input = history_str + '\n当前轮query：' + str(query)
    return llm_input
```

**截断策略**：
1. **历史记录截断**：保留最近6轮对话
2. **逐级截断**：
   - 第一轮：assistant回复截断到500字符
   - 第二轮：assistant回复截断到100字符
   - 第三轮：user内容截断到1000字符
3. **总长度控制**：历史记录总长度不超过2048字符

**截断辅助方法**：
```python
@staticmethod
def _truncate_by_pattern(histories, pattern, indices, max_length, wrapper):
    """通用截断方法：按正则匹配内容并截断到 max_length"""
    for i in indices:
        if i >= len(histories):
            continue
        match = re.search(pattern, histories[i], re.DOTALL)
        if match:
            content = match.group(1)
            histories[i] = wrapper.format(content[:max_length])
```

### 3.4 工具内容构建 _build_tools_content

```python
def _build_tools_content(self, tools, tools_history, trace_id):
    """构建工具定义描述文本"""
    # 添加 knowledgeQA 工具
    tools_list = list(dict.fromkeys(tools + ['knowledgeQA']))
    
    # 特殊环境添加 GUI 交互工具
    if self.copilot_env == 'ltx':
        tools_list = list(dict.fromkeys(tools + ['simulate_user_interaction'] + ['knowledgeQA']))
    
    # 过滤特殊工具
    ALI_TOOLS = {"alipay_direct_service", "alipay_execution_service"}
    SPECIAL_TOOLS = {"meituan_service"} | ALI_TOOLS
    
    if self.copilot_env != 'ltx':
        tools_list = [t for t in tools_list if t != "meituan_service"]
    
    if self.copilot_env not in ['ymr', 'ts']:
        tools_list = [t for t in tools_list if t not in ALI_TOOLS]
    
    # 检查是否注入特殊Prompt
    if SPECIAL_TOOLS & set(tools_list):
        logger.info("special prompt注入")
        self.special_flag = 0
    
    # 构建工具描述
    tools_content_list = []
    tools_list = sorted(tools_list)
    
    for value in tools_list:
        tool_def = self.intent_def_dict.get(value, '')
        if not tool_def:
            continue
        
        tool_desc = f"工具名：{value}。工具说明:{tool_def}"
        slot_info = self.intent_slot_dict.get(value, '')
        slot_str = f"当前工具槽位说明：\n{slot_info}  \n" if slot_info and slot_info != 'nan' else '\n'
        tools_content_list.append(f"{tool_desc}\n{slot_str}")
    
    # 去重并编号
    unique_tools = list(dict.fromkeys(tools_content_list))
    return "\n".join(f"{i + 1}. {item}" for i, item in enumerate(unique_tools))
```

**构建策略**：
1. **必添加工具**：始终添加 `knowledgeQA` 工具
2. **环境适配**：特定环境添加特殊工具（如GUI交互、美团服务）
3. **工具过滤**：根据环境过滤不适用的工具
4. **特殊Prompt标记**：检测到特殊工具时设置 `special_flag`
5. **格式统一**：统一工具描述格式，添加编号

### 3.5 向量搜索任务 _vector_search_task

```python
async def _vector_search_task(self, query, trace_id, top_k, max_score, min_score, timeout=2.0):
    """执行向量搜索并返回 (结果, 是否高分命中)"""
    vector_start = int(time.time() * 1000)
    
    try:
        # 在线程池中执行同步的向量搜索
        query_results = await asyncio.wait_for(
            asyncio.to_thread(
                gen_llm_vsearch_res, query, trace_id=trace_id, n_results=top_k
            ),
            timeout=timeout,
        )
        max_score_result, min_score_result = score_match(query_results, max_score, min_score)
    except asyncio.TimeoutError:
        vector_cost = int(time.time() * 1000) - vector_start
        logger.warning(f"向量库搜索超时({timeout}s)，降级返回空结果，耗时：{vector_cost}ms")
        return [], False
    except Exception as e:
        vector_cost = int(time.time() * 1000) - vector_start
        logger.warning(f"向量库搜索异常，降级返回空结果：{e}，耗时：{vector_cost}ms")
        return [], False
    
    vector_cost = int(time.time() * 1000) - vector_start
    logger.info(f"向量库搜索耗时：{vector_cost}ms")
    
    if max_score_result:
        return max_score_result, True
    return min_score_result, False
```

**设计要点**：
1. **异步包装**：使用 `asyncio.to_thread` 将同步调用转为异步
2. **超时控制**：设置2秒超时，避免阻塞主流程
3. **降级策略**：超时或异常时返回空结果，不阻塞模型推理
4. **性能监控**：记录向量搜索耗时

### 3.6 模型推理任务 _get_router_result

```python
async def _get_router_result(self, query, query_content, tools_content, trace_id):
    """调用路由模型获取分类结果"""
    llm_start = int(time.time() * 1000)
    logger.info(f"工具选择：{tools_content}")
    
    result_dict = await self._parse_llm_result_v2(
        query_content, tools_content, trace_id, self.copilot_env, self.base_url, self.special_flag
    )
    self.special_flag = 1  # 重置标记
    
    llm_cost = int(time.time() * 1000) - llm_start
    logger.info(f"路由模型请求耗时：{llm_cost}ms")
    return result_dict
```

**流程**：
1. 记录开始时间
2. 调用 `_parse_llm_result_v2` 获取模型结果
3. 重置 `special_flag`
4. 记录耗时并返回结果

## 4. 结果解析与后处理

### 4.1 SGLang 结果解析 _parse_llm_result_v2

```python
@staticmethod
async def _parse_llm_result_v2(query_content, tools_content, trace_id, copilot_env, base_url, special_flag):
    """使用 SGLang 原生 /generate + stop_token_ids 解析 LLM 返回"""
    result_dict = _make_result_dict(task_type="complex", fill="err")
    
    try:
        # 测试模式
        if base_url:
            test_time = await call_cicd_test(tools_content, query_content, trace_id_ctx_var, base_url=base_url)
            return {'task_type': test_time, 'is_intent_specific': 'err', ...}
        
        # 调用 SGLang /generate
        sglang_result = await call_sglang_generate(
            tools_content, query_content, trace_id,
            base_url=router_router_config,
            special_flag=special_flag
        )
        llm_raw_result = sglang_result["output_text"]
        matched_label = sglang_result["matched_label"]
        
        logger.info(f"llm原始返回（sglang）: {llm_raw_result!r}, matched_label={matched_label}")
        
        # 解析输出
        if (not llm_raw_result or not isinstance(llm_raw_result, str)) and not matched_label:
            return result_dict
        
        # 分割输出并添加命中标签
        text_parts = [p.strip().lower() for p in llm_raw_result.strip().split() if p.strip()]
        if matched_label:
            parts = text_parts + [matched_label]
        else:
            parts = text_parts
        
        # 验证字段数量
        if len(parts) > 4:
            logger.error(f"llm返回格式错误，期望最多4个字段，实际得到: {parts}")
            return result_dict
        
        # 推断早停位置
        task_index = len(parts) - 1 if len(parts) > 0 else 0
        skip_count = Router._infer_skip_count(task_index, matched_label)
        
        # 补全字段
        parts = Router._parse_partial_output(parts, skip_count)
        
        # 映射到结果字典
        field_keys = [
            "is_use_tool",
            "is_intent_specific",
            "is_special_instruction",
            "is_exe_success",
        ]
        for key, value in zip(field_keys, parts):
            result_dict[key] = value
        
        # 字段校验
        VALID_VALUES = [
            {"chat", "qa", "single", "para", "seq", "unsupported", "pend", "multi", "special"},
            {"infer", "lack", "clear", "vague"},
            {"short", "cond", "normal"},
            {"abnormal", "ok"},
        ]
        
        for i, (key, valid_set) in enumerate(zip(field_keys, VALID_VALUES)):
            val = result_dict[key]
            if val == "":  # 早停跳过的字段
                continue
            if val.lower() not in valid_set:
                logger.error(f"llm返回值校验失败: 字段[{key}]的值'{val}'不在合法范围{valid_set}中")
                return _make_result_dict(task_type="complex", fill="err")
        
        # 计算 task_type
        status = result_dict.get("is_exe_success", "")
        if "历史对话:[]" in query_content and isinstance(status, str) and status == "abnormal":
            logger.info(f"非历史对话场景，将 abnormal 状态改写为 ok")
            result_dict["is_exe_success"] = "ok"
        
        is_complex = (
            result_dict["is_intent_specific"].lower() in ["infer", "vague"]
            or result_dict["is_use_tool"].lower() in ["multi", "chat", "pend", "special"]
            or result_dict["is_special_instruction"].lower() in ["cond"]
            or result_dict["is_exe_success"].lower() in ["abnormal"]
        )
        result_dict["task_type"] = "complex" if is_complex else "easy"
        
        # 标签映射
        result_dict["is_use_tool"] = "specific" if result_dict["is_use_tool"] == "special" else result_dict["is_use_tool"]
        result_dict["is_special_instruction"] = "norm" if result_dict["is_special_instruction"] == "normal" else result_dict["is_special_instruction"]
        
        logger.info(f"解析后结果（sglang）: {result_dict}")
        
    except Exception as e:
        logger.error(f"处理llm结果时发生异常: {str(e)}")
    
    return result_dict
```

**核心逻辑**：
1. **SGLang调用**：使用 `/generate` 接口，支持早停
2. **���出解析**：分割空格分隔的标签，添加命中的早停标签
3. **早停推断**：根据已解析字段数推断早停位置
4. **字段补全**：将早停跳过的字段赋空字符串
5. **字段校验**：验证每个字段值是否在合法范围内
6. **task_type计算**：根据规则判断任务复杂度
7. **标签映射**：将内部标签映射为对外标签

### 4.2 早停推断 _infer_skip_count

```python
@staticmethod
def _infer_skip_count(task_index: int, matched_label: str | None) -> int:
    """根据命中的字段位置和标签，推断需要跳过的字段数"""
    if matched_label is None:
        return 0
    
    if task_index == 0:
        return TASK1_SKIP_MAP.get(matched_label, 0)
    
    task_name = f"task{task_index + 1}"
    return TASKN_SKIP_MAP.get(task_name, {}).get(matched_label, 0)
```

**早停映射表**（在 request_llm_v2.py 中定义）：
```python
TASK1_SKIP_MAP = {
    "qa": 3,      # qa 后面三个字段全跳过
    "multi": 2,   # multi 后面两个字段跳过
    "chat": 2,
    "pend": 2,
}

TASKN_SKIP_MAP = {
    "task2": {"infer": 2, "vague": 2},
    "task3": {"cond": 1},
    "task4": {"abnormal": 0},
}
```

### 4.3 字段补全 _parse_partial_output

```python
@staticmethod
def _parse_partial_output(parts: list, skip_count: int) -> list:
    """将早停后的不完整输出补全为 4 个字段"""
    # 补全到 4 个字段
    while len(parts) < 4:
        parts.append("")
    
    # 从末尾开始跳过 skip_count 个字段
    for i in range(skip_count):
        idx = 3 - i
        parts[idx] = ""
    
    return parts
```

**补全策略**：
1. 先将字段列表补全到4个
2. 从末尾开始，将需要跳过的字段设为空字符串

## 5. 正则模板匹配 dispatch

```python
async def dispatch(self, query, tools=None):
    """根据正则模板匹配 domain"""
    tools = tools or []
    domains = [DOMAIN_Z2E.get(k.get('domain', ''), 'normal') for k in tools]
    
    match_domain = 'normal'
    match_template = ''
    template_matched = False
    
    for domain_key in domains:
        templates = regex_templates.get(domain_key, [])
        for pattern in templates:
            if re.search(pattern, query):
                match_domain = domain_key
                match_template = pattern
                template_matched = True
                break
        if template_matched:
            break
    
    return {
        "template": {
            "matched": template_matched,
            "match_domain": match_domain,
            "match_template": match_template,
        },
        "entropy": {"matched": False},
    }
```

**匹配策略**：
1. 提取工具所属领域
2. 遍历领域对应的正则模板
3. 第一个匹配的模板即为结果
4. 返回匹配结果和匹配的模板

## 6. 结果融合逻辑

```python
# 向量搜索结果容错
if isinstance(results[0], Exception):
    logger.warning(f"向量搜索失败，降级使用路由模型结果: {results[0]}")
    q_q_result, is_high_score = [], False
else:
    (q_q_result, is_high_score) = results[0]

# 路由模型结果容错
if isinstance(results[1], Exception):
    logger.error(f"路由模型调用失败: {results[1]}")
    return _make_result_dict(task_type="complex", fill="err")
result_dict = results[1]

# 模板命中优先返回
if need_dispatch:
    matched = results[2]
    if matched["template"]["matched"]:
        return _make_result_dict(task_type="easy", fill="template")

# 高分向量命中直接返回
if is_high_score:
    logger.info(f"命中向量库大于指定阈值的向量，直接返回结果: {q_q_result[0]}")
    task = 'easy' if q_q_result[0] == '简单任务' else 'complex'
    result_dict['post_type'] = 'hit_vector'
    result_dict['task_type'] = task

return result_dict
```

**融合优先级**：
1. **模板匹配**：正则模板命中 → 返回 easy
2. **向量高分**：向量相似度 > 0.95 → 直接返回
3. **模型结果**：使用模型推理结果

## 7. 性能优化策略

### 7.1 并发执行
```python
coroutines = [
    self._vector_search_task(...),
    self._get_router_result(...),
]
results = await asyncio.gather(*coroutines)
```

**优势**：
- 向量搜索和模型推理并行执行
- 总耗时取两者最大值而非累加
- 充分利用系统资源

### 7.2 早停优化
- 使用 SGLang 的 `stop_token_ids` 参数
- 模型生成到特定token时立即停止
- 显著降低生成延迟

### 7.3 超时降级
```python
query_results = await asyncio.wait_for(
    asyncio.to_thread(gen_llm_vsearch_res, ...),
    timeout=timeout,
)
```

**降级策略**：
- 向量搜索超时2秒 → 返回空结果
- 不阻塞模型推理主流程
- 保证服务可用性

### 7.4 历史记录截断
- 保留最近6轮对话
- 逐级截断assistant和user内容
- 总长度控制在2048字符内

## 8. 错误处理

### 8.1 异常捕获
```python
try:
    # 主流程
    ...
except Exception as e:
    logger.error(f"query:{query} 出错；原因：{e}")
    traceback.print_exc()
    return _make_result_dict(task_type="complex", fill="err")
```

### 8.2 降级策略
- 向量搜索失败 → 使用模型结果
- 模型推理失败 → 返回错误结果
- 字段校验失败 → 返回错误结果

### 8.3 统一错误格式
```python
def _make_result_dict(task_type="complex", fill="err"):
    """生成统一的结果字典模板"""
    return {
        "task_type": task_type,
        "is_intent_specific": fill,
        "is_use_tool": fill,
        "is_special_instruction": fill,
        "is_exe_success": fill,
        "post_type": '',
    }
```

## 9. 设计理念总结

### 9.1 并发优先
- 最大化利用异步IO
- 向量搜索和模型推理并行
- 减少总响应时间

### 9.2 降级容错
- 向量搜索超时降级
- 模型推理失败降级
- 保证服务高可用

### 9.3 短路优化
- 基于SGLang早停机制
- 减少不必要的token生成
- 显著降低延迟

### 9.4 多维度融合
- 向量检索辅助
- 正则模板快速匹配
- 模型推理精确分类
- 多路结果智能融合

### 9.5 灵活扩展
- 支持工具融合规则
- 支持正则模板扩展
- 支持Prompt版本切换

## 10. 使用示例

### 10.1 基本调用
```python
router = Router()

result = await router.search(
    trace_id="trace-123",
    query="帮我定一个明天早上8点的闹钟",
    tools=[{"key": "create_alarm", "function_name": ["timeAndSchedule.createAlarmClock"]}],
    tools_history=[],
    chat_history=[],
    need_dispatch=True,
    copilot_env="v1"
)

print(result)
# {
#     "task_type": "easy",
#     "is_intent_specific": "clear",
#     "is_use_tool": "single",
#     "is_special_instruction": "norm",
#     "is_exe_success": "ok",
#     "post_type": ""
# }
```

### 10.2 带历史对话
```python
result = await router.search(
    trace_id="trace-456",
    query="改成9点",
    tools=[...],
    tools_history=[],
    chat_history=[
        {"role": "user", "content": "帮我定一个明天早上8点的闹钟"},
        {"role": "assistant", "content": "好的，已为您设置明天早上8点的闹钟"}
    ],
    need_dispatch=False
)
```

## 11. 常见问题

### 11.1 模型返回格式错误
**现象**：日志显示 "llm返回格式错误"

**原因**：
1. 模型生成了超过4个字段
2. 模型生成了非法标签

**排查方法**：
```python
# 查看原始返回
logger.info(f"llm原始返回: {llm_raw_result}")

# 检查Prompt是否正确
logger.info(f"工具选择：{tools_content}")
```

### 11.2 向量搜索超时
**现象**：日志显示 "向量库搜索超时"

**原因**：
1. VSearch服务响应慢
2. 网络延迟高

**解决方案**：
1. 增加超时时间（不推荐）
2. 优化VSearch服务性能
3. 接受降级，使用模型结果

### 11.3 早停未生效
**现象**：模型生成了完整的4个字段，没有早停

**原因**：
1. 模型未生成早停标签
2. `stop_token_ids` 配置错误

**排查方法**：
```python
# 检查命中标签
logger.info(f"matched_label={matched_label}")

# 检查output_ids
logger.info(f"output_ids={output_ids}")
```

## 12. 最佳实践

1. **合理设置超时**：向量搜索超时2秒，平衡性能和可用性
2. **监控早停命中率**：统计早停触发比例，评估优化效果
3. **定期更新工具定义**：保持Excel工具定义与业务同步
4. **日志追踪**：使用trace_id关联完整请求链路
5. **性能监控**：记录各环节耗时，识别性能瓶颈
