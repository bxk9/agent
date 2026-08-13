**线程安全**：
- 使用 `_mcp_mapping_lock` 保护全局变量更新
- 先清空再更新，避免数据不一致

## 4. 环境适配策略

### 4.1 环境识别

```python
app_env = os.environ.get("APP_ENV", "dev")
```

**支持的环境**：
- `dev`: 开发环境
- `test`: 测试环境
- `pre`: 预发布环境
- `prd`: 生产环境

### 4.2 配置中心地址适配

```python
def __do_init_env_vars(self) -> None:
    self._app_env = os.environ.get("APP_ENV", "dev")
    
    if self._app_env != 'prd':
        self._app_name = 'intent-tool-retrieval'
        self._config_version = 'router'
    else:
        self._app_name = 'intent-tool-retrieval'
        self._config_version = os.environ.get("CONFIG_VERSION", "1")
    
    # 配置中心地址
    if self._app_env in ['pre', 'prd']:
        self._config_host = "http://vivocfg-agent.prd.bj01.vivo.lan:8080/vivocfgV2/getConfig"
    else:
        self._config_host = "http://vivocfg-agent.test.vivo.xyz/vivocfgV2/getConfig"
    
    # 本地默认配置（兜底）
    self._configs["mcp_intention_mapping"] = tools_intent
```

**适配策略**：
1. **应用名称**：生产环境使用独立配置版本
2. **配置中心**：预发布和生产使用生产配置中心
3. **默认配置**：从本地Excel加载默认MCP映射

### 4.3 工具定义文件适配

```python
def _load_tool_data(self):
    """加载工具定义的Excel数据"""
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
```

**设计要点**：
- 生产环境使用独立的工具定义文件
- 支持工具定义的版本化管理

## 5. 设计理念总结

### 5.1 配置分离原则
- **静态配置**：代码中硬编码，如API地址
- **动态配置**：配置中心管理，如MCP映射
- **环境配置**：环境变量控制，如服务地址

### 5.2 容错设计
- **配置同步失败**：不影响服务运行，下次重试
- **正则验证失败**：跳过该配置项，保留旧值
- **回调执行失败**：记录日志，不影响其他回调

### 5.3 性能优化
- **增量更新**：通过时间戳避免全量同步
- **本地缓存**：减少配置中心访问
- **后台线程**：异步同步，不阻塞主流程

### 5.4 线程安全
- **读写锁**：`RLock` 保护配置读写
- **原子更新**：先清空再更新，保证一致性
- **死锁避免**：锁外执行回调

## 6. 使用示例

### 6.1 获取配置

```python
from config.config_mapping import config

# 获取配置值
mcp_mapping = config.get_config("mcp_intention_mapping", {})

# 获取配置并解析
raw = config.get_config("some_config", "{}")
if isinstance(raw, str):
    data = json.loads(raw)
else:
    data = raw
```

### 6.2 注册变更回调

```python
def on_config_change():
    """配置变更处理逻辑"""
    new_value = config.get_config("my_config")
    # 更新业务逻辑...

# 注册回调
config.register_on_change("my_config", on_config_change)
```

### 6.3 使用Prompt模板

```python
from config.prompt import system_prompt_compressed, user_prompt

# 填充模板
content = user_prompt.replace("{{TOOLS}}", tools_content)
content = content.replace('{{USER_QUERY}}', user_query)

# 发送给模型
messages = [
    {"role": "system", "content": system_prompt_compressed},
    {"role": "user", "content": content}
]
```

## 7. 常见问题

### 7.1 配置不生效
**可能原因**：
1. 配置中心未更新
2. 同步间隔未到（30秒）
3. 配置项名称不匹配

**排查方法**：
```python
# 查看当前配置
print(config._configs)

# 手动触发同步
config.__sync_config()
```

### 7.2 回调未触发
**可能原因**：
1. 配置值未实际变更
2. 回调未正确注册
3. 回调执行异常

**排查方法**：
```python
# 检查注册的回调
print(config._on_change_callbacks)

# 检查配置是否变更
old_val = config.get_config("key")
# 更新配置中心...
new_val = config.get_config("key")
print(old_val != new_val)
```

### 7.3 正则验证失败
**现象**：配置中心更新了正则表达式，但本地未生效

**原因**：正则表达式语法错误，被验证逻辑拦截

**排查方法**：
```python
import re
try:
    re.findall(pattern, "test")
except Exception as e:
    print(f"正则错误: {e}")
```

## 8. 最佳实践

1. **配置命名规范**：使用小写字母和下划线，如 `mcp_intention_mapping`
2. **默认值设置**：始终提供合理的默认值，避免配置缺失导致服务异常
3. **回调幂等性**：回调函数应支持多次执行，避免重复执行导致问题
4. **日志记录**：在回调中记录关键日志，便于问题排查
5. **异常处理**：回调函数内部做好异常捕获，避免影响其他回调
