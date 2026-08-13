# Data 模块详细文档

## 1. 模块概述

### 1.1 模块职责
Data 模块负责定义项目的数据结构和工具映射关系，包括：
- **请求参数定义**：定义API接口的请求参数模型
- **工具意图映射**：定义工具名称到MCP意图的映射关系
- **数据验证**：使用Pydantic进行参数验证

### 1.2 文件结构
```
data/
├── params.py       # 请求参数模型定义
└── intent2tool.py  # 工具意图映射表
```

## 2. 核心组件详解

### 2.1 params.py - 请求参数模型

#### 2.1.1 Params 类定义

```python
from pydantic import BaseModel
from typing import Optional, Union, Any

class Params(BaseModel):
    query: Optional[Union[str, int, float]] = ''           # 当前对话
    chat_history: Optional[list] = []                      # session历史记录
    scene: Optional[dict] = {}                             # 场景信息
    session_id: Optional[str] = ''                         # 会话ID
    request_id: Optional[str] = ''                         # 请求ID
    tools: Optional[list] = []                             # 候选工具列表
    tools_history: Optional[list] = []                     # 历史工具调用
    trace_id: Optional[str] = ''                           # 追踪ID
    need_dispatch: Optional[bool] = False                  # 是否启用正则匹配
    copilot_env: Optional[str] = 'v1'                      # 环境标识
    base_url: Optional[str] = ''                           # 自定义模型地址
    extra: Optional[Any] = None                            # 扩展参数
```

**字段说明**：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `query` | str/int/float | '' | 用户当前输入的query |
| `chat_history` | list | [] | 历史对话列表，格式为 `[{"role": "user", "content": "..."}, ...]` |
| `scene` | dict | {} | 场景信息（预留字段） |
| `session_id` | str | '' | 会话ID，用于关联同一会话的多次请求 |
| `request_id` | str | '' | 请求ID，用于唯一标识一次请求 |
| `tools` | list | [] | 候选工具列表，格式为 `[{"key": "tool_name", "function_name": [...]}]` |
| `tools_history` | list | [] | 历史工具调用记录 |
| `trace_id` | str | '' | 追踪ID，用于日志追踪和链路关联 |
| `need_dispatch` | bool | False | 是否启用正则模板匹配 |
| `copilot_env` | str | 'v1' | Copilot环境标识（v1/ltx/ymr/ts等） |
| `base_url` | str | '' | 自定义模型服务地址（用于测试） |
| `extra` | Any | None | 扩展参数，用于传递额外信息 |

#### 2.1.2 使用示例

```python
from data.params import Params

# 基本请求
params = Params(
    query="帮我定一个明天早上8点的闹钟",
    tools=[
        {
            "key": "create_alarm",
            "function_name": ["timeAndSchedule.createAlarmClock"]
        }
    ],
    trace_id="trace-123"
)

# 带历史对话的请求
params = Params(
    query="改成9点",
    chat_history=[
        {"role": "user", "content": "帮我定一个明天早上8点的闹钟"},
        {"role": "assistant", "content": "好的，已为您设置明天早上8点的闹钟"}
    ],
    tools=[...],
    trace_id="trace-456"
)

# 启用正则匹配的请求
params = Params(
    query="定一个明天早上8点的闹钟",
    tools=[...],
    need_dispatch=True,
    trace_id="trace-789"
)
```

#### 2.1.3 Pydantic 验证

```python
# 自动类型转换
params = Params(query=123)  # int 自动转为 str
print(params.query)  # "123"

# 默认值
params = Params()
print(params.query)  # ""
print(params.chat_history)  # []

# 可选字段
params = Params(query="test", scene=None)  # scene 可以为 None
```

**验证特性**：
- 自动类型转换（int/float → str）
- 默认值填充
- 可选字段支持
- 类型检查

### 2.2 intent2tool.py - 工具意图映射

#### 2.2.1 映射表结构

```python
tools_intent = {
    "search_alarm": [
        "timeAndSchedule.queryAlarmClock"
    ],
    "show_alarm_card": [
        "timeAndSchedule.queryAlarmClock"
    ],
    "control_timer": [
        "timeAndSchedule.createTimerAndStopwatch"
    ],
    "create_alarm": [
        "timeAndSchedule.createAlarmClock"
    ],
    "operate_alarm": [
        "timeAndSchedule.createAlarmClock",
        "timeAndSchedule.deleteAlarmClock",
        "timeAndSchedule.offAlarmClock"
    ],
    # ... 更多映射
}
```

**映射关系**：
- **Key**: 工具意图名称（如 `create_alarm`）
- **Value**: MCP工具全限定名列表（如 `["timeAndSchedule.createAlarmClock"]`）

#### 2.2.2 映射分类

**时间与日程类**：
```python
"search_alarm": ["timeAndSchedule.queryAlarmClock"]
"create_alarm": ["timeAndSchedule.createAlarmClock"]
"modify_alarm": ["timeAndSchedule.updateAlarmClock"]
"operate_alarm": [
    "timeAndSchedule.createAlarmClock",
    "timeAndSchedule.deleteAlarmClock",
    "timeAndSchedule.offAlarmClock"
]
"create_schedule": [
    "timeAndSchedule.addSchedule",
    "timeAndSchedule.extractSchedule"
]
"delete_schedule": ["timeAndSchedule.deleteSchedule"]
"search_schedule": ["timeAndSchedule.searchSchedule"]
"modify_schedule": ["timeAndSchedule.updateSchedule"]
```

**系统操作类**：
```python
"restart_phone": ["systemOperationAndSettings.restartPhone"]
"adjust_volume": ["systemOperationAndSettings.adjustVolume"]
"lock_screen": ["systemOperationAndSettings.lockScreen"]
"capture_screen": ["systemOperationAndSettings.screenCapture"]
"open_app": ["systemOperationAndSettings.appOpenAndClose"]
"close_app": ["systemOperationAndSettings.appOpenAndClose"]
```

**媒体类**：
```python
"play_music": ["media.playSpecificMusic"]
"play_music_list": ["media.playMusicList"]
"play_video": ["media.playSpecificVideo", "media.searchVideo"]
"play_broadcast": ["media.listenToRadio"]
"control_media_read": [
    "systemOperationAndSettings.screenReadingControl",
    "media.meidaPlayControl",
    "systemOperationAndSettings.readingSpeedSetting"
]
```

**导航与出行类**：
```python
"perform_navigation": ["traveling.navigation"]
"perform_route_services": [
    "traveling.navigation",
    "traveling.remainingTimeRouteInquiry"
]
"search_poi": ["traveling.locationInquiry"]
"call_taxi": ["traveling.callTaxi"]
"manage_flight_tickets": ["traveling.flightInquiry"]
"manage_train_tickets": ["traveling.trainInquiry"]
```

**社交与通讯类**：
```python
"make_phone_call": ["Socializing.makeCall"]
"send_wechat_message": ["Socializing.sendMessage"]
"search_phone_contact": ["Socializing.searchContact"]
"create_new_contact": ["Socializing.createNewContact"]
"answer_call": ["Socializing.callRejectAndAnswer"]
"reject_call": [
    "Socializing.callRejectAndAnswer",
    "Socializing.ignoreIncomingCall"
]
```

**知识问答类**：
```python
"knowledgeQA": [
    "chattingAndQA.chattingAndQA",
    "textGeneration.writing",
    "officeWork.translate",
    "knowledgeBasedProblemSolving.knowledgeBasedProblemSolving",
    "summary.summary",
    "news.hotEventTracking",
    "mathematicalCalculation.numericalCalculation",
    "textGeneration.polish"
]
```

**图像编辑类**：
```python
"generate_images": [
    "imageEditing.aigcStylization",
    "imageEditing.removeHandwriting",
    "imageEditing.removePassersby",
    "imageEditing.applyAIEffect",
    "imageEditing.changeIdPhotoBackground",
    "imageEditing.imageMerge",
    "imageEditing.generatePoster",
    "imageEditing.pictureBeautyMakeup",
    "imageEditing.adjustImage",
    "imageEditing.imageEditOther",
    "imageEditing.expandImage",
    "imageEditing.textToPicture",
    "imageEditing.textToWallpaper",
    "imageEditing.textGenerateArtFont",
    "album.rotateImageVideo",
    "album.compressImageVideo"
]
```

**IoT设备控制类**：
```python
"iot_control_device": [
    "Iot.acTemperatureAdjustment",
    "Iot.adjustCurtains",
    "Iot.adjustDeviceWindSpeed",
    "Iot.adjustFanShakingHeadDir",
    "Iot.adjusthumidity",
    "Iot.adjustIotDeviceBrightness",
    "Iot.adjustLightColorTemp",
    "Iot.controlACExtraProperty",
    "Iot.controlCleaningRobot",
    "Iot.deviceModeAdjustment",
    "Iot.deviceOnOff",
    "Iot.deviceRiseAndFall",
    "Iot.IotCameraContorl",
    "Iot.onOffDisinfectHeatDry",
    "Iot.robotVacuumCharging",
    "Iot.socketSwitchExtraPowerSetting",
    "Iot.switchLightColor"
]
```

#### 2.2.3 映射特点

**一对多映射**：
```python
"operate_alarm": [
    "timeAndSchedule.createAlarmClock",
    "timeAndSchedule.deleteAlarmClock",
    "timeAndSchedule.offAlarmClock"
]
```
- 一个意图可能对应多个MCP工具
- 表示该意图可以通过多种方式实现

**多对一映射**：
```python
"open_app": ["systemOperationAndSettings.appOpenAndClose"]
"close_app": ["systemOperationAndSettings.appOpenAndClose"]
```
- 多个意图可能对应同一个MCP工具
- 表示同一个工具可以服务多种意图

**复合工具**：
```python
"knowledgeQA": [
    "chattingAndQA.chattingAndQA",
    "textGeneration.writing",
    "officeWork.translate",
    ...
]
```
- 知识问答包含多种子能力
- 每个子能力对应一个MCP工具

## 3. 数据流转

### 3.1 在Config模块中的使用

```python
# config/config_mapping.py
from data.intent2tool import tools_intent

class VivoConfigManager:
    def __do_init_env_vars(self) -> None:
        # 从本地加载默认MCP映射
        self._configs["mcp_intention_mapping"] = tools_intent
```

**用途**：
- 作为配置中心的默认值
- 配置中心未下发时使用本地映射

### 3.2 在Router模块中的使用

```python
# router/router_v2.py
from data.intent2tool import tools_intent

def _extract_tools(self, tools, tools_history):
    """从请求参数中提取有效的工具名称列表"""
    # 白名单过滤（通过 global_intention_mcps）
    result = [
        fn for item in filtered 
        for fn in global_intention_mcps.get(item['key'], []) 
        if fn not in EXCLUDED_TOOLS
    ]
    return result
```

**用途**：
- 根据工具意图名称查找对应的MCP工具
- 过滤掉不需要的工具

### 3.3 在Main模块中的使用

```python
# main.py
from data.intent2tool import tools_intent
from config.config import global_mcp_intentions, global_intention_mcps
