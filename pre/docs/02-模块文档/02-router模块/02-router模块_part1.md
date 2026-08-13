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