| 0-2b | 通用前置 | JD 截图解析 `jd.extract` | OCR + 视觉理解 | 截图倾斜/低质需预处理 | 图片问答相关 | 入: `jd_image`; 中间: OCR文本; 出→session: `jd{…}` (同0-2a) — **写入共享session** |
| 0-2c | 通用前置 | JD 平台 API Adapter → **云侧 Claw 浏览器抓取** | 浏览器自动化 + Schema 映射 | 平台登录态维护；反爬策略 | **云侧 Claw** | 云侧 Claw 登录 BOSS/拉勾/脉脉，浏览器渲染后提取 JD 文本；出→session: `jd{…}` (同schema) — **写入共享session** |
| 0-3 | 通用前置 | 联网面经检索 `web.search` | 信息检索 + 摘要 | 旧面经误导，需时间过滤 | 文档问答相关 | 入: `{company_canonical, role}`; 出: `search_results[{source, content, timestamp, quality_score}]` — **项目独有，经dispatcher缓存** |
| 0-4 | 通用前置 | 分层画像构建 `company.profile_build/cache` | 知识合成 + 二维KV缓存 | 二维缓存命中逻辑复杂 | 记忆相关 | 缓存key: `company_canonical` × `role`(二维拆分); 出→session: `active_profile{company_base, role_flavor, 合成画像{核心特质[], 雷区[], 面试风格}}` — **写入共享session** |
| 1-1 | 简历包装 | 简历解析 `resume.parse` | 文档解析 + 结构化抽取 | `bullet_id` 必须在此生成且全局稳定 | 文档问答相关 | 入: `resume_file`; 出: `{resume_id, bullets[{bullet_id, original_text}], education[], skills[]}` — **项目独有** |
| 1-2 | 简历包装 | 简历存储与版本管理 | 版本链 + 快照归档 | 快照fork时机需明确 | 记忆相关 | 存储: `{resume_id, version, parent_id, based_on_jd_id, bullets[]}`; 快照写→session: `resume_snapshot_id` — **存储项目独有，snapshot_id写入共享session** |
| 1-3 | 简历包装 | 样本风格检索 `resume.exemplar_retrieval` | 检索 + 风格抽象 | 风格量化模糊，LLM一致性差 | 文档问答相关 | 入: `{company_canonical, role}`; 出: `style_json{avg_len, quantification_ratio, verb_style, structure_pattern}` — **项目独有，与1-4/1-5共享缓存** |
| 1-4 | 简历包装 | 经历改写 `resume.rewrite_bullet` | 受限文本生成 | LLM捏造数字；小红书帖质量 | 文档问答相关 | 入: `{bullet_id, original_text, session.jd, session.active_profile, style_json, memory.bullet_performance[bullet_id]}`; 出: `{rewritten_text, rewrite_reason}`; 校验: 数字exact match — **混合：读共享session，写项目存储** |
| 1-5 | 简历包装 | 简历重排 `resume.tailor_compose` | 四维加权排序 | 小红书维度权重过高风险 | 文档问答相关 & 记忆相关 | 入: `{bullets[], jd_weight, profile_score, sample_frequency, memory_score}`; 出: `sorted_bullets[]`; 各维权重: `w1/w2/w3/w4`(初期等权) — **项目独有** |
| 1-6 | 简历包装 | Diff 渲染 `resume.diff_render` | 文本比对 + 双模式渲染 | 模式B Track Changes XML复杂 | 文档问答相关 | 入: `{bullets_before[], bullets_after[], rewrite_reasons[], diff_mode}`; `diff_mode`: `client`→HTML高亮 / `docx`→带批注DOCX — **项目独有** |
| 1-7 | 简历包装 | 多格式渲染 `resume.render` | 文档模板渲染 | 中文PDF字体嵌入细节 | **云侧 Claw** | 手机端侧触发，云侧 Claw 执行渲染（WeasyPrint/python-docx），二进制文件流回传端侧供下载；端侧仅展示 MD/HTML 预览 — **云侧执行，端侧接收** |
| 2-1a | 面试准备 | 面试通知分类 `notify.capture` | 文本二分类 | 促销通知误触发 | 文档问答相关 | 入: `sms_text`; 出: `{is_interview:bool, confidence:float}`; 阈值: confidence>0.8 才触发NER — **项目独有** |
| 2-1b | 面试准备 | 通知信息抽取 `notify.parse` | NER + 时间推算 | 相对时间需结合设备时间推算 | 文档问答相关 | 入: `{sms_text, device_now}`; 出: `{time_abs, company_raw, role, interview_type, link}` — **项目独有** |
| 2-2 | 面试准备 | 日历写入 `calendar.write` | Android 系统API | 必须写入jd_id作为复盘入口 | ⚠️ 待定·端能力（仍需端侧工程） | 入: `{time_abs, company, role, interview_type, jd_id, session_id}`; 出: `calendar_event_id`; 此项仍需 Android 工程支持，云侧 Claw 无法替代 — **项目独有** |
| 2-3 | 面试准备 | 题库生成 `interview.question_bank_gen` | 条件生成 + 去重 | 冷启动退化；去重需embedding | 文档问答相关 | 入: `{session.jd, resume_snapshot_id, session.active_profile, memory.weak_dimensions, face_frequency_map}`; 出存储: `question_bank{questions[{id, text, source, frequency, priority, practiced:false}]}` — **混合：读共享session，写项目存储** |
| 2-4 | 面试准备 | 模拟面试 `interview.session_context` | 面经搜索+排题+上下文注入 | 题库已练/未练需区分 | 文档问答相关 & 记忆相关 | 注入→session: `{session.active_profile, question_bank, current_idx:0, follow_up_depth:0}`; 更新: `question_bank.practiced_ids[]`; 写memory: 本场答题评分 — **写入共享session，同时维护项目存储** |
| 2-5 | 面试准备 | 对齐式即时反馈 `answer.alignment_check` | rubric评估 | 内部评分(0-2)对用户不展示 | 文档问答相关 & 记忆相关 | 入: `{user_answer, session.active_profile}`; 出(用户侧): `{aligned[], misaligned[], direction}`; 出(内部): `internal_severity(0-2)` → 写memory — **混合：读共享session，internal_severity为项目独有** |
| 3-1 | 复盘 | 录音自动匹配 `record.fetch_local` | 文件检索 + 时间匹配 | 双轨录制需确认 | ⚠️ 待定·端能力（仍需端侧工程） | 入: `{calendar_event_time, jd_id}`; 匹配容差: ±10分钟; 出: `recording_path`; 优先长度>30分钟; 此项仍需 Android 工程支持 — **项目独有** |
| 3-2 | 复盘 | ASR 转写 `audio.asr_batch` | 语音识别 + 说话人分离 | 8kHz窄带质量 | **云侧 Claw** | 手机端将录音文件上传至云侧 Claw，云侧调用讯飞/阿里云 8kHz 专项 ASR + pyannote 说话人分离，转写结果回传端侧；端侧无需本地 ASR 能力 — **云侧执行，端侧接收** |
| 3-3 | 复盘 | 对话切分 `dialog.segment` | 话语边界 + Q-A配对 | 多面试官/一问多题 | 文档问答相关 | 入: `transcript[]`; 出: `qa_pairs[{q, a, question_boundary_confident:bool}]` — **项目独有** |
| 3-4 | 复盘 | 三重对照复盘 `answer.review` | 多维评估 + 对比生成 | 长context分批；简历必须取快照版 | 文档问答相关 | 入: `{qa_pairs[], session.jd, resume_snapshot(按snapshot_id取), session.active_profile}`; 出: `review[{diagnosis, high_score_ref, diff_vs_original}]` — **混合：读共享session，输出为项目独有** |
| 3-5 | 复盘 | 简历-问题语义关联 | 跨文档语义匹配 | 误关联污染经验池 | 文档问答相关 & 记忆相关 | 入: `{question_text, bullets[]}`; 出: `{bullet_id, confidence:float}`; 阈值: confidence<0.7则不关联 — **项目独有** |
| 3-6 | 复盘 | 错题本 `mistake.book_build` | 结构化组织 + 持久化 | 需与bullet_id关联 | 记忆相关 | 入: `{review[], bullet_id_map}`; 存储: `mistake[{失分点, orig_answer, gap, high_score_ref, severity(0-2), bullet_id}]` — **项目独有** |
| 3-7 | 复盘 | 复盘优化计划 `mistake.spaced_review` | 搜索增强 + SM-2调度 | 冷门公司无缓存延迟；引用来源防伪造 | 记忆相关 & 文档问答相关 | 入: `{mistake_book, search_results(公司倾向+JD+面经), memory.weak_dimensions}`; 出: `{advice[{content, source_ref}], schedule[{topic, next_date, interval_days, priority}]}` — **项目独有** |
| 共-1 | 三场景共用 | 求职经验池 `memory.job_journey` | 跨session持久化 | Schema需先于所有场景定好 | 记忆相关 | `{bullet_performance{bullet_id:{overall_tag, recommend_action, sessions[]}}, weak_dimensions{name:{count, trigger_intensive}}, strong_tags[], high_freq_questions[], session_history[]}` — **项目独有** |
| 共-2 | 三场景共用 | 多源搜索 `search.dispatcher` | 搜索路由 + 聚合 + 缓存 | 小红书内容质量过滤 | 文档问答相关 & 记忆相关 | 入: `{search_type, company, role, source_list[]}`; 缓存key: `hash(type+company+role)`; 出: `{results[{source, content, timestamp, quality_score}], from_cache:bool}` — **项目独有** |

---

### 承接方工作量汇总

| 承接方 | 技术点数 | 主要工作 |
| --- | --- | --- |
| **文档问答相关** | 13 个 | JD文本解析、面经检索、简历解析/改写/重排/Diff、通知分类/NER、题库生成、模拟面试Skill定义+上下文注入、对齐反馈、对话切分、三重复盘、语义关联、**多源搜索路由+结果聚合** |
| **图片问答相关** | 1 个 | JD 截图解析（OCR + Vision LLM） |
| **记忆相关** | 8 个 | **公司名归一化**（移入缓存层）、分层画像缓存、简历版本管理、经验池读写、错题本、复习计划调度；与文档问答相关联合承接 3 个交叉点 |
| **云侧 Claw（新增层）** | 4 个 | ① JD 平台浏览器抓取（替代 API Adapter）② 重量级 ASR 转写+说话人分离 ③ 多格式简历渲染（PDF/DOCX）④ 三方平台内容自动采集（小红书/牛客/脉脉/看准）；**端侧发起调起，云侧执行后回传结果** |
| **各承接团队各自负责** | 1 个（贯穿全部） | Skill 定义设计：每个团队负责自己模块的 Skill 触发描述编写；额外增加端云调起协议的 Skill 描述 |
| **待定·端能力（仍需工程支持）** | 2 个 | 日历写入、通话录音文件匹配（Android ContentProvider，云侧无法替代，需 Android 工程介入） |

---

## 二、技术全景（按技术域分类）

产品涉及的算法能力可归为 6 个技术域，后续各场景的拆分均落回这 6 类：

| 技术域 | 涉及场景 | 核心难点 |
| --- | --- | --- |
| **多模态理解 & 信息抽取** | 场景0、场景2 | JD 录入（截图/API 双路）、通知 NER |
| **检索增强生成（RAG）** | 场景0、场景1 | 面经检索质量、样本风格量化 |
| **受限文本生成** | 场景1、场景2、场景3 | 改写不捏造事实、对齐画像风格 |