![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/Y0cL0RkkqjOZVcFcugRAqoicFbk9vTP1p_cY9wfDCFYviz9wJLNl1BtMQjZLrTLH "image.png")

| 传输协议 | WebSocket Binary Frame |
| --- | --- |
| 序列化格式 | 外层 Protobuf，payload 内 JSON转成的bytes |
| 连接入口 | `/blueclaw/core` |
| header参数 | vivo-fingerprint-token |
|  |  |

【url参数】：通过key1=val1&key2=val2..&keyn=valn 方式拼接，必传的参数必须传值且不为空，网关会校验

| 字段 | 类型 | 说明 | 是否必选 | 是否urlencode | 备注 |
| --- | --- | --- | --- | --- | --- |
| **biz_code** | **string** | **业务域名称** | **是** | **是** | **蓝龙虾：blueclaw，记忆：memory** |
| **package_name** | **string** | **调用方包名** | **是** | **是** |  |
|  |  |  |  |  |  |
| token | **string** | vivo token | **可选** | 是 |  |
| vivo-fingerprint-token | **string** | 设备指纹token | **可选** | 是 |  |
| appid | string | 接入业务的appid | 是 | 是 | 服务端分配**，**每个业务唯一 |
| userid | string | 用户ID | 是 | 是 | 传openid值 |
| vaid | string | 设别ID | 是 | 是 |  |
| system_time | string | 请求时系统时间 | 是 | 是 | Unix timestamp, 单位: 毫秒 |
| product | string | 客户端内部型号 | 否 | 是 | 手机接入必传 |
| model | string | 客户端外部型号 | 否 | 是 | 手机接入必传 |
| android_version | string | android版本号 | 否 | 是 | 手机接入必传 |
| client_version | string | 客户端app版本号 | 是 | 是 |  |
| system_version | string | 客户端系统版本号 | 否 | 是 | 手机接入必传 |
| rom_ver | string | rom版本号 | 否 | 是 | 手机接入必传 |
| net_type | string | 网络状态 | 否 | 是 | 取值：mobile：移动网络， wifi：wifi网络<br>手机接入必传 |
| platform | string | 平台类型 | 是 | 是 | 取值：android、ios、web |

## 基础协议（protobuf信封）

所有websocket的基础协议模板如下，业务参数放在payload中

```protobuf
message DataPackage {
    string msg_type = 1;   // 消息类型（如 "handshake", "handshake_ack", "disconnect"）
    Header header = 2;     // 通用头部
    bytes payload = 3;     // 业务负载
}

message Header {
    uint64 request_timestamp = 1;  // Unix毫秒时间戳
    string user_id = 2;            // 用户唯一标识符openid
    string session_id = 3;         // 服务端生成的当前会话唯一标识
    string flow_id = 4;            // 服务端生成的对话id
    uint64 sequence_id = 5;        // 客户端/服务端的必要内容包序号
    string package_id = 6;         // 请求包唯一标识
    string ack_id = 7;             // 回复包匹配请求包的package_id
    bool skip_ack = 8;             // 是否跳过ack
    bool eager = 9;                // 消息是否可以不按顺序执行
    PayloadDatatype payload_datatype = 10;  // 数据类型(JSON_STRING/TEXT/BINARY_DATA)
    CompressAlgorithm compress_algorithm = 11;  // 压缩算法(NO_COMPRESS/ZSTD/GZIP)
}
```

payload_datatype 固定使用JSON_STRING

# 1、大模型调用协议

## 接口信息

| 项目 | 说明 |
| --- | --- |
| 连接入口 | `/blueclaw/core` |
| 传输协议 | WebSocket Binary Frame |
| 序列化格式 | 外层 Protobuf（DataPackage），payload 内 JSON |
| 请求 msg_type | `llm_request` |
| 响应ack msg_type | `llm_request_ack` |
| 响应数据内容 msg_type | `llm_request`（流式多帧推送） |

> [https://docs.vivo.xyz/s/XzNIDJwJ](https://docs.vivo.xyz/s/XzNIDJwJ) 邀请您加入文档协作【大模型调用接口文档】
> 大模型调用复用第2节 A2A 协议的 WebSocket + Protobuf 通道，连接参数（appid、userid、鉴权等）通过 URL 查询参数携带，具体参见第2节「连接入口」的 URL 参数表。

---

# 2、agent通信协议（A2A）

TODO:

1、定时任务协议，单独拉会确认

2、history字段确认

A2A规范：[https://a2a-protocol.org/latest/specification/](https://a2a-protocol.org/latest/specification/)

## 一、概述

本协议定义了客户端与 云侧claw、二方agent 之间基于 WebSocket + Protobuf 的通信规范。协议在现有 `DataPackage` protobuf 信封基础上，在 `payload` 字段内嵌入符合 **JSON-RPC 2.0** 规范的 A2A V1.0版本（Agent-to-Agent）Task 生命周期语义，实现任务的提交、流式更新、取消等完整交互能力。

protobuf 信封 msg_type定义如下：

| 请求 msg_type | `a2a_msg` |
| --- | --- |
| 响应ack msg_type | `a2a_msg_ack` |
| 响应内容 msg_type | `a2a_msg` |
|  |  |

## 二、Method 定义

| method | 方向 | JSON-RPC 类型 | 说明 |
| --- | --- | --- | --- |
| `SendMessage` | C→S | Request | 发送消息/创建任务，期望流式更新 |
| `GetTask` | C→S | Request | 查询任务当前状态 |
| `CancelTask` | C→S | Request | 取消任务 |
| `task/statusUpdate` | S→C | Notification | 任务状态更新推送 |
| `task/artifactUpdate` | S→C | Notification | 任务产物推送 |

## 三、Task 状态机

| 状态 | 说明 | 是否终态 |
| --- | --- | --- |
| `TASK_STATE_SUBMITTED` | 任务已提交，等待 Agent 处理 | 否 |
| `TASK_STATE_WORKING` | Agent 正在处理中，可能有流式中间输出 | 否 |
| `TASK_STATE_INPUT_REQUIRED` | Agent 需要额外用户输入才能继续 | 否 |
| `TASK_STATE_AUTH_REQUIRED` | Agent 需要用户完成身份验证才能继续 | 否 |
| `TASK_STATE_COMPLETED` | 任务完成，产物在 artifacts 中 | 是 |
| `TASK_STATE_FAILED` | 任务失败 | 是 |
| `TASK_STATE_CANCELED` | 任务被取消 | 是 |
| `TASK_STATE_REJECTED` | 任务被 Agent 拒绝（如权限不足、不支持的请求） | 是 |

备注：如果向终态任务发送消息，服务端应该返回：

```json
{
  "jsonrpc": "2.0",
  "id": "req-005",
  "error": {
    "code": -32004,
    "message": "Cannot send message to a completed task",
    "data": {
      "taskId": "task-xxx",
      "currentState": "TASK_STATE_COMPLETED"
    }
  }
}
```

---

## 四、数据结构定义

### 4.1 Message 对象

`Message` 是客户端与 Agent 之间的单次通信单元，通过 `contextId` 关联同一对话上下文，通过 `taskId` 关联具体任务。

```json

    {
        "messageId": "msg-uuid-003",
        "role": "ROLE_USER",
        "contextId": "ctx-uuid",
        "taskId": "task-uuid",
        "referenceTaskIds":["task-uuid-1"],
        "parts": [
            {
                "text": "这张图片里有什么？"
            },
            {
                "url": "http://xxxx",
                "mimeType": "image/jpeg",
                "filename": "photo.jpg",
                "metadata": {
                    "batch_id": "xxx"
                    
                }
            }
        ]
    }

```

**Message 字段说明：**

| 字段 | 类型 | 必须 | 说明 |
| --- | --- | --- | --- |
| messageId | string | 是 | 消息唯一标识（UUID），由消息创建方生成 |
| role | string | 是 | 消息发送方：`ROLE_USER`（客户端）或 `ROLE_AGENT`（Agent） |
| contextId | string | 否 | 对话上下文唯一标识，关联同一会话内的多个任务和消息 |
| taskId | string | 否 | 关联的任务 ID；继续现有任务时必填 |
| parts | Part[] | 是 | 消息内容，见下方 Part 说明 |
| referenceTaskIds | string[] | 否 | 本消息引用的其他任务 ID 列表 |
| metadata | object | 否 | 扩展元数据 |
| extensions | string[] | 否 | 本消息使用的扩展协议 URI 列表 |

**Part 字段说明：**

Part 通过实际填写的字段来区分内容类型，无需 `type` 判别符字段。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| text | string | 文本内容 |
| data | object/array | 结构化 JSON 数据 |
| url | string | 文件/媒体的 URL 或 URI |
| raw | string | 文件二进制内容（base64 编码） |
| filename | string | 文件名（可选） |
| mimeType | string | MIME 类型，如 `text/plain`、`image/jpeg`、`application/json` |
| metadata | object | 扩展元数据（如分片信息等） |

### 4.2 Artifact 对象

Artifact 表示任务的输出产物，通过 `task/artifactUpdate` 通知推送。`append` 和 `lastChunk` 是事件层字段，不属于 Artifact 本身。

```json
{
  "artifactId": "artifact-uuid",
  "name": "产物名称",
  "parts": [ Part ],
  "description": "",
  "metadata": {}
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| artifactId | string | 产物唯一标识（UUID），在同一 Task 内唯一 |
| name | string | 产物名称（可选） |
| description | string | 产物描述（可选） |
| parts | Part[] | 产物内容，至少包含一个 Part |
| metadata | object | 扩展元数据（可选） |
| extensions | string[] | 使用的扩展协议 URI 列表（可选） |

---

## 五、各方法 payload 定义

### 5.1 `SendMessage`（C→S）

发送消息并创建/继续任务。新任务不携带 `taskId`（由服务端分配）；继续现有任务（如 `TASK_STATE_INPUT_REQUIRED` 后补充输入）时，在 `message.taskId` 中填写已有任务 ID。

TODO： parts中的metadata确认

**请求（新建任务）：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-uuid-001",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "parts": [
          {
              "text": "这张图片里有什么？"
          },
          {
              "url": "http://xxxx",
              "raw": "iVBORw0KGgoAAAANSUhEUgAA...", //url和raw二选一
              "mimeType": "image/jpeg",
              "filename": "photo.jpg",
              "metadata": {
                  "batch_id": "xxx",
                  "width":"1024",
                  "height":"768",
                  "size":"1024242",
                  "result":{
                     xxx，见下方表格
                  }
                  
              }
          }
       ],
      "metadata": {
          "agentId":"xxxx",
          "headerParam":{
            "product":"xxx",
            "model":"xxx"
          },
          "urlParam":{
            "source":"",