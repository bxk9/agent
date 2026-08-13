assistant: <|im_start|>assistant:好的，我来为您写一篇关于人工智能的文章。人工智能（Artificial Intelligence，简称AI）是计算机科学的一个分支...<|im_end|>（100字符）
user: 继续写
assistant: <|im_start|>assistant:接下来我们来看AI的技术原理...<|im_end|>（100字符）
```

### 7.4 效果评估

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 平均历史长度 | 3000字符 | 1500字符 | **减少50%** |
| 超长历史比例 | 25% | <1% | **显著降低** |
| 推理时间 | 250ms | 200ms | **降低20%** |
| Token成本 | 高 | 中 | **降低40%** |

**截断触发统计**：
```
assistant截断到500：  15%  → 第一轮截断
assistant截断到100：  5%   → 第二轮截断
user截断到1000：      2%   → 第三轮截断
无需截断：            78%  → 历史较短
```

### 7.5 关键代码文件

- `router/router_v2.py`: 历史截断逻辑（675行）

---

## 8. 工具定义管理与映射

### 8.1 问题描述

**背景**：需要管理100+工具意图映射，支持动态更新。

**痛点**：
- 工具数量多，映射关系复杂
- 需要支持一对多、多对一映射
- 需要支持工具融合
- 需要支持动态更新

**目标**：建立清晰的工具映射体系，支持灵活扩展。

### 8.2 技术难点

1. **映射设计**：需要设计合理的映射结构
2. **工具融合**：需要支持相关工具的融合
3. **动态更新**：需要支持配置中心动态更新
4. **白名单过滤**：需要过滤不需要的工具

### 8.3 解决方案

#### 8.3.1 工具意图映射表

```python
# data/intent2tool.py

tools_intent = {
    # 时间与日程类
    "search_alarm": ["timeAndSchedule.queryAlarmClock"],
    "create_alarm": ["timeAndSchedule.createAlarmClock"],
    "modify_alarm": ["timeAndSchedule.updateAlarmClock"],
    "operate_alarm": [
        "timeAndSchedule.createAlarmClock",
        "timeAndSchedule.deleteAlarmClock",
        "timeAndSchedule.offAlarmClock"
    ],
    
    # 系统操作类
    "restart_phone": ["systemOperationAndSettings.restartPhone"],
    "adjust_volume": ["systemOperationAndSettings.adjustVolume"],
    "open_app": ["systemOperationAndSettings.appOpenAndClose"],
    "close_app": ["systemOperationAndSettings.appOpenAndClose"],
    
    # 媒体类
    "play_music": ["media.playSpecificMusic"],
    "play_video": ["media.playSpecificVideo", "media.searchVideo"],
    
    # 知识问答类
    "knowledgeQA": [
        "chattingAndQA.chattingAndQA",
        "textGeneration.writing",
        "officeWork.translate",
        "knowledgeBasedProblemSolving.knowledgeBasedProblemSolving",
        "summary.summary",
        "news.hotEventTracking",
        "mathematicalCalculation.numericalCalculation",
        "textGeneration.polish"
    ],
    
    # ... 更多映射
}
```

**映射特点**：
- **一对多**：`operate_alarm` → 3个MCP工具
- **多对一**：`open_app`和`close_app` → 同一个MCP工具
- **复合工具**：`knowledgeQA` → 8个子能力

#### 8.3.2 工具提取与融合

```python
# router/router_v2.py

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

#### 8.3.3 MCP映射构建

```python
# main.py

def _build_mcp_mapping():
    """构建MCP工具映射"""
    raw = config.get_config("mcp_intention_mapping", {})
    if isinstance(raw, str):
        mcp_intention_mapping = json.loads(raw)
    else:
        mcp_intention_mapping = raw
    
    # 构建反向映射
    new_intention_mcps = {"common_tools": ["knowledgeQA"]}
    
    for k, v in mcp_intention_mapping.items():
        v = [_v.split('.')[-1] for _v in v]
        for _v in v:
            if _v not in new_intention_mcps:
                new_intention_mcps[_v] = []
            new_intention_mcps[_v] = new_intention_mcps[_v] + [k]
    
    return mcp_intention_mapping, new_intention_mcps
```

**映射结构**：
- `global_mcp_intentions`：意图 → MCP工具（正向）
- `global_intention_mcps`：MCP工具 → 意图（反向）

### 8.4 效果评估

| 指标 | 数值 | 说明 |
|------|------|------|
| 工具意图数 | 100+ | 覆盖主要场景 |
| MCP工具数 | 200+ | 细粒度工具 |
| 映射更新次数 | 39次 | 持续迭代 |
| 工具融合规则 | 1条 | 可扩展 |
| 白名单过滤 | 6个工具 | 排除不需要路由的工具 |

**工具分布**：
```
时间与日程：    15个意图
系统操作：      30个意图
媒体：          20个意图
导航与出行：    15个意图
社交与通讯：    10个意图
知识问答：      1个意图（8个子能力）
图像编辑：      10个意图
IoT设备控制：   10个意图
其他：          若干
```

### 8.5 关键代码文件

- `data/intent2tool.py`: 工具映射表（579行）
- `router/router_v2.py`: 工具提取与融合（675行）
- `main.py`: MCP映射构建（166行）

---

## 总结

### 技术难点统计

| 难点类别 | 数量 | 复杂度 | 解决效果 |
|----------|------|--------|----------|
| 性能优化 | 3 | ★★★★★ | 延迟降低80% |
| 准确性提升 | 2 | ★★★★★ | 准确率96% |
| 高可用保障 | 2 | ★★★★☆ | 可用性99.95% |
| 工程实现 | 1 | ★★★☆☆ | 灵活扩展 |

### 关键技术成果

1. **SGLang早停优化**：业界领先的token级短路策略
2. **并发执行架构**：充分利用异步IO，性能提升33%
3. **Prompt工程体系**：50次迭代，准确率96%
4. **动态配置热更新**：无需重启，实时生效
5. **多层容错降级**：任何组件失败不影响整体服务

### 技术亮点

- **创新性**：SGLang早停优化在业界属于领先实践
- **实用性**：所有技术方案都已在生产环境验证
- **可维护性**：代码结构清晰，文档完善
- **可扩展性**：模块化设计，便于后续扩展

### 经验总结

1. **性能优化要量化**：每个优化都要有明确的性能指标
2. **Prompt工程要迭代**：持续优化，小步快跑
3. **容错设计要全面**：考虑所有可能的失败场景
4. **文档要及时**：边开发边写文档，避免遗忘

这些技术难点的解决，为Dynamic Router项目的成功奠定了坚实的基础。
