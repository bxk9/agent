# Config 模块详细文档

## 1. 模块概述

### 1.1 模块职责
Config 模块负责项目的所有配置管理，包括：
- **静态配置**：API密钥、服务地址、模型参数等
- **动态配置**：通过配置中心实现运行时配置热更新
- **Prompt管理**：统一管理所有Prompt模板
- **环境适配**：根据环境变量自动切换配置

### 1.2 文件结构
```
config/
├── config.py              # 核心配置类和环境配置
├── config_mapping.py      # 动态配置管理器
├── prompt.py              # Prompt模板管理
├── atom_intents_router.xlsx      # 工具定义Excel（开发环境）
├── atom_intents_router-prd.xlsx  # 工具定义Excel（生产环境）
└── gui.json               # GUI交互工具定义
```

## 2. 核心组件详解

### 2.1 config.py - 静态配置管理

#### 2.1.1 Config 类
```python
class Config:
    # 豆包模型配置
    DOUBAO_DOMAIN = 'chatgpt-api-pre.vivo.lan:8080'
    DOUBAO_URI = '/chatgpt/completions'
    APP_ID_30b = '9098904344'
    APP_KEY_30b = config_key  # 从配置中心获取
    
    # OpenAI兼容接口配置
    OPENAI_API_KEY = '1111111'
    OPENAI_BASE_URL = 'http://10.121.36.5:32876/v1'
    OPENAI_BASE_URL_14B = 'http://10.121.36.5:38205/v1'
    
    # 14B模型配置
    MODEL_14B_URL = "http://0.0.0.0:8080/predict"
    
    # 工具召回服务
    TOOL_RETRIEVAL_URL = "http://10.121.36.5:32338/test"
```

**设计要点**：
- 集中管理所有外部服务的连接信息
- 支持多模型配置（30B、14B）
- API密钥通过配置中心动态获取

#### 2.1.2 环境配置映射

```python
ROUTER_MODEL_URL = {
    "dev": "http://intent-tool-router-model-pre.vmic.xyz",
    "pre": "http://intent-tool-router-model-pre.vivo.lan:8080",
    "prd": "http://intent-tool-router-model-prd.vivo.lan:8080",
    "test": "http://intent-tool-router-model-pre.vivo.lan:8080",
}

LLM_VSEARCH_SERVER = {
    'local': {...},
    'dev': {...},
    'test': {...},
    'pre': {...},
    'prd': {...}
}
```

**环境切换逻辑**：
```python
vsearch_config = LLM_VSEARCH_SERVER[os.getenv('APP_ENV', 'dev')]
router_router_config = ROUTER_MODEL_URL[os.getenv('APP_ENV', 'dev')]
```

#### 2.1.3 全局状态变量

```python
global_mcp_intentions = {}
global_intention_mcps = {"common_tools": ["knowledgeQA"]}
cloud_node_id = "intent-tool-retrieval"
```

**用途**：
- `global_mcp_intentions`: MCP工具到意图的映射
- `global_intention_mcps`: 意图到MCP工具的反向映射
- 支持运行时热更新

### 2.2 config_mapping.py - 动态配置管理

#### 2.2.1 VivoConfigManager 类

这是配置管理的核心类，实现了配置的动态同步和变更通知机制。

```python
class VivoConfigManager:
    _last_modified: int = -1
    _config_version = 1
    _configs: dict = {}
    _interval: int = 30  # 同步间隔（秒）
    _config_host = None
    _app_name = None
    _app_env = None
```

**核心属性**：
- `_last_modified`: 配置最后修改时间戳，用于增量更新
- `_config_version`: 配置版本号
- `_configs`: 本地配置缓存
- `_interval`: 配置同步间隔，默认30秒

#### 2.2.2 配置同步机制

```python
def __sync_config(self):
    """从配置中心同步配置"""
    params = {
        "appName": self._app_name,
        "appEnv": self._app_env,
        "configVersion": self._config_version,
        "lastModified": self._last_modified,
    }
    
    response = requests.get(self._config_host, params)
    
    if response.status_code == 200:
        result = response.json()
        ret_code = result["retcode"]
        
        if ret_code == 0:  # 配置有更新
            data = result['data']
            self._last_modified = data["lastModified"]
            self.__parse_config(data["configs"])
        elif ret_code == 21304:  # 配置未修改
            pass
```

**同步策略**：
1. **增量更新**：通过 `lastModified` 时间戳实现增量同步
2. **定时轮询**：后台线程每30秒同步一次
3. **状态码处理**：
   - `0`: 配置更新成功
   - `21304`: 配置未修改
   - 其他: 更新失败

#### 2.2.3 配置解析与变更通知

```python
def __parse_config(self, config_list):
    """解析配置列表并触发变更回调"""
    _new_configs = {}
    _changed_keys = set()
    
    # 解析新配置
    for config in config_list:
        if config["name"] == "intervene_re":
            # 正则表达式验证
            try:
                re.findall(str(config["value"]), "验证正则表达式是否合规")
            except Exception as e:
                logger.error("配置中心 intervene_re 表达式错误")
                continue  # 验证失败，不更新
        _new_configs[config["name"]] = config["value"]
    
    # 检测变更
    with self._lock:
        for key, new_val in _new_configs.items():
            old_val = self._configs.get(key)
            if old_val != new_val:
                _changed_keys.add(key)
        
        # 合并配置（保留本地初始化的key）
        merged = dict(self._configs)
        merged.update(_new_configs)
        self._configs = merged
        
        # 收集需要触发的回调
        callbacks_to_fire = [
            cb for k, cb in self._on_change_callbacks if k in _changed_keys
        ]
    
    # 在锁外执行回调，避免死锁
    for cb in callbacks_to_fire:
        try:
            cb()
        except Exception as e:
            logger.error(f"配置变更回调执行异常: {e}")
```

**关键设计**：
1. **正则验证**：对正则表达式类型的配置进行语法验证
2. **线程安全**：使用 `RLock` 保护配置读写
3. **变更检测**：只触发实际变更的配置项回调
4. **死锁避免**：在锁外执行回调函数

#### 2.2.4 变更回调注册

```python
def register_on_change(self, key: str, callback):
    """注册配置变更回调"""
    with self._lock:
        self._on_change_callbacks.append((key, callback))
```

**使用示例**（在 main.py 中）：
```python
def reload_mcp_mapping():
    """MCP映射热更新回调"""
    with _mcp_mapping_lock:
        try:
            new_intentions, new_mcps = _build_mcp_mapping()
            global_mcp_intentions.clear()
            global_mcp_intentions.update(new_intentions)
            global_intention_mcps.clear()
            global_intention_mcps.update(new_mcps)
            print("mcp_intention_mapping 热更新成功")
        except Exception as e:
            print(f"mcp_intention_mapping 热更新失败: {e}")

# 注册回调
config.register_on_change("mcp_intention_mapping", reload_mcp_mapping)
```

#### 2.2.5 后台同步线程

```python
def _schedule_update(self):
    """后台定时同步配置"""
    while True:
        self.__sync_config()
        time.sleep(self._interval)

# 启动后台线程
config = VivoConfigManager()
__timer_thread = threading.Thread(target=config._schedule_update, daemon=True)
__timer_thread.start()
```

**设计要点**：
- 使用守护线程（`daemon=True`），主进程退出时自动终止
- 同步失败不影响服务运行，下次重试即可

### 2.3 prompt.py - Prompt模板管理

#### 2.3.1 Prompt版本管理

```python
from data_process.router_prompt import *
from data_process.router_prompt_special import *
from data_process.router_prompt_4token import *

# 不同场景的Prompt版本
system_prompt_compressed = system_prompt_no_reason
system_prompt_compressed_special = system_prompt_no_reason_special
system_prompt_compressed_space = system_prompt_no_reason_space
```

**版本说明**：
- `system_prompt_no_reason`: 标准版本，不输出推理过程
- `system_prompt_no_reason_special`: 特殊场景版本（如美团、支付宝服务）
- `system_prompt_no_reason_space`: 带空格分隔的版本（用于SGLang早停）

#### 2.3.2 User Prompt模板

```python
user_prompt = """
# 工具库
以下是当前可用的工具定义（请基于此范围判断）：
{{TOOLS}}

# 任务
分析以下用户输入（无历史对话时用[]表示）：
{{USER_QUERY}}
"""
```

**模板变量**：
- `{{TOOLS}}`: 候选工具定义列表
- `{{USER_QUERY}}`: 用户query和历史对话

#### 2.3.3 Prompt组装流程

```
data_process/router_prompt.py
    ↓ 定义基础组件
    - system_prompt_core (分类标准)
    - system_prompt_base (系统角色)
    - output_format_no_reason (输出格式)
    - case_no_reason (示例)
    ↓ 组装完整Prompt
    - system_prompt_no_reason = base + format + case
    ↓
config/prompt.py
    ↓ 版本管理
    - system_prompt_compressed = system_prompt_no_reason
    ↓
utils/request_llm.py
    ↓ 实际使用
    - 填充 {{TOOLS}} 和 {{USER_QUERY}}
    - 发送给模型
```

## 3. 配置热更新机制

### 3.1 热更新流程

```
配置中心更新配置
    ↓
VivoConfigManager 定时轮询（30秒）
    ↓
检测到配置变更
    ↓
更新本地缓存 _configs
    ↓
触发注册的回调函数
    ↓
业务逻辑热更新（如MCP映射）
```

### 3.2 MCP映射热更新示例

```python
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

def reload_mcp_mapping():
    """热更新回调"""
    with _mcp_mapping_lock:
        try:
            new_intentions, new_mcps = _build_mcp_mapping()
            global_mcp_intentions.clear()
            global_mcp_intentions.update(new_intentions)
            global_intention_mcps.clear()
            global_intention_mcps.update(new_mcps)
            print("mcp_intention_mapping 热更新成功")
        except Exception as e:
            print(f"mcp_intention_mapping 热更新失败: {e}")
```

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
