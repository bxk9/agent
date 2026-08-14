# 素材库与历史简历版本管理设计方案

> 状态：设计定稿（待实现）
> 关联文档：`md/历史简历管理方案.md`、`ARCHITECTURE.md`
> 核心目标：解决「删减简历丢素材」「AI 编造内容污染」「同一事实随时间演进」三大问题

---

## 一、设计决策（已拍板）

| 决策点 | 结论 |
|--------|------|
| fact 拆分粒度 | 以「一条 bullet / 一个可量化成果」为 fact 单位（中等粒度） |
| timeline 追加自动化 | LLM 先判断是否为已有 fact 的更新 + 关键处让用户确认 |
| 成长叙事 | 工作量可控则实现（检测 timeline 多点时提示「从 X 到 Y」） |
| AI 生成内容准入 | 默认进隔离区（pending），`accept_ai_marks` 确认后转正 |
| 版本号维度 | 按「公司 + 岗位」分组自增（v1/v2/v3） |

---

## 二、整体架构：素材层 / 产物层分离

```
┌──────────────────────────────────────────────────────┐
│  素材层 Master Profile（事实源，只增不删，可信度分级）      │
│  memory/master_profile.json                            │
│  - fact 原子事实点（bullet / 可量化成果）                 │
│  - timeline 时序演进（80%→85%→90%）                     │
│  - source 可信度闸门（user_input / ai_generated ...）    │
└──────────────────────────────────────────────────────┘
              │ 生成时取 active facts 做数据源
              │ 历史版本仅作「措辞/结构」参考
              ▼
┌──────────────────────────────────────────────────────┐
│  产物层 Resume Versions（投递快照，引用素材）              │
│  memory/resume_index.json（改造）                       │
│  - group_key = 公司::岗位                                │
│  - version 组内自增                                      │
│  - fact_refs 引用了哪些 fact 的哪个时间点                 │
│  - trimmed_facts 本版删减掉的点（可回捞）                 │
└──────────────────────────────────────────────────────┘
              │ 物理文件全量兜底
              ▼
   output/resumes/_all/  +  {user}/{company}/{position}/vN
```

**关键收益**：
- 简历数据源永远是 Master Profile，不是上一版删减简历 → 不丢素材
- `get_active_facts` 只放行已核实点 → AI 编造内容不被复用
- timeline 保留全部快照 → 支持成长叙事 + 历史回溯

---

## 三、数据结构

### 3.1 素材层 fact（`master_profile.json`）

```json
{
  "user_id": {
    "person_id": {
      "facts": [
        {
          "fact_id": "rag_accuracy_projx",
          "category": "project",
          "belong_to": "智能问答项目",
          "label": "RAG 检索准确率",
          "timeline": [
            {"date": "2026-04", "value": "80%", "raw": "4月RAG准确率80%",
             "source": "user_input", "verified": true},
            {"date": "2026-05", "value": "85%", "raw": "优化召回后85%",
             "source": "user_input", "verified": true},
            {"date": "2026-06", "value": "90%", "raw": "引入rerank后90%",
             "source": "user_input", "verified": true}
          ],
          "current": {"date": "2026-06", "value": "90%"},
          "status": "active",
          "created_at": "...",
          "updated_at": "..."
        }
      ]
    }
  }
}
```

**source 可信度闸门**：

| source | 含义 | 进 active 池 | 可被简历复用 |
|--------|------|:---:|:---:|
| `user_input` | 用户亲口提供 | ✅ | ✅ |
| `user_confirmed` | AI 补全后用户确认 | ✅ | ✅ |
| `ai_generated` | AI 补全，带 `<<<>>>`，未核实 | ⚠️ 隔离 | ❌ |
| `deprecated` | 用户明确弃用 | ❌ | ❌ |

### 3.2 产物层简历版本（`resume_index.json` 改造）

```json
{
  "resume_id": "...",
  "company": "腾讯",
  "position": "nlp岗",
  "group_key": "腾讯::nlp岗",
  "version": 3,
  "parent_id": "上一版resume_id",
  "fact_refs": [
    {"fact_id": "rag_accuracy_projx", "used_date": "2026-06", "used_value": "90%"}
  ],
  "trimmed_facts": ["xxx_fact_id"],
  "is_trimmed": true,
  "template": "orange",
  "summary": "...", "html_url": "...", "pdf_url": "...", "docx_url": "...",
  "content_hash": "...", "created_at": "..."
}
```

> 向后兼容：旧记录无新字段时按缺省处理（version=1、fact_refs=[]、group_key 由 company+position 补算）。

---

## 四、模块接口设计

### 4.1 新增 `memory/master_profile.py`

```python
# 写入（source 分流）
add_or_update_fact(user_id, person_id, label, value, date, category,
                   belong_to, raw, source="user_input") -> fact_id
    # LLM 判定为已有 fact → timeline 追加 + current 前移
    # 新 fact → 新建
    # source=ai_generated → 写入但 verified=false，不进 active

# AI 内容转正（由 accept_ai_marks 联动）
confirm_fact(user_id, person_id, fact_id, timeline_index) -> None
    # ai_generated → user_confirmed，verified=true

# 弃用（规避坏表述）
deprecate_fact(user_id, person_id, fact_id) -> None

# 取数据源（最后防污染闸门）
get_active_facts(user_id, person_id) -> list[fact]
    # 只返回 status=active 且含 verified=true timeline 的点

# 成长叙事支持
get_fact_timeline(user_id, person_id, fact_id) -> list[timeline_entry]
    # 返回演进史，供「从X到Y」表述生成
```

### 4.2 改造 `memory/resume_index.py`

```python
add_resume(..., fact_refs=None, trimmed_facts=None)
    # 计算 group_key = f"{company}::{position}"
    # version = 同组最大 version + 1
    # 不再用 hash_id 命名去重，改用 version

select_reference_resumes(user_id, company, position) -> dict
    # 精确命中：同 group_key → 该组最新版
    # 类比命中：同 position 不同 company → 该岗位最近5版
    # 新领域：无匹配 → 全局最近5版
```

### 4.3 新增素材库 LangChain 工具 `app/tools/master_profile_tool.py`

```python
@tool save_resume_facts(...)   # 对话中沉淀素材（LLM 判断新增/更新）
@tool query_resume_facts(...)  # 生成前拉取 active facts 做数据源
```

---

## 五、关键数据流

```
4月："RAG 80%"  → 新建fact timeline=[80%] → 简历v1 fact_refs=[80%]
5月："RAG 85%"  → 同fact追加 timeline=[80%,85%] → 简历v2 fact_refs=[85%]
6月："RAG 90%"  → timeline=[80%,85%,90%] → 简历v3 fact_refs=[90%]
                → 💡检测3点提升，提示"是否写成80%→90%成长表述"

AI补全"提升20%"（用户没说）
   → 存pending, source=ai_generated, verified=false
   → 渲染红色<<<>>>
   → 用户确认 → accept_ai_marks() → confirm_fact() → 转正active
   → 用户否认 → deprecate_fact() → 永久隔离+规避
```

---

## 六、实现 TodoList 清单（按优先级分阶段）

### 阶段 P0：版本管理基础（低成本，先满足产品需求）✅ 已完成
- [x] `resume_index.py` 增加 `group_key` / `version` / `parent_id` 字段（含旧记录兼容，`_ensure_compat`）
- [x] `add_resume` 改造：按公司+岗位分组自增 version，去掉 hash_id 命名依赖
- [x] 新增 `select_reference_resumes`：三级命中（精确/类比/新领域）
- [x] 文件命名改为 `{姓名}-{公司}-{岗位}-v{N}-{时间}`（渲染侧命名，`pipeline.py` L261-269）

### 阶段 P1：素材库核心（解决丢素材 + 防污染）✅ 已完成
- [x] 新建 `memory/master_profile.py`：fact 数据结构 + CRUD
- [x] 实现 `add_or_update_fact`（source 分流，ai_generated 进隔离区）
- [x] 实现 `get_active_facts`（防污染出口，只放行 verified）
- [x] 实现 `confirm_fact` / `confirm_facts_by_text` / `deprecate_fact` / `get_fact_timeline`
- [x] 打通 `accept_ai_marks()` → `confirm_facts_by_text()` 联动（复用现有 @tool）
- [x] 复用 `_resolve_person_key`（ai_marks_store）做 user_id→person 隔离

### 阶段 P2：工具与流程接入 ✅ 已完成
- [x] 新增 `app/tools/master_profile_tool.py`（save/query facts 两个 @tool）
- [x] 工具注册到 `app/tools/__init__.py` + `agent_executor.py` 中文名映射
- [x] `resume_index.py` 的 `add_resume` 支持 `fact_refs` / `trimmed_facts` 参数
- [x] `resume_generator.md` 流程改造：
  - [x] 开场先查 Master Profile（素材库优先 + 数据源优先级说明）
  - [x] 生成数据源改为 active facts，历史版本仅作参考
  - [x] 收集时 save_resume_facts 落库（source 分流 + 关键处让用户确认）
  - [x] 删减版按 JD 删减仅体现在产物层，不删素材库

### 阶段 P3：成长叙事（工作量可控则做）✅ 已完成
- [x] `detect_growth_facts` 检测多点演进（基于 get_active_facts）
- [x] `query_resume_facts` 返回成长轨迹提示 + skill Step3 接入「从 X 到 Y」话术

### 阶段 P4：分层存储兜底（方案 A：逻辑分层 + 链接生命周期管理）✅ 已完成
> 决策：文件真身在 BlueClaw VFS 当前 7 天（远期 90 天），upload 接口返回的链接同为 7 天 TTL。
> 采用逻辑分层（不做物理目录），核心是「存持久 vfs_path + 直接用 upload 返回的 7 天链接」。
> 链接过期后（>7 天），`refresh_share_urls` 用 vfs_path 重签 1 天短链。
> 重签分层：面向用户输出（`query_my_resumes`）才重签；纯检索（`query_resumes`/`list_grouped_resumes`）不重签，降低 VFS 请求量。
> 内部下载：`_download_file` 走 `GET /workspace/download` 直接拿字节，无需预签 URL。
- [x] `_upload` 改造为 `_upload_with_path`，返回 (upload 返回的 7 天 URL, 持久vfs_path)
- [x] `add_resume` 存 `html_vfs_path` / `pdf_vfs_path` / `docx_vfs_path`