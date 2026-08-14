| acc（2的占比） | 56/80 | 43/80 | 55/80 |

4 模型

2.0-lite-0215版本有TPM, 现在已经用上

2.0-lite-0428 有responses-api, 暂时没TPM，cache

5 模型对比

6 豆包手操

7 搜索自动化测评：

[https://docs.vivo.xyz/s/eDcN7abw](https://docs.vivo.xyz/s/eDcN7abw) 邀请您加入文档协作【搜索词召回质量自动化评测方案】

[https://docs.vivo.xyz/s/bNtMy2df](https://docs.vivo.xyz/s/bNtMy2df) 邀请您加入文档协作【Batch 评测报告】

[https://docs.vivo.xyz/s/NdotF8qi](https://docs.vivo.xyz/s/NdotF8qi) 邀请您加入文档协作【batch_summary】

8 智能路由

### 0519待办

效果： 最新端到端结果（没加搜索路由）： 线上78.7%（303/385），预发82.6%（318/385）；耗时3.0问答4s，agentic 8s

[https://docs.vivo.xyz/s/oNUYPQ8x](https://docs.vivo.xyz/s/oNUYPQ8x) 邀请您加入文档协作【agentVS线上豆包实验组】

​​1. 中控联调进展​​

（2.0 可以， 3.0不行-地理/历史答案缺失-done）

意图都传好了

​​2. 通用搜索优化​​ -军炜（效果更新中）

3 专项搜索接入 -陈乾

[https://docs.vivo.xyz/s/dM5lcV4g](https://docs.vivo.xyz/s/dM5lcV4g) 邀请您加入文档协作【高考通效果对比】

|  | 小V线上 | 问答Agent-接入前 | 问答Agent-接入后 |
| --- | --- | --- | --- |
| acc（2的占比） | 56/80 | 43/80 | 55/80 |

小V线上即将接入高考通智能体，暂不接入问答Agent

问答-出行场景：高德，百度，飞猪，同程，效果测试中

4 模型

2.0-lite-0215版本有TPM, 现在已经用上

2.0-lite-0428 有responses-api, 暂时没TPM，cache

所有链路都更新到搜索路由的版本

5 模型对比

6 豆包手操

7 搜索自动化测评：

[https://docs.vivo.xyz/s/eDcN7abw](https://docs.vivo.xyz/s/eDcN7abw) 邀请您加入文档协作【搜索词召回质量自动化评测方案】

[https://docs.vivo.xyz/s/bNtMy2df](https://docs.vivo.xyz/s/bNtMy2df) 邀请您加入文档协作【Batch 评测报告】

[https://docs.vivo.xyz/s/NdotF8qi](https://docs.vivo.xyz/s/NdotF8qi) 邀请您加入文档协作【batch_summary】

8 智能路由

9 综搜的智能路由

0515网页 Demo 及手机预发 V1 (2.0链路)以及（3.0链路 ）已同步更新至最新版本，主要变更：

 - 耗时优化：默认模型切换为 Doubao-Seed-2.0-lite-TPM

 - 最近的bug 修复 & PE 调整

 - 通用搜索优化

 - 新增 qwen3.6-max 支持及独立 prompt在数值计算场景

 - 适配 2.0 客户端 UI

### 0520待办

效果： 剔除agentic不如问答的意图， 耗时： 3.0问答4.2s，agentic 6.3s

效果；数据17.3%（346/2000）会走到agentic， 比3.0问答高8.7%

数据：[https://docs.vivo.xyz/s/dihLZ1Qf](https://docs.vivo.xyz/s/dihLZ1Qf) 邀请您加入文档协作【自测报告-0519】

高考通工具上线v1：目前主要覆盖rag意图为高考-分数咨询的query，要包含高校名称和查分数线意图

​​1. 中控联调进展​​

（2.0 可以， 3.0不行-地理/历史答案缺失-done）

意图都传好了

​​2. 通用搜索优化​​ -军炜（效果更新中）

3 专项搜索接入 -陈乾

[https://docs.vivo.xyz/s/dM5lcV4g](https://docs.vivo.xyz/s/dM5lcV4g) 邀请您加入文档协作【高考通效果对比】

|  | 小V线上 | 问答Agent-接入前 | 问答Agent-接入后 |
| --- | --- | --- | --- |
| acc（2的占比） | 56/80 | 43/80 | 55/80 |

小V线上即将接入高考通智能体，暂不接入问答Agent

问答-出行场景：高德，百度，飞猪，同程，效果测试中

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/3O9Kni8NX9-eyN4Wzm_ZA74srvJJkNHc5em5V67cUUscQkaK7BqMedK44qbuwfG- "image.png")

4 模型

2.0-lite-0215版本有TPM, 现在已经用上

2.0-lite-0428 有responses-api, 暂时没TPM，cache

所有链路都更新到搜索路由的版本

5 模型/框架对比

6 搜索自动化测评：

7 不搜

8 智能路由

9 综搜的智能路由

10 提测事项同步  [https://docs.vivo.xyz/s/uMk1edBX](https://docs.vivo.xyz/s/uMk1edBX) 邀请您加入文档协作【问答agentic接入小v提测】

### 0521待办

性能： 剔除agentic不如问答的意图， 耗时： 3.0问答4.2s，agentic 6.3s

效果；数据17.3%（346/2000）会走到agentic， 比3.0问答高8.7%； sbs 0.55（22个1，68个0，11个-1）

数据：[https://docs.vivo.xyz/s/dihLZ1Qf](https://docs.vivo.xyz/s/dihLZ1Qf) 邀请您加入文档协作【自测报告-0519】

​​1. 中控联调进展

3.0地理-进展： 自己去开发：确认用户地理位置

2. 通用搜索优化​​ -军炜（效果更新中）

限制搜索：限制24条最好（=约等于之前的50条）；耗时： 首字5%以内

![截屏2026-05-21 10.05.56.png](http://veditor.vivo.xyz/api/v1/attachment/file/DGLJWk12krqrGDwFgl-865fLyEhvR7q1t_Si8BknmsZjFcx_s3_1pse42B8JgGve "截屏2026-05-21 10.05.56.png")

[https://docs.vivo.xyz/s/1YKr0Buf](https://docs.vivo.xyz/s/1YKr0Buf) 邀请您加入文档协作【2026-5-21 搜索策略对比v2】

3 专项搜索接入 -陈乾

[https://docs.vivo.xyz/s/dM5lcV4g](https://docs.vivo.xyz/s/dM5lcV4g) 邀请您加入文档协作【高考通效果对比】

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/3O9Kni8NX9-eyN4Wzm_ZA74srvJJkNHc5em5V67cUUscQkaK7BqMedK44qbuwfG- "image.png")

[https://docs.vivo.xyz/s/mRQgixJO](https://docs.vivo.xyz/s/mRQgixJO) 邀请您加入文档协作【懂车帝效果评测】

[https://docs.vivo.xyz/s/w5bAFE1O](https://docs.vivo.xyz/s/w5bAFE1O) 邀请您加入文档协作【出行智能体效果评测】

4 模型

2.0-lite-0215版本有TPM, 现在已经用上

2.0-lite-0428 有responses-api, 暂时没TPM，cache

显cache 8% ；cache和tpm不同时使用

5 模型/框架对比：新链路 [https://docs.vivo.xyz/s/IGzdiumP](https://docs.vivo.xyz/s/IGzdiumP) 邀请您加入文档协作【模型融合方案】 [https://docs.vivo.xyz/s/kFNsdRl9](https://docs.vivo.xyz/s/kFNsdRl9) 邀请您加入文档协作【多node版本效果对比】

6 搜索自动化测评（支持多轮-react）：

[https://docs.vivo.xyz/s/xVQNyvvn](https://docs.vivo.xyz/s/xVQNyvvn) 邀请您加入文档协作【搜索召回自动化评测_v1】

整理了搜索召回评测目前的进展，包括评测方案、评测结果、badcase自动优化归因实验。目前以跑通方案为主，评测集规模较小（89条query）

7 智能路由

8 提测事项同步  [https://docs.vivo.xyz/s/uMk1edBX](https://docs.vivo.xyz/s/uMk1edBX) 邀请您加入文档协作【问答agentic接入小v提测】

准备事项： 链路（2.0服务端+2.0中控+3.0算法， 3.0服务端+3.0中控+3.0算法）

耗时： 中控， 搜索，搜索后处理，模型

### 0525待办

提测数据： 计算类考虑替换为tpm：[https://docs.vivo.xyz/s/dihLZ1Qf](https://docs.vivo.xyz/s/dihLZ1Qf) 邀请您加入文档协作【问答agentic效果和性能自测报告】

​​1. 中控联调进展（需要在ts链路上）

3.0地理-进展： 自己去开发：确认用户地理位置

2. 通用搜索优化​​ -军炜（效果更新中）

不同意图不同搜索条数限制： 降低使用量， 没有降低效果（耗时）

计算类： 计算器（恶意注入；输入是可控的-数字/fu hao）

3 专项搜索接入 -陈乾

[https://docs.vivo.xyz/s/dM5lcV4g](https://docs.vivo.xyz/s/dM5lcV4g) 邀请您加入文档协作【高考通效果对比】

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/3O9Kni8NX9-eyN4Wzm_ZA74srvJJkNHc5em5V67cUUscQkaK7BqMedK44qbuwfG- "image.png")

[https://docs.vivo.xyz/s/mRQgixJO](https://docs.vivo.xyz/s/mRQgixJO) 邀请您加入文档协作【懂车帝效果评测】

[https://docs.vivo.xyz/s/w5bAFE1O](https://docs.vivo.xyz/s/w5bAFE1O) 邀请您加入文档协作【出行智能体效果评测】

4 模型

2.0-lite-0215版本有TPM, 现在已经用上

2.0-lite-0428 有responses-api, 暂时没TPM，cache

显cache 8% ；cache和tpm不同时使用

5 模型/框架对比：新链路 [https://docs.vivo.xyz/s/IGzdiumP](https://docs.vivo.xyz/s/IGzdiumP) 邀请您加入文档协作【模型融合方案】 [https://docs.vivo.xyz/s/kFNsdRl9](https://docs.vivo.xyz/s/kFNsdRl9) 邀请您加入文档协作【多node版本效果对比】

6 搜索自动化测评/搜索词优化：

[https://docs.vivo.xyz/s/xVQNyvvn](https://docs.vivo.xyz/s/xVQNyvvn) 邀请您加入文档协作【搜索召回自动化评测_v1】

整理了搜索召回评测目前的进展，包括评测方案、评测结果、badcase自动优化归因实验。目前以跑通方案为主，评测集规模较小（89条query）

7 智能路由

8 提测事项同步  [https://docs.vivo.xyz/s/uMk1edBX](https://docs.vivo.xyz/s/uMk1edBX) 邀请您加入文档协作【问答agentic接入小v提测】

准备事项： 链路（2.0服务端+2.0中控+3.0算法， 3.0服务端+3.0中控+3.0算法）

9 耗时： [https://docs.vivo.xyz/s/ODjc8dtt](https://docs.vivo.xyz/s/ODjc8dtt) 邀请您加入文档协作【agentic链路有问题（2.0中控 2.0客户端 3.0算法）_pre_0521_首字耗时_agent】

### 0526待办

3.0 端到端6s， 单元测试2.76s：[https://docs.vivo.xyz/s/ODjc8dtt](https://docs.vivo.xyz/s/ODjc8dtt) 邀请您加入文档协作【agentic链路有问题（2.0中控 2.0客户端 3.0算法）_pre_0521_首字耗时_agent】

提测数据：计算类考虑替换为tpm，2.0 结果 ： [https://docs.vivo.xyz/s/dihLZ1Qf](https://docs.vivo.xyz/s/dihLZ1Qf) 邀请您加入文档协作【问答agentic效果和性能自测报告】

​​1. 中控联调进展（需要在ts链路上）

3.0地理-进展： 自己去开发：确认用户地理位置

开发完成，效果待确认

2. 通用搜索优化​​ -军炜（效果更新中）

不同意图不同搜索条数限制： 降低使用量， 没有降低效果（耗时）

计算类： 计算器（恶意注入；输入是可控的-数字/符号）

3 专项搜索接入 -陈乾

什么值得买智能体效果评测（优惠查询，商品推荐，选购建议）

筛选购物类相关意图

<table>
<tr>
<td>一级意图</td>
<td>二级意图</td>
<td>在问答中占比</td>
<td>小V线上</td>
<td>agentic问答</td>
<td>智能体</td>
</tr>
<tr>