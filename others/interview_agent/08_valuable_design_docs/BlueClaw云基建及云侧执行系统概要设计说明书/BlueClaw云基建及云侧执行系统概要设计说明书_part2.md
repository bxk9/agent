Backend: 查 online_devices["xxx"]["bbb"] → session_id="x2", ws_conn=conn1
    ↓
Backend: 通过 conn1 下发 DataPackage(header.session_id="x2", msg_type="memory_query")
    ↓
网关: 按 session_id 透传到对应客户端
    ↓
客户端: 收到请求，处理后原路返回响应
```

#### 3.1.2.4 代理转发

网关作为透传代理，根据 **环境** 和 **业务标识参数** 将客户端 WebSocket 连接路由到对应的 backend 连接池。

```plaintext
客户端连接: ws://gateway:9999/blueclaw/core?biz_code=xxx&userid=x&appid=x&vaid=x&test=xxx
                                                                        ↑
                                                                   分流参数(仅非prd)
```

| 环境 | 路由逻辑 |
| --- | --- |
| dev/test/pre | 如果客户端 URL 带 `test=xxx`，走对应 pipeline；否则走 `common` |
| prd | 忽略 test 参数，强制走 `common` pipeline |

#### 3.1.2.5 模型服务  @刘大成

// TODO： 审核策略详细梳理

// TODO： 端上脚本/高危工具干预能力

  **1）审核干预（策略复用小V现有能力）**

  审核干预模块负责对用户的输入（输入审核）和上屏内容（输出审核）进行审核。

  1.输入审核：对用户的输入（不含prompt和系统上下文）利用审核平台能力进行审核，如果审核通过则进行正常的模型和工具调用，如果审核失败则获取上屏数据并调用小v中控的后处理接口获取拒答ui协议数据（封装拒答话术）。

  2.输出审核：

  1）大模型或工具输出的流式文本在jovi-backed服务进行审核，审核通过放行；审核不通过先获取拒答话术数据，然后调用小v中控的后处理接口进行ui数据封装，小v中控后处理接口返回封装后的上屏ui协议数据和清屏ui协议数据。

  2）图片审核通过http接口调用小v中控 ，正常情况（未完全过滤）小v中控直接返回list列表，不包含上屏UI协议；异常情况（全部过滤）小v中控返回封装后的上屏ui协议数据（封装拒答话术）。

  3）引用审核通过http接口调用小v中控，正常情况（未完全过滤）小v中控直接返回list列表，不包含上屏UI协议；异常情况（全部过滤）小v中控返回封装后的上屏ui协议数据（封装拒答话术）。

  **2）模型调用**

  模型调用请求基于玄机封装的用量统计计费接口，具体计费策略后面有说明。

![审核方案泳道图.drawio.png](http://veditor.vivo.xyz/api/v1/attachment/file/zic8r7x3FwVsLsJmXw9Spjc1VoexBhEspeVa5vmDfUi35op1zUxnhgzD82jGW_dw "审核方案泳道图.drawio.png")

  接口文档：[https://docs.vivo.xyz/detail/editor/120114253736](https://docs.vivo.xyz/detail/editor/120114253736)

  2）模型路由  @汤文浩

  见：[https://docs.vivo.xyz/s/tQwHKrDN](https://docs.vivo.xyz/s/tQwHKrDN) 邀请您加入文档协作【智能路由】

  3）模型计费  @王玕一

    **见：第4章**

#### 3.1.2.6 端云反查

反查整体链路图

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/0tDDcU0K3IPfYFYmFCiLDI7LvtgAZXU1EVBk5pkGzWbduu0wlPptfRlYOLuGlh8o "image.png")

##### 接口协议：

[https://docs.vivo.xyz/s/PLOpnmIm](https://docs.vivo.xyz/s/PLOpnmIm) 邀请您加入文档协作【记忆反查http接口协议】

##### 清理机制

| 场景 | 清理动作 |
| --- | --- |
| WebSocket 正常/异常断开 | 删除本地映射 + 删除 Redis key |
| Redis key TTL 到期 | 自动过期（兜底防僵尸） |
| 转发目标实例无响应 | 清除该 Redis key |
| 每次收到客户端消息 | 刷新 Redis TTL（被动续期） |

#### 3.1.4  workspace&云沙箱 @周健-AI技术开发二部

[https://docs.vivo.xyz/s/1MCnj1ru](https://docs.vivo.xyz/s/1MCnj1ru) 邀请您加入文档协作【Workspace 软件设计文档】

![4.svg](http://veditor.vivo.xyz/api/v1/attachment/file/8Bhg2CRo_s86FrALIYstRCZuT6G15jVEQECZyVJhYwL8ukO7TXbBW2gtgAS1CnPh "4.svg")

## 3.2 云侧执行子系统   @孙建蛟

[https://docs.vivo.xyz/s/8puarm39](https://docs.vivo.xyz/s/8puarm39) 邀请您加入文档协作【小v 中控3.0&Pro模式融合执行子系统】

#### 3.2.1 调用整体链路

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/GAGgB6dns2kj1qCRS7n8pHWBz3XvYXFS8s10o0A4fn_9hMu64_Jh5gX3cfh0gB5O "image.png")

1. **内置工具**：屏蔽调用差异，保证端/云共享同一份 Skill

2. **标准协议**： tool通过mcp调用(兼容开源生态), agent通过A2A协议调用

#### 3.2.2 云侧工具

**调用流程：**

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/da3qYhHu0acB_uKWuk93zjx0ARqMOz0JLb_hoewMSHeF4irQGOBzeiqM8RQxu9xE "image.png")

**上线流程：**

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/rSBjcSy5cuqcISAzs9TPX6iIRJzFTITsnhQuOdNhx-XNafCfeJ6SDAkzfohwqASt "image.png")

**工具范围：**

| 问答搜索 | 手机问答、联网索索 |
| --- | --- |
| 天气 | 天气查询 |
| 出行 | 路线规划、地点曹锁 |
| 办公 | 文档问答、文档总结 |
| 图像处理 | 图像生成、图片编辑(证件照、去除手写能力支持)、图片理解 |
| 图片问答 | 解题、搜题、搜同款 |
| 自检工具 | tool搜索工具、skill搜索工具、代码/脚本执行工具等 |

#### 3.2.3 云侧Agent

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/_hDgVDDzYib8cOHx5qMm6MdnrsCoq4N_wKIO-67CJpplSZlq0r4MTDMys8w0e5Jv "image.png")

#### 3.2.4 Skill设计

**skill规范：**

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/8iOim0DqBJxxgyngRXPlZ3xBagTDdBf5YieV6Aea7IJr4zSqUo42lrPpq4aAG-yx "image.png")

- skill name命名规范：中横线分隔，使用 `kebab-case` 1-3 个词最佳， 仅允许 `[a-zA-Z0-9_]`
- too name命名规范：下划线分隔，使用 `snake_case`，仅允许 `[a-zA-Z0-9_]`；多服务/多来源场景：`{namespace}_{verb}_{resource}`；自建tool: {verb}_{resource}
**平台无关skill执行架构：**

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/lNCd3WKoCJ7XyIbpHD0wTzKRxzuZOx0K0DrLe8BgJYW3LMAnDdK4N6iD8TXDVcMT "image.png")

**Skill设计原则**

> **1. 遵守 Skill 的定义：按需加载**
> 
> Skill 的完整内容不是常驻的，但 Skill 的 description 会长期参与匹配。所以 description 写得好不好，直接决定 Skill 会不会被正确触发。
> 
> 如果你有很多 Skill，或者某个 Skill 本身很长并且不常用，可以在 Skill 里设置 disable关闭自动加载，降级为手动开启或者skill召回。
> 
> disable 的核心意义不只是防止误触发，更重要的是节省 context。
> 
> **2. 限制 Skill 的工具边界**
> 
> Skill 可以限制允许使用哪些工具。这不是必须的，但很有用。因为不同 Skill 需要的权限不同。
> 
> 例如：如果是封面图生成，可能需要读参考资料、写出 prompt，再调用图片工具：
> 
> allowed-tools:
> 
>   - Read
> 
>   - Write
> 
>   - ImageGenerate
> 
> **3. 给 Skill 配置最适合的模型**
> 
> 有些模型更强，但更贵。有些模型便宜，但足够完成简单任务。一个成熟的 Skill 系统，不应该所有任务都默认用同一个模型。它应该根据任务类型选择合适的执行模型。
> 
> **4. 渐进式披露，限制 **[**Skill.md**](http://Skill.md)** 的大小**
> 
> [SKILL.md](http://SKILL.md) 最好少于 500 行，如果 Skill 太长优先考虑三件事：
> 
> 1）.长说明移到 references/
> 
> 2）.稳定操作写成 scripts/
> 
> 3）.模板和样例放到 assets/
> 
> **5. 写完 Skill 之后还需要验证、打分、迭代**
> 
> 建议做3类验证：
> 
> 1）能不能跑
> 
> 2）能不能正确触发
> 
> 3）跑出来的结果，是否真的比不用 Skill 更好

**什么是好的SKill**

> 1.能被正确触发。
> 
> 2.不该触发时保持安静。
> 
> 3.工具权限足够但不过度。
> 
> 4.模型选择符合任务成本和难度。
> 
> 5. [SKILL.md](http://SKILL.md) 足够短，资料按需展开。
> 
> 6. 重要 Skill 最好有 test data、有 eval、有失败案例、有迭代。

#### 3.2.5 异步任务执行  @周健-AI技术开发二部

![mermaid-diagram (2).svg](http://veditor.vivo.xyz/api/v1/attachment/file/iX7Z7ePbX7gBQVtbOjKx-nxEFNXbR84RWdPJDcLmTwYhoPkmui6pxyvxR5UQSDsz "mermaid-diagram (2).svg")

[https://docs.vivo.xyz/s/emf2MIbo](https://docs.vivo.xyz/s/emf2MIbo) 邀请您加入文档协作【异步任务执行管理 — 软件设计文档】

## 3.3 基础能力 — 可观测\度量平台  @周健-AI技术开发二部

![9.svg](http://veditor.vivo.xyz/api/v1/attachment/file/TqCHQcQ02Nc9o0SIX3oTq-7Kj4wKfLIFr__h35IAgiQ4k5vixWxM9UlqHMP0wr__ "9.svg")

[https://docs.vivo.xyz/s/uJHJmhdx](https://docs.vivo.xyz/s/uJHJmhdx) 邀请您加入文档协作【蓝龙虾效率平台设计方案】

# 4.模型用量统计

## 4.1.模型封装

vivoClaw Server 以 **OpenAI 兼容协议**作为统一接入标准，对客户端屏蔽上游模型供应商的差异，实现"一套 API 接入所有模型"。

[https://docs.vivo.xyz/s/bVur3k4g](https://docs.vivo.xyz/s/bVur3k4g) 邀请您加入文档协作【玄机模型相关信息】

#### 当前接入模型矩阵

| 模型 | 供应商 | 定位 | 170:1 场景成本（元/百万token） |
| --- | --- | --- | --- |
| Doubao-Seed-2.0-mini | volcengine | 轻量经济 | 0.21 |
| Doubao-Seed-2.0-lite | volcengine | 均衡 | 0.62 |
| Volc-DeepSeek-V3.2 | volcengine | 中高端代码/推理 | 2.01 |
| qwen3.6-plus | aliyun | 中高端通用 | 2.06 |
| Ali-MiniMax-M2.7 / M2.5 | aliyun | 高端多模态 | 2.14 |
| Doubao-Seed-2.0-pro | volcengine | 高端旗舰 | 3.28 |
| Ali-GLM-5 | aliyun | 高端通用 | 4.08 |
| Ali-Kimi-k2.5 / Kimi-K2.5 | aliyun / moonshot | 高端长文本 | 4.10 |
| GLM-5-Turbo | zhipu | 旗舰推理 | 5.10 |

## 4.2.模型用量

#### 账号体系架构

采用 `bizName#openId#accessToken` 三层维度鉴权模型：

- **bizName**：业务线/产品线标识，实现多产品隔离
- **openId**：打通公司账号中心，用户身份与公司 SSO 绑定
- **accessToken**：账号中心鉴权token，与openid绑定
- **自动注册**：首次请求自动完成用户创建，降低接入门槛
```plaintext