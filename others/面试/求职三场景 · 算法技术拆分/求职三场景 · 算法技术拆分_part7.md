│  JD Source:                    面经 Source:                       │
│  ├─ CloudBossAdapter           ├─ CloudXHSAdapter（小红书）       │
│  │   浏览器登录BOSS直聘         │   浏览器登录小红书               │
│  ├─ CloudLaGouAdapter          ├─ CloudNiuKeAdapter（牛客）       │
│  └─ 提取JD文本 → 回传          └─ 提取面经帖子 → 回传            │
│                                                                   │
│  简历样本 Source:              公司倾向 Source:                   │
│  ├─ CloudXHSAdapter            ├─ CloudXHSAdapter                 │
│  │   搜索"[公司][岗位]简历"     │   搜索"[公司]文化/入职感受"     │
│  └─ 提取帖子内容 → 回传        ├─ CloudMaimaiAdapter（脉脉）      │
│                                └─ 提取公司评价 → 回传            │
│                                                                   │
│  统一回传格式：{ source, content, url, publish_date }            │
└──────────────────────────────────────────────────────────────────┘
       │ 结果回传手机端
       ▼
  统一 Result Schema 返回给调用方 Skill
  { source, content, timestamp, quality_score, via_cloud: bool }
```

### 各技术点与 search.dispatcher 的关系

| 原技术点 | 调用 search.dispatcher 的方式 | 对原技术点的影响 |
| --- | --- | --- |
| 0-2a/b/c `jd.extract` | `dispatcher(type=jd, ...)` | 阶段一走 Web 兜底，阶段二插入平台 Adapter，`jd.extract` 本身不感知来源差异 |
| 0-3 `web.search`（面经） | `dispatcher(type=interview_exp, source=[小红书,牛客,看准], company, role)` | 小红书作为主要来源；面经 TTL=7天；质量过滤在 dispatcher 层统一处理 |
| 1-3/1-4 `resume.exemplar_retrieval` + 改写 | `dispatcher(type=resume_sample, source=[小红书,GitHub], company, role)` | **1-4 和 1-5 共享同一次搜索结果**，不重复请求；小红书简历晒单是核心来源 |
| 2-4 题库排序 | `dispatcher(type=interview_exp, source=[小红书,牛客], company, role)` | 与场景0 面经搜索共享缓存（TTL=7天），通常直接命中；驱动题目频率排序 |
| 3-7 复盘优化 | `dispatcher(type=company_style, source=[小红书,脉脉], company)` | 新增公司倾向搜索类型；与公司画像缓存配合，通常直接命中 |

### 核心技术挑战

| 挑战 | 描述 | 建议处理方式 |
| --- | --- | --- |
| **Source 异构** | 三类来源返回格式完全不同（JSON / 非结构化文本 / 摘要） | 每个 Adapter 各自规范化到统一 Result Schema，dispatcher 只处理统一格式 |
| **缓存 key 设计** | query 参数可能有细微差异导致缓存命中失败（"字节" vs "字节跳动"） | key 生成前先经过 0-1 的公司名归一化，保证同一公司的查询命中同一缓存 |
| **质量过滤一致性** | 面经时效性（7天）vs 简历样本稳定性（30天）TTL 完全不同 | dispatcher 按 search_type 读取对应的 TTL 配置，不硬编码 |
| **阶段切换透明** | 阶段二接入平台 API 后，下游 Skill 不应感知变化 | Source 适配器层隔离；`jd.extract` 只调用 dispatcher，不直接引用具体 Adapter |

### 三方信源采集主策略：云侧 Claw 浏览器自动化

> **架构升级后的主链路**（非 Backup）：手机端侧 Claw 可调起云侧 Claw（Law），由云侧在电脑浏览器环境中自动完成平台登录、内容提取，结果回传手机端。三方平台无需开放 API。

```plaintext
┌─────────────────────────────────────────────────────────┐
│               三方信源自动化采集链路（主链路）              │
│                                                         │
│  手机端侧 Claw                                           │
│       │  1. search.dispatcher 缓存未命中                 │
│       │  2. 判断 search_type 需要三方平台内容             │
│       │  3. 向云侧 Claw 发起 browser.automation 任务     │
│       ▼                                                 │
│  云侧 Claw（Law）· 浏览器自动化执行                      │
│       │  4. 打开目标平台浏览器标签（小红书/牛客/脉脉等）  │
│       │  5. 检查登录态 → 已登录跳过，未登录走储存凭据    │
│       │  6. 执行搜索（公司+岗位+关键词，如"字节算法面经"）│
│       │  7. 提取帖子列表 + 正文（Playwright DOM 提取）   │
│       │  8. 质量初筛（过滤营销帖/无内容帖）              │
│       ▼                                                 │
│  结果回传手机端                                          │
│       │  9. 回传 { source, content, url, publish_date } │
│       ▼                                                 │
│  search.dispatcher 统一处理                              │
│       │  10. 规范化 → 质量评分 → 去重 → 写入本地缓存     │
│       └─→  下游 Skill 无感知（via_cloud=true 内部标记）  │
└─────────────────────────────────────────────────────────┘
```

| 项 | 内容 |
| --- | --- |
| **触发条件** | 本地缓存未命中（或 TTL 过期）且 search_type 为三方平台类型 |
| **云侧 Claw 执行能力** | Playwright 浏览器自动化；DOM 提取（无需 OCR）；登录态持久化（加密存储凭据，用户首次授权后自动复用） |
| **数据回传格式** | `{ source, content, url, publish_date }`，与 Web Search 兜底统一 Schema，`dispatcher` 处理层无差异 |
| **平台覆盖** | 小红书（面经/简历晒单/公司文化）、牛客（面经）、看准（公司评价）、脉脉（公司评价）、BOSS直聘/拉勾（JD 文本） |
| **降级策略** | 云侧 Claw 不可达（网络/登录态失效）→ 降级到通用 Web Search 兜底；数据质量不足时提示用户手动粘贴 |
| **隐私边界** | 云侧 Claw 仅读取公开内容（搜索结果页、帖子正文）；不访问用户私信/个人账号数据；登录凭据端侧加密存储，不上传至任何服务器 |

---

## 七、共享基础设施 · `memory.job_journey` 求职经验池

**地位**：三场景闭环的数据飞轮，所有场景都读它、写它，是产品 Pro 模式区别于"通用模式"的核心差异。

### 数据模型

```json
{
  "bullet_performance": {
    "b_001": {
      "text_snapshot": "豆包长文档 D7 +6.2%",
      "sessions": [
        {"session_id": "s_001", "company": "字节", "type": "real",
         "asked": true, "follow_up_depth": 3,
         "severity": 2, "stuck_reason": "归因链路不清",
         "linked_question": "D7提升的归因是什么"}
      ],
      "overall_tag": "weak",            // strong / weak / neutral
      "recommend_action": "weaken"      // keep / strengthen / weaken / delete
    }
  },
  "weak_dimensions": {
    "归因链路": {"count": 2, "trigger_intensive": true},
    "Hallucination阈值机制": {"count": 1}
  },
  "strong_tags": ["RAG两段式架构", "用户共情有数据"],
  "high_freq_questions": [
    {"q": "D7提升归因是什么", "frequency": 3, "best_answer_session": "s_005"}
  ],
  "session_history": [
    {"session_id": "s_001", "type": "real",
     "company": "字节", "role": "算法",
     "resume_snapshot_id": "rv_snap_001",
     "jd_id": "jd_001", "timestamp": "2024-06-03T10:00:00Z"}
  ]
}
```

### 读写时机

| 场景 | 读 | 写 |
| --- | --- | --- |
| **简历包装** | 读各 bullet 历史表现 → 决定排序和改写优先级 | 写"本次改写打标"（哪些 bullet 被强化/弱化） |
| **模拟面试** | 读弱项 → 题库加权；读强项 → 追问预演 | 写本场模拟答题评分（session 结束后批量写） |
| **真实复盘** | 读历史弱点 → 复习计划加权 | 写本场真实表现（弱点+1/强项+1/bullet 待删档） |

### 冷启动策略

| 数据状态 | 降级行为 |
| --- | --- |
| 经验池为空 | 简历排序退化为 JD 关键词权重排序；题库退化为公司画像 + LLM 先验 |
| 1-2 场数据 | 弱点维度开始积累，题库加权开始生效 |
| 3 场以上 | 弱点重复触发专项强化包，简历 recommend_action 开始产生 delete 建议 |

---

## 八、关键技术风险 & 攻关优先级

| 优先级 | 技术点 | 风险描述 | 端云架构影响 | 建议动作 |
| --- | --- | --- | --- | --- |
| P0 | **端云通信稳定性** | 手机端调起云侧 Claw 的通信链路可靠性；网络断开/云侧不可达时的降级策略 | **新增风险（端云协作引入）** | 设计完整的降级链路：云侧不可达 → Web Search 兜底；关键路径（如面试准备）必须有离线预缓存 |
| P0 | **双轨通话录音** | 是否支持直接决定 ASR 和复盘质量上限 | 端侧仍负责录音文件获取；云侧负责 ASR 转写，录音上传隐私合规需确认 | 第一周与拨号器团队确认；明确录音文件仅传云侧 Claw 本地环境，不上第三方服务器 |
| P0 | **bullet_id 稳定性设计** | 整个闭环的索引键，设计错了后续全部数据污染 | 不受端云架构影响 | 在其他模块动工前先定 Schema |
| P1 | **云侧平台登录态维护** | 小红书/牛客等平台的登录态过期、反爬检测、账号风控 | **端云协作新增风险** | 用户首次授权后加密存储凭据；设置合理请求频率（TTL 缓存减少重复请求）；触发风控时降级 Web Search |
| P1 | **改写防数字幻觉** | LLM 改写简历时篡改数据是产品信任红线 | 不受端云架构影响 | 数字 exact match 校验，上线前必须验证 |