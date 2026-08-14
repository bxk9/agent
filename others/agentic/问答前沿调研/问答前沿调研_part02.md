<td>llm判断当前内容是否足够完成任务，自行决定继续/结束react循环;<br>框架有硬性条件兜底终止</td>
<td>根据预定义的硬规则**选用大模型**，策略保守，简单复杂任务都偏向使用主模型；<无前置路由><br>固定注入工具schema的**prompt前缀**并缓存；<br>**复用搜索结果**，同个会话同一个query不再调用联网搜索； **跨会话**场景复用历史信息；</td>
<td>没有任何明确的 Query 编写要求<br>**复杂问题拆解**：把用户的多维度问题，拆分成多个独立、聚焦的子 Query<br>**迭代优化：**如果工具返回空 / 不完整结果，必须调整 Query、更换搜索策略重试，不能直接放弃或编造信息。</td>
<td>搜索后端**自动降级**<和claw类似><br>通过**控制工具集**的启用/弃用来匹配任务复杂度；<br>**两层tool call校验机制： **格式校验+工具可用性二次校验（tool是否在当前会话可用toolset，权限）</td>
<td>- Exa: [https://exa.ai](https://exa.ai) (search, extract)<br>- Firecrawl（默认）: [https://docs.firecrawl.dev/introduction](https://docs.firecrawl.dev/introduction) (search, extract, crawl)<br>- Parallel: [https://docs.parallel.ai](https://docs.parallel.ai) (search, extract)<br>- Tavily: [https://tavily.com](https://tavily.com) (search, extract, crawl)</td>
<td>**会话记忆持久化**：会话结束后，存储完整对话到数据库<对应跨会话复用历史>；更新两类核心记忆：（1）memory：环境事实、项目惯例等任务相关知识（2）user：用户偏好、沟通风格等用户画像知识<br>**技能自主沉淀**：若本次会话完成了复杂多步工具调用任务，Agent可自主将执行流程沉淀为可复用的Skill文件</td>
</tr>
</table>

## open claw

1. **框架路由方案**: Gateway 中央路由 + Agent 内部决策路由 + 简单/复杂模型路由
  1. Gateway 中央消息路由: 处理各个消息渠道，初始化对话
  2. Agent内部决策 (Prompt路由):  直接回答/调用工具执行技能
  3. 模型路由: 支持多模型
    1. **规则路由**（最快）
      - 简单闲聊 → 小模型 / 便宜模型
      - 工具调用、复杂推理 → 强模型
    2. **轻量分类 LLM**（更智能）
用一个超小模型Haiku分类：simple → 轻量模型/normal → 标准模型/complex → 最强模型

```plaintext

         用户输入消息
               ↓
┌─────────────────────────────┐
│        Gateway 网关层        │
│  • 会话绑定、排队、权限校验     │
│  • 处理上下文（历史+问题）      │
└───────────────┬─────────────┘
                ↓
┌─────────────────────────────┐
│      模型路由 Model Router   │ ←——【选择模型：简单模型 / 复杂模型】
│  • 规则/轻量LLM判断任务复杂度  │
│  • 选定LLM模型               │
└───────────────┬─────────────┘
                ↓
┌─────────────────────────────┐
│       Agent 智能体决策层      │
│    用【刚才选定的模型】推理     │
└───────────────┬─────────────┘
                ↓
              【决策分叉】
       /                           \
      /  无需工具                    \ 需要工具
     /                               \
┌─────────────┐             ┌─────────────────────────┐
│ 直接生成回答  │             │ 解析 tool_calls         │
└──────┬──────┘             │ 调用 Skill 工具执行层     │
       ↓                    │ 执行后把结果塞回上下文      │
       │                    └─────────────┬───────────┘
       │                                  ↓
       │                    ┌─────────────────────────┐
       │                    │ Agent 再次调用同一模型     │
       │                    │ 整理工具结果，生成最终回答   │
       └────────────────────┴───────────┬─────────────┘
                                        ↓
                           ┌─────────────────────────────┐
                           │        Gateway 网关层        │
                           │      返回结果给用户            │
                           └─────────────────────────────┘
                                         ↓
                                      对话结束                                    
```

### 3.1.1 联网搜索工具

**框架搜索SKILL实现方案 :**  [https://docs.vivo.xyz/s/kcrMeHuD](https://docs.vivo.xyz/s/kcrMeHuD) 邀请您加入文档协作【OpenClaw搜索Skill实现细节解读】

### 3.1.2 其他claw资料

[https://docs.vivo.xyz/s/HLHUfHgI](https://docs.vivo.xyz/s/HLHUfHgI) 邀请您加入文档协作【转载：OpenClaw技术分析(面向技术开发)-V1.3】

[https://docs.vivo.xyz/s/zpqyCILs](https://docs.vivo.xyz/s/zpqyCILs) 邀请您加入文档协作【OpenClaw (🦞)底层机制剖析及给小V的进阶启示】

[https://docs.vivo.xyz/detail/pdf/100112740276?secondSpaceId=120112682872&relationId=lkaoI9i0hptPTEj1rzkvE](https://docs.vivo.xyz/detail/pdf/100112740276?secondSpaceId=120112682872&relationId=lkaoI9i0hptPTEj1rzkvE) : OpenClaw橙皮书, 入门

## 3.2 claude code

```plaintext
1. 用户输入
   ↓
2. 查询初始化
   ↓
3. 上下文准备 ←──────────---┐
   ↓                      │
4. API 调用                │
   ↓                      │  ↺ LOOP 循环
5. 流式处理                │
   ↓                      │
[判断：是否需要调用工具？]    │
   ↙        ↘             │
YES           NO          │
 ↓             ↓          │
6. 工具执行     9. 流程结束  │
 ↓                        │
7. 结果反馈                │
 ↓                        │
8. 循环判断 ───────────────┘
```

Q：**如何判断是否需要调用工具？何时输出回答？**

A：1. 用户输入 → 调用LLM API

    客户端将消息和工具定义一起发给 LLM API

  2. 流式解析响应，检测 tool_use 块

    解析LLM API响应流。在 content_block_start 事件中，若 type === 'tool_use'，开始累积工具输入 JSON；在 content_block_stop 时生成完整的 AssistantMessage 并 yield。

  3. 有工具调用 → 执行工具 → 结果回传 → 继续循环

    工具结果作为 tool_result 类型的 UserMessage 追加到消息列表，然后 while(true) 循环回到顶部，再次调用LLM API，直到模型不再生成 tool_use 块。

WebSearch 的执行不是简单地调一个搜索 API——它在内部启动了一个**微型 ReAct Agent**，让一个子模型自主规划和执行搜索。

#### 整体架构

```plaintext
用户提问 → 主模型生成 WebSearch({ query: "..." })
                         │
                         ▼
               WebSearchTool.call()
                         │
            ┌────────────┴────────────────────┐
            │  启动微型 ReAct Agent             │
            │                                  │
            │  角色: "搜索助手"                  │
            │  任务: "搜索: <query>"            │
            │  唯一装备: web_search 服务端工具    │
            │                                  │
            │  Agent 自主循环:                   │
            │    思考 → 搜索 → 观察结果           │
            │    → 再思考 → 再搜索(可选)          │
            │    → ... (最多8轮)                 │
            │    → 输出最终文字摘要               │
            └────────────┬────────────────────┘
                         │
                         ▼
              格式化为 tool_result 返回给主模型
              (文字摘要 + URL 链接列表)
```

可以把它理解为一个极简的 ReAct Agent：

- **系统提示**：`"You are an assistant for performing a web search tool use"`
- **用户消息**：`"Perform a web search for the query: React 19 new features"`
- **工具箱只有一件**：Anthropic 服务端的 `web_search` 工具（最多可调用 8 次）
- **无其他工具**：`tools: [web_search_20250305]`——这个 Agent 除了搜索什么也不能做

这个微型 Agent 会自主决定：搜几次、每次用什么搜索词、何时停止。例如面对 query "React 19 new features"，它可能：

```plaintext
[思考] 我需要搜索 React 19 的新特性
[搜索] web_search({ query: "React 19 new features" })
[观察] 得到 10 条结果，但没有关于 breaking changes 的信息
[思考] 用户可能也想知道 breaking changes，补充搜一次
[搜索] web_search({ query: "React 19 breaking changes migration" })
[观察] 得到 8 条结果，信息足够了
[输出] 综合两次搜索结果的文字摘要
```

### 3.2.1 联网搜索工具

[https://docs.vivo.xyz/s/X8qdi3UU](https://docs.vivo.xyz/s/X8qdi3UU) 邀请您加入文档协作【Claude Code 联网信息获取能力调研】

## 3.3 hermes @陈妮

### 3.3.1 核心设计思想

**方案：模型路由-预定义规则判断任务复杂度，agent路由-llm推理决定是否调用工具**

- 预定义规则：