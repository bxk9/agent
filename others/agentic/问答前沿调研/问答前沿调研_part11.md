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

[https://docs.vivo.xyz/s/AohOCy3w](https://docs.vivo.xyz/s/AohOCy3w) 邀请您加入文档协作【问答Agent接入智能体效果评测汇总】

4  搜索自动化测评/搜索词优化-海天

[https://docs.vivo.xyz/s/xVQNyvvn](https://docs.vivo.xyz/s/xVQNyvvn) 邀请您加入文档协作【搜索召回自动化评测_v1】

整理了搜索召回评测目前的进展，包括评测方案、评测结果、badcase自动优化归因实验。目前以跑通方案为主，评测集规模较小（89条query）

5 提测事项同步  [https://docs.vivo.xyz/s/uMk1edBX](https://docs.vivo.xyz/s/uMk1edBX) 邀请您加入文档协作【问答agentic接入小v提测】

准备事项： 链路（3.0客户端+3.0中控+3.0算法， 3.0客户端+3.0中控+2.0算法）； tpm模型签约；搜索接口走互联网；（模型12qps，搜索接口上36qps流量）

-- 品质提出了UI/交互问题，需要与产品沟通；

6.问答agent与中控agent融合

- 融合-v1版本，机评准确率指标差3pp+（融合后82.3% vs 融合前85.7%，评测集数量170条左右）
- 融合-v2版本：机评准确率与sub-agent持平（85.8%），性能较优，首字5.95s vs 4.19s
- 0603:扩充评测集评测中，评测完成后进行问题分析，0605输出结论

7.蓝龙虾问答能力接入：

- 蓝龙虾度量能力接入问答自动化准确率评测能力
- 蓝龙虾-v1版本，优化前后的机评acc指标差25pp（优化后75% vs 优化前50%，评测集数量40条左右），扩大评测集测试中
- 0603：扩充评测集评测中，评测完成后进行问题分析，0603输出结论

8.蓝龙虾ai-brief（资讯）：主要围绕四个领域（科技，社会，财经，八卦），先进行信源摸底，0602输出可行性和人力评估；0603：可行性和人力评估完成，待同步；同步启动开发

9.蓝龙虾的深度研究：需求阶段

10.蓝龙虾的面试skills：需求阶段

agentic都用ws全双工版本+3.0Loading态样式

3.0客户端 + 3.0中控 + 3.0算法

• 开发环境：test=ltx（纯 pro-agent）

• 开发环境：test=ts（智能路由版本）

3.0客户端 + 3.0中控 + 2.0算法

### 0603待办

算法单已结

0 干预：改写/信源/总结

​​1~~. 中控联调进展~~

~~3.0地理~~

~~需要确认3.0中控/2.0算法-接口/产品也需要重新确认；~~

2. 通用搜索优化​​ -军炜（效果更新中）[https://docs.vivo.xyz/s/XWQC7lBc](https://docs.vivo.xyz/s/XWQC7lBc) 邀请您加入文档协作【军炜版本_对比分析】

不同意图不同搜索条数限制： 降低使用量， 没有降低效果（耗时5.36s ）

计算类： 计算器（恶意注入；输入是可控的-数字/符号）

火山： 需要全部接互联网接口

3 ~~专项搜索接入 -陈乾~~

[https://docs.vivo.xyz/s/AohOCy3w](https://docs.vivo.xyz/s/AohOCy3w) 邀请您加入文档协作【问答Agent接入智能体效果评测汇总】

4  搜索自动化测评/搜索词优化-海天

[https://docs.vivo.xyz/s/xVQNyvvn](https://docs.vivo.xyz/s/xVQNyvvn) 邀请您加入文档协作【搜索召回自动化评测_v1】

整理了搜索召回评测目前的进展，包括评测方案、评测结果、badcase自动优化归因实验。目前以跑通方案为主，评测集规模较小（89条query）

[https://docs.vivo.xyz/s/x8UTdLuo](https://docs.vivo.xyz/s/x8UTdLuo) 邀请您加入文档协作【0602-429条-评测结果】

通用搜索优化 87.0% VS 通用搜索优化+搜索词优化 88.6%

新的智能路由， agentic vs 小v （预计周五下午完成评测）

5 提测事项同步  [https://docs.vivo.xyz/s/uMk1edBX](https://docs.vivo.xyz/s/uMk1edBX) 邀请您加入文档协作【问答agentic接入小v提测】

准备事项： 链路（3.0客户端+3.0中控+3.0算法， 3.0客户端+3.0中控+2.0算法）； tpm模型签约；搜索接口走互联网；（模型12qps，搜索接口上36qps流量）

-- 品质提出了UI/交互问题，需要与产品沟通；

6.问答agent与中控agent融合

- 融合-v1版本，机评准确率指标差3pp+（融合后82.3% vs 融合前85.7%，评测集数量170条左右）
- 融合-v2版本：机评准确率与sub-agent持平（85.8%），性能较优，首字5.95s vs 4.19s
- 0603:扩充评测集评测中，评测完成后进行问题分析，0605输出结论

7.蓝龙虾问答能力接入：

- 蓝龙虾度量能力接入问答自动化准确率评测能力
- 蓝龙虾-v1版本，优化前后的机评acc指标差25pp（优化后75% vs 优化前50%，评测集数量40条左右），扩大评测集测试中
- 0603：扩充评测集评测中，评测完成后进行问题分析，0603输出结论

8.蓝龙虾ai-brief（资讯）：主要围绕四个领域（科技，社会，财经，八卦），先进行信源摸底，0602输出可行性和人力评估；0603：可行性和人力评估完成，待同步；同步启动开发

9.蓝龙虾的深度研究：需求阶段

10.蓝龙虾的面试skills：需求阶段

agentic都用ws全双工版本+3.0Loading态样式

3.0客户端 + 3.0中控 + 3.0算法

• 开发环境：test=ltx（纯 pro-agent）

• 开发环境：test=ts（智能路由版本）

3.0客户端 + 3.0中控 + 2.0算法

### 0604待办

干预： done

记忆： 海天/博文

[https://docs.vivo.xyz/s/bM1yggpf](https://docs.vivo.xyz/s/bM1yggpf) 邀请您加入文档协作【中控记忆接入】

通用搜索优化：确认耗时和效果 @李军炜 [https://docs.vivo.xyz/s/ODjc8dtt](https://docs.vivo.xyz/s/ODjc8dtt) 邀请您加入文档协作【agentic链路有问题（2.0中控 2.0客户端 3.0算法）_pre_0521_首字耗时_agent】

搜索词优化：

[https://docs.vivo.xyz/s/jTgBnOix](https://docs.vivo.xyz/s/jTgBnOix) 邀请您加入文档协作【2026-6-4 耗时分析】

|  | 5-25 提测270版本（s） | 占比 | 6-3 pre_2.0使用439版本耗时（s） | 占比 | 6-4 压缩calculator使用范围439版本（s) | 占比 | 6-4 对齐270版本 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 无搜索耗时 | 1.26 | 63% | 1.184 | 49% | 0.920 | 46% | 0.921 |
| 有搜索耗时 | 5.098 | 37% | 4.808 | 51% | 5.588 | 54% | 5.690 |
| 平均耗时 | 2.682 |  | 3.016 |  | 3.429 |  | 2.930 |
| 自动化评估2分率 |  |  | 86.78% |  | 85.25% |  | 88.92% |

**需要将带有搜索的耗时下降600ms**

ai_search 调用次数与得分

| 调用次数 | auto均分 |
| --- | --- |
| 0次 | **1.929** |
| 1次 | 1.842 |
| 2+次 | 1.556 |

**结论：搜索次数越多，得分下降越明显。多次搜索（2+次）得分显著低于不搜索。**

需评估针对搜索次数2+次，强制压缩为1次，准确率是否有显著下降。

搜索词优化：@李海天 [https://docs.vivo.xyz/s/VgQR0NQm](https://docs.vivo.xyz/s/VgQR0NQm) 邀请您加入文档协作【搜索词优化点】

### 0605待办

干预： done

记忆： 海天/博文

中间词展示：

[https://docs.vivo.xyz/s/bM1yggpf](https://docs.vivo.xyz/s/bM1yggpf) 邀请您加入文档协作【中控记忆接入】

通用搜索优化：确认耗时和效果 @李军炜 [https://docs.vivo.xyz/s/ODjc8dtt](https://docs.vivo.xyz/s/ODjc8dtt) 邀请您加入文档协作【agentic链路有问题（2.0中控 2.0客户端 3.0算法）_pre_0521_首字耗时_agent】

搜索词优化：

新的智能路由的效果：[https://docs.vivo.xyz/s/MlXl15Cv](https://docs.vivo.xyz/s/MlXl15Cv) 邀请您加入文档协作【智能路由-评测集】

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/56HBS1AUOm9PXsMUUps8t7HEuREM1ekKt5shNBrVg_AbQGy2Wnt0Gihmy957Mpdy "image.png")

**需要将带有搜索的耗时下降600ms**

ai_search 调用次数与得分

| 调用次数 | auto均分 |
| --- | --- |
| 0次 | **1.929** |
| 1次 | 1.842 |
| 2+次 | 1.556 |

**结论：搜索次数越多，得分下降越明显。多次搜索（2+次）得分显著低于不搜索。**

需评估针对搜索次数2+次，强制压缩为1次，准确率是否有显著下降。

搜索词优化：@李海天 [https://docs.vivo.xyz/s/VgQR0NQm](https://docs.vivo.xyz/s/VgQR0NQm) 邀请您加入文档协作【搜索词优化点】

产品prompt测评：通用底座+动态注入SP [https://docs.vivo.xyz/s/UXtgxj6I](https://docs.vivo.xyz/s/UXtgxj6I) 邀请您加入文档协作【通用底座+动态注入SP评测】