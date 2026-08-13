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