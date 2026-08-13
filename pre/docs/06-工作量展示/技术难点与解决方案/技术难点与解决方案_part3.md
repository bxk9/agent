# 典型示例

**Case 1 —— 闲聊招呼，无任务诉求**
历史对话:[]
当前query：你好呀，今天心情不错
Output: chat clear norm ok

**Case 2 —— 知识问答，调用 knowledgeQA**
历史对话:[]
当前query：西红柿炒鸡蛋怎么做
Output: qa clear norm ok

**Case 3 —— 意图清晰但工具不支持 → 跨维度绑定 clear**
历史对话:[]
当前query：帮我买一张去月球的票
Output: unsupported clear norm ok

**Case 4 —— 修饰主体不明确，多工具歧义 → 跨维度绑定 vague**
历史对话:[]
当前query：到10%
Output: pend vague norm ok

**Case 5 —— 异常反馈：用户否定上一轮生成结果**
历史对话:
user:帮我画一张漂亮女生的照片
assistant:好的，已经生成了漂亮女生的图片
当前query：不够好看，帮我换一张颜值很高的女生的照片
Output: single clear norm abnormal

**Case 6 —— 正常推进：用户自行变更，非纠错，对照 Case 5→ ok**
历史对话:
user:帮我画一张漂亮女生的照片
assistant:好的，已经生成了漂亮女生的图片
当前query：想了下，还是换成帅气男生的照片吧
Output: single clear norm ok

**Case 7 —— 单工具参数缺失（缺目的地，须问用户）→ lack**
历史对话:[]
当前query：帮我打个车
Output: single lack norm ok

**Case 8 —— 参数需推理（江苏最高电视塔需检索具体名称）**
历史对话:[]
当前query：导航到江苏最高的电视塔
Output: single infer norm ok

**Case 9 —— 多工具调用（先截屏识别再绘图）**
历史对话:[]
当前query：帮我查下屏幕上这首诗是谁写的，然后画一幅这个作者的肖像图
Output: multi clear norm ok

**Case 10 —— 复合指令子任务缺参（定闹钟缺时间参数）→ 整体取最高档 lack**
历史对话:[]
当前query：打开网易云播放周杰伦，然后给我定个闹钟
Output: multi lack norm ok

**Case 11 —— 多任务含 vague 子任务 → 整体取最高档 vague**
历史对话:[]
当前query：调到10%，再放首歌
Output: multi vague norm ok

**Case 12 —— 条件指令（外部条件触发+待执行任务）→ cond**
历史对话:[]
当前query：等我到家了帮我把空调打开
Output: single clear cond ok

**Case 13 —— 完整动宾但多相似候选工具，方向不明 → pend+vague**
历史对话:[]
当前query：帮我买张票
Output: pend vague norm ok

**Case 14 —— 本轮的指令是对上一轮条件指令的补充，本轮视为cond → cond**
历史对话:
user:充电时帮我做点事
assistant:请问你想让我在充电时帮你执行什么操作呢？
当前query：帮我播放周杰伦的歌
Output: single clear cond ok
"""
```

**示例设计原则**：
- 覆盖所有标签组合
- 包含对比示例（Case 5 vs Case 6）
- 覆盖边界case（Case 4、Case 11）
- 包含多轮对话场景（Case 14）

#### 3.3.5 迭代优化流程

```
1. 收集错误case
   └─ 从评测结果中提取误判样本

2. 分析错误原因
   ├─ 分类标准不清晰？
   ├─ 规则定义有歧义？
   ├─ 缺少相关示例？
   └─ 优先级规则不合理？

3. 优化Prompt
   ├─ 修改分类标准描述
   ├─ 添加扩展/排除规则
   ├─ 新增典型示例
   └─ 调整优先级规则

4. 验证效果
   ├─ 在测试集上评测
   ├─ 检查是否引入新问题
   └─ 确认准确率提升

5. 提交更新
   └─ git commit并记录变更原因
```

**迭代记录示例**：
```
2026-05-22 | 更新了条件指令判断逻辑
原因：发现"定时打开音乐"被误判为norm，实际应为cond

2026-06-16 | 优化了infer和abnormal
原因：infer和lack边界模糊，abnormal误判率高

2026-06-26 | 更新了省略式属性查询处理规则
原因："电池容量"被误判为vague，实际应为clear
```

### 3.4 效果评估

| 指标 | V1.0 | V5.1 | 提升 |
|------|------|------|------|
| 整体准确率 | 85% | **96%** | +11% |
| 工具类型准确率 | 88% | **97%** | +9% |
| 意图明确度准确率 | 82% | **95%** | +13% |
| 指令类型准确率 | 90% | **98%** | +8% |
| 执行状态准确率 | 92% | **96%** | +4% |
| 输出格式正确率 | 95% | **100%** | +5% |

**迭代次数统计**：
- 总迭代次数：50次
- 平均每周迭代：2次
- 关键版本：6个（V1.0 ~ V5.1）

### 3.5 关键代码文件

- `data_process/router_prompt.py`: 核心Prompt（385行，50次修改）
- `data_process/router_prompt_special.py`: 特殊场景Prompt（399行）
- `data_process/router_prompt_4token.py`: 4token优化Prompt（385行）
- `config/prompt.py`: Prompt模板管理（139行）

---

## 4. 动态配置热更新

### 4.1 问题描述

**背景**：MCP工具映射等业务规则需要频繁更新，但服务重启成本高。

**痛点**：
- 配置更新需要重启服务，影响可用性
- 配置中心同步可能失败，需要容错机制
- 配置变更需要触发业务逻辑更新
- 多线程环境下需要保证线程安全

**目标**：支持配置热更新，无需重启服务，保证数据一致性。

### 4.2 技术难点

1. **配置同步**：需要定期从配置中心拉取最新配置
2. **变更检测**：需要检测配置是否真正发生变化
3. **回调触发**：需要在配置变更时触发业务逻辑更新
4. **线程安全**：需要保证多线程环境下的数据一致性
5. **容错处理**：配置同步失败时不能影响服务运行

### 4.3 解决方案

#### 4.3.1 VivoConfigManager实现

```python
# config/config_mapping.py

class VivoConfigManager:
    _last_modified: int = -1
    _config_version = 1
    _configs: dict = {}
    _interval: int = 30  # 同步间隔（秒）
    _config_host = None
    _app_name = None
    _app_env = None

    def __init__(self):
        # 读写_configs和_on_change_callbacks的锁
        self._lock = threading.RLock()
        self._on_change_callbacks: list = []
        self.__do_init_env_vars()
        self.__sync_config()

    def register_on_change(self, key: str, callback):
        """注册配置变更回调"""
        with self._lock:
            self._on_change_callbacks.append((key, callback))

    def __sync_config(self):
        """从配置中心同步配置"""
        try:
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
                    print(f"{self._app_name} {self._app_env} configs sync success.")
                elif ret_code == 21304:  # 配置未修改
                    print(f"{self._app_name} {self._app_env} configs not modified.")
                else:
                    print(f"{self._app_name} {self._app_env} configs update failed.")

            else:
                print(f"{self._app_name} {self._app_env} configs sync error.")
        except Exception as e:
            print(f"{self._app_name} {self._app_env} configs sync error.", e)

    def __parse_config(self, config_list):
        """解析配置列表并触发变更回调"""
        _new_configs = {}
        _changed_keys = set()
        
        # 解析新配置
        if config_list is not None:
            for config in config_list:
                if config["name"] == "intervene_re":
                    # 正则表达式验证
                    try:
                        re.findall(str(config["value"]), "验证正则表达式是否合规")
                    except Exception as e:
                        logger.error("配置中心 intervene_re 表达式错误")
                        continue  # 验证失败，不更新
                _new_configs[config["name"]] = config["value"]

        # 检测变更并更新
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

    def _schedule_update(self):
        """后台定时同步配置"""
        while True:
            self.__sync_config()
            time.sleep(self._interval)

    def get_config(self, key, default_value: object = None):
        """获取配置值"""
        with self._lock:
            return self._configs.get(key, default_value)

    def __do_init_env_vars(self) -> None:
        """初始化环境变量"""
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

