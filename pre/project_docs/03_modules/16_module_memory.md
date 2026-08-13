# 16 · 模块 · 持久化存储 `memory/`

## 1. 模块定位

`memory/` 是**业务级持久化层**，位于 VFS 之上。它把"简历版本 / 素材事实 / AI 标记 / 错题 / 复盘"等业务对象抽象成**索引 JSON**，用户中心化按 `user_id` 隔离。所有 JSON 最终落 VFS。

一句话：**VFS 存本体，memory 存索引与事实**。

## 2. 文件清单

| 文件 / 目录 | 职责 |
|-----------|------|
| `resume_index.py` | 简历历史索引：按「公司+岗位」分组版本管理、三级命中选取、链接生命周期 |
| `ai_marks_store.py` | AI 补全标记持久化（user_id → person_id 双层隔离，跨轮/跨天保持） |
| `error_book_index.py` | 错题本索引 |
| `review_report_index.py` | 面试复盘报告索引 |
| `_vfs_json.py` | VFS JSON 读写底层封装（原子替换、并发写协调） |
| `clean_content_json_base64.py` | 内容清理 + JSON/Base64 编解码工具 |
| `master_profile/`（子包） | 素材库核心实现：API / 定位 / 匹配 / 存储 |
| `master_profile.json` | 素材库示例数据 |
| `resume_index.json` | 简历索引示例数据 |
| `ai_marks_store.json` | AI 标记示例数据 |

## 3. 对外契约

### 3.1 简历索引

```python
from memory.resume_index import (
    append_version, list_versions, pick_best,
)
append_version(user_id, {"company": "...", "position": "...", "pdf_file_id": ...})
best = pick_best(user_id, company="X", position="Y")  # 三级命中
```

三级命中：
1. **精确**：company + position 完全匹配 → 最新版
2. **模糊**：company 或 position 单命中 → 最新版
3. **兜底**：全库最新版

### 3.2 素材库（Master Profile）

```python
from memory.master_profile import get_profile, upsert_fact, list_facts, deprecate

profile = get_profile(user_id)
upsert_fact(user_id, fact={
    "type": "experience",
    "content": "...",
    "source": "user_input",   # user_input / ai_generated / deprecated
    "timeline": {"from": "2022-06", "to": "2024-03"},
})
```

素材可信度闸门：渲染优先 `user_input`；`ai_generated` 需要用户确认；`deprecated` 不再展示但保留历史。

### 3.3 AI 标记

```python
from memory.ai_marks_store import get_marks, put_marks, clear_person

# 结构：{user_id: {person_id: [{"path": "basic.email", "hint": "疑似伪造", ...}]}}
marks = get_marks(user_id, person_id)
put_marks(user_id, person_id, marks)
```

跨轮持久化：Agent 每轮把 `<<<...>>>` 标记 diff 更新�� marks；下轮加载后注入到 system prompt，让 LLM 保持"记忆"。

### 3.4 错题本 / 复盘

- `error_book_index.py`：按 `user_id` 存题目/答案/时间/标签；配合 `tools/error_book.py` 使用；
- `review_report_index.py`：按 `user_id` 存复盘报告的元信息，实际 HTML 落 VFS。

## 4. 核心设计理念（模块级）

1. **索引 = JSON on VFS**  
   没有独立数据库。索引 JSON 落 VFS，天然多设备同步；小体量（每用户 KB 级）够用。

2. **原子替换 + 版本追加**  
   `_vfs_json.py` 用"读取 → 修改 → 覆盖上传"模式；并发写靠**乐观锁**（读时带 etag，写时对比）。目前单副本部署下冲突极少。

3. **可信度闸门（source）**  
   素材库最重要的字段是 `source`：
   - `user_input` 是事实源，不允许 AI 覆盖；
   - `ai_generated` 待确认，UI 高亮；
   - `deprecated` 保留但不参与渲染。

4. **AI 标记跨轮而不跨人**  
   按 `user_id → person_id` 双层隔离：同一账号可能优化多份简历（找不同工作/给不同人），标记必须按 person 分开。

5. **索引不存原文**  
   索引里只有 `file_id`、时间、标签、少量摘要；原文永远在 VFS。避免索引膨胀。

## 5. 典型调用链

**素材沉淀**：

```
Agent (mock_interview) 得到用户新经历
  → tool: master_profile_tool.upsert
  → memory.master_profile.upsert_fact(uid, {"source": "user_input", ...})
  → VFS put_json users/{uid}/master_profile.json
```

**简历渲染前拉素材**：

```
Agent (resume_generator)
  → tool: master_profile_tool.list
  → memory.master_profile.list_facts(uid, filter={"source": ["user_input", "ai_generated"]})
  → 注入 LLM 上下文
```

**AI 标记闭环**：

```
LLM 输出 <<<...>>>  → agent 后处理提取
  → memory.ai_marks_store.put_marks(uid, pid, marks)
下一轮：
  → memory.ai_marks_store.get_marks → 注入 system prompt
```

## 6. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增业务索引 | 新建 `xxx_index.py`；复用 `_vfs_json.py` 的原子替换；约定 `users/{uid}/xxx_index.json` |
| 需要跨用户统计 | 目前不支持（用户中心化路径）；应新建独立命名空间 `stats/...` |
| 素材字段扩展 | 只加字段不删字段；`master_profile/` 内保持向后兼容 |
| 强一致性需求 | 目前是最终一致（VFS 覆盖上传）；如需强一致要引入分布式锁（不建议） |

**易踩坑**：
- 并发写同一 user 的 index，最后写入者胜出。已在业务层通过"读改写窗口极短 + 每次操作独立"降低碰撞。
- 删除后**没有回收站**；写入前建议先 `_backup`（部分 index 已内置）。
- `master_profile.json` 单个用户上限约 100KB 级；超过考虑分片。

## 7. 与 tools/ 的边界

- **tools/** 是"面向 LLM 的入口"；
- **memory/** 是"面向持久化的实现"；
- 工具函数**不**直接读写 VFS JSON，而是调 `memory/*` 提供的语义函数。这样：
  - 工具专注参数校验与结果封装；
  - 数据一致性规则收敛在 memory 层。
