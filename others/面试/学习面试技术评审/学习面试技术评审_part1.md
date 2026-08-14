> 产品需求文档-文件管理需同步： [https://docs.vivo.xyz/s/FYfwgkwA](https://docs.vivo.xyz/s/FYfwgkwA) 邀请您加入文档协作【「简历面试」产品策略文档】

## 一、背景与范围

学习面试场景覆盖三个子场景：

| # | 子场景 | 核心能力 |
| --- | --- | --- |
| 1 | **简历改写** | JD解析 → 简历对齐诊断 → 定向改写 → PDF/DOCX渲染 |
| 2 | **模拟面试** | 面经驱动题库 → 多轮深度对话（ASR+Agent+TTS） → 评分反馈 |
| 3 | **面试复盘** | 真实录音 → ASR转写 → 切分QA对 → 三重对照复盘 → 错题本 → 分流简历改写/模拟面试 |

工具规模：**46 个工具**（16 个通用复用 + **30 个场景自建**）+ 4 个复合 Skill

---

能力维度：

![技术skill拆分.png](http://veditor.vivo.xyz/api/v1/attachment/file/Eby05h3SY4uUhcZVFKCnbtvOvKWtvVFZ6lTj3OQ8lHJq5scmdGfn7mI760SBY1xQ "技术skill拆分.png")

## 二、技术选型：Agent vs Skill

### 效果优先（已6.8会议上对齐）： 1 当前用agent形式先跑通，后续对比测试skill vs agent效果；2 agent先以独立agent接入，然后使用统一的云runtime框架（1-2周）

### Skill vs Agent 对比

| 维度 | Skill | Agent | 我们的场景 |
| --- | --- | --- | --- |
| 任务复杂度 | 单轮、确定性 | 多轮、上下文依赖、多步决策 | 简历改写依赖文件，模拟面试多轮对话，复盘关联简历+模拟记录 |
| 工具调用 | 1-3 个链式 | 可编排 46 个，动态决策顺序 | 16 通用 + 30 专属，复杂编排；<br>如果拆分为skill： 简历优化/模拟面试/面试复盘，以及上述三个通用的文件管理/面试专用搜索 |
| 状态管理 | 无状态或简单 | 长记忆、会话状态、多文件上下文 | 简历文件、模拟记录、复盘报告需持久化关联 |
| 自主决策 | 固定流程 | 根据上下文自主选择策略 | 面试表现驱动追问策略，动态调整复盘重点 |
| 文件系统集成 | 简单读写 | 文件作为核心知识库持续更新 | 简历 v1→v2 迭代、面试记录归档、复盘对比 |
| 注册管理 | 多个 Skill 分别注册 | 一个 Agent 注册，后续管理方便 | — |

**结论：本期用 Agent 方案**；效果稳定后按架构要求迁移 Skill，改动量可控。

> 沟通记录：郑坤建议通用 Skill /场景skill上技能平台，来统一调试；其他场景也不做 Skill，目前仅有云 Claw agent 和 GUI agent。

### 补充理由：搜索能力需要定制化，Skill 固定流程无法覆盖

本场景的信息获取（面经/JD/公司评价）依赖多个专业职场平台（牛客、小红书、看准、脉脉、BOSS），**通用 **`**web_search**`** 覆盖不全，质量无法控制**。为此需要引入**火山搜定制化搜索**（`search.volcano_career`），并配合多级降级链：

```plaintext
search.dispatcher 调用时：
  1. 命中缓存           → 直接返回（零成本）
  2. 火山搜 API         → 垂类内容召回，质量过滤（Phase 2）
  3. 云 Claw 浏览器抓取 → Chromium 渲染，结构化抽取（Phase 1 兜底）
  4. web_search         → 通用兜底，质量最低
```

这个**四级动态降级决策**正是 Skill 固定流程无法处理的典型场景：

| 问题 | Skill 的局限 | Agent 的解法 |
| --- | --- | --- |
| 缓存是否命中要在运行时判断 | 固定流程无法感知缓存状态 | Agent 每轮读 memory，动态跳过已缓存查询 |
| 火山搜 API 还未上线（Phase 1） | 流程写死后换后端要改代码 | 配置路由优先级，API 上线后零代码切换 |
| 不同 `query_intent` 对应不同信源和 TTL | 需多个 Skill 分别注册 | 一个 `search.dispatcher` Tool，参数驱动路由 |
| 搜索失败需重试或告知用户 | 异常路径难以统一编排 | Agent ReAct 循环天然支持重试 + 用户提示 |

> 详细工具设计（参数/缓存/质量过滤/风险）见 `火山搜定制化搜索设计.md`

### 补充理由：不能直接复用云 Claw Agent，需独立自建

#### 云 Claw 现状

云 Claw 目前是一个**独立 Agent**，通过 **A2A 协议**与端侧 Blue Claw 通信（经 `module_claw_a2a` → `module_claw_cloud` 通道），其内部已注册一套**通用工具池**：

| 工具 | 类型 | 说明 |
| --- | --- | --- |
| `convert_to_ppt` | 通用 | 内容转 PPT |
| `convert_to_pdf` | 通用 | 内容转 PDF |
| ... | 通用 | 其他场景共用工具 |

#### 共存冲突

学习面试场景需要在云 Claw 中新增**场景专有工具**（`resume.render`、`audio.asr_batch`、`browser.jd_fetch` 等），与现有通用工具在同一 Agent 进程中共存，带来三个问题：

| 问题 | 具体表现 |
| --- | --- |
| **命名空间污染** | 通用工具的 Prompt 描述可能被面试 Agent 误调；反之面试工具暴露给非面试场景 |
| **Skill 内部路由** | 云 Claw 收到调用请求后，需区分"这是通用 Skill 的请求"还是"面试 Skill 的请求"，否则工具选择混乱 |
| **迭代节奏不同** | 面试工具迭代频率高（本期 7 个），与通用工具独立发版，耦合在同一 Agent 增加双方维护风险 |

#### 解法：A2A 请求携带 `skill_namespace`，云侧按 namespace 隔离工具池

```plaintext
Blue Claw runtime
  └─ 面试 Tool（如 ResumeRenderTool）
       └─ A2A Request { skill_namespace: "job_seeker", tool_name: "resume.render", ... }
            └─ 云 Claw Agent ToolDispatcher
                 ├─ namespace=generic    → 通用工具池（convert_ppt/pdf/web_fetch）
                 └─ namespace=job_seeker → 面试工具池（resume.render/asr_batch/browser.*）
```

端侧每个云代理 Tool 在构造 A2A 请求时**强制注入** `skill_namespace="job_seeker"`，云侧 `ToolDispatcher` 按此字段路由，两池互不可见。

> **关键待确认**：A2A 消息体是否支持扩展 `skill_namespace` 字段 

---

深度对话：需要新增语音交互：包括上文注入语音以及语音总结注入到会话历史中来，请设计这块的工具调用以及上下文工具

## 三、工具总表（38 条）

### 工具分类汇总

| 类别 | 工具数 | 代表工具 | 执行位置 | 相关方 |
| --- | --- | --- | --- | --- |
| 一、信息获取 | 4 | `company.normalize`, `search.dispatcher`, `jd.parse`, `company.profile_build` | 端侧 |  |
| 二、简历处理 | 6 | `resume.parse`, `star_split`, `align_diagnose`, `snapshot_create`, `rewrite_bullet`, `tailor_compose`, `diff_render` | 云侧 |  |
| 三、面试准备 | 3 | `interview.question_bank_gen`, `session_context`, `answer.alignment_check` | 云侧 |  |
| 四、复盘与记忆 | 6 | `dialog.segment`, `answer.review`, `mistake.book_build`, `spaced_review`, `update_mastery`, `memory.bullet_performance.update` | 云侧 |  |
| 五、系统感知 | 8 | `notify.capture`, `notify.parse`, `calendar.read`, `calendar.write`, `record.fetch_local`, `file.save_to_local`, `notebook.export_local`, `notify.push` | 端侧 |  |
| 六、PC Claw交互 | 6 | `browser.jd_fetch`, `browser.experience_fetch`, `audio.asr_batch`, `file.scan_local`, `file.cross_device_transfer`, `resume.render` | 云侧/PC（依赖PC claw接入） |  |
| 七、内容管理 | 4 | `context_bootstrap`, `resume_tailor`, `interview_simulate`, `interview_debrief` | 云侧 |  |
| 八、录音 | 1 | `audio.asr_batch` | 端/云未定 |  |

---

## 四、Blue Claw 端侧工具

### 系统感知工具：

|  | 触发场景 | 是否可行 |
| --- | --- | --- |
| `calendar.read` | 前置搜索用户需求 | ✅增删改查都具备 |
| `calendar.write` | 日历日程安排 | ✅ |
| `notify.capture` | 前置搜索用户需求 | ❌ |
| `notify.parse` | 前置搜索用户需求 | ❌ |
| `email.read` | 前置搜索用户需求 | 待办：金乐 --自带邮件（只支持搜）/正在做 |
| `notify.push` | 面试学习场景推送 | 1 ✅面试通知：日历/龙虾的心跳机制<br>2 依赖感知的其他app跳转：7月才能决策 |

| 日历✅ | 邮件❌ | 短信✅ | push✅ |
| --- | --- | --- | --- |
| ![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/4AHLehdaA5apr3DisHwGw1wooAPDuUW2XlQP0oElqdhwpTliveuqHekD4QzPG92I) | ![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/mPl5rkpexBaGhleFfNSg5UcTNiiscAytyldNwWHCibag4AIu5KZZ5wDLTfr6rTVh) | ![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/3QHIDJDRPNTBRgkZXWiXiGqZRMmG2aL5T1nOGbIfO82jtNyRC_OY3N94S56rb6A6) | ![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/rGj5CqArlA5rOONIbr0MPSVLpZGAtVMkZvmGLKzJ0zYkcqvWbgFl7TkFHp7Jfaai) |

### 上传/下载工具（部分可以）

文件上传/下载：度量都是通的-鑫奇需要新的包， pdf/jpg 可以解析

<table>
<tr>
<td>文件类型</td>
<td>上传</td>
<td>下载</td>
<td colspan="2">上传截图</td>
<td colspan="2">下载截图</td>
</tr>
<tr>
<td>doc/docx</td>
<td>docx✅<br>doc❌ 可以上传，单无法解析</td>
<td>docx✅</td>
<td>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/JwDuPXesdmpDXZSa5ZgPeWz9_3pzGDk83TRMePnncRK0f1TLEk5ZOndvC32czk9S)</td>
<td></td>
<td>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/FoMii938HPq7AcMUP4FIpmgHJq4qfiXcfI4sc0E4Uad7Lc56EEKOrhEwSi7dZUsd)</td>
<td>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/HCtgRNOS-mb1m5Hx5ism020yw0Y6_C5DYlEgcU3UspRUkTzScMIKAQHmHTg9hoH6)</td>
</tr>
<tr>
<td>pdf</td>
<td>✅</td>
<td>❌可以保存到手机上，提供的路径正确，但是打不开</td>
<td>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/9jHZlZJQfNy3QqwPREpcRC36kdb8oUWpqdCnXHY3NgqFasWp4BstGGr1sWiH1lGV)</td>
<td></td>
<td>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/7WdPRTTb7i8KKr_r6_Fp0mkEsCRukzDgnCR6bjbTK_3o-PSy4sMrhCUSP671-9ol)</td>
<td>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/YDynSVtdG30MzuDXLyujPM5NomdKm_-deiD4uApIkq1AH7f7FDiJLXPIEPbshUH2)</td>
</tr>
<tr>
<td>图片<br>png\jpg\heic</td>
<td>png\jpg✅<br>heic❌可以上传但解析会卡住</td>
<td>jpg✅<br>png❌存下来了，但是无法打开</td>
<td>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/OIbEtNbUyAdQ-5W7twxbQFBqbb6XSG-3WkO-_Bl_9Lj_brk-joc_U33okf4LJBBI)</td>