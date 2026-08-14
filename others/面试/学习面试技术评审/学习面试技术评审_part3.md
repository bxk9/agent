  "用户近期专注 Java 后端面试准备..."
  ↓
LLM 推断：用户可能想周末刷题/模拟面试
  ↓
回答："要不要我帮你安排一场周末模拟面试？或者刷几道你弱项的系统设计题？"
```

**机制**：L1 全局 prompt 注入，零成本。

### **场景 ② 用户问"推荐几本书"**

```
LLM 决定调用 search_user_memory(query="用户职业方向和学习目标", mode="core")
  ↓
返回："用户是 Java 后端，准备大厂面试，弱项系统设计"
  ↓
回答：推荐《Designing Data-Intensive Applications》《System Design Interview》
```

**机制**：L2 主动检索，按需。

### **场景 ③ 用户切换到面试 Skill 问"上次面得咋样"**

```
面试 Skill 激活 → vfs_glob history → vfs_read_file 最新一份
  ↓
回答详细到逐题评分
```

**机制**：L3 Skill 私有详情，详细。

---

# 八、ASR**：端云方案都需要**

> 负责人：赵雪君（11170258）；端：张焕；云：拍明

| 能力 | 说明 | 风险 |
| --- | --- | --- |
| `audio.asr_batch` | 8kHz 窄带 ASR + 说话人分离<br>复用： 小v帮记 或者 录音机 | 其他团队/三方协助（端侧/云侧）<br>--云侧处理/端侧的效果验证<br>云侧模式是三方的，有成本 |
| 深度对话（需求还没有决策） | [https://docs.vivo.xyz/s/SMCLXfB6](https://docs.vivo.xyz/s/SMCLXfB6) 邀请您加入文档协作【模拟面试场景 · 深度对话接入需求文档】 | 待办：1 需要先测试带入文字上文/带出文字下文的能力； <br>2 评估各方工作量：端侧/phoneGPT/云侧 |

# 九、分阶段交付计划

<table>
<tr>
<th>阶段</th>
<th>内容</th>
<th>时间排期</th>
</tr>
<tr>
<td rowspan="4">**阶段一（核心链路）**</td>
<td>文字输入/简历上传->(JD解析) → 简历对齐 → 改写 → 渲染；</td>
<td>-6.30</td>
</tr>
<tr>
<td>题库生成 → 抓取邮件/日历 → 模拟面试（文本）</td>
<td>-6.30</td>
</tr>
<tr>
<td>文件管理：简历，个人题库，面试录音，错题本，求职档案</td>
<td>-6.30</td>
</tr>
<tr>
<td>真实录音 ASR 转写->面试复盘</td>
<td>-6.30</td>
</tr>
<tr>
<td>**阶段二（系统感知）**</td>
<td>后台自动读写日历，自动读vivo邮件</td>
<td>-7.15</td>
</tr>
<tr>
<td>阶段三（PC打通）</td>
<td>依赖PC claw打通，按需求赋予学习面试能力，目前需求只有搜索文件和文件传输</td>
<td>跟PC claw接入节奏走</td>
</tr>
<tr>
<td>**阶段四（语音深度对话）**</td>
<td>产品没有决策</td>
<td>跟整体规划走（暂不排期）</td>
</tr>
<tr>
<td>**阶段四**（本地搜相关文件）</td>
<td>需求提给本地搜（1 链路 2 能力上限）</td>
<td></td>
</tr>
</table>

边界： 跳出agent-兜底应该怎么做（不应该进但是进了， 应该进了但是没进）

输入：输入拆分；相关网站-phoneGPT； 链接抓取-PC claw

---

# 十、关键人员与对齐状态

| 方向 | 负责人 |
| --- | --- |
| 端框架 | 齐雪生 |
| 技能平台 | 郑坤  |
| 端技能 | 谢竺霖  |
| 云基建&云技能 | 姚利军、张硕 |
| 云侧-Agentic（云Agent+长技能+沙箱） | 张硕 |
| 感知记忆 | 许胜华  |
| 安全 | 王福维  |
| OS Agent框架 | 封优  |
| pc claw+小v智能体 | 黄卫兵  |
| asr | 端：张焕；云：拍明 |

# 技术工具拆解

[https://docs.vivo.xyz/s/LZCWCOHd](https://docs.vivo.xyz/s/LZCWCOHd) 邀请您加入文档协作【「简历面试」Skill工具梳理】

# 开发技能 ：额外Tool & Skill 设计规范

> 设计原则：主模型读 `description` 决策调用时机，不需要单独意图分类器。
> Skill = 主模型 dispatch 的单元（原子 Skill 或复合 Skill 均如此）；Tool = Skill 内部调用的原子能力，主模型不直接 dispatch。

---

## 目录

- [Tool 定义规范](#tool-定义规范)
- [一、信息获取类工具](#一信息获取类工具)
- [二、简历处理类工具](#二简历处理类工具)
- [三、面试准备类工具](#三面试准备类工具)
- [四、复盘与记忆类工具](#四复盘与记忆类工具)
- [五、系统感知类工具](#五系统感知类工具)
- [六、云侧工具（cloud execution）](#六云侧工具cloud-execution)
- [七、复合 Skill（多工具编排）](#七复合-skill多工具编排)
- [八、Memory Schema](#八memory-schema)
- [九、Session job_context 扩展](#九session-job_context-扩展)

---

## Tool 定义规范

每个 Tool 按以下字段定义，所有 Tool 注册到 Skill 描述表供主模型读取：

```plaintext
name              工具唯一 ID
type              tool | skill          # skill = 主模型可 dispatch 的单元（含复合编排）
                                        # tool  = Skill 内部调用的原子能力，主模型不直接 dispatch
execution_target  local | cloud | adaptive
description       触发条件（主模型据此决策，需精确）
parameters        入参 schema
returns           出参 schema
cache_policy      缓存策略（可选）
constraints       硬约束
error_handling    异常降级
```

---

## 一、信息获取类工具

### `company.normalize`

```yaml
name: company.normalize
type: tool
execution_target: local
description: |
  将用户输入的公司名原始字符串归一化为标准名称。
  在任何涉及公司画像缓存查询之前必须先调用此工具。
  示例："字节" → "字节跳动"，"抖音" → "字节跳动"，"ByteDance" → "字节跳动"。

parameters:
  company_raw: string    # 用户说的原始公司名

returns:
  company_canonical: string   # 标准化公司名，作为 memory 缓存 key
  is_exact_match: bool        # 是否命中映射表（false 则以原始字符串兜底）

cache_policy:
  type: in_memory
  alias_table: 维护人工别名映射表，覆盖主流大厂常见别名/子品牌

constraints:
  - 第一期子品牌统一到公司粒度（抖音/飞书 → 字节跳动）
  - 未命中映射表时以原始字符串兜底，不报错
  - 映射表需长期维护（公司改名/新品牌）

error_handling:
  not_found: 返回 { company_canonical: company_raw, is_exact_match: false }
```

---

### `search.dispatcher`

```yaml
name: search.dispatcher
type: tool
execution_target: adaptive   # 缓存命中走端侧，未命中调云侧浏览器
description: |
  求职场景统一搜索入口。根据 search_type 路由到不同信源，
  结果聚合后质量过滤、去重、本地缓存。
  search_type 枚举：jd | interview_exp | resume_sample | company_style。
  - jd: JD 文本（优先用户粘贴/截图，无则云侧抓取 BOSS/拉勾）
  - interview_exp: 面经（小红书/牛客/看准，云侧浏览器抓取，TTL=7d）
  - resume_sample: 优秀简历样本（小红书简历晒单，TTL=14d）
  - company_style: 公司评价/文化（脉脉/看准，TTL=30d）
  缓存命中直接返回，不重复触发云侧。

parameters:
  search_type: enum[jd, interview_exp, resume_sample, company_style]
  company: string      # 经 company.normalize 后的标准名
  role: string         # 岗位名
  source_list:         # 可选，指定信源；不传则按 search_type 使用默认信源
    - enum[小红书, 牛客, 看准, 脉脉, BOSS, web_search]
  force_refresh: bool  # 强制绕过缓存，默认 false

returns:
  results:
    - source: string
      content: string
      timestamp: string
      quality_score: float    # 内部质量分，不对用户展示
  from_cache: bool
  cache_key: string

cache_policy:
  key: hash(search_type + company + role)
  ttl:
    jd: 30d
    interview_exp: 7d
    resume_sample: 14d
    company_style: 30d

constraints:
  - 过滤"求转发/点赞"类营销帖（quality_score < 0.4 丢弃）
  - 面经只保留 1 年内内容（timestamp 过滤）
  - 同一 cache_key 并发时只触发一次云侧请求（防重复调起）

error_handling:
  cloud_unavailable: 降级到 web_search 兜底，告知用户结果质量下降
  all_sources_fail: 返回空列表 + 提示用户手动粘贴内容
```

---

### `jd.parse`

```yaml
name: jd.parse
type: tool
execution_target: local
description: |
  解析 JD，输出统一结构化 schema。
  支持三种输入通道（Adapter 可插拔）：
  - TextAdapter: 用户粘贴 JD 文本
  - ImageAdapter: 用户截图（端侧 OCR + LLM 抽取）
  - PlatformAdapter: 云侧浏览器抓取结果（jd_raw 由 browser.jd_fetch 提供）
  三种通道共享同一出参 schema，下游场景只认这个 schema。

parameters:
  input_type: enum[text, image, platform_raw]
  jd_text: string       # input_type=text 时
  jd_image: string      # input_type=image 时（本地文件路径）
  jd_raw: object        # input_type=platform_raw 时（browser.jd_fetch 返回）

returns:
  jd_id: string         # 全局唯一，格式 jd_{company}_{role}_{timestamp}
  source: string        # text | image | boss | laGou | maimai | ...
  skills: [string]
  experience_req: string
  explicit_req: [string]
  hidden_req: [string]  # 纯 JD 文本无法覆盖，依赖 search.dispatcher(interview_exp) 补充
  team_style: string

constraints:
  - hidden_req 字段若无面经支撑，标注 "需面经验证"，不凭空生成
  - jd_id 一旦生成不可变，作为后续所有关联数据的锚点

error_handling:
  ocr_quality_low: 提示用户重新截图或手动粘贴
  extraction_incomplete: 返回已抽取部分 + 标注 incomplete 字段
```

---

### `company.profile_build`

```yaml
name: company.profile_build
type: tool
execution_target: local
description: |
  基于 JD 解析结果和搜索摘要，构建"公司×岗位"两层画像并写入 memory。
  缓存命中（TTL 内同公司同岗位已有画像）时直接返回缓存，不触发 LLM 合成。
  两层分离存储：company_base（7天内同公司不同岗位可复用）+
               role_flavor（岗位层，company_base + role 组合唯一）。

parameters:
  company: string        # 经 company.normalize 后
  role: string
  jd_structured: object  # jd.parse 输出
  search_results: array  # search.dispatcher(interview_exp + company_style) 输出

returns:
  profile_id: string
  company_base:
    industry: string