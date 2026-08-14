        { "text": "这是上个月的销售数据" },
        {
          "url": "http://xxxxx",
          "mimeType": "text/csv",
          "filename": "report_data.csv"
        }
      ]
    }
  }
}
```

**混合表单（INPUT_REQUIRED - 一次下发多种交互类型）：**

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
        "messageId": "msg-agent-mixed-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": "请完成以下配置后开始生成报告：" },
          {
            "data": {
              "type": "form",
              "title": "报告生成配置",
              "description": "请填写以下信息，预计生成耗时 3-5 分钟",
              "fields": [
                {
                  "name": "dateRange",
                  "type": "radio",
                  "label": "数据时间范围",
                  "required": true,
                  "options": [
                    { "value": "2024-q1q4", "label": "2024 Q1-Q4" },
                    { "value": "2025-full", "label": "2025 全年" },
                    { "value": "custom", "label": "自定义范围" }
                  ]
                },
                {
                  "name": "chapters",
                  "type": "checkbox",
                  "label": "包含章节",
                  "minSelect": 1,
                  "options": [
                    { "value": "summary", "label": "执行摘要" },
                    { "value": "trends", "label": "趋势分析" },
                    { "value": "forecast", "label": "预测展望" }
                  ]
                },
                {
                  "name": "title",
                  "type": "text",
                  "label": "报告标题",
                  "placeholder": "输入自定义标题（可选）",
                  "required": false,
                  "maxLength": 200
                },
                {
                  "name": "confirmGenerate",
                  "type": "confirm",
                  "label": "确认生成",
                  "description": "生成后将消耗 1 次高级报告配额",
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

**混合表单用户回复：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-010",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-user-mixed-001",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "parts": [
        {
          "data": {
            "type": "form",
            "values": {
              "dateRange": "2024-q1q4",
              "chapters": ["summary", "trends", "forecast"],
              "title": "2024年度销售分析报告",
              "confirmGenerate": true
            }
          },
          "mimeType": "application/json"
        }
      ]
    }
  }
}
```

**INPUT_REQUIRED 交互类型协议规范：**

所有交互请求统一使用 `DataPart` 下发，`data.type = "form"` 为固定标识，通过 `fields[].type` 区分具体交互控件类型。客户端回复同样使用 `data.type = "form"`，通过 `data.values` 返回用户填写的值。

统一结构约定：

- 服务端下发：`data.type = "form"` + `data.fields = [...]`
- 客户端回复：`data.type = "form"` + `data.values = { fieldName: value }`
- 每个 field 必须包含 `name`（字段标识）和 `type`（控件类型）
- 支持的 field type：`radio` | `checkbox` | `select` | `confirm` | `text` | `textarea`
- 文件上传不使用 form，直接用 Part 的 `raw` / `url` 字段
**Field Type 速查表：**

| type | 用途 | values 中的值类型 | 特有属性 |
| --- | --- | --- | --- |
| `radio` | 单选 | `string` | options, defaultValue |
| `select` | 下拉单选 | `string` | options, defaultValue |
| `checkbox` | 多选 | `string[]` | options, minSelect, maxSelect, defaultValue |
| `confirm` | 二次确认 | `boolean` | description, confirmLabel, cancelLabel, severity |
| `text` | 单行文本 | `string` | placeholder, maxLength, pattern |
| `textarea` | 多行文本 | `string` | placeholder, maxLength |

**实现建议：**

- 客户端应根据 `fields[].type` 渲染对应的 UI 控件
- `required: true` 的字段必须填写，否则客户端应阻止提交
- 不识别的 field type 建议降级为纯文本输入（`text`）
- `confirm` 类型的 `severity` 决定弹框样式：`info`（蓝色）/ `warning`（黄色）/ `error`（红色）
**需要用户授权（AUTH_REQUIRED）：**

当 Agent 执行过程中需要访问第三方服务（如 OAuth 授权），通过 `TASK_STATE_AUTH_REQUIRED` 中断任务，等待客户端完成授权后回传凭证。

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_AUTH_REQUIRED",
      "message": {
        "messageId": "msg-agent-auth-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": "需要访问 Google Sheets，请授权后继续。" },
          {
            "data": {
              "type": "auth-request",
              "authScheme": "oauth2",
              "authorizationUrl": "https://accounts.google.com/o/oauth2/auth?client_id=...&scope=spreadsheets.readonly",
              "scopes": ["https://www.googleapis.com/auth/spreadsheets.readonly"]
            },
            "mimeType": "application/json"
          }
        ]
      },
      "timestamp": "2026-05-04T10:00:05Z"
    },
    "final": false
  }
}
```

**AUTH_REQUIRED data 字段说明：**

| 字段 | 类型 | 必须 | 说明 |
| --- | --- | --- | --- |
| type | string | 是 | 固定值 `"auth-request"`，标识授权请求 |
| authScheme | string | 是 | 授权方案类型，如 `"oauth2"`、`"bearer"`、`"apiKey"` |
| authorizationUrl | string | 否 | OAuth 授权页 URL（authScheme 为 oauth2 时必填） |
| scopes | string[] | 否 | 请求的权限范围列表 |

**用户完成授权后的回复：**

```json
{
  "jsonrpc": "2.0",
  "id": "req-011",
  "method": "SendMessage",
  "params": {
    "message": {
      "messageId": "msg-user-auth-001",
      "role": "ROLE_USER",
      "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
      "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
      "parts": [
        {
          "data": {
            "type": "auth-response",
            "authScheme": "oauth2",
            "token": "ya29.a0AfH6SMBxxx..."
          },
          "mimeType": "application/json"
        }
      ]
    }
  }
}
```

**auth-response data 字段说明：**

| 字段 | 类型 | 必须 | 说明 |
| --- | --- | --- | --- |
| type | string | 是 | 固定值 `"auth-response"`，标识授权回复 |
| authScheme | string | 是 | 与请求中的 authScheme 一致 |
| token | string | 是 | 授权凭证（如 OAuth access_token） |

**任务完成（COMPLETED）：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_COMPLETED",
      "message": {
        "messageId": "msg-agent-done-001",
        "role": "ROLE_AGENT",
        "parts": [{ "text": "任务已完成。" }]
      },
      "timestamp": "2026-05-04T10:00:10Z"
    },
    "final": true
  }
}
```

**任务失败（FAILED）：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/statusUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "status": {
      "state": "TASK_STATE_FAILED",
      "message": {
        "messageId": "msg-agent-err-001",
        "role": "ROLE_AGENT",
        "parts": [
          { "text": "任务执行失败：无法解析上传文件的格式。" },
          {
            "data": {
              "errorCode": "FILE_PARSE_ERROR",
              "details": "Unexpected token at line 45, column 8"
            },
            "mimeType": "application/json"
          }
        ]
      },
      "timestamp": "2026-05-04T10:05:00Z"
    },
    "final": true
  }
}
```

**task/statusUpdate params 字段说明：**

| 字段 | 类型 | 必须 | 说明 |
| --- | --- | --- | --- |
| taskId | string | 是 | 任务 ID |
| contextId | string | 是 | 对话上下文 ID |
| status | TaskStatus | 是 | 当前状态 |
| status.state | string | 是 | 任务状态枚举值 |
| status.message | Message | 否 | 当前状态附带的单条消息 |
| status.timestamp | string | 是 | ISO 8601 时间戳 |
| final | boolean | 是 | `true` 表示终态（COMPLETED/FAILED/CANCELED/REJECTED），客户端可清理任务 |

### 5.5 `task/artifactUpdate`（S→C Notification）

服务端向客户端推送任务产物。这是 JSON-RPC Notification（无 `id` 字段）。

**流式文本（中间帧）：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/artifactUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "artifact": {
      "artifactId": "artifact-article-001",
      "name": "spring_article.md",
      "parts": [
        { "text": "春天是万物复苏的季节，大地重新焕发生机..." }
      ]
    },
    "append": true,
    "lastChunk": false
  }
}
```

**最后一个 chunk：**

```json
{
  "jsonrpc": "2.0",
  "method": "task/artifactUpdate",
  "params": {
    "taskId": "task-363422be-b0f9-4692-a24d-278670e7c7f1",
    "contextId": "ctx-05217e44-7e9f-473e-ab4f-2c2dde50a2b1",
    "artifact": {
      "artifactId": "artifact-article-001",
      "name": "spring_article.md",
      "parts": [