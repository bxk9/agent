   - 只触发变更配置项的回调

4. **回调机制**：
   - 支持注册多个回调函数
   - 回调函数签名为`callback(new_value)`

5. **容错机制**：
   - 同步失败时继续使用旧配置
   - 加载本地默认配置作为兜底

#### 2.2.2 配置中心API设计

**请求**：
```
GET /api/config?lastModified=1234567890
```

**响应**：
```json
{
  "hasUpdate": true,
  "lastModified": 1234567920,
  "configs": {
    "mcp_intention_mapping": {
      "create_alarm": ["timeAndSchedule.createAlarmClock"],
      "play_music": ["media.playSpecificMusic"]
    },
    "vector_search_threshold": 0.95,
    "max_history_rounds": 6
  }
}
```

**字段说明**：
- `hasUpdate`：是否有更新（基于lastModified判断）
- `lastModified`：配置最后修改时间戳
- `configs`：变更的配置项（如果hasUpdate=false，则为空）

### 2.3 业务模块集成

#### 2.3.1 Router模块集成

```python
# main.py

from config.config_mapping import VivoConfigManager
from config.config import global_mcp_intentions, global_intention_mcps

# 初始化配置管理器
config_manager = VivoConfigManager(
    config_center_url="http://config-center.example.com/api/config",
    sync_interval=30
)

def reload_mcp_mapping(new_mapping):
    """MCP映射热更新回调"""
    with _mcp_mapping_lock:
        try:
            # 清空旧映射
            global_mcp_intentions.clear()
            global_intention_mcps.clear()
            
            # 构建新映射
            for intent, tools in new_mapping.items():
                global_mcp_intentions[intent] = tools
                for tool in tools:
                    if tool not in global_intention_mcps:
                        global_intention_mcps[tool] = []
                    global_intention_mcps[tool].append(intent)
            
            logger.info(f"MCP映射热更新成功，{len(new_mapping)}个意图")
        except Exception as e:
            logger.error(f"MCP映射热更新失败: {e}")

# 注册回调
config_manager.register_callback("mcp_intention_mapping", reload_mcp_mapping)

# 初始化时加载配置
initial_mapping = config_manager.get_config("mcp_intention_mapping", {})
reload_mcp_mapping(initial_mapping)
```

**关键点**：
1. **注册回调**：使用`register_callback`注册MCP映射的变更回调
2. **线程安全**：使用`_mcp_mapping_lock`保护全局映射的更新
3. **初始化加载**：启动时立即加载配置，不等待第一次同步

#### 2.3.2 QueryRetrieval模块集成

```python
# query_retrieval/query_recall.py

from config.config_mapping import config_manager

def get_vector_search_threshold():
    """获取向量检索阈值"""
    return config_manager.get_config("vector_search_threshold", 0.95)

def get_min_score_threshold():
    """获取最小相似度阈值"""
    return config_manager.get_config("min_score_threshold", 0.8)

def score_match(recall_results, max_score=None, min_score=None):
    """根据分数阈值筛选匹配结果"""
    # 使用动态配置
    if max_score is None:
        max_score = get_vector_search_threshold()
    if min_score is None:
        min_score = get_min_score_threshold()
    
    # ... 原有逻辑
```

**关键点**：
1. **动态获取**：每次调用时从配置管理器获取最新阈值
2. **默认值**：配置不存在时使用默认值（0.95和0.8）
3. **无需回调**：阈值参数无需回调，直接读取即可

#### 2.3.3 PromptManager模块集成

```python
# config/prompt.py

from config.config_mapping import config_manager

def get_system_prompt():
    """获取系统Prompt"""
    return config_manager.get_config(
        "system_prompt",
        "你是一个智能路由分类器..."
    )

def get_few_shot_examples():
    """获取Few-shot示例"""
    return config_manager.get_config(
        "few_shot_examples",
        [
            {"query": "定个闹钟", "output": "single clear norm ok"},
            {"query": "播放音乐", "output": "single clear norm ok"}
        ]
    )

def build_prompt(query, tools, history):
    """构建完整Prompt"""
    system_prompt = get_system_prompt()
    examples = get_few_shot_examples()
    
    # ... 构建Prompt
```

**关键点**：
1. **动态Prompt**：支持动态更新系统Prompt和Few-shot示例
2. **无需重启**：修改Prompt后30秒内自动生效
3. **A/B测试**：可以通过配置中心进行Prompt的A/B测试

---

## 3. 关键技术细节

### 3.1 线程安全保证

**问题**：多个线程同时读写配置，如何保证数据一致性？

**解决方案**：使用`threading.RLock()`（可重入锁）

```python
class VivoConfigManager:
    def __init__(self, ...):
        self._lock = threading.RLock()
        self._configs = {}
    
    def get_config(self, key: str, default: Any = None) -> Any:
        """获取配置值（线程安全）"""
        with self._lock:
            return self._configs.get(key, default)
    
    def _sync_config(self):
        """同步配置（线程安全）"""
        # ... 获取新配置
        
        with self._lock:
            self._configs.update(new_configs)
            self._last_modified = new_last_modified
```

**为什么使用RLock而不是Lock？**
- `RLock`是可重入锁，同一个线程可以多次获取锁
- 避免死锁：如果`get_config`在锁内调用另一个需要锁的方法，不会死锁
- 性能略低于`Lock`，但更安全

**锁的粒度**：
- 细粒度锁：每个配置项一个锁（复杂，性能高）
- 粗粒度锁：所有配置项共用一个锁（简单，性能略低）
- **选择粗粒度锁**：配置项数量少（<100），粗粒度锁足够

### 3.2 增量更新机制

**问题**：每次同步都拉取所有配置，网络开销大

**解决方案**：基于`lastModified`时间戳的增量更新

```python
def _sync_config(self):
    """增量同步配置"""
    # 发送lastModified时间戳
    params = {
        "lastModified": self._last_modified
    }
    
    response = requests.get(
        self.config_center_url,
        params=params,
        timeout=5
    )
    
    data = response.json()
    
    # 检查是否有更新
    if data.get("hasUpdate", False):
        # 只返回变更的配置项
        new_configs = data.get("configs", {})
        new_last_modified = data.get("lastModified", 0)
        
        # 更新配置
        with self._lock:
            self._configs.update(new_configs)
            self._last_modified = new_last_modified
    else:
        # 无更新，不传输配置数据
        pass
```

**增量更新流程**：
1. 客户端发送`lastModified`时间戳（上次同步的时间）
2. 配置中心对比时间戳，判断是否有更新
3. 如果有更新，只返回变更的配置项
4. 如果无更新，返回`hasUpdate=false`，不传输配置数据

**性能提升**：
- 无更新时：网络传输从10KB降到100字节（减少99%）
- 有更新时：只传输变更的配置项（通常<10%）

### 3.3 变更检测算法

**问题**：如何检测哪些配置项发生了变化？

**解决方案**：逐一对比新旧配置

```python
def _detect_changes(self, new_configs: Dict[str, Any]) -> List[str]:
    """检测配置变更"""
    changed_keys = []
    
    with self._lock:
        for key, new_value in new_configs.items():
            old_value = self._configs.get(key)
            
            # 对比新旧值
            if old_value != new_value:
                changed_keys.append(key)
    
    return changed_keys
```

**对比策略**：
- 使用`!=`运算符对比（支持dict、list、基本类型）
- 对于复杂对象（如dict），Python会递归对比所有字段

**性能优化**：
- 只对比配置中心返回的配置项（变更的配置项）
- 不对比未变更的配置项

### 3.4 回调触发机制

**问题**：如何通知业务模块配置已变更？

**解决方案**：观察者模式（发布-订阅）

```python
def register_callback(self, key: str, callback: Callable):
    """注册配置变更回调"""
    with self._lock:
        if key not in self._callbacks:
            self._callbacks[key] = []
        self._callbacks[key].append(callback)

def _trigger_callbacks(self, changed_keys: List[str]):
    """触发变更回调"""
    for key in changed_keys:
        callbacks = self._callbacks.get(key, [])
        for callback in callbacks:
            try:
                # 传递新值给回调函数
                new_value = self.get_config(key)
                callback(new_value)
                logger.info(f"配置变更回调执行成功: {key}")
            except Exception as e:
                logger.error(f"配置变更回调执行失败: {key}, 错误: {e}")
```

**回调执行策略**：
1. **同步执行**：回调函数在同步线程中执行
2. **异常隔离**：一个回调失败不影响其他回调
3. **传递新值**：回调函数接收新值作为参数

**回调函数签名**：
```python
def callback(new_value: Any) -> None:
    """配置变更回调
    
    Args:
        new_value: 配置的新值
    """
    pass
```

### 3.5 容错与降级

**问题**：配置同步失败时如何保证服务可用？

**解决方案**：多层容错机制

```python
def _sync_config(self):
    """同步配置（带容错）"""
    try:
        response = requests.get(
            self.config_center_url,
            params={"lastModified": self._last_modified},
            timeout=5  # 5秒超时
        )
        
        if response.status_code == 200:
            # 成功
            data = response.json()
            # ... 处理响应
        else:
            # HTTP错误
            logger.warning(f"配置同步失败，HTTP状态码: {response.status_code}")
    
    except requests.Timeout:
        # 超时
        logger.warning("配置同步超时")
    
    except requests.ConnectionError:
        # 连接错误
        logger.warning("配置中心连接失败")
    
    except Exception as e:
        # 其他异常
        logger.error(f"配置同步异常: {e}")
    
    # 无论成功失败，都继续使用旧配置
    # 下次同步时重试
```

**容错策略**：