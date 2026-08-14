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
        "method": "queryMemory",
        "bizName": "BlueClaw",
        "data":{
          "memoryList": [
            {
                "outerId": "de1803c0-5f94-47f0-97af-73ffeba16d74",
                "userId": "user_de1803c0",
                "memoryType": "EPISODIC",
                "metadata": "metadata",
                "actor": "user",
                "details": "用户有一张火车票，车次号为D2284，座位号为5车3B...",
                "eventType": "AIE火车票订单",
                "labelTree": "[\"个人\",\"AIE火车票订单\"]",
                "occurredAt": "2026-05-12T15:30:00+08:00",
                "source": "com.vivo.xxxx",
                "summary": "用户有一张火车票，车次号为D2284，座位号为5车3B...",
                "entities": [
                    {
                        "entityDescription": "D2284",
                        "entityLabel": "AIE火车票订单",
                        "entityText": "D2284",
                        "entityType": "train_number",
                        "parentMemoryType": "episodic",
                        "source": "com.vivo.xxxx"
                    }
                ]
            }
          ]
        }
    }
}
```

### websocket响应

msg_type="cloud2client"

ack msg_type="cloud2client_ack"

payload和http保持一致

## 3.1.2 记忆反查协议 V2（新版协议）

### http请求payload（结构化filter检索 V2）

以下示例以 `episodic` 类型为例，展示 memory/entity/slot 三层所有可用字段的检索方式：

```json
{
    "msgType": "cloud2client",
    "version": "1.0",
    "packageName": "com.vivo.ai.copilot",
    "timestamp": 1778157212883,
    "sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
    "traceId": "d49e1bfd43f64acd8de7b684be762a0e",
    "userId": "dsfsfdsfsfsdfsd",
    "vaid": "seed-user-alice",
    "body": {
        "method": "queryMemory",
        "bizName": "BlueClaw",
        "params": {
            "paramList": [
                {
                    "memoryType": "episodic",
                    "strategy": "filter",
                    "isEntityRelated": true,
                    "limit": 50,
                    "filter": {
                        "memory": [
                            {                    
                                "labelTree": "personal",                        
                                "field": "String",
                                "matchMode": "fuzzy",
                                "ignoreCase": true
                            },
                            {
                                "field": "Long",
                                "createdAtStart": 1700000000000,
                                "createdAtEnd": 1900000000000,
                                "opStart": "ge",
                                "opEnd": "le"
                            },
                            {
                                "field": "Long",
                                "updatedAtStart": 1700000000000,
                                "updatedAtEnd": 1900000000000,
                                "opStart": "ge",
                                "opEnd": "le"
                            },        
                            {
                                "field": "TimeString",
                                "occurredAtStart": "2025-01-01T00:00:00+08:00",
                                "occurredAtEnd": "2026-12-31T23:59:59+08:00",
                                "opStart": "ge",
                                "opEnd": "le"
                            }
                        ],
                        "entity": [
                            {
                                "entityType": "commute_record",
                                "entityName": "通勤记录",
                                "field": "String",
                                "matchMode": "fuzzy",
                                "ignoreCase": true
                            },
                            {
                                "field": "Long",
                                "createdAtStart": 1700000000000,
                                "createdAtEnd": 1900000000000,
                                "opStart": "ge",
                                "opEnd": "le"
                            },
                            {
                                "field": "Long",
                                "updatedAtStart": 1700000000000,
                                "updatedAtEnd": 1900000000000,
                                "opStart": "ge",
                                "opEnd": "le"
                            }
                        ],
                        "slot": [
                            {
                                "slotType": "commute_action",
                                "slotText": "enter",
                                "field": "String",
                                "matchMode": "fuzzy",
                                "ignoreCase": true
                            },
                            {
                                "field": "Long",
                                "slotTimeMsStart": 1700000000000,
                                "slotTimeMsEnd": 1900000000000,
                                "opStart": "ge",
                                "opEnd": "le"
                            },
                            {
                                "field": "Long",
                                "createdAtStart": 1700000000000,
                                "createdAtEnd": 1900000000000,
                                "opStart": "ge",
                                "opEnd": "le"
                            },
                            {
                                "field": "Long",
                                "updatedAtStart": 1700000000000,
                                "updatedAtEnd": 1900000000000,
                                "opStart": "gt",
                                "opEnd": "lt"
                            },
                            {
                                "field": "TimeString",
                                "slotTextStart": "2025-01-01T00:00:00+08:00",
                                "slotTextEnd": "2026-12-31T23:59:59+08:00",
                                "opStart": "ge",
                                "opEnd": "le"
                            }
                        ]
                    }
                }
            ]
        }
    }
}
```

> **说明**：实际使用时不需要传所有字段，以上仅为展示每个字段的检索方式。每个条件对象内可只包含需要的字段。

### http请求payload（向量vector检索，与 3.1 一致）

```json
{
    "msgType": "cloud2client",
    "version": "1.0",
    "packageName": "com.vivo.ai.copilot",
    "timestamp": 1778157212883,
    "sessionId": "ccf5bbb2-89c9-4cd3-b9c7-7e22e80ec0a7",
    "traceId": "d49e1bfd43f64acd8de7b684be762a0e",
    "userId": "dsfsfdsfsfsdfsd",
    "vaid": "seed-user-alice",
    "body": {
        "method": "queryMemory",
        "bizName": "BlueClaw",
        "params": {
            "paramList": [
                {
                    "memoryType": "episodic",
                    "strategy": "vector",
                    "isEntityRelated": true,
                    "vector": {
                        "topK": 10,
                        "query": "昨天我跟谁一起开会来着",
                        "queryField": "summary",
                        "minSimilarity": 0.8
                    }
                }
            ]
        }
    }
}
```

**paramList[] 元素字段说明**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| memoryType | String | 是 | 记忆类型：`episodic`、`semantic`、`core`、`procedural`、`resource`、`knowledgeVault` |
| strategy | String | 是 | 检索策略：`filter`（结构化）或 `vector`（向量） |
| isEntityRelated | Boolean | 是 | 是否关联实体信息返回。为 true 时结果中包含 entities 字段 |
| limit | Int | 否 | 单query最大返回条数，默认 100 |
| filter | Object | strategy=filter时必填 | 结构化过滤条件，包含三级子条件 |
| vector | Object | strategy=vector时必填 | 向量检索参数（与 3.1 一致） |

### filter 对象结构

filter 包含三个可选数组，分别对应三张表的条件：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| memory | Array<Object> | 记忆表条件。每个对象为一个独立条件，所有条件之间 AND 关系 |
| entity | Array<Object> | 实体表条件。每个对象为一个独立条件组，组间取**交集** |
| slot | Array<Object> | 槽位表条件。每个对象为一个独立条件组，组间取**交集** |

**分组交集逻辑：**

- entity[] 中每个 JSON 对象独立查询 memory_entity 表得到 entityIds，各组取交集
- slot[] 中每个 JSON 对象独立查询 memory_slot 表得到 entityIds，各组取交集
- entity 结果 ∩ slot 结果 → 最终 entityIds → 通过 relation 表得到 memoryIds → 与 memory[] 条件交集
**条件对象通用字段**

每个条件对象中，除业务字段外，以下为保留控制字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| field | String | 是 | 字段值类型：`"String"`、`"Long"`、`"TimeString"` |
| matchMode | String | 否 | 匹配模式：`"exact"`（默认，精确）或 `"fuzzy"`（LIKE %value%）。仅 field=String 时生效 |
| ignoreCase | Boolean | 否 | 是否忽略大小写，默认 false。仅 field=String 时生效 |