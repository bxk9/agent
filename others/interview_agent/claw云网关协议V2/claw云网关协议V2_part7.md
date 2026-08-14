| opStart | String | 否 | 起始边界运算符：`"gt"`(>)、`"ge"`(>=，默认)、`"lt"`(<)、`"le"`(<=)。field=Long/TimeString 时使用 |
| opEnd | String | 否 | 结束边界运算符：同 opStart。默认 `"le"` |

**field 类型详解**

field = "String"

精确匹配或模糊匹配。条件对象中除保留字段外的所有 key 视为业务字段。

- **matchMode**：不传或传 `"exact"` → 精确匹配（`=`）；传 `"fuzzy"` → 模糊匹配（`LIKE %value%`）
- **ignoreCase**：不传或传 `false` → 大小写敏感；传 `true` → 忽略大小写（`COLLATE NOCASE`）
**示例1：模糊 + 忽略大小写**

```json
{
    "entityType": "commute_record",
    "entityName": "通勤",
    "field": "String",
    "matchMode": "fuzzy",
    "ignoreCase": true
}
```

含义：`entityType LIKE '%commute_record%' COLLATE NOCASE AND entityName LIKE '%通勤%' COLLATE NOCASE`

**示例2：不传 matchMode / ignoreCase（使用默认值：精确 + 大小写敏感）**

```json
{
    "entityType": "commute_record",
    "field": "String"
}
```

含义：`entityType = 'commute_record'`（精确匹配，大小写敏感）

**field = "Long"**

数值范围查询。使用 `{fieldName}Start` / `{fieldName}End` 命名约定。

```json
{
    "field": "Long",
    "createdAtStart": 1700000000000,
    "createdAtEnd": 1900000000000,
    "opStart": "ge",
    "opEnd": "le"
}
```

含义：`createdAt >= 1700000000000 AND createdAt <= 1900000000000`

field = "TimeString"

字符串范围比较（利用 ISO8601 或数字字符串的字典序）。用于存储为字符串的时间字段。

```json
{
    "field": "TimeString",
    "occurredAtStart": "2025-01-01T00:00:00+08:00",
    "occurredAtEnd": "2026-12-31T23:59:59+08:00",
    "opStart": "ge",
    "opEnd": "le"
}
```

含义：`occurredAt >= '2025-01-01T00:00:00+08:00' AND occurredAt <= '2026-12-31T23:59:59+08:00'`（字符串字典序比较）

### 各表可查询字段

[https://docs.vivo.xyz/s/KXgq64vI](https://docs.vivo.xyz/s/KXgq64vI) 邀请您加入文档协作【记忆存储方案设计】 见数据模型

### vector 对象结构

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| query | String | 是 | 查询文本，用于生成向量 embedding |
| topK | Int | 否 | 返回最相似的前 K 条，默认 10 |
| queryField | String | 是 | 向量索引字段名（如 `"summary"`、`"content"`、`"caption"`） |
| minSimilarity | Double | 否 | 最小相似度阈值（0~1），低于此值的结果被过滤，默认 0.0 |

### http响应payload

与 3.1 响应格式完全一致（参见 3.1 http响应payload）。

### websocket请求/响应

与 3.1 完全一致。

### 相比 3.1 的升级点（paramList 内部）

| 升级点 | 3.1 | 3.1.2 V2 |
| --- | --- | --- |
| filter 结构 | entity 条件中混合了 entity 表和 slot 表字段 | 三级分离：memory[] / entity[] / slot[] 分别对应独立表 |
| slot 条件 | 不支持（合并在 entity 条件中） | 独立 slot[] 数组，支持 slotType/slotText/slotTimeMs 等字段 |
| 条件修饰符 | 不支持 | 支持 matchMode(fuzzy/exact)、ignoreCase |
| TimeString 类型 | 不支持 | 支持（memory/entity/slot 三层均可使用字符串范围比较） |
| 分组交集语义 | entity 条件组间逻辑未明确 | entity[] 和 slot[] 各组独立查询后取交集，语义明确 |

## 3.2 云侧下发记忆构建结果（记忆服务端调用）

域名：

预发环境机房：      [blueclaw-infra-pre.vmic.xyz](http://blueclaw-infra-pre.vmic.xyz)

预发环境办公网：   [blueclaw-infra-pre.vivo](http://blueclaw-infra-pre.vivo).lan:8080

http url : /device/proxy

content-type: application/json

### http请求payload

更新：

核心记忆与原子记忆的 payload 格式相同。区别是核心记忆每次必传 deleteMemory，且memoryType为core，source为fusion，outerIds 字段为空，这样端侧每次会先删除全部的（source 为 fusion的）核心记忆，然后再写入。

```json
{
	"msgType": "cloud2client",
	"version": "1.0",
	"packageName": "com.vivo.ai.copilot",
	"timestamp": 1731000001000,
	"sessionId": "cb-9a2b7d1f",
	"traceId": "job-01HQY...",
	"userId": "u-demo-001",
	"vaid": "u-demo-001",
	"body": {
		"method": "storeMemory",
		"bizName": "BlueClaw",
		"params": {
			"payload": [
                {
					"action": "deleteMemory",
					"data": [
						{
							"memoryType": "episodic",
							"source": "chat",
							"outerIds": [
								"ep-01HQX2",
								"ep-01HPZ9"
							]
						},
						{
							"memoryType": "semantic",
							"source": "chat",
							"outerIds": [
								"sem-01HPZ7"
							]
						}
					]
				},
				{
					"action": "upsertMemory",
					"data": [
						{
							"memoryType": "core",
							"source": "human",
							"outerId": "core-01HQY1",
							"label": "兴趣爱好",
							"content": "喜欢摄影和徒步",
							"contentLimit": 5000,
							"extendData": "extend data"
						},
						{
							"memoryType": "episodic",
							"source": "chat",
							"outerId": "ep-01HQY2",
							"occurredAt": "2026-05-09T11:00:00Z",
							"eventType": "user_message",
							"actor": "user",
							"summary": "用户更新周末计划",
							"details": "改为周日出行",
							"labelTree": "生活/兴趣/摄影",
							"extendData": "extend data",
							"entities": [
								{
									"entityType": "commute_time",
									"entityName": "1731000001000",
									"entityDescription": "用户上班打卡时间"
								}
							]
						},
						{
							"memoryType": "semantic",
							"source": "chat",
							"outerId": "sem-01HQY3",
							"name": "徒步装备清单",
							"summary": "用户的徒步装备偏好",
							"details": "登山鞋品牌 X，背包容量 40L",
							"labelTree": "生活/装备",
							"extendData": "extend data",
							"entities": [
								{
									"entityType": "preference",
									"entityName": "winter clothing",
									"entityDescription": "用户服饰购物偏好"
								}
							]
						},
						{
							"memoryType": "procedural",
							"source": "chat",
							"outerId": "proc-01HQY4",
							"entryType": "workflow",
							"summary": "周末摄影出行流程",
							"steps": "[查看天气, 准备器材, 规划路线, 出发]",
							"labelTree": "生活/流程",
							"extendData": "extend data",
							"entities": [
								{
									"entityType": "skill",
									"entityName": "frontend development",
									"entityDescription": "用户擅长前端搜索功能开发"
								}
							]
						},
						{
							"memoryType": "resource",
							"source": "chat",
							"outerId": "res-01HQY5",
							"title": "推荐摄影书单",
							"summary": "入门到进阶的 5 本书",
							"resourceType": "doc",
							"content": "1. 《纽约摄影学院教材》...",
							"labelTree": "生活/学习",
							"extendData": "extend data",
							"entities": [
								{
									"entityType": "resource_tag",
									"entityName": "JavaScript",
									"entityDescription": "代码语言类型"
								}
							]
						},
						{
							"memoryType": "knowledgeVault",
							"source": "chat",
							"outerId": "kv-01HQY6",
							"entryType": "credential",
							"sensitivity": "medium",
							"secretValue": "用户住在北干街道育才北路590号",
							"caption": "用户收货地址",
							"extendData": "extend data",
							"entities": [
								{
									"entityType": "card_id",
									"entityName": "card info",
									"entityDescription": "用户身份证信息"
								}
							]
						}
					]
				}
			]
		}
	}
}
```

### websocket请求（云端请求端侧，传输记忆构建结果）

msg_type="cloud2client"

ack msg_type="cloud2client_ack"

payload和http保持一致

### websocket响应

msg_type="cloud2client"

ack msg_type="cloud2client_ack"

payload和http保持一致

### http响应payload

```json
{
    "code": 0,
    "message": "success",
    "durationMs": 100,
    "msgType": "cloud2client",
    "version": "1.0",
    "packageName": "com.vivo.ai.copilot",
    "timestamp": 1778157212883,
    "sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
    "traceId": "d49e1bfd43f64acd8de7b684be762a0e",
    "userId" : "dsfsfdsfsfsdfsd",
    "vaid": "seed-user-alice",
    "body": {
        "method": "storeMemory",
        "bizName": "BlueClaw",
        "data":{        
          
        }
    }
}
```

## 3.4 websocket协议 （客户端调用）

### 3.4.1 用户快慢记忆检索

msg_type=searchUserMemory

ack msg_type="searchUserMemory_ack"

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
        "method": "searchUserMemory",
        "bizName": "BlueClaw",
        "params": {
          "query": "我喜欢吃什么",
          "mode": "core"
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
        "method": "searchUserMemory",
        "bizName": "BlueClaw",
        "data": {
          "memory": "根据用户的手机使用过程中生产的记忆总结出一个记忆合集，内容如下：\n合集主题：餐饮创业与美食分享\n合集摘要：该合集主要围绕餐饮业创业经验分享、避坑指南以及各类餐厅和美食品牌的介绍。内容涉及B站UP主'勇哥餐饮避坑指南'等创作者发布的餐饮创业分析视频，多家特色餐厅如大疆素食食堂、福气鲜活面包等的经营情况及用户评价，还有特定饮品品牌如霸王茶姬的产品特点介绍。",
      }  
    }
}
```

### 3.4.2 agent记忆检索

msg_type=searchAgentMemory

ack msg_type="searchAgentMemory_ack"

请求payload

```json
{
