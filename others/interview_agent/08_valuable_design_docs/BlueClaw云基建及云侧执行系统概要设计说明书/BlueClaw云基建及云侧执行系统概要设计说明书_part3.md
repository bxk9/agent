客户端请求
    │  Authorization: {bizName}#{openId}#{token}
    ▼
解析 bizName + openId + token
    ▼
账号中心校验 token 合法性
    ▼
MySQL get_or_create_user（幂等）
    ▼
返回用户对象（含用量配额信息）
```

#### 用量管控

| 维度 | 策略 | 默认值 |
| --- | --- | --- |
| 每日 Token 上限 | 超限返回 429 | 5000,000 |
| 每月 Token 上限 | 超限返回 429 | 当前不限制 |
| 计数方式 | Redis 原子 INCRBY，pipeline 写入，TTL 自动过期 | — |

#### 当前用量数据

| 指标 | 数值 |
| --- | --- |
| 试用用户数 | ~120 人（公司内部） |
| 日均 Token 消耗 | ~6,000 万 token |
| 环境状态 | DEV + PRE 已就绪，预发已开放内部试用 |

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/cdCpBoI0OM9xF-enaFpqdvDgZFQGpX-s62eCssQVKOh4FNbBBq6zqFc3xU7qkECr "image.png")

### 用量监控

已落地运管平台：[https://vivo-claw-server-pre.vivo.com/](https://vivo-claw-server-pre.vivo.com/)

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/ilg5LIwIakzBkr36Sz26yoHG-3THhK_LJJBJ5U103LYdZqknTlBX_xTFqhRGoA1v "image.png")

# 5. 数据对象与存储设计

# 6. 安全性设计

# 7. 数据保护合规设计
8 附录

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/xjd8UzmN8ajSgUpemjJfgjOMbYShZ7PXInaxQEPgr_W4vC9Hu7DNWs7-ivw1meVz "image.png")

## 流程图

### 工具上线流程

```plaintext
@startuml
skinparam backgroundColor #FEFEFE
skinparam shadowing false
skinparam defaultFontName "PingFang SC,Helvetica Neue,Arial"
skinparam defaultFontSize 13
skinparam activity {
  BackgroundColor #FFFFFF
  BorderColor #B8D4E3
  FontColor #4A4A4A
  DiamondBackgroundColor #FFFFFF
  DiamondBorderColor #C8A2C8
}
skinparam swimlane {
  BorderColor #E0E0E0
  TitleFontSize 14
  TitleFontColor #5A5A5A
}
|#FDF2F8|💻 开发者|
start
:判断已有能力是否需要适配;
if (需要适配?) then (是)
  :开发适配的MCP;
else (否)
endif
:本地验证;
|#F0F9FF|📊 度量|
:通过效率平台进行度量;
|#FDF2F8|💻 开发者|
:上线到技能平台;
|#F5F3FF|✅ 审核|
:管理员审核上线;
stop
@enduml
```

### 调用流程

```plaintext
%%{init: {'theme': 'base', 'themeVariables': {'actorBkg': '#E3F2FD', 'actorTextColor': '#37474F', 'actorBorder': '#90CAF9', 'signalColor': '#555', 'signalTextColor': '#444', 'labelBoxBkgColor': '#F0FAF7', 'labelBoxBorderColor': '#5BB5A2', 'loopTextColor': '#5BB5A2'}}}%%
sequenceDiagram
    participant Client as 🖥️ 端Claw
    participant Proxy as ⚙️ 技能平台工具代理服务
    participant MCP as 🔌 MCP适配服务
    participant Downstream as 🌐 下游服务<br/>(天气/搜索/文档...)
    rect rgb(240, 253, 250)
        Client->>Proxy: 工具调用请求
    end
    rect rgb(255, 252, 240)
        Proxy->>Proxy: 路由判断
    end
    alt 需要MCP适配（可选路径）
        rect rgb(243, 240, 255)
            Proxy->>MCP: 转发请求(协议适配)
            MCP->>Downstream: 调用下游服务
            Downstream-->>MCP: 返回结果
            MCP-->>Proxy: 适配后响应
        end
    else 直连下游（无需适配）
        rect rgb(240, 248, 255)
            Proxy->>Downstream: 直接调用下游服务
            Downstream-->>Proxy: 返回结果
        end
    end
    rect rgb(240, 253, 250)
        Proxy-->>Client: 返回工具调用结果
    end
```

### tool && skill 选择

```plaintext
graph TD
    A["🔵 全量 Tool 注册<br/>50+ tools（平台 + 第三方 + 用户自建）"]
    A -->|"按领域拆分端点"| B
    subgraph L1["Layer 1: Namespace 拆分（部署层）"]
        B["/mcp/weather<br/>3 tools"]
        C["/mcp/search<br/>5 tools"]
        D["/mcp/doc<br/>4 tools"]
    end
    B -->|"tools/list 按场景过滤"| E
    subgraph L2["Layer 2: 动态 Tool Discovery（协议层）"]
        E["返回 Skill 相关子集<br/>2~5 tools"]
    end
    E -->|"Skill 指令精确指定"| F
    subgraph L3["Layer 3: Skill 分层调用（知识层）"]
        F["weather_forecast<br/>1~2 tools"]
    end
    F -->|"极小候选集"| G["✅ 模型选择<br/>准确率 ≈ 100%"]
    style A fill:#e3f2fd
    style G fill:#e8f5e9
    style L1 fill:#fff3e0,stroke:#ff9800
    style L2 fill:#fce4ec,stroke:#e91e63
    style L3 fill:#e8eaf6,stroke:#3f51b5

```