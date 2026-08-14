| P1 | **简历-问题语义关联** | 复盘"这题在追问简历哪条"是闭环核心价值，但语义匹配难 | 不受端云架构影响 | 设置置信度阈值，低于阈值不强制关联 |
| P2 | **8kHz ASR 模型选型** | Whisper 对电话窄带支持差，需要专项模型 | **云侧 Claw 承接，风险降低**：云侧有完整 Python 环境，可直接调用讯飞/阿里云 API | 云侧 Claw 优先集成讯飞电话语音 ASR；提前测试转写准确率 |
| P2 | **面经时效性过滤** | 旧面经误导题库生成 | 云侧 Claw 抓取时可直接获取帖子发布时间，过滤更精准 | 云侧 Adapter 提取 `publish_date`；dispatcher 按 TTL 7天自动失效 |
| P3 | **通知误触发** | 招聘平台促销 vs 真实面试通知混淆 | 不受端云架构影响 | 强信号词规则 + 小模型二分类 |
| P3 | **云侧渲染结果回传体积** | PDF/DOCX 文件通过端云通信回传，大文件传输延迟 | **端云协作新增风险** | 文件压缩后传输；MD/HTML 格式端侧直接渲染，PDF/DOCX 按需生成不默认下发 |

---

## 九、参数设计

本章区分两类参数的归属与生命周期，避免各团队边界模糊。

### 9.1 Open Claw 共享参数（session context）

> 这些参数存活于**当前对话 session**，由各 Skill 写入后，主模型（龙虾大脑）可直接读取并用于决策和回复生成。主模型**不直接访问**持久化存储。

| 参数名 | 类型 | 写入时机 | 写入 Skill | 主要用途 |
| --- | --- | --- | --- | --- |
| `session.jd` | object | JD 录入后 | `jd.extract` (0-2a/b/c) | 改写约束、题库生成、复盘对照基准 |
| `session.jd.jd_id` | string | 同上 | 同上 | 跨 Skill 引用 JD 的稳定 key |
| `session.jd.skills[]` | string[] | 同上 | 同上 | 技能关键词，改写/题库加权 |
| `session.jd.explicit_req[]` | string[] | 同上 | 同上 | 显性要求，改写必须命中 |
| `session.jd.hidden_req[]` | string[] | 同上 | 同上 | 隐性要求（来自面经补充） |
| `session.jd.team_style` | string | 同上 | 同上 | 团队文化风格描述 |
| `session.active_profile` | object | 画像构建后 | `company.profile_build` (0-4) | 改写风格参考、题库偏向、复盘评估视角 |
| `session.active_profile.company_base` | object | 同上 | 同上 | 公司层面特质（核心价值观、面试雷区） |
| `session.active_profile.role_flavor` | object | 同上 | 同上 | 岗位层面偏向（技术深度/业务广度等） |
| `session.resume_snapshot_id` | string | 面试 session 开始时 | `resume.version_control` (1-2) | 锁定复盘时使用的简历版本（不随后续改写变化） |
| `session.question_bank` | object | 题库生成后 | `interview.question_bank_gen` (2-3) | 主模型扮演面试官时的出题依据 |
| `session.question_bank.current_idx` | int | 模拟面试中 | `interview.session_context` (2-4) | 追踪当前题目位置 |
| `session.question_bank.follow_up_depth` | int | 模拟面试中 | 同上 | 当前追问层数（上限 2） |
| `session.interview_round` | string | 通知解析后 | `notify.parse` (2-1b) | 区分初筛/技术/HR面，影响题库偏向 |

**设计原则**

- 所有共享参数以 `session.` 为命名空间，避免与 Open Claw 框架内置参数冲突
- Skill 只负责**写入**；读取由主模型在 system prompt 中完成，无需算法团队处理
- session 结束（对话关闭）后共享参数**不持久化**，需持久化的数据走 9.2 存储接口

---

### 9.2 项目独有参数（持久化存储）

> 这些参数由各 Skill 内部读写，存活于**用户生命周期**，主模型不直接访问。Skill 需要向主模型汇报时，将摘要写入 session context（见 9.1）。

#### A. 求职经验池 `memory.job_journey`

```plaintext
{
  "user_id": "u_001",
  "bullet_performance": {
    "<bullet_id>": {
      "overall_tag": "keep|strengthen|delete",
      "recommend_action": "string",          // 给用户看的建议文案
      "sessions": [
        {
          "session_id": "string",
          "company": "string",
          "role": "string",
          "event": "rewrite|mock_answer|real_interview",
          "score": 0,                         // 0-2，内部评分，用户不可见
          "note": "string"
        }
      ]
    }
  },
  "weak_dimensions": {
    "<dimension_name>": {
      "count": 0,                             // 触发次数
      "trigger_intensive": false              // count>=3 时触发专项强化包
    }
  },
  "strong_tags": ["string"],                  // 高置信强项标签
  "high_freq_questions": [
    {
      "text": "string",
      "company": "string",
      "role": "string",
      "frequency": 0
    }
  ],
  "session_history": [
    {
      "session_id": "string",
      "company": "string",
      "role": "string",
      "type": "mock|real",
      "resume_snapshot_id": "string",
      "timestamp": "ISO8601"
    }
  ]
}
```

**所有者**：记忆相关
**读写接口**：统一通过 `memory.job_journey.read(user_id, keys[])` / `memory.job_journey.write(user_id, patch)` — Skill 不直接操作存储层

---

#### B. 简历版本存储

```plaintext
// 版本节点（每次改写产生一个）
{
  "resume_id": "res_001",
  "version": 3,
  "parent_id": "res_001_v2",                 // null 表示原始上传版
  "based_on_jd_id": "jd_001",
  "created_at": "ISO8601",
  "bullets": [
    {
      "bullet_id": "b_001",                  // 全局稳定，跨版本不变
      "original_text": "string",             // v0 原文，永不修改
      "current_text": "string",              // 本版本文本
      "rewrite_reason": "string",
      "is_deleted": false                    // 软删除，不物理删除
    }
  ]
}

// 快照（面试 session 开始时 fork，只读）
{
  "resume_snapshot_id": "rv_snap_001",
  "forked_from": "res_001_v3",
  "forked_at": "ISO8601",
  "session_id": "string",
  "bullets": [ /* 与版本节点 bullets 相同结构，冻结不可变 */ ]
}
```

**所有者**：记忆相关
**关键约束**：`bullet_id` 在用户首次上传简历时生成，后续所有版本和快照**不得重新生成**

---

#### C. 搜索缓存 `search.cache`

```plaintext
{
  "key": "<hash(search_type + company_canonical + role)>",
  "search_type": "jd_platform|mianJing|resume_sample|company_tendency",
  "results": [
    {
      "source": "小红书|牛客|GitHub|脉脉|Boss直聘|...",
      "content": "string",
      "url": "string",
      "publish_date": "ISO8601",
      "quality_score": 0.0                   // 0-1，内部过滤用
    }
  ],
  "cached_at": "ISO8601",
  "ttl_days": 7,                             // jd=30, 面经=7, 简历样本=14, 公司倾向=30
  "expired": false
}
```

**所有者**：记忆相关（缓存层） + 文档问答相关（路由/聚合层）
**TTL 规则**：过期后 `search.dispatcher` 重新拉取并覆盖；题库依赖面经缓存，面经 TTL 到期后题库需主动失效重建

---

#### D. 题库存储 `interview.question_bank`

```plaintext
{
  "bank_id": "bank_001",
  "company_canonical": "string",
  "role": "string",
  "jd_id": "string",
  "generated_at": "ISO8601",
  "face_frequency_map": {                    // 面经来源频率统计
    "<question_text_hash>": { "count": 0, "sample_text": "string" }
  },
  "questions": [
    {
      "id": "q_001",
      "text": "string",
      "source": "mianJing|jd_inferred|memory_weak",
      "frequency": 0,                        // 面经命中次数
      "priority": 0,                         // 综合排序分
      "practiced": false,                    // 是否已在模拟中练习过
      "practiced_at": null
    }
  ]
}
```

**所有者**：文档问答相关（生成）+ 记忆相关（持久化）
**失效条件**：依赖的面经缓存 TTL 到期 → 整个 `question_bank` 标记 `stale=true` → 下次进入面试准备场景时重建

---

#### E. 错题本 `mistake.book`

```plaintext
{
  "mistake_id": "mk_001",
  "session_id": "string",
  "bullet_id": "string",                     // null 表示与简历无明确关联
  "question_text": "string",
  "orig_answer": "string",                   // 用户实际回答（来自 ASR）
  "gap": "string",                           // 与高分答案的差距描述
  "high_score_ref": "string",               // 参考高分答法
  "severity": 2,                             // 0=轻微/1=中等/2=严重
  "created_at": "ISO8601",
  "review_schedule": {
    "next_review_date": "ISO8601",
    "interval_days": 1,                      // SM-2 当前间隔
    "priority": 0
  }
}
```

**所有者**：记忆相关
**与 bullet_id 关联**：通过 `3-5 语义关联` 模块置信度 ≥ 0.7 才写入；低于阈值则 `bullet_id=null`

---

#### F. 内部评分（不对用户展示）

| 字段 | 范围 | 用途 | 所在模块 |
| --- | --- | --- | --- |
| `internal_severity` | 0–2 | 答题严重程度，驱动弱点维度计数 | `answer.alignment_check` (2-5) |
| `confidence` | 0.0–1.0 | 简历-问题语义匹配置信度，<0.7 不关联 | `dialog.segment` 关联层 (3-5) |
| `quality_score` | 0.0–1.0 | 搜索结果内容质量，过滤低质小红书帖 | `search.dispatcher` (共-2) |

---

### 9.3 参数边界示意图

```plaintext
主模型（龙虾大脑）
    │  读  session.jd / session.active_profile
    │  读  session.resume_snapshot_id / session.question_bank
    │  ← Skill 写入 session context ─────────────────────────┐
    │                                                          │
    ▼                                                  各 Skill 内部
  用户对话界面                                         ┌───────────────┐
                                                       │ 读写持久化存储 │
                                                       │  A. 经验池    │
                                                       │  B. 简历版本  │
                                                       │  C. 搜索缓存  │