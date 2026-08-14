    scale: string
    stage: string
    tech_stack: [string]
    values: [string]
    recent_strategy: string
  role_flavor:
    team_position: string
    focus: string
    promotion_path: string
  merged_profile:
    core_traits: [string]
    red_flags: [string]      # 面试雷区
    interview_style: string
  from_cache: bool

cache_policy:
  key_company_base: company_canonical
  key_role_flavor: "{company_canonical}_{role}"
  ttl: 14d

constraints:
  - 每个字段必须标注数据来源（JD原文 / 面经摘要 / web）
  - 找不到信息时标注 "未检索到"，不捏造
```

---

## 二、简历处理类工具

### `resume.parse`

```yaml
name: resume.parse
type: tool
execution_target: local
description: |
  解析用户上传的简历文件（PDF/DOCX/图片/文字粘贴），
  输出结构化 JSON 并生成稳定的 bullet_id。
  bullet_id 是跨版本追踪同一条经历的全局 key，
  在此生成后整个生命周期不可变。

parameters:
  resume_file: string    # 本地文件路径，或文字粘贴时为 text
  input_type: enum[pdf, docx, image, text]

returns:
  resume_id: string      # 格式 resume_{user}_{timestamp}
  basic_info: object     # 姓名/联系方式
  education: [object]
  experience:
    - bullet_id: string  # 格式 b_{resume_id}_{seq}，全局唯一且稳定
      text: string
      section: string    # 所属段落（工作/项目/实习）
  skills: [string]
  awards: [string]

constraints:
  - bullet_id 首次生成后，后续改写版本只更新 rewritten_text，bullet_id 不变
  - 用户删除某条经历时打 deleted=true 标记，不物理删除
  - 多栏排版/图片简历解析率低，引导用户上传标准格式

error_handling:
  parse_failed: 返回已解析部分 + 引导用户手动粘贴文字版
```

---

### `resume.star_split`

```yaml
name: resume.star_split
type: tool
execution_target: local
description: |
  将每条简历 bullet 拆解为 STAR 四要素（情境/任务/行动/结果）。
  是 resume.align_diagnose 的前置工具，拆解结果用于精准诊断漏项。

parameters:
  bullets:
    - bullet_id: string
      text: string

returns:
  star_bullets:
    - bullet_id: string
      situation: string   # 可为空（bullet 未提供背景）
      task: string
      action: string
      result: string
      missing_elements: [enum[S, T, A, R]]   # 缺失要素列表

constraints:
  - 不补全用户未写的内容，只标注缺失，不捏造
```

---

### `resume.align_diagnose`

```yaml
name: resume.align_diagnose
type: tool
execution_target: local
description: |
  对照 JD 和公司画像，对简历每条 bullet 做四象限对齐诊断。
  输出"匹配/漏项/弱表达/风险项"四类，每条标注 JD 原文依据。

parameters:
  star_bullets: array     # resume.star_split 输出
  jd_structured: object   # jd.parse 输出
  merged_profile: object  # company.profile_build 输出

returns:
  four_quadrant:
    matched:
      - bullet_id: string
        jd_ref: string
        suggestion: string    # 如何进一步强化
    missing:
      - jd_req: string
        can_excavate: bool    # 用户是否可能有相关经历但没写
        tip: string
    weak:
      - bullet_id: string
        rewrite_hint: string  # 表述问题，改写方向
    risky:
      - bullet_id: string
        risk_type: string     # 与画像冲突 / 数字存疑 / 夸大
        mitigation: string
  priority_order:
    - bullet_id: string
      impact_label: enum[高, 中, 低]   # 不打数字分

constraints:
  - 每条诊断结论必须标注 JD 原文条目或画像维度作为依据
  - 不输出数字评分（"80分"类）
```

---

### `resume.snapshot_create`

```yaml
name: resume.snapshot_create
type: tool
execution_target: local
description: |
  在用户确认"开始面试/模拟面试"时，fork 当前最新简历版本为不可变快照。
  快照与 session_id 1:1 绑定，复盘时用的是"当时实际投出的那版"，而非最新版。

parameters:
  resume_id: string       # 当前最新版本 ID
  session_id: string      # 触发快照的面试 session

returns:
  snapshot_id: string     # 格式 snap_{resume_id}_{session_id}
  snapshot_path: string   # 本地存储路径（只读）
  based_on_version: string

constraints:
  - 快照写入后不可修改（immutable）
  - 仅在"用户确认进入面试 session"时触发，不在投递时触发（投递时机不明确）
```

---

### `resume.rewrite_bullet`

```yaml
name: resume.rewrite_bullet
type: tool
execution_target: local
description: |
  对单条简历 bullet 进行定向改写。
  对照 JD 要求和公司画像为改写目标，以同公司同岗位简历样本风格为约束。
  同时读取 memory 中该 bullet 的历史面试表现作为参考。

parameters:
  bullet_id: string
  original_text: string
  jd_structured: object
  merged_profile: object
  style_ref: object         # search.dispatcher(resume_sample) 提炼的风格特征
  bullet_history:           # memory.bullet_performance[bullet_id]，可为空
    overall_tag: string
    sessions: [object]

returns:
  bullet_id: string
  rewritten_text: string
  rewrite_reason: string    # 对照了哪条 JD 要求 / 哪个画像特质 / 参考了哪类样本
  change_type: enum[微调, 重写, 结构调整]

constraints:
  - 数字原文不变（exact match 校验，"D7+4%" 不得改为其他数字）
  - 改动幅度 ≤ 30%（体验基准）
  - 动词开头，长度在原文 ±20% 范围内
  - 不凭空添加简历中不存在的事实

error_handling:
  number_mismatch: 拦截输出，回退到原始文本，告知用户
```

---

### `resume.tailor_compose`

```yaml
name: resume.tailor_compose
type: tool
execution_target: local
description: |
  对所有改写后的 bullet 做四维加权重排，高匹配度经历前置。
  与 resume.rewrite_bullet 共享同一次 search.dispatcher 结果，不重复请求。

parameters:
  bullets: array              # resume.rewrite_bullet 输出
  jd_structured: object
  merged_profile: object
  sample_frequency_map:       # search.dispatcher(resume_sample) 中各经历类型出现频率
    experience_type: float
  memory_strong_tags: [string]  # memory 中用户历史强项

returns:
  sorted_bullets: array       # 重排后的 bullet 顺序
  section_order: [string]     # 模块顺序（如"项目经历"前置）
  suppressed_bullets:         # 建议弱化的 bullet
    - bullet_id: string
      reason: string

constraints:
  - 四维权重（JD匹配/画像对齐/样本频率/历史强项）冷启动时退化为前两维
  - 样本频率维度权重不超过 0.3（防外部信号主导）
  - 不删除任何 bullet，只做顺序调整
```

---

### `resume.diff_render`

```yaml
name: resume.diff_render
type: tool
execution_target: local
description: |
  生成改写前后的对照视图。支持两种模式：
  - client: 手机端 HTML 高亮展示，支持逐条回退
  - docx: 带 Track Changes 批注的 DOCX 文件（cloud 渲染）

parameters:
  bullets_before: array
  bullets_after: array
  rewrite_reasons: [string]
  diff_mode: enum[client, docx]

returns:
  diff_view: string         # diff_mode=client 时：HTML 字符串
  docx_request_params:      # diff_mode=docx 时：传给 resume.render(cloud) 的参数
    bullets_before: array
    bullets_after: array
    comments: [string]

constraints:
  - 整段重写时显示"重写"标签而非逐字 diff（避免视觉噪音）
  - 每条改动旁必须展示 rewrite_reason（改动依据可溯）
```

---

## 三、面试准备类工具

### `interview.question_bank_gen`

```yaml
name: interview.question_bank_gen
type: tool
execution_target: local
description: |
  基于 JD、简历快照、公司画像、历史弱项，生成个性化分类题库。
  历史弱项维度自动加权（历史答差次数多的类型优先生成）。
  题目去重（与上次题库 embedding 相似度 > 0.85 则替换）。

parameters:
  jd_structured: object
  resume_snapshot_id: string
  merged_profile: object
  weak_dimensions: object      # memory.user_profile.weak_dimensions，可为空
  face_frequency_map: object   # search.dispatcher(interview_exp) 提取的高频题，可为空
  interview_round: enum[一面, 二面, 终面, HR面]

returns:
  question_bank:
    questions:
      - id: string             # 格式 q_{session_id}_{seq}
        text: string
        category: enum[行业基础, 岗位专业, 公司特异, 简历追问, 行为面试]
        difficulty_label: enum[基础, 进阶, 高频]
        exam_point: [string]
        source_ref: string     # 出题依据（JD条目 / 面经 / 简历bullet_id）
        follow_up_hints: [string]
        practiced: false

constraints:
  - 冷启动（无 memory）时退化为纯 JD + 画像生成，效果已优于通用题库
  - 题目不数字评级，只标难度标签
  - 去重异步执行，不阻塞主流程
```

---

### `interview.session_context`

```yaml
name: interview.session_context
type: tool
execution_target: local
description: |
  将公司画像、题库、简历快照注入当前 session 上下文，
  主模型据此扮演面试官角色。
  面经搜索驱动题目优先级排列（面经高频题前置）。

parameters:
  merged_profile: object
  question_bank: object       # interview.question_bank_gen 输出
  resume_snapshot_id: string
  face_frequency_map: object  # 面经高频题频率

returns:
  session_context_patch:      # 注入到 session job_context 的增量字段
    active_profile: object
    question_bank_state:
      ordered_questions: [question_id]   # 三维排序后的出题顺序
      current_idx: 0
      practiced_ids: []
    resume_snapshot_id: string
  interviewer_persona: string  # 注入主模型的角色扮演 prompt 片段

constraints:
  - 注入后主模型按 ordered_questions 顺序出题，追问 ≤ 3 层
  - 面经与 JD 无关的高频题（如"你最大缺点"）纳入而不过滤
  - 面经 TTL=7天，过期后题库需主动失效重建
```

---

### `answer.alignment_check`

```yaml
name: answer.alignment_check
type: tool
execution_target: local
description: |