          "trigger_intensive": false
        }
      },
      "strong_tags": ["string"],
      "bullet_performance": {
        "{bullet_id}": {
          "overall_tag": "强项 | 待优化 | 风险项",
          "recommend_action": "保留突出 | 优化表述 | 降权",
          "sessions": [
            { "session_id": "string", "signal": "被追问 | 被挖坑 | 未被提及 | 获好评" }
          ]
        }
      }
    },
    "mistake_book": {
      "entries": [
        {
          "question_id": "string",
          "question_text": "string",
          "exam_point": ["string"],
          "source": "mock | real",
          "mastery": "unknown | learning | mastered",
          "severity": 1,
          "bullet_id": "string | null",
          "last_reviewed": "timestamp",
          "next_review_ms": 1234567890
        }
      ]
    },
    "resume_snapshots": {
      "{snapshot_id}": {
        "resume_id": "string",
        "session_id": "string",
        "based_on_version": "string",
        "created_at": "timestamp",
        "immutable": true
      }
    }
  }
}
```

**关键约束：**

- `bullet_id` 在 `resume.parse` 时生成，格式 `b_{resume_id}_{seq}`，全生命周期不可变
- `resume_snapshots` 写入后不可修改，标记 `immutable: true`
- 所有数据存储在本机加密文件系统，不上云

---

## 九、Session job_context 扩展

> 在现有 session 元数据中新增 `job_context` 字段，不修改 session 其他结构。

```json
{
  "job_context": {
    "active_jd_id": "jd_bytedance_algo_20260602",
    "active_profile_id": "prof_bytedance_algo_xxx",
    "resume_snapshot_id": "snap_resume_001_sess_001",
    "question_bank_state": {
      "ordered_questions": ["q_001", "q_002", "q_003"],
      "current_idx": 0,
      "practiced_ids": []
    },
    "interviewer_persona": "..."
  }
}
```

**注入时机：**

| 时机 | 写入字段 |
| --- | --- |
| `context_bootstrap` 完成 | `active_jd_id` + `active_profile_id` |
| `resume.snapshot_create` 完成 | `resume_snapshot_id` |
| `interview.session_context` 完成 | `question_bank_state` + `interviewer_persona` |
| 每轮 `answer.alignment_check` 后 | `question_bank_state.current_idx` + `practiced_ids` |

---

## 附：工具依赖关系一览

```plaintext
user_input
    │
    ▼
company.normalize ──────────────────────────────────┐
    │                                                │
    ▼                                                │
search.dispatcher ←─────────────────────────────────┤
    │ (interview_exp / resume_sample / company_style)│
    ▼                                                │
company.profile_build ──────────────────────────────┤
    │                                                │
    ├──→ jd.parse                                    │
    │                                                │ memory读写
    ├──→ resume.parse                                │
    │        │                                       │
    │        ▼                                       │
    │    resume.star_split                           │
    │        │                                       │
    │        ▼                                       │
    │    resume.align_diagnose                       │
    │        │                                       │
    │        ▼                                       │
    │    resume.rewrite_bullet ←── bullet_performance│
    │        │                                       │
    │        ▼                                       │
    │    resume.tailor_compose                       │
    │        │                                       │
    │        ▼                                       │
    │    resume.diff_render → resume.render(cloud)   │
    │        │                                       │
    │        ▼                                       │
    │    resume.snapshot_create                      │
    │                                                │
    ├──→ interview.question_bank_gen                 │
    │        │                                       │
    │        ▼                                       │
    │    interview.session_context                   │
    │        │                                       │
    │        ▼                                       │
    │    answer.alignment_check ─────────────────────┤
    │                                                │
    └──→ audio.asr_batch(cloud)                      │
             │                                       │
             ▼                                       │
         dialog.segment                             │
             │                                       │
             ▼                                       │
         answer.review                              │
             │                                       │
             ▼                                       │
         mistake.book_build ─────────────────────────┤
             │                                       │
             ▼                                       │
         mistake.spaced_review → IScheduler         │
             │                                       │
             ▼                                       │
         memory.bullet_performance.update ───────────┘
```

# 已有技能

[https://docs.vivo.xyz/s/LZCWCOHd](https://docs.vivo.xyz/s/LZCWCOHd) 邀请您加入文档协作【「简历面试」Skill工具梳理】

### ⚠️ 已有但覆盖不全

| 工具名 | 说明 |
| --- | --- |
| `web_search` | 通用检索可用；小红书 / 牛客 / 看准 / BOSS / 脉脉等专业求职平台需**云侧 Claw  web_fetch 或者后处理来支持** |

# 安全合规