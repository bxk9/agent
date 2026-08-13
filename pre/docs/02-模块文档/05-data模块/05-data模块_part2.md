def _build_mcp_mapping():
    """构建MCP工具映射"""
    raw = config.get_config("mcp_intention_mapping", {})
    if isinstance(raw, str):
        mcp_intention_mapping = json.loads(raw)
    else:
        mcp_intention_mapping = raw
    
    new_intention_mcps = {"common_tools": ["knowledgeQA"]}
    
    for k, v in mcp_intention_mapping.items():
        v = [_v.split('.')[-1] for _v in v]
        for _v in v:
            if _v not in new_intention_mcps:
                new_intention_mcps[_v] = []
            new_intention_mcps[_v] = new_intention_mcps[_v] + [k]
    
    return mcp_intention_mapping, new_intention_mcps
```

**用途**：
- 构建正向映射：意图 → MCP工具
- 构建反向映射：MCP工具 → 意图

## 4. 映射表维护

### 4.1 添加新工具

```python
# 在 intent2tool.py 中添加
tools_intent = {
    # ... 现有映射
    
    # 新增工具
    "new_tool_intent": [
        "domain.newMcpTool"
    ],
}
```

**步骤**：
1. 确定工具意图名称
2. 确定对应的MCP工具全限定名
3. 添加到 `tools_intent` 字典
4. 更新Excel工具定义文件

### 4.2 修改映射关系

```python
# 修改前
"play_music": ["media.playSpecificMusic"]

# 修改后（添加新的MCP工具）
"play_music": [
    "media.playSpecificMusic",
    "media.playMusicFromPlaylist"
]
```

**注意事项**：
- 确保MCP工具名称正确
- 测试修改后的映射
- 更新相关文档

### 4.3 删除工具

```python
# 删除不再使用的映射
# "deprecated_tool": ["domain.deprecatedMcpTool"]  # 已删除
```

**注意事项**：
- 确认工具已下线
- 检查是否有其他地方引用
- 更新配置中心

## 5. 设计理念总结

### 5.1 数据验证
- 使用Pydantic进行参数验证
- 自动类型转换和默认值填充
- 保证数据一致性

### 5.2 映射解耦
- 工具意图与MCP工具解耦
- 支持一对多、多对一映射
- 便于扩展和维护

### 5.3 配置化管理
- 映射表支持配置中心动态更新
- 本地映射作为默认值
- 支持热更新

### 5.4 分类组织
- 按领域分类工具映射
- 便于查找和维护
- 清晰的命名规范

## 6. 使用示例

### 6.1 查询工具映射

```python
from data.intent2tool import tools_intent

# 查询某个意图对应的MCP工具
mcp_tools = tools_intent.get("create_alarm", [])
print(mcp_tools)  # ["timeAndSchedule.createAlarmClock"]

# 查询所有意图
all_intents = list(tools_intent.keys())
print(f"共有 {len(all_intents)} 个工具意图")

# 查询所有MCP工具
all_mcp_tools = set()
for tools in tools_intent.values():
    all_mcp_tools.update(tools)
print(f"共有 {len(all_mcp_tools)} 个MCP工具")
```

### 6.2 构建反向映射

```python
from data.intent2tool import tools_intent

# 构建反向映射：MCP工具 → 意图
mcp_to_intent = {}
for intent, mcp_tools in tools_intent.items():
    for mcp_tool in mcp_tools:
        short_name = mcp_tool.split('.')[-1]
        if short_name not in mcp_to_intent:
            mcp_to_intent[short_name] = []
        mcp_to_intent[short_name].append(intent)

# 查询某个MCP工具对应的意图
intents = mcp_to_intent.get("createAlarmClock", [])
print(intents)  # ["create_alarm", "operate_alarm"]
```

### 6.3 验证请求参数

```python
from data.params import Params
from pydantic import ValidationError

try:
    params = Params(
        query="帮我定闹钟",
        tools=[{"key": "create_alarm", "function_name": ["timeAndSchedule.createAlarmClock"]}],
        trace_id="trace-123"
    )
    print(f"参数验证通过: {params.query}")
except ValidationError as e:
    print(f"参数验证失败: {e}")
```

## 7. 常见问题

### 7.1 工具映射缺失
**现象**：Router找不到某个工具意图对应的MCP工具

**原因**：
1. `tools_intent` 中未定义该映射
2. 配置中心未下发该映射
3. 工具名称拼写错误

**排查方法**：
```python
from data.intent2tool import tools_intent
from config.config_mapping import config

# 检查本地映射
print("create_alarm" in tools_intent)

# 检查配置中心映射
mcp_mapping = config.get_config("mcp_intention_mapping", {})
print("create_alarm" in mcp_mapping)
```

### 7.2 参数验证失败
**现象**：API返回422错误（参数验证失败）

**原因**：
1. 必填参数缺失
2. 参数类型错误
3. 参数格式不正确

**排查方法**：
```python
# 查看详细的验证错误
try:
    params = Params(...)
except ValidationError as e:
    print(e.json())
```

### 7.3 映射冲突
**现象**：同一个MCP工具对应多个意图，导致路由混乱

**原因**：
1. 工具设计不合理
2. 映射关系定义不清晰

**解决方案**：
1. 重新设计工具分类
2. 明确工具职责边界
3. 添加优先级规则

## 8. 最佳实践

1. **命名规范**：使用小写字母和下划线，如 `create_alarm`
2. **分类清晰**：按领域分类工具，避免交叉
3. **文档同步**：修改映射时同步更新文档
4. **测试验证**：修改映射后进行充分测试
5. **版本管理**：重要修改记录版本历史
6. **配置中心优先**：优先使用配置中心的映射
7. **定期审查**：定期审查映射表，清理废弃工具

## 9. 扩展建议

### 9.1 添加元数据
```python
tools_intent_meta = {
    "create_alarm": {
        "mcp_tools": ["timeAndSchedule.createAlarmClock"],
        "domain": "时间与日程",
        "priority": 1,
        "description": "创建闹钟"
    }
}
```

### 9.2 支持版本化
```python
tools_intent_v1 = {...}
tools_intent_v2 = {...}

def get_tools_intent(version="v2"):
    if version == "v1":
        return tools_intent_v1
    return tools_intent_v2
```

### 9.3 添加验证规则
```python
from pydantic import validator

class Params(BaseModel):
    tools: Optional[list] = []
    
    @validator('tools')
    def validate_tools(cls, v):
        for tool in v:
            if 'key' not in tool:
                raise ValueError("工具必须包含key字段")
        return v
```
