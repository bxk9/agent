            "openid":"xxx",
            "deviceId":"xxx"
          },
          "history": [  
              {
                "messageId": "msg-user-001",
                "role": "ROLE_USER",
                "parts": [{ "text": "帮我分析 2024 年的销售数据" }]
              },
              {
                "messageId": "msg-agent-001",
                "role": "ROLE_AGENT",
                "parts": [{ "text": "好的，已完成分析，总销售额同比增长 23%..." }]
              }
          ]
          
      }
    },
    "configuration": { 
      "acceptedOutputModes": ["text/plain", "text/markdown"],
      "historyLength": 10
    }
    
  }
}
```

| 字段名 | 描述 |  |
| --- | --- | --- |
| role | ROLE_USER、ROLE_AGENT |  |
| url | 文件url |  |
| raw | base64编码的文件内容，和url字段二选一 |  |
| mimeType | image/jpeg、ppt... |  |
| metadata样例(文件类型) | {<br>    "batch_id": "5e6809fb-f8e4-4660-8d77-e71440aef394",<br>    "result": {<br>        "user_id": "9e78c9985dd7e9b6",<br>        "window_id": "claw_v",<br>        "batch_id": "5e6809fb-f8e4-4660-8d77-e71440aef394",<br>        "dialog_id": "0b0c5c0c-77c5-4a43-9a91-fc213dd947d6",<br>        "app_id": "6776289947",<br>        "device_type": "foldable",<br>        "batch_category": "picture",<br>        "batch_preprocess_status": "done",<br>        "related_intentions": null,<br>        "files": [<br>            {<br>                "file_id": "30ec6b40-5988-4551-9d9c-69013719c06a",<br>                "file_url": "http://chilong-prd-bj.vivo.lan/xiaov-pre/d49f7368-709d-4807-afd2-fd8babb4e2b5.jpg?Signature=m3bGtua%2BhLusDHNMbwq9QJttm7Y%3D&Expires=1810709341&KSSAccessKeyId=F1NcWrVEqd1WdbiqiKBc",<br>                "file_category": "picture",<br>                "file_external_url": "https://chilong-prd-bj.vivo.com.cn/xiaov-pre/d49f7368-709d-4807-afd2-fd8babb4e2b5.jpg?Signature=m3bGtua%2BhLusDHNMbwq9QJttm7Y%3D&Expires=1810709341&KSSAccessKeyId=F1NcWrVEqd1WdbiqiKBc",<br>                "file_compressed_url": "http://chilong-prd-bj.vivo.lan/xiaov-pre/d49f7368-709d-4807-afd2-fd8babb4e2b5.jpg@base@tag=imgScale&m=0&h=2400?Signature=m3bGtua%2BhLusDHNMbwq9QJttm7Y%3D&Expires=1810709341&KSSAccessKeyId=F1NcWrVEqd1WdbiqiKBc",<br>                "file_size": 4074,<br>                "file_path": null,<br>                "file_relative_path": null,<br>                "file_type": "image/jpeg",<br>                "file_name": "image_1779173339356_0.jpg",<br>                "file_tag": "泰迪熊,人,键盘,桌子,墙壁,纸盒,背景",<br>                "file_summary": " 这张照片展示了一只黄色的卡通玩偶，玩偶有大大的眼睛和黄色的鸭嘴，被一只手拿着。背景中可以看到一个黑色的键盘，键盘上方摆放着多个小玩具，包括红色、粉色、橙色、蓝色和紫色的卡通角色，以及三个黄色的小兔子玩偶。这些玩偶都摆放在一个白色的平面上，背景中还有一些电线和插座。照片的左下角显示了拍摄设备信息：vivo X Fold3 \| ZEISS，拍摄时间为2026年4月29日9点04分。",<br>                "file_content_class": "商品",<br>                "file_content_subclasses": [<br>                    {<br>                        "key": "商品兜底",<br>                        "value": null,<br>                        "confidence": 100,<br>                        "provider": {<br>                            "id": "preclass",<br>                            "name": "vivo",<br>                            "type": "image_subject"<br>                        },<br>                        "type": "image_subject"<br>                    }<br>                ],<br>                "file_review_result": null,<br>                "file_preprocess_status": "done",<br>                "source": "default",<br>                "extra": null,<br>                "picture_analysis_extra": {<br>                    "picture_ner_list": [<br><br>                    ],<br>                    "picture_ocr_text": "vivoXFold3 IZEISS\n2026.04.29 09:04",<br>                    "picture_card_classify": "others",<br>                    "face_detect_number": 0,<br>                    "picture_width": 3072,<br>                    "picture_height": 4080,<br>                    "picture_compressed_width": 1807,<br>                    "picture_compressed_height": 2400<br>                },<br>                "create_time": 1779173339,<br>                "upload_time": 1779162635.6797912<br>            }<br>        ]<br>    }<br>} |  |

**响应（Task 创建成功，进入 SUBMITTED）：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "result": {
    "task": {
      "id": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "status": {
        "state": "TASK_STATE_SUBMITTED",
        "message": {
            "messageId": "msg-agent-progress-001",
            "role": "ROLE_AGENT",
            "parts": [
              { "text": "正在读取并解析销售数据，请稍候..." }
            ]
        },
        "timestamp": "2026-05-04T10:00:00Z"
      },
    }
  }
}
```

**请求（继续任务 — INPUT_REQUIRED 后补充输入）：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-002",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-uuid-002",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "parts": [
        { "text": "确认，请继续" }
      ]
    },
    "configuration": {
      "acceptedOutputModes": ["text/plain", "text/markdown"]
    }
  }
}
```

**响应（任务重回 WORKING）：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-002",
  "result": {
    "task": {
      "id": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "status": {
        "state": "TASK_STATE_WORKING",
        "timestamp": "2026-05-04T10:01:00Z"
      },
      "artifacts": []
    }
  }
}
```

**SendMessage params 字段说明：**

| 字段 | 类型 | 必须 | 说明 |
| --- | --- | --- | --- |
| message | Message | 是 | 本次发送的消息对象（结构参考 4.1） |
| configuration.acceptedOutputModes | string[] | 否 | 客户端可接受的输出 MIME 类型 |
| configuration.historyLength | integer | 否 | 响应中携带的历史消息最大条数 |

**任务创建/续传规则：**

- 有 `message.taskId` → 续传已有任务（INPUT_REQUIRED / AUTH_REQUIRED 流程）
- 无 `message.taskId`，有 `message.contextId` → 在同一会话下新建任务
- 两者都没有 → 全新的独立任务
### 5.2 `GetTask`（C→S）

查询指定任务的当前状态。

**请求：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-003",
  "method": "GetTask",
  "params": {
    "id": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "historyLength": 5
  }
}
```

**响应：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-003",
  "result": {
    "task": {
      "id": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "status": {
        "state": "TASK_STATE_WORKING",
        "message": {
          "messageId": "msg-agent-001",
          "role": "ROLE_AGENT",
          "parts": [{ "text": "正在生成报告..." }]
        },
        "timestamp": "2026-05-04T10:00:05Z"
      },
      "artifacts": []
    }
  }
}
```

### 5.3 `CancelTask`（C→S）

取消指定任务。

**请求：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-004",
  "method": "CancelTask",
  "params": {
    "id": "task-363422be-b0f9-4692-a24d-278670e7c7f1"
  }
}
```

**响应（取消成功）：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-004",
  "result": {
    "task": {
      "id": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "status": {
        "state": "TASK_STATE_CANCELED",
        "message": {
          "messageId": "msg-agent-cancel-001",
          "role": "ROLE_AGENT",
          "parts": [{ "text": "任务已取消。" }]
        },
        "timestamp": "2026-05-04T10:01:00Z"
      },
      "artifacts": []
    }
  }
}
```

**响应（任务不可取消 — 已是终态）：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-004",
  "error": {
    "code": -32002,
    "message": "Task not cancelable",
    "data": {
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "currentState": "TASK_STATE_COMPLETED"
    }
  }
}
```

### 5.4 `task/statusUpdate`（S→C Notification）

服务端向客户端推送任务状态变更。这是 JSON-RPC Notification（无 `id` 字段）。

**WORKING 状态推送--文本：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_WORKING",
      "message": {
        "messageId": "msg-agent-progress-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": "正在搜索相关信息..." }
        ]
      },
      "timestamp": "2026-05-04T10:00:01Z"
    },
    "final": false
  }
}
```

**WORKING 状态推送--工具调用：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_WORKING",
      "message": {
        "messageId": "msg-agent-progress-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": ""vClaw正在执行工具..." },
          {"data":{
            "type": "tool_use",
            "content": {
                "id": "tool-use-id",
                "name": "setAlarm",
                "label": "设置闹钟",
                "status": "tool_waiting",
                "params": "{\"time\":\"21:05\"}"
            }
          }}
        ]
      },
      "timestamp": "2026-05-04T10:00:01Z"
    },
    "final": false
  }
}
```

**WORKING 状态推送--工具调用结果：**

```json
{
  "jsonrpc": "2.0",