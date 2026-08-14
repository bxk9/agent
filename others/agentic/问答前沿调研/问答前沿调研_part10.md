<td rowspan="5">时尚美妆</td>
<td>穿搭配饰</td>
<td rowspan="5">1.23%</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>品牌</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>护肤技巧</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>彩妆技巧</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>时尚其它</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>社交沟通</td>
<td>礼品/礼物</td>
<td>0.14%</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td rowspan="2">育儿</td>
<td>母婴食品</td>
<td rowspan="2">0.07%</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>母婴用品</td>
<td>86.15%</td>
<td></td>
<td>89.74%</td>
</tr>
<tr>
<td>宠物</td>
<td>宠物用品</td>
<td>0.02%</td>
<td></td>
<td></td>
<td></td>
</tr>
</table>

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

### 0527待办

3.0 端到端6s， 单元测试2.76s：[https://docs.vivo.xyz/s/ODjc8dtt](https://docs.vivo.xyz/s/ODjc8dtt) 邀请您加入文档协作【agentic链路有问题（2.0中控 2.0客户端 3.0算法）_pre_0521_首字耗时_agent】

提测数据：计算类考虑替换为tpm，2.0 结果 ： [https://docs.vivo.xyz/s/dihLZ1Qf](https://docs.vivo.xyz/s/dihLZ1Qf) 邀请您加入文档协作【问答agentic效果和性能自测报告】

​​1. 中控联调进展

3.0地理

需要确认3.0中控/2.0算法-http接口/产品也需要重新确认；

2. 通用搜索优化​​ -军炜（效果更新中）

不同意图不同搜索条数限制： 降低使用量， 没有降低效果（耗时5.36s）

计算类： 计算器（恶意注入；输入是可控的-数字/符号）

火山： 需要全部接互联网接口

3 专项搜索接入 -陈乾

什么值得买智能体效果评测（优惠查询，商品推荐，选购建议）

筛选购物类相关意图

<table>
<tr>
<td></td>
<td></td>
<td></td>
<td></td>
<td colspan="2">小V线上</td>
<td colspan="2">agentic问答</td>
<td colspan="2">智能体</td>
</tr>
<tr>
<td>一级意图</td>
<td>二级意图</td>
<td>在问答中占比</td>
<td>测试数据量</td>
<td>acc</td>
<td>首字耗时</td>
<td>acc</td>
<td>首字耗时</td>
<td>acc</td>
<td>首字耗时</td>
</tr>
<tr>
<td rowspan="5">时尚美妆</td>
<td>穿搭配饰</td>
<td rowspan="5">1.23%</td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>品牌</td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>护肤技巧</td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>彩妆技巧</td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>时尚其它</td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>社交沟通</td>
<td>礼品/礼物</td>
<td>0.14%</td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td rowspan="2">育儿</td>
<td>母婴食品</td>
<td rowspan="2">0.07%</td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>母婴用品</td>
<td>108</td>
<td>83.02%</td>
<td>3.38s</td>
<td>87.04%</td>
<td>4.83s</td>
<td>89.74%</td>
<td>8.80s</td>
</tr>
<tr>
<td>宠物</td>
<td>宠物用品</td>
<td>0.02%</td>
<td>170</td>
<td>84.21%</td>
<td>3.63s</td>
<td>85.80%</td>
<td>3.99s</td>
<td>80.12%</td>
<td>8.66s</td>
</tr>
</table>

4  搜索自动化测评/搜索词优化-海天

[https://docs.vivo.xyz/s/xVQNyvvn](https://docs.vivo.xyz/s/xVQNyvvn) 邀请您加入文档协作【搜索召回自动化评测_v1】

整理了搜索召回评测目前的进展，包括评测方案、评测结果、badcase自动优化归因实验。目前以跑通方案为主，评测集规模较小（89条query）

5 提测事项同步  [https://docs.vivo.xyz/s/uMk1edBX](https://docs.vivo.xyz/s/uMk1edBX) 邀请您加入文档协作【问答agentic接入小v提测】

准备事项： 链路（3.0客户端+3.0中控+3.0算法， 3.0客户端+3.0中控+2.0算法）； tpm模型签约；搜索接口走互联网；（模型12qps，搜索接口上36qps流量）

agentic都用ws全双工版本+3.0Loading态样式

3.0客户端 + 3.0中控 + 3.0算法

• 开发环境：test=ltx（纯 pro-agent）

• 开发环境：test=ts（智能路由版本）

3.0客户端 + 3.0中控 + 2.0算法

• 预发环境，无需分流参数

### 0528待办

3.0 端到端6s， 单元测试2.76s：[https://docs.vivo.xyz/s/ODjc8dtt](https://docs.vivo.xyz/s/ODjc8dtt) 邀请您加入文档协作【agentic链路有问题（2.0中控 2.0客户端 3.0算法）_pre_0521_首字耗时_agent】

提测数据：计算类考虑替换为tpm，2.0 结果 ： [https://docs.vivo.xyz/s/dihLZ1Qf](https://docs.vivo.xyz/s/dihLZ1Qf) 邀请您加入文档协作【问答agentic效果和性能自测报告】

​​1. 中控联调进展

3.0地理

需要确认3.0中控/2.0算法-接口/产品也需要重新确认；

2. 通用搜索优化​​ -军炜（效果更新中）[https://docs.vivo.xyz/s/XWQC7lBc](https://docs.vivo.xyz/s/XWQC7lBc) 邀请您加入文档协作【军炜版本_对比分析】

不同意图不同搜索条数限制： 降低使用量， 没有降低效果（耗时5.36s ）

计算类： 计算器（恶意注入；输入是可控的-数字/符号）

火山： 需要全部接互联网接口

3 专项搜索接入 -陈乾

什么值得买智能体效果评测（优惠查询，商品推荐，选购建议）

筛选购物类相关意图

<table>
<tr>
<td></td>
<td></td>
<td></td>
<td></td>
<td colspan="2">小V线上</td>
<td colspan="2">agentic问答</td>
<td colspan="2">智能体</td>
</tr>
<tr>
<td>一级意图</td>
<td>二级意图</td>
<td>在问答中占比</td>
<td>测试数据量</td>
<td>acc</td>
<td>首字耗时</td>
<td>acc</td>
<td>首字耗时</td>
<td>acc</td>
<td>首字耗时</td>
</tr>
<tr>
<td rowspan="5">时尚美妆</td>
<td>穿搭配饰</td>
<td rowspan="5">1.23%</td>
<td>164</td>
<td>83.02%</td>
<td>2.58s</td>
<td>89.02%</td>
<td>2.92s</td>
<td>89.54%</td>
<td>9.91s</td>
</tr>
<tr>
<td>品牌</td>
<td>174</td>
<td>85.03%</td>
<td>3.00s</td>
<td>84.48%</td>
<td>5.13s</td>
<td>80.00%</td>
<td>9.56s</td>
</tr>
<tr>
<td>护肤技巧</td>
<td>237</td>
<td>90.25%</td>
<td>2.82s</td>
<td>89.87%</td>
<td>3.98s</td>
<td>89.38%</td>
<td>9.85s</td>
</tr>
<tr>
<td>彩妆技巧</td>
<td>56</td>
<td>81.82%</td>
<td>2.69s</td>
<td>82.14%</td>
<td>3.53s</td>
<td>88.68%</td>
<td>9.55s</td>
</tr>
<tr>
<td>时尚其它</td>
<td>177</td>
<td>90.80%</td>
<td>2.93s</td>
<td>88.14%</td>
<td>4.16s</td>
<td>88.55%</td>
<td>9.62s</td>
</tr>
<tr>
<td>社交沟通</td>
<td>礼品/礼物</td>
<td>0.14%</td>
<td>143</td>
<td>96.48%</td>
<td>3.27s</td>
<td>94.41%</td>
<td>1.94s</td>
<td>93.01%</td>
<td>9.58s</td>
</tr>
<tr>
<td rowspan="2">育儿</td>
<td>母婴食品</td>
<td rowspan="2">0.07%</td>
<td>199</td>
<td>84.34%</td>
<td>3.15s</td>
<td>85.93%</td>
<td>4.42s</td>
<td>80.30%</td>
<td>8.83s</td>
</tr>
<tr>
<td>母婴用品</td>
<td>108</td>
<td>83.02%</td>
<td>3.38s</td>
<td>87.04%</td>
<td>4.83s</td>
<td>89.74%</td>
<td>8.80s</td>
</tr>
<tr>
<td>宠物</td>
<td>宠物用品</td>
<td>0.02%</td>
<td>170</td>
<td>85.12%</td>
<td>3.63s</td>
<td>85.88%</td>
<td>3.99s</td>
<td>80.59%</td>
<td>8.66s</td>
</tr>
</table>

京东商品搜索接口目前还未提供可用接口，希望后续通过A2A的形式接入

4  搜索自动化测评/搜索词优化-海天

[https://docs.vivo.xyz/s/xVQNyvvn](https://docs.vivo.xyz/s/xVQNyvvn) 邀请您加入文档协作【搜索召回自动化评测_v1】

整理了搜索召回评测目前的进展，包括评测方案、评测结果、badcase自动优化归因实验。目前以跑通方案为主，评测集规模较小（89条query）

5 提测事项同步  [https://docs.vivo.xyz/s/uMk1edBX](https://docs.vivo.xyz/s/uMk1edBX) 邀请您加入文档协作【问答agentic接入小v提测】

准备事项： 链路（3.0客户端+3.0中控+3.0算法， 3.0客户端+3.0中控+2.0算法）； tpm模型签约；搜索接口走互联网；（模型12qps，搜索接口上36qps流量）

-- 品质提出了UI/交互问题，需要与产品沟通；

6.问答agent与中控agent融合：v1版本问题分析完成，0528完成迭代，0529输出新版评测结论

7.蓝龙虾问答能力接入：待问题分析，待评测度量评测集（自动化准确率评测能力接入蓝龙虾度量能力）

8.蓝龙虾ai-brief（资讯）：主要围绕四个领域（科技，社会，财经，八卦），先进行信源摸底，

9.蓝龙虾的深度研究：需求阶段

10.蓝龙虾的面试skills：需求阶段

agentic都用ws全双工版本+3.0Loading态样式

3.0客户端 + 3.0中控 + 3.0算法

• 开发环境：test=ltx（纯 pro-agent）

• 开发环境：test=ts（智能路由版本）

3.0客户端 + 3.0中控 + 2.0算法

• 预发环境，无需分流参数

### 0602待办
