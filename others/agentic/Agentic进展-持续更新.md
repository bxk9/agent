整体计划： 对标豆包快速/思考/专家模式

技术对标计划：

|  | 豆包方案 | 预研方案 | 线上方案 |
| --- | --- | --- | --- |
| 快速（进行中） | 效果对比中 | DeepAgents Plan | 普通模式 |
| 思考 | 未启动 | 未启动 | 思考模式 |
| 专家 | 未启动 | 未启动 | / |

|  | 链接 | 版本 | 效果 | 时间 |
| --- | --- | --- | --- | --- |
| 问答数据集 |  [http://docs.vivo.xyz/s/NnfIajrM](http://docs.vivo.xyz/s/NnfIajrM)  | v1: 0331最优版本: plan+AI搜（一次总结）+总结<br>v2: plan+裸搜工具+总结<br>v3:  plan+AI搜（按链路总结）+总结(已废弃)<br>v4: 智能plan、搜、react | v1:<br>v2:<br>v3: | v1: 18s<br>v2: 9s<br>v3: <br>v4: 6s |
| deep research 数据集 | [http://docs.vivo.xyz/s/vYfjJiVs](http://docs.vivo.xyz/s/vYfjJiVs) | v4 |  |  |

快速模式下的优化：以自动化评测豆包 vs 预发 vs 线上为主来做优先级排序

效果优化todo:

1. 1、压缩时间:
  1. referecnes处理方式不占耗时 ✅
  2. 框架修改agent.astream_events换为更加轻量的agent.astream, 捕获的事件更少, 延迟更低 ✅
2. 按链路总结, 搜+总结并行调用。✅
3. 分析豆包
4. 原子化工具、让agent自主决定是否plan、改写、搜、搜索总结、react
5. 根据复杂度智能改写 ✅
6. 改写prompt优化
7. plan prompt优化, 根据复杂度智能选择步数 ✅
8. plan的时候同步输出改写词 ✅
9. 多轮+前端多轮
10. 加 vivo 日志