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
            "type": "tool_result",
            "content": {
                "id": "tool-use-id",
                "name": "setAlarm",
                "label": "设置闹钟",
                "status": "tool_result",
                "params": "{\"time\":\"21:05\"}",
                "result": { },
                "ok": true,
                "latencyMs": 234
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

**需要用户确认（INPUT_REQUIRED - 二次确认 confirm）：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_INPUT_REQUIRED",
      "message": {
        "messageId": "msg-agent-confirm-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": "即将为您发送邮件，请确认是否继续？" },
          {
            "data": {
              "type": "form",
              "fields": [
                {
                  "name": "sendConfirm",
                  "type": "confirm",
                  "label": "确认发送邮件",
                  "description": "确认后将立即发送邮件给目标收件人。",
                  "confirmLabel": "确认发送",
                  "cancelLabel": "取消",
                  "severity": "info"
                }
              ]
            },
            "mimeType": "application/json"
          }
        ]
      },
      "timestamp": "2026-05-04T10:00:02Z"
    },
    "final": false
  }
}
```

**用户确认后的回复（SendMessage 续传）：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-005",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-user-confirm-001",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "parts": [
        {
          "data": {
            "type": "form",
            "values": {
              "sendConfirm": true
            }
          },
          "mimeType": "application/json"
        }
      ]
    }
  }
}
```

**需要用户选择（INPUT_REQUIRED - 单选 radio）：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_INPUT_REQUIRED",
      "message": {
        "messageId": "msg-agent-radio-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": "请选择您想要的出行方式：" },
          {
            "data": {
              "type": "form",
              "fields": [
                {
                  "name": "travelMode",
                  "type": "radio",
                  "label": "出行方式",
                  "required": true,
                  "options": [
                    { "value": "flight", "label": "飞机（约2小时）" },
                    { "value": "train", "label": "高铁（约5小时）" },
                    { "value": "drive", "label": "自驾（约8小时）" }
                  ]
                }
              ]
            },
            "mimeType": "application/json"
          }
        ]
      },
      "timestamp": "2026-05-04T10:00:02Z"
    },
    "final": false
  }
}
```

**用户单选后的回复：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-006",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-user-radio-001",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "parts": [
        {
          "data": {
            "type": "form",
            "values": {
              "travelMode": "train"
            }
          },
          "mimeType": "application/json"
        }
      ]
    }
  }
}
```

**需要用户多选（INPUT_REQUIRED - checkbox）：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_INPUT_REQUIRED",
      "message": {
        "messageId": "msg-agent-checkbox-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": "请选择报告需要包含的章节（可多选）：" },
          {
            "data": {
              "type": "form",
              "fields": [
                {
                  "name": "chapters",
                  "type": "checkbox",
                  "label": "包含章节",
                  "minSelect": 1,
                  "maxSelect": 4,
                  "options": [
                    { "value": "summary", "label": "执行摘要" },
                    { "value": "trends", "label": "趋势分析" },
                    { "value": "forecast", "label": "预测展望" },
                    { "value": "competition", "label": "竞品对比" }
                  ],
                  "defaultValue": ["summary"]
                }
              ]
            },
            "mimeType": "application/json"
          }
        ]
      },
      "timestamp": "2026-05-04T10:00:02Z"
    },
    "final": false
  }
}
```

**用户多选后的回复：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-007",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-user-checkbox-001",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "parts": [
        {
          "data": {
            "type": "form",
            "values": {
              "chapters": ["summary", "trends", "forecast"]
            }
          },
          "mimeType": "application/json"
        }
      ]
    }
  }
}
```

**需要用户文本输入（INPUT_REQUIRED - text / textarea）：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_INPUT_REQUIRED",
      "message": {
        "messageId": "msg-agent-text-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": "请补充以下信息以继续生成报告：" },
          {
            "data": {
              "type": "form",
              "fields": [
                {
                  "name": "projectName",
                  "type": "text",
                  "label": "项目名称",
                  "placeholder": "请输入项目名称",
                  "required": true,
                  "maxLength": 100
                },
                {
                  "name": "remarks",
                  "type": "textarea",
                  "label": "备注说明",
                  "placeholder": "请输入补充说明（可选）",
                  "required": false,
                  "maxLength": 500
                }
              ]
            },
            "mimeType": "application/json"
          }
        ]
      },
      "timestamp": "2026-05-04T10:00:02Z"
    },
    "final": false
  }
}
```

**用户文本输入后的回复：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-008",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-user-text-001",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "parts": [
        {
          "data": {
            "type": "form",
            "values": {
              "projectName": "Q4 营销活动分析",
              "remarks": "重点关注 ROI 和用户转化率"
            }
          },
          "mimeType": "application/json"
        }
      ]
    }
  }
}
```

**需要用户上传文件（INPUT_REQUIRED - 文件上传）：**

文件上传不使用 form 机制，直接利用 Part 的 `raw`（base64）或 `url`（URI 引用）字段。

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_INPUT_REQUIRED",
      "message": {
        "messageId": "msg-agent-file-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": "请上传需要分析的 CSV 或 Excel 文件" }
        ]
      },
      "timestamp": "2026-05-04T10:00:02Z"
    },
    "final": false
  }
}
```

**用户上传文件回复 — 方式一：base64 内嵌：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-009",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-user-file-001",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "parts": [
        {
          "raw": "UEsDBBQAAAAIAO1YV1kAAA...",
          "url": "http://xxx",
          "mimeType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          "filename": "sales_2024.xlsx"
        }
      ]
    }
  }
}
```

**用户上传文件回复 — 方式二：URL 引用：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-009",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-user-file-001",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "parts": [