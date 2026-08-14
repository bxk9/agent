  对用户的单条回答做对齐式即时反馈。
  以公司画像为固定 rubric 逐维度判断（字节看 ownership/量化，腾讯看协同/稳重）。
  内部生成轻量严重程度分用于 memory 写入，对用户只展示文字反馈，不打分。

parameters:
  user_answer: string
  question_id: string
  merged_profile: object      # 从 session job_context 取，保证同 session 一致

returns:
  aligned_points: [string]    # 覆盖了画像的哪些维度
  misaligned_points: [string] # 漏了哪些维度
  improvement_direction: string
  internal_severity: int      # 0=良好 1=有瑕疵 2=明显失分（仅用于 memory，不展示）
  question_id: string

constraints:
  - 同 session 内多轮反馈标准一致（session 锁定画像）
  - 不输出数字评分给用户
  - internal_severity 写入 memory，用于题库后续加权
```

---

## 四、复盘类工具

### `dialog.segment`

```yaml
name: dialog.segment
type: tool
execution_target: local
description: |
  将 ASR 转写文本按说话人/语义边界切分为 Q-A 对。
  处理多面试官/一问多题/追问嵌套等复杂情况。

parameters:
  transcript:
    - speaker: string      # "interviewer" | "candidate"
      timestamp: string
      text: string

returns:
  qa_pairs:
    - q_text: string
      q_timestamp: string
      a_text: string
      a_timestamp: string
      question_boundary_confident: bool  # 边界置信度低时标 false

constraints:
  - question_boundary_confident=false 的 pair 在展示时加"边界不确定"提示
  - 一问多题时拆分为多个 qa_pair，a_text 对应同一段回答
```

---

### `answer.review`

```yaml
name: answer.review
type: tool
execution_target: local
description: |
  三重对照复盘：对每个 Q-A pair 对照 JD、当时投出的简历快照（非最新版）、公司画像
  做诊断，生成高分参考答案。
  长 context 时分批处理（每批 ≤ 8 个 qa_pair）。

parameters:
  qa_pairs: array
  jd_structured: object
  resume_snapshot_id: string    # 必须取快照版，不取最新版
  merged_profile: object

returns:
  review:
    - question_id: string
      original_answer: string
      covered: [string]
      missed: [string]
      diagnosis: string
      reanswer_ref: string       # "如果重答会这样答"
      high_score_ref: string     # 高分答案参考
      timestamp_link: string     # 可回听原话
      severity: int              # 0-2，写入 memory

constraints:
  - 简历字段必须取 resume_snapshot_id 对应的快照，而非最新版
  - severity 写入 memory，不对用户展示数字
  - 长 context 分批处理时，批间保持 session 上下文一致
```

---

### `mistake.book_build`

```yaml
name: mistake.book_build
type: tool
execution_target: local
description: |
  将复盘结果中 severity >= 1 的条目写入错题本，
  关联 bullet_id，按考点聚类，生成 SM-2 初始复习节点。

parameters:
  review: array              # answer.review 输出
  bullet_id_map:             # question_id → bullet_id（可为空）
    question_id: bullet_id

returns:
  mistake_entries:
    - question_id: string
      question_text: string
      exam_point: [string]
      source: enum[mock, real]
      mastery: unknown        # 初始状态
      bullet_id: string       # 可为空
      severity: int
  sm2_initial_schedule:      # 初始复习时间（SM-2 首次节点）
    - question_id: string
      next_review_ms: int

constraints:
  - severity=0 的条目不写入错题本（答对了不入库）
  - bullet_id 关联置信度 < 0.7 时不强行关联（防污染经验池）
```

---

### `mistake.spaced_review`

```yaml
name: mistake.spaced_review
type: tool
execution_target: local
description: |
  基于 SM-2 算法为错题本中的题目生成自适应复习排程，
  并通过 IScheduler(EVENT + timestamp condition) 注册定时触发。
  用户完成复习后调用 mistake.update_mastery 更新掌握度，触发下次节点重算。

parameters:
  mistake_book: array
  weak_dimensions: object     # memory 中用户历史弱项维度
  search_results: object      # search.dispatcher(interview_exp) 公司倾向数据（可选）

returns:
  schedule:
    - question_id: string
      next_review_ms: int
      interval_days: int
      priority: enum[紧急, 正常, 已掌握]
  advice:
    - content: string
      source_ref: string      # 引用来源（防伪造）

constraints:
  - SM-2 首次间隔 1 天，之后按答题质量动态调整
  - priority=已掌握 的题目不再注册新 IScheduler 任务
  - advice 每条必须有 source_ref，无来源时不生成建议
```

---

### `mistake.update_mastery`

```yaml
name: mistake.update_mastery
type: tool
execution_target: local
description: |
  用户完成一道错题复习后更新掌握度，触发 SM-2 下次节点重算，
  重新向 IScheduler 注册新的定时任务。

parameters:
  question_id: string
  rating: enum[完全不会, 想起来了, 熟练]

returns:
  new_mastery: enum[unknown, learning, mastered]
  next_review_ms: int        # 0 表示已掌握，不再安排
  updated_interval_days: int
```

---

---

## 七、复合 Skill（多工具编排）

> 复合 Skill 与原子 Skill 的接口类型相同（`type: skill`），区别仅在于内部实现会编排多个 Tool。 主模型读 `description` dispatch 这些 Skill 时，不感知其内部是一步还是多步。

### `context_bootstrap`（公司画像构建）

```yaml
name: context_bootstrap
type: skill
execution_target: local
description: |
  当用户首次明确提到目标公司和岗位时触发（如"我要投字节算法岗"）。
  若 session 中已存在该公司+岗位的画像则跳过，直接复用缓存。

steps:
  1. company.normalize(company_raw)
  2. memory.read(key="{company_canonical}_{role}")  # 缓存命中则直接返回
  3. jd.parse(input)                                # 如果用户提供了 JD
  4. search.dispatcher(type=interview_exp, ...)
  5. search.dispatcher(type=company_style, ...)
  6. company.profile_build(...)
  7. memory.write(profile)

parameters:
  company: string     # 用户原始输入
  role: string
  jd_input: string | image | null

returns:
  profile_id: string
  merged_profile: object
  from_cache: bool
```

---

### `resume_tailor`（简历改写流水线）

```yaml
name: resume_tailor
type: skill
execution_target: local
description: |
  用户提供简历和目标岗位，执行完整简历改写流水线。
  先做诊断展示给用户确认，用户确认后再执行改写和渲染。

steps:
  1. context_bootstrap(company, role, jd)  # 确保画像就绪
  2. resume.parse(resume_file)
  3. resume.star_split(bullets)
  4. resume.align_diagnose(star_bullets, jd, profile)
  5. [展示四象限诊断，等待用户确认]
  6. search.dispatcher(type=resume_sample, ...)
  7. resume.rewrite_bullet(each bullet, ...)      # 并行处理
  8. resume.tailor_compose(bullets, ...)
  9. resume.diff_render(before, after, mode=client)
  10. file.save_to_local(resume_structured)
  11. memory.write(version_id, jd_id)

parameters:
  resume_file: string
  company: string
  role: string
  jd_input: string | image | null
```

---

### `interview_simulate`（模拟面试）

```yaml
name: interview_simulate
type: skill
execution_target: local
description: |
  用户发起模拟面试时触发。基于公司画像和面经生成专属题库，
  主模型扮演面试官进行多轮对话，逐题提供对齐式反馈，写入记忆。

steps:
  1. context_bootstrap(company, role)      # 确保画像就绪
  2. resume.snapshot_create(current_resume, session_id)
  3. search.dispatcher(type=interview_exp, ...)
  4. interview.question_bank_gen(jd, snapshot, profile, memory.weak_dims, face_freq_map)
  5. interview.session_context(profile, question_bank, snapshot_id)
  6. [主模型进入面试官角色，多轮对话]
  7. answer.alignment_check(each answer)   # 每轮回答后即时反馈
  8. [面试结束]
  9. memory.write(weak_dims, strong_tags, question_bank.practiced_ids)

parameters:
  company: string
  role: string
  interview_round: enum[一面, 二面, 终面, HR面]
  mode: enum[practice, realistic]    # practice=边答边反馈，realistic=全程后反馈
```

---

### `interview_debrief`（面试复盘）

```yaml
name: interview_debrief
type: skill
execution_target: local
description: |
  真实面试后触发复盘流水线。
  自动匹配录音 → 云侧 ASR → 切分 Q-A → 三重对照复盘 → 写错题本 → 注册复习计划。

steps:
  1. calendar.read(time_range) → 获取 jd_id + session_id
  2. record.fetch_local(calendar_event_time, jd_id)  # ⚠️ 需端侧工程支持
  3. audio.asr_batch(recording_path)           # cloud execution
  4. dialog.segment(transcript)
  5. memory.read(jd_id, snapshot_id, profile)
  6. answer.review(qa_pairs, jd, snapshot, profile)  # 分批并行，≤4并发
  7. mistake.book_build(review, bullet_id_map)
  8. memory.bullet_performance.update(bullet_id, signal)
  9. mistake.spaced_review(mistake_book, weak_dims)  # 注册 IScheduler 定时任务
  10. memory.write(updated job_journey, weak_dims)

parameters:
  trigger: enum[manual, calendar_event]    # 用户手动发起 或 日历事件触发
  recording_path: string                   # trigger=manual 时用户手动指定
```

---

## 八、Memory Schema

> 仅扩展 `job_seeker` namespace，不影响现有 memory 数据。

```json
{
  "job_seeker": {
    "job_journey": {
      "{company_canonical}_{role}": {
        "profile_id": "string",
        "company_profile": { "...": "TTL=14d" },
        "jd_structured": {},
        "resume_versions": [
          { "version_id": "string", "file_path": "string", "based_on_jd_id": "string" }
        ],
        "interview_sessions": [
          {
            "session_id": "string",
            "snapshot_id": "string",
            "type": "mock | real",
            "result": "in_progress | offer | rejected | pending",
            "date": "string"
          }
        ]
      }
    },
    "user_profile": {
      "weak_dimensions": {
        "{dimension_name}": {
          "count": 3,