# BlueClaw云基建及云侧执行系统概要设计说明书

# **1 业务分析**

## **1.1 需求描述**

见：产品需求说明书：[https://docs.vivo.xyz/s/0w4m68UY](https://docs.vivo.xyz/s/0w4m68UY￼)
        策略方案：[https://docs.vivo.xyz/s/B7vk3N1v](https://docs.vivo.xyz/s/B7vk3N1v)

## **1.2 ****软件设计目标阐述**

  1.实现端云协同的Agent架构，提供端云协同的工具和任务协同调用；

  2.提供端Claw的执行能力扩展，提供云工具、云Agent执行能力扩展；

  3.提供基础平台能力，实现模型计费、全链路可观测、度量能力、框架和模型质量A/B测试等。

# 2. 系统设计

## **2.1 系统架构图**

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/v8oGbHAY8q0IrUlvqsnM7a_UmDpBdmWad1WmZEWd-XZl3hmc076lpDoN0t0Bl7BE "image.png")

**      模块定义与职责**

| 模块 | 职责 |
| --- | --- |
| blueclaw云网关 | 负责端云协同通信、访问鉴权、跨端设备注册、多业务接入代理 |
| Worksapce: 系统内置文件、跨端用户文件管理，沙箱文件挂载路径管理等，云侧任务执行状态管理 |  |
| 模型Provider: 模型调用、审核，对齐小V标准模式 |  |
| 端云反查调用：服务端下发端侧工具调用； |  |
| Agent代理：Agent任务协同调用 |  |
| UI渲染：对齐小V标准模式的UI编排能力，实现A2UI的渲染能力 |  |
| 云工具/Agent能力层 | 云工具：对接小V云侧工具能力、新增Pro模式工具能力； 工具范围参考产品文档 |
| 云Agent: 对接二方Agent能力，实现跨端A2A能力调用。 |  |
| 平台层 | 全链路可观测/度量：链路信息可视化，系统关键指标统计（工具/skill调用次数、健康情况等等）；工具&skill离线/在线评测 |

# 3. 模块功能设计

## 3.1 blueclaw 云网关

### 3.1.1 网关接入层  @金绍杰

#### 3.1.1.1 端云通信

  [https://docs.vivo.xyz/s/LpaZXAEG](https://docs.vivo.xyz/s/LpaZXAEG) 邀请您加入文档协作【claw云网关协议】

#### 3.1.1.2 鉴权校验

网关负责对客户端身份进行鉴权验证。鉴权通过后，网关将客户端请求转发至后端 backend 服务。

##### 3.1.1.2.1. 鉴权流程

```plaintext
客户端 WebSocket 连接
        │
        ▼
┌─────────────────────┐
│  URL 参数校验        │  缺少 userid/appid/vaid → 返回 250000
│  (userid/appid/vaid) │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  判断是否需要鉴权    │  appid 在 token_auth_config 白名单中 → 跳过鉴权
│  (check_need_auth)   │
└─────────┬───────────┘
          │ 需要鉴权
          ▼
┌─────────────────────┐
│  指纹鉴权（优先）    │  请求头含 vivo-fingerprint-token → 调用指纹服务
│  fingerprint_kit     │  成功(resp_code=200) → 鉴权通过
└─────────┬───────────┘
          │ 未通过或未携带
          ▼
┌─────────────────────┐
│  Vivo Token 鉴权     │  URL 参数含 token → 调用 vivo token 服务
│  vivo_token          │  成功(retcode=200) → 鉴权通过
└─────────┬───────────┘
          │ 未通过
          ▼
┌─────────────────────┐
│  鉴权失败            │  返回 250018
│  关闭 WebSocket 连接 │
└─────────────────────┘
```

1. **参数校验**：客户端连接 URL 必须包含 `userid`、`appid`、`vaid` 三个参数，缺少任何一个返回错误码 `250000`
2. **鉴权判断**：根据 `token_auth_config` 配置判断当前 `appid` 是否需要鉴权
3. **指纹鉴权**（优先级高）：检查请求头中是否携带 `vivo-fingerprint-token`，若有则调用指纹验证服务
4. **Vivo Token 鉴权**（降级方案）：指纹鉴权未通过时，检查 URL 参数中是否携带 `token`，若有则调用 vivo token 验证服务
5. **用户白名单**：两种鉴权方式在调用远程服务前，都会先检查 `userid` 是否命中 `token_white_list`，命中则直接通过
##### 3.1.2.2.2 鉴权方式详解

###### 3.1.2.2.2.1 指纹鉴权（Fingerprint Auth）

| 项目 | 说明 |
| --- | --- |
| 触发条件 | 请求头包含 `vivo-fingerprint-token` |
| 接口地址 | `POST http://fingerprint-prd.vivo.lan:8080/fingerprint` |
| 超时时间 | 3000ms |
| 成功标志 | 响应 JSON 中 `resp_code == 200` |
| 失败默认码 | 405 |

**请求头：**

| Header | Value |
| --- | --- |
| `Content-Type` | `application/json` |
| `vivo-fingerprint-token` | 客户端传入的指纹 token 原始值 |

**请求体：**

```json
{
    "serviceName": "userlogin",
    "openid": "<userid>",
    "vivo-fingerprint-token": "<指纹 token>",
    "clientId": "172",
    "clientIp": "<服务器 IP>",
    "fromDetail": "com.vivo.ai.copilot",
    "cid": "<连接 ID>"
}
```

**响应判断：**

- 解析响应 JSON，取 `resp_code` 字段
- `resp_code == 200` 表示鉴权成功
- 其他值或请求失败返回 `405`
###### 3.1.2.2.2 Vivo Token 鉴权

| 项目 | 说明 |
| --- | --- |
| 触发条件 | 指纹鉴权未通过，且 URL 参数含 `token` |
| 接口地址 | `POST http://vgateway-middle-prd.vivo.lan:8080/api/authVivoToken` |
| 超时时间 | 5000ms |
| 成功标志 | 响应 JSON 中 `retcode == 200` |
| 失败默认码 | 403 |

**请求头：**

| Header | Value |
| --- | --- |
| `Content-Type` | `application/json` |
| `gwSignature` | 计算生成的签名（见签名算法） |
| `serviceName` | `userlogin` |

**请求体：**

```json
{
    "serviceName": "userlogin",
    "openid": "<userid>",
    "vivotoken": "<URL 参数中的 token>",
    "clientId": "172",
    "clientIp": "<服务器 IP>",
    "fromDetail": "com.vivo.ai.copilot"
}
```

**签名算法：**

```plaintext
invoker_name_encoded = base64("copilot-api-gateway")
body_encoded = hex(SHA256(app_secret + timestamp + body))
signature = invoker_name_encoded + "@#" + timestamp + "@#" + body_encoded
```

- `app_secret`：`7oC0^_77?e8RpL3_{86^X}DPNMu]ddjk`
- `timestamp`：当前时间毫秒数
- `body`：请求体 JSON 字符串
**响应判断：**

- 解析响应 JSON，取 `retcode` 字段
- `retcode == 200` 表示鉴权成功
- 其他值或请求失败返回 `403`
##### 3.1.2.2.3. 白名单

###### AppID 免鉴权白名单（token_auth_config）

在 `config.lua` 中配置。白名单内的 `appid` 连接时**不需要鉴权**，直接放行：

```lua
_M["token_auth_config"] = {
    ["3914138966"] = 1,
    ["qianxun"] = 1,
    ["smart_jovi"] = 1,
    ["origin_note_web"] = 1,
    ["browser"] = 1,
    ["meta_human"] = 1
}
```

###### 用户白名单（token_white_list）

在 `config.lua` 中配置。白名单内的 `userid` 在鉴权时**跳过远程接口调用**，直接返回成功：

```lua
_M["token_white_list"] = {}
```

当前为空，按需添加。

##### 3.1.2.2.4. 错误码

| 错误码 | 触发场景 | error_detail | 用户提示（error_msg） |
| --- | --- | --- | --- |
| 250000 | URL 缺少 userid | userid missing | 账号验证失败 |
| 250000 | URL 缺少 appid/vaid | params check failed | 请求参数非法 |
| 250018 | 鉴权失败 | auth failed | 账号登陆失败，暂无法使用，请前往"设置"重新登录vivo账号。 |

错误消息格式为 protobuf 编码的 `DataPackage`，`msg_type = "gateway_error"`，payload 为 JSON：

```json
{
    "error_code": 250018,
    "error_msg": "账号登陆失败，暂无法使用，请前往"设置"重新登录vivo账号。",
    "error_detail": "auth failed"
}
```

#### 3.1.2.3 节点注册管理

##### 场景说明

每个用户有一个唯一的 vivo 账号（userid），可以通过多台手机（vaid 区分）登录同一账号。网关需要支持节点注册功能，使 backend 能感知同一账号下所有在线设备，未来端云通信时可定向选择设备交互。

```plaintext
用户A (userid) ─┬─ 手机1 (vaid=aaa) ── WS ──> 网关实例1 ──> Backend
                ├─ 手机2 (vaid=bbb) ── WS ──> 网关实例1 ──> Backend
                └─ 手机3 (vaid=ccc) ── WS ──> 网关实例2 ──> Backend
```

##### 数据模型

Backend 侧维护在线设备表：

```python
# userid → { vaid → DeviceNode }
online_devices = {
    "user_123": {
        "vaid_aaa": DeviceNode(session_id="x1", ws_conn=conn1, connected_at=...),
        "vaid_bbb": DeviceNode(session_id="x2", ws_conn=conn1, connected_at=...),
        "vaid_ccc": DeviceNode(session_id="x3", ws_conn=conn2, connected_at=...),
    }
}
```

##### 注册/注销时机

| 事件 | 触发方 | Backend 动作 |
| --- | --- | --- |
| handshake 成功 | Backend 收到 handshake 消息 | 从 payload 提取 `userid` + `vaid`，注册到 `online_devices` |
| 客户端断连 | 网关发送 `msg_type=disconnect` | 从 `online_devices` 中移除该 `vaid` |
| 网关↔Backend WS 断连 | Backend 检测到连接断开 | 清理该连接上所有已注册的设备节点 |
| Resume 成功 | 客户端带旧 session_id 重连 | 无需更新（session_id 不变） |
| Resume 失败 → 新握手 | Backend 收到新 handshake | 用新 session_id 覆盖该 vaid 记录 |

##### 信息来源

客户端连接 URL 已携带：

- `userid` — 用户标识
- `vaid` — 设备标识
网关在 handshake 时将这些参数透传给 backend（handshake payload 中），网关侧不需要额外改动。

##### 查询接口

```plaintext
GET /api/devices/online?userid=xxx

Response:
{
    "userid": "xxx",
    "devices": [
        {"vaid": "aaa", "session_id": "x1", "connected_at": 1778157212883},
        {"vaid": "bbb", "session_id": "x2", "connected_at": 1778157215000}
    ]
}
```

##### 定向通信流程

当需要向特定设备发消息时：

```plaintext
调用方 → Backend: "给 userid=xxx, vaid=bbb 发反查请求"
    ↓