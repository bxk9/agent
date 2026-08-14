3. **工具需求：**一旦指令中出现“计算”、“查询”或“起草邮件”等关键词，路由器会自动调度配备专用工具的模型。与早期需手动启用插件的系统不同，现在的 GPT-5 会隐形处理这一过程：若查询明显需要执行代码或访问数据库，系统将自动移交专属模型。早期测试显示，凭借更精准的路由与专业化分工，GPT-5 的工具调用错误率较 GPT-4 降低近 50%。
4. **工具需求****：**一般情况下，路由器会直接响应用户指令。若输入“请深入思考”，系统会立即启动深度推理模式。笔者测试过“快速总结”与“深度剖析”等具有细微差异的不同措辞，能清晰观察到 GPT-5 在实时切换处理模式 —— 这仿佛解锁了新的“软指令”层，用户措辞对路由决策的影响程度，已不亚于系统内置的启发式规则。
5. 备注： 内部数据agent：[https://openai.com/zh-Hans-CN/index/inside-our-in-house-data-agent/](https://openai.com/zh-Hans-CN/index/inside-our-in-house-data-agent/)

### 3.4.2 Grok

搜索效果非常好，豆包没对的case 可以搜对，原因如下：

1. loop：执行前先搜think->（按需翻译translate）->check/compare/analyze/search/refine/expore按步骤搜索（按需查看网页）->identify/confirm缺失信息（按需搜索；大部分都是确认问题能不能回答）
2. 在拆分分析问题前，先搜索thinking；最后搜索完之后，反思confirm（看情况进行搜索）
3. 数据质量非常高：淘宝/知乎/抖音/新浪
4. 工具： 检查网页

| 问题（来自豆包错误的例子） | 链接 | 答案 | 原因分析 | Thinking | Checking | Confirming |
| --- | --- | --- | --- | --- | --- | --- |
| 协和医院皮肤科推荐的防晒霜有哪些？这些产品在屈臣氏能不能买到？ | [https://x.com/i/grok/share/077a10256273427b9a783cbea702d429](https://x.com/i/grok/share/077a10256273427b9a783cbea702d429) | ![截屏2026-04-15 17.24.33.png](http://veditor.vivo.xyz/api/v1/attachment/file/RHRhhxJBOLW0UyfMSTGKsvf4C2giyOnt9rQjGgx166Zh6o1zw-mlvEc53rkFRHVv) | Thinking about your request<br>Checking hospital recommendations<br>Confirming product availability | ![截屏2026-04-15 17.26.35.png](http://veditor.vivo.xyz/api/v1/attachment/file/MTVVUHyUKjlbtUjb2aZa8rikbtjRFCCvZsgbq3rRUP2G9Im7OfeG1a1CxoBA3V54) | Open page<br>![截屏2026-04-15 17.27.29.png](http://veditor.vivo.xyz/api/v1/attachment/file/8F21RuBCs1vvcjlBuw1lAcvssoqLzSgJBFv59kBxm02ddAWmyoTR3Ajwqno51sJD)<br>![截屏2026-04-15 17.27.55.png](http://veditor.vivo.xyz/api/v1/attachment/file/HcycaCCIZC5klj2ztS4XT39TXWmLj0Z6KyAN5N1_0RbhPfYvOsErnX-Zlzs_52Vd) | ![截屏2026-04-15 17.28.55.png](http://veditor.vivo.xyz/api/v1/attachment/file/2_q_aOMkyJP-i9PJDG0VUbWAd2kDmqrd25MQfQVBa0gukAsyOHqjDZfJvBgfvB7f) |
| 周口师范学院与河南工程学院哪个学校比较综合实力比较强？在高考分数哪个高？ | [https://x.com/i/grok/share/52c4cae763374b289aa7f2a3864f1433](https://x.com/i/grok/share/52c4cae763374b289aa7f2a3864f1433) | ![截屏2026-04-15 17.35.06.png](http://veditor.vivo.xyz/api/v1/attachment/file/9xwWU5kyoJJ2Km5zUkEPIho5YnJOg1xgaOLax4tXAgVAYsi6fBGwGpmvlNdeeUcH)<br>![截屏2026-04-15 17.35.29.png](http://veditor.vivo.xyz/api/v1/attachment/file/ayPf53_Bn_WV6LX_JQrOWpo0vqYtxkIjWHLN6h3KuJF59y1o0fHq98uAm-bmGPvE) | Thinking about your request<br>Comparing school strengths<br>Analyzing Gaokao scores<br>Confirming university profiles | ![截屏2026-04-15 17.36.29.png](http://veditor.vivo.xyz/api/v1/attachment/file/dO95zSQZ-XAlljtT8mhzG1FxvX_cV7dGMmYNHKXPhr8JewUb10YX9fhpLeTEGkqi) | ![截屏2026-04-15 17.36.41.png](http://veditor.vivo.xyz/api/v1/attachment/file/fs_pA2cE5h_JJTAEm4Kiylf2_9qPrDixdXzeWJxVaTLxmeIVL9OqdRX8X2E3FM8W)<br>![截屏2026-04-15 17.36.56.png](http://veditor.vivo.xyz/api/v1/attachment/file/sl--a73AATvZ0uHLMmglMEYJjUAXUTSLvHYcbSFH3WJnC5nO5JIZ3cMMqrenBKol) | ![截屏2026-04-15 17.37.06.png](http://veditor.vivo.xyz/api/v1/attachment/file/bJllBaBNSQDVCz3l1AlMNLSCzj7y4xzKwc2ohob7B7EFCesbeCXW-X3TrYf6a3-N) |
| 比亚迪海豹在欧洲NCAP碰撞测试中的评分如何？同级别哪些国产车得分更高？ | [https://x.com/i/grok/share/01a5591105a54c44a13cfd0a4f307d48](https://x.com/i/grok/share/01a5591105a54c44a13cfd0a4f307d48) | ![截屏2026-04-15 17.38.01.png](http://veditor.vivo.xyz/api/v1/attachment/file/JnsZET1qEL4Q7ppH_4dsD4nmCBwrEDlcFOBa7M-tKKlPR1LUdEo89bwPygQl5cK9)<br>![截屏2026-04-15 17.38.16.png](http://veditor.vivo.xyz/api/v1/attachment/file/axt9S_VbiBdy-FxN7wAtOVMvHTjN509SZtUaS7J5zteAXldz7tE4NCQ4thbth-BW) | Thinking about your request<br>Checking BYD Seal rating<br>Comparing XPeng P7 scores<br>Confirming NIO ET5 details | ![截屏2026-04-15 17.38.32.png](http://veditor.vivo.xyz/api/v1/attachment/file/jfI9Qq9MpQclgGn5YuKbBJRyDsVMJ0V6w5OUj5KIN66RhhDWzYCrTtqg6Wkn80cx) | ![截屏2026-04-15 17.39.01.png](http://veditor.vivo.xyz/api/v1/attachment/file/XFJdHlzgBeqnfQhc4t3yqhtiiR5zO3FSTbw7PfcwzN1IMNii4BipxSlKT94qFmhH)<br>![截屏2026-04-15 17.39.15.png](http://veditor.vivo.xyz/api/v1/attachment/file/yifocavXRr2aMmO01ZYSs9acDjHZQ3qDFvfeNTcEwFJmQzkP11gvW3GGmqizOV1d) | ![截屏2026-04-15 17.39.23.png](http://veditor.vivo.xyz/api/v1/attachment/file/pEO5hkmounOouY1Hg_DwQgDfQd1PpvJanW9QGCH92_PU4UDkHrPSRAwz4x02JaGy) |
| 中国新能源汽车2025年Q4出口量前三的品牌分别是哪些？这些品牌今年上半年在欧洲市场的销量增长情况如何？ | [https://x.com/i/grok/share/4e006156a34d4a4897c0141fcda8d165](https://x.com/i/grok/share/4e006156a34d4a4897c0141fcda8d165) | ![截屏2026-04-15 17.40.38.png](http://veditor.vivo.xyz/api/v1/attachment/file/FLZoalvNe2plVsaAGmdyRRGVJyNwjnZDEJVRzy7JkkQmFu113_NXb5PXab4kC5ol)<br>![截屏2026-04-15 17.40.48.png](http://veditor.vivo.xyz/api/v1/attachment/file/ECbePrMGLJaOzPC3AXFVzTCNUwT3u3O--vUPeka1XRGL-zGKSIJY5883ISfOquJ4) | Thinking about your request<br>Translating query<br>Searching export data<br>Identifying top brands<br>Assessing Europe growth | ![截屏2026-04-15 17.41.35.png](http://veditor.vivo.xyz/api/v1/attachment/file/_dqk5gxeKcKXQsmXiidv6UoFmAtB3mGVelk6NOthe8SecX3uQrZQq0-_bTEC9Te_) | ![截屏2026-04-15 17.41.47.png](http://veditor.vivo.xyz/api/v1/attachment/file/zOYoQ24Ov-YZwYYaVnha2KS6pnU8zKPuIElbSIbqQLlXeFfC5erFdadPwUmG5gYe)<br>![截屏2026-04-15 17.42.05.png](http://veditor.vivo.xyz/api/v1/attachment/file/7s67DyZKO05dJ-ZX7NxmrZKKFZwG4uB84JhN-m_R6CrIcwS_1ZCjUmSG8mCdor7N) | ![截屏2026-04-15 17.42.15.png](http://veditor.vivo.xyz/api/v1/attachment/file/26X70lY6NQSL4cLxnGTBOMa_bZAL_4dKuqRKZaCwKQV59FObu9-cpDE9RjcDFhD3) |
| Costco新上架的网红泡面在哪些城市有货？山姆会员店同款价格差多少？ | [https://x.com/i/grok/share/32581e47d2ee43aeb78fd4d439357292](https://x.com/i/grok/share/32581e47d2ee43aeb78fd4d439357292) | ![截屏2026-04-15 17.43.39.png](http://veditor.vivo.xyz/api/v1/attachment/file/dBL8GO8YkxWlh4w-ZvyPPhaVmLL4eB0taw1jj9-oaW9FWGZ2BoASbxt5BeyD0YZd)<br>![截屏2026-04-15 17.43.49.png](http://veditor.vivo.xyz/api/v1/attachment/file/whmL_KeTkEE1zp0sSDmm0CDQ2lJ-DhtQGdLZDijtETEgh-jdSzmc3mSv10aT6HtG) | Thinking about your request<br>Checking availability<br>Searching for details<br>Refining search<br>Exploring markets<br>Identifying product<br>Confirming locations | ![截屏2026-04-15 17.44.07.png](http://veditor.vivo.xyz/api/v1/attachment/file/zKZZvX5wb8EIpkCpkFtpopFuyhe3HwD71JZJoLEp1eR8LN21NoDcamIr9zvWSGlF) | ![截屏2026-04-15 17.44.28.png](http://veditor.vivo.xyz/api/v1/attachment/file/DJhqdyp-WJAiKUuu4k0sov8Z7vA7Yh6yytZRIHnG2nSy-gYXcOfMQxwTnKdEGYy8)<br>![截屏2026-04-15 17.44.49.png](http://veditor.vivo.xyz/api/v1/attachment/file/l_Kj0AxMmWmdH2CIwh6db6yK84egMYOPgsyeQWbbsBLuYmA2dAy6UKUJQYWyBXkJ)<br>![截屏2026-04-15 17.45.05.png](http://veditor.vivo.xyz/api/v1/attachment/file/UrQnCyxwdwrJvU1v5Gi3zNvLPsGcufs6Y7zbtBkyxAH0PeXnnwN5-AXRonIwoGhK)<br>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/YnYZWp9F0oH1OwO7KZtqu0456ssOmyHE-QkeKMAANZw0beSCuOsy9jKyYBdwyH0i) | ![截屏2026-04-15 17.46.23.png](http://veditor.vivo.xyz/api/v1/attachment/file/zk760ahggxZiRUknZPcAHfsSpy29QH4KwlU4_--F7YCgCgTLMIQC9dBgPO6ZB4h_) |

# 4 问答Agent与中控对接方案

### 阶段一：sub-agent

  - 参考claude code sub-agent的架构，问答可以作为子Agent
  - 问答agent链路：问答智能路由+简单问答链路+agentic问答链路

![AI搜索-第 5 页.drawio.png](http://veditor.vivo.xyz/api/v1/attachment/file/bbKtp_41kmGud6y3-6OxYySz0q4o50_rtTmCqBpCRWQTJnTXpVc_go0-Zr-jkWY2 "AI搜索-第 5 页.drawio.png")

> TODO：对齐430接入的中控的方案@孙启明 @甘明润 
> 智能路由：特征-句法、行业、query长度、历史的badcase 

### 阶段二：中控Agent统一规划

  - 参考open claw/hermes核心采用主agent调用工具的架构，统一使用LLM（pro）的规划编排能力，直接对复杂的问答query进行规划编排、反思总结
  - 智能问答路由和中控的智能路由合并，问答agent合并进现在的中控agent，问答提供纯搜索或者AI搜索接口

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/053PQ0pA0Qo5eGK0bXGR9rCAyG8CVfnVaYbG9zcFg29n8lYobWUWzEeLeyD__r0Y "image.png")

> 计划：
> 
> 两个阶段都投人力预研，优先把问答作为sub-agent接入（参考Claude Code架构），包含智能路由+简单问答链路+问答agent链路；
> 
> 同时预研 问答智能路由与中控智能路由合并，统一使用中控agent的规划编排能力
> 
> 原因：
> 
> 阶段二的预研依赖于阶段一的收益；
> 
> 因为对比独立Agent，融合为一个Agent更考验LLM的规划编排能力，以及工具选择能力；

# 5 问答agent方案

问答agent = 智能路由+agentic问答

## 智能路由

### （一）设计方案

目标：路由复杂难题给agentic问答

短期方案：[https://docs.vivo.xyz/s/NtbbVXTx](https://docs.vivo.xyz/s/NtbbVXTx) 邀请您加入文档协作【问答agentic-参考】

### （二） 产品定义

[https://docs.vivo.xyz/s/KXf3PN8D](https://docs.vivo.xyz/s/KXf3PN8D) 邀请您加入文档协作【Agentic分流策略】

### （三） 路由结果

@孙启明
