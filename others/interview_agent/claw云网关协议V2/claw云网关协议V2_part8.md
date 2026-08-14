    "version": "1.0",
    "packageName": "com.vivo.ai.copilot",
    "timestamp": 1778157212883,
    "sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
    "traceId": "d49e1bfd43f64acd8de7b684be762a0e",
    "userId" : "test-user-cxl",
    "vaid": "seed-user-alice",
    "body": {
        "method": "searchAgentMemory",
        "bizName": "BlueClaw",
        "params": {
          "agentId": "default"
        }
            
    }
    
}
```

响应payload

```json

{
    "code": 0,
    "message": "success",
    "durationMs": 100,
    "version": "1.0",
    "packageName": "com.vivo.ai.copilot",
    "timestamp": 1778157212883,
    "sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
    "traceId": "d49e1bfd43f64acd8de7b684be762a0e",
    "userId" : "dsfsfdsfsfsdfsd",
    "vaid": "seed-user-alice",
    "body": {
        "method": "searchAgentMemory",
        "bizName": "BlueClaw",
        "data": {
            "userMemory": "Alice是一名28岁的前端工程师，居住在深圳南山区。",
            "soulMemory": "与Alice对话时，使用简洁直接的技术风格",
            "userVersion": 2,
            "soulVersion": 2
        }
    }
}

```

### 3.4.3 `addMessage`

msg_type=`addMessage`

ack msg_type=`addMessage_ack`

构建服务端预发环境url：http://[ai-memory-builder-pre.vivo](http://ai-memory-builder-pre.vivo).lan:8080/memory/add_message/v1

请求payload

```json
{
    "version": "1.0",
    "packageName": "com.vivo.ai.copilot",
    "timestamp": 1778157212883,
    "sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
    "traceId": "d49e1bfd43f64acd8de7b684be762a0e",
    "userId" : "dsfsfdsfsfsdfsd",
    "vaid": "seed-user-alice",
    "body": {
        "method": "addMessage",
        "bizName": "BlueClaw",
        "params": {
          "chatSessionId": "chat-session-id",
          "source": "小v记忆_随心记_吃药打卡",
          "agentId": "string（可选）— 设备端 AI Bot 标识符；缺失或为空时默认为 \"default\""
          "messages": [
            {
              "role": "user", 
              "type": "text", // 🆕 "text" | "image"; 不传时,默认 text
              "content": "string", 
              "fileContent": {     // 🆕                     
                "url": "http://...",    
                "mimeType": "image/jpeg",
                "data": ""
              }
              "chatTime": "2026-05-12T15:30:00+08:00"
            },
            {
              "role": "assistant", 
              "type": "text", // 🆕 "text" | "image"; 不传时,默认 text
              "content": "string", 
              "fileContent": {      // 🆕                    
                "url": "http://...",    
                "mimeType": "image/jpeg",
                "data":""
              }
              "chatTime": "2026-05-12T15:30:00+08:00" 
            }
          ]
        }
    }
}
```

响应payload

```json

{
    "code": 0,
    "message": "success",
    "durationMs": 100,
    "version": "1.0",
    "packageName": "com.vivo.ai.copilot",
    "timestamp": 1778157212883,
    "sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
    "traceId": "d49e1bfd43f64acd8de7b684be762a0e",
    "userId" : "dsfsfdsfsfsdfsd",
    "vaid": "seed-user-alice",
    "body": {
        "method": "addMessage",
        "bizName": "BlueClaw",
        "data": {
            "messageId": "string — chat_message 行标识符",
            "status": "saved",
            "jobTriggered": true,
            "startMemoryJobId": "string|null — start_memory_job 标识符（仅在 job_triggered=true 时存在）",
            "userMemoryJobId": "string|null — user_memory_job 标识符（仅在 job_triggered=true 时存在）"
        }
    }
}

```

### 3.4.4  `bizChannelReady（AIE主动触发）`

msg_type=`bizChannelReady`

ack msg_type=`bizChannelReady_ack`

构建服务端预发环境url：http://[ai-memory-builder-pre.vivo](http://ai-memory-builder-pre.vivo).lan:8080/jobs/retry-delivery

请求payload

```json
{

    "version": "1.0",
    "packageName": "com.vivo.ai.copilot",
    "timestamp": 1778157212883,
    "sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
    "traceId": "d49e1bfd43f64acd8de7b684be762a0e",
    "userId" : "dsfsfdsfsfsdfsd",
    "vaid": "seed-user-alice",
    "body": {
        "method": "bizChannelReady",
        "bizName": "BlueClaw",
        "params": {
          "clientId": "string（可选）"
        }
            
    }
    
}
```

响应payload

msg_type=`bizChannelReady`

ack msg_type=`bizChannelReady_ack`

```json

{
    "code": 0,
    "message": "success",
    "durationMs": 100,
    "version": "1.0",
    "packageName": "com.vivo.ai.copilot",
    "timestamp": 1778157212883,
    "sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
    "traceId": "d49e1bfd43f64acd8de7b684be762a0e",
    "userId" : "dsfsfdsfsfsdfsd",
    "vaid": "seed-user-alice",
    "body": {
        "method": "bizChannelReady",
        "bizName": "BlueClaw",
        "data": null
    }
}

```

### 3.4.5 `profileExtract`

msg_type=`profileExtract`

ack msg_type=`profileExtract_ack`

构建服务端预发环境url：http://[ai-memory-builder-pre.vivo](http://ai-memory-builder-pre.vivo).lan:8080/profile/extract/v1

请求payload

```json
{
	"version": "1.0",
	"packageName": "com.vivo.ai.copilot",
	"timestamp": 1778157212883,
	"sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
	"traceId": "d49e1bfd43f64acd8de7b684be762a0e",
	"userId": "dsfsfdsfsfsdfsd",
	"vaid": "seed-user-alice",
	"body": {
		"method": "profileExtract",
		"bizName": "BlueClaw",
		"params": {
			"core_memory": [
				{
					"outerId": "d4169c04-5cb3-4c3d-9aac-038b5b844ea7",
					"source": "fusion",
					"label": "个人基础信息_基础信息",
					"content": "用户是一名AI技术开发人员，专注于记忆存储与AI辅助技术的开发与应用。",
					"contentLimit": 50,
					"extendData": "{\"label_tree\":[\"个人基础信息\", \"基础信息\"]}"
				},
				{
					"outerId": "d4169c04-5cb3-4c3d-9aac-038b5b844ea7",
					"source": "human",
					"label": "个人基础信息_基础信息",
					"content": "用户叫陈晓龙，是一名AI技术开发人员，专注于记忆存储与AI辅助技术的开发与应用。喜欢玩《赛博朋克2077》",
					"contentLimit": 5000,
					"extendData": "{}"
				}
			],
			"episodic_memory": [
				{
					"outerId": "d4169c04-5cb3-4c3d-9aac-038b5b844ea8",
					"occurredAt": "2026-05-09T11:00:00",
					"eventType": "user_activity",
					"actor": "user",
					"summary": "用户在拼多多浏览贵人鸟冬季新款羽绒服",
					"details": "用户在拼多多应用中浏览贵人鸟品牌的冬季新款羽绒服商品页面。该商品为男女孩子中儿童款式...",
					"labelTree": "[个人 , 购物 , 服装]",
					"source": "xxx",
					"extendData": "{}"
				}
			]
		}
	}
}
```

首次响应payload，告知端侧发起成功，不返回最终构建的记忆结果

```json
{
	"code": 0,
	"message": "success",
	"durationMs": 100,
	"version": "1.0",
	"packageName": "com.vivo.ai.copilot",
	"timestamp": 1778157212883,
	"sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
	"traceId": "d49e1bfd43f64acd8de7b684be762a0e",
	"userId": "dsfsfdsfsfsdfsd",
	"vaid": "seed-user-alice",
	"body": {
		"method": "storeMemory",
		"bizName": "BlueClaw",
		"data": null
	}
}
```

# 4、其他http协议

## 鉴权方式

所有 HTTP 接口（非 WebSocket）均需在请求 Header 中携带鉴权信息，网关通过 vivo token 服务校验身份。

---

请求 Header

| Header 名称 | 必填 | 说明 |
| --- | --- | --- |
| X-Vivo-Token | 是 | vivo 登录 token，用于身份校验 |
| X-Vivo-UserId | 是 | 用户openid（与 WebSocket 连接 URL 中的 userid 一致） |