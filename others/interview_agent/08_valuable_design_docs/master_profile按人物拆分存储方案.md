# master_profile 按人物拆分存储方案（解决大文件截断）

> 状态：待评审
> 关联模块：`memory/master_profile.py`、`memory/_vfs_json.py`、`app/vfs/namespace.py`
> 关联调用方：`app/tools/resume_sidebar/pipeline.py`、`app/tools/master_profile_tool.py`、`app/tools/resume_memory_tool.py`

---

## 一、问题回顾

### 1.1 截断层症状

`_resolve_large_result`（`memory/_vfs_json.py`）原本只处理一层截断：分页拼装 `large_tool_results` 后直接返回，未检查拼装结果是否**又包含嵌套截断标记**。当 `master_profile.json` 足够大时，VFS 网关会对 `large_tool_results` 的分页响应再次触发截断，导致拼装后的 `full` 仍是截断提示文本而非 JSON。

> 现状：已在 130-132 行补了递归解析（`if _LARGE_RESULT_MARKER in full: return _resolve_large_result(...)`），能兜住嵌套截断，但这是**治标**。

### 1.2 病根：单文件聚合多人物

当前存储为「一户一文件」，但文件内顶层是 `person_key → entry`，聚合了该用户名下**所有人物**的全量 `facts[].timeline`。文件越大：

- VFS 网关截断层数越多，分页拼装越脆弱（超时/丢页概率随页数累积）；
- 单次读写传输体积大，`_HTTP_TIMEOUT_READ=3.0s` 更易超时，触发 `READ_ERROR` 后写操作被覆盖保护中止，落库失败。

**治本方向**：把存储粒度从「用户」下沉到「人物」，让单个物理文件足够小，从源头规避截断。

---

## 二、目标存储结构

```
users/{uid}/memory/master_profile/
├── index.json                    ← 轻量索引（人物元数据，永不含 facts）
├── {person_slug}.json            ← 单个人物的完整 facts
└── {person_slug}.json
```

### 2.1 index.json（小文件，只存定位所需字段）

```json
{
  "version": 2,
  "persons": {
    "李明": {
      "name": "李明",
      "phone": "138xxxx",
      "job_intent": "nlp岗",
      "slug": "liming_a1b2c3",
      "fact_count": 50,
      "updated_at": "2026-07-10T17:00:00"
    }
  }
}
```

- key 为现有 `_resolve_person_key` 产出的逻辑主键（姓名归一化）。
- `slug` 为**物理文件名**，对 person_key 安全化：`safe_ascii(name) + "_" + md5(person_key)[:8]`，保证唯一且可读。
- `persons` 内仅存匹配/展示所需元数据，**绝不含 facts**，保证 index 恒为小文件。

### 2.2 {person_slug}.json（单人物，体积可控）

```json
{
  "name": "李明",
  "phone": "138xxxx",
  "job_intent": "nlp岗",
  "facts": [ { "fact_id": "...", "label": "...", "timeline": [ ... ], "current": {}, "status": "active" } ],
  "block_fps": [ "..." ]
}
```

---

## 三、模块改造点（`memory/master_profile.py`）

核心思路：**IO 从「整桶」降级为「索引 + 按需单人物」**，业务 API 签名全部保持不变。

### 3.1 新增 IO 原语

| 函数 | 作用 |
|------|------|
| `_load_index(user_id)` / `_load_index_for_write(user_id)` | 读/写前读 `index.json`（复用 `read_json_checked` 三态保护） |
| `_load_person(user_id, slug)` | 读单个人物文件 |
| `_save_person(user_id, slug, entry)` | 写单个人物文件 |
| `_save_index(user_id, index)` | 写索引 |
| `_person_slug(person_key, name)` | person_key → 安全文件名 |

### 3.2 定位逻辑改造（关键）

现 `_resolve_person_key_fuzzy` 遍历整个 bucket 做 phone 强锚点 + name 模糊匹配。拆分后**不能读全量 facts**，但匹配只依赖 `name/phone/job_intent`——这些字段 index.json 里全有。

- 改为入参从 `bucket` 换成 index 的 `persons` 元数据 dict，匹配逻辑（phone 锚点、CJK 前缀、编辑距离）完全不变。
- `_get_person_entry` 改为：先用 index 定位 person_key/slug → 只读该 person 文件 → 拿到 entry；命中不到且 `create=True` 时新建 entry + 在 index 注册。

### 3.3 各 API 的读写降级

- **只读类**（`get_active_facts` / `get_block_fingerprints` / `get_fact_timeline` / `detect_growth_facts`）：读 index 定位 → 读单人物文件。IO 量从「全量」降到「单人」，天然规避截断。
- **写类**（`add_or_update_fact` / `batch_add_or_update_facts` / `confirm_*` / `deprecate_*`）：读 index + 读目标 person 文件 → 改 → 写回 person 文件 + 更新 index（`fact_count` / `updated_at`）。覆盖保护（`_load_for_write` 的 `READ_ERROR` 中止）迁移到 person 文件与 index 两处。
- **`rename_person`**：跨人物合并，读 old + new 两个 person 文件 → 合并 → 写 new + 删 old 文件 + 更新 index（删 old key、改/加 new key）。

---

## 四、迁移策略（旧单文件 → 新目录）

懒迁移，无需停机脚本：

1. 新增 `_ensure_migrated(user_id)`：读/写操作入口先检查 `master_profile/index.json` 是否存在。
2. 不存在 → 尝试读旧 `master_profile.json`：
   - 有内容 → 逐个 person 拆成 `{slug}.json`，生成 `index.json`，写入新目录；
   - 迁移成功后**保留旧文件**（不物理删，便于回滚）。
3. 旧文件不存在 → 直接按空 index 走（新用户）。

> 迁移本身可能读到大文件，但迁移是一次性的，且 `_resolve_large_result` 递归解析已覆盖；迁移后彻底摆脱大文件。

---

## 五、兼容与风险控制

- **API 签名零变更**：所有对外函数（`add_or_update_fact`、`get_active_facts`、`rename_person` 等）签名不动，`pipeline.py` / `master_profile_tool.py` 无需改。
- **`_load` 兼容 shim**：`resume_memory_tool.py:202` 直接 `from memory.master_profile import _load as _mp_load` 探测 `has_master`。需保留 `_load(user_id)` 私有函数：改为读 index 判断 `persons` 是否非空并聚合返回一个兼容视图（或将探测逻辑改为读 index）。
- **覆盖保护延续**：index 与 person 文件都走 `read_json_checked` 三态；`READ_ERROR` 一律中止写，防空覆盖。
- **原子性局限**：写 person + 写 index 是两次 VFS 请求，非事务。策略：**先写 person 文件，成功后再写 index**。index 落后于 person 只会导致「文件在但索引缺」，可在读 index 时做一次目录列举兜底校正（可选增强）。

---

## 六、测试影响

- `test_master_profile_unit.py` / `test_master_profile_regression.py` / `test_master_profile_vfs.py` 的 mock VFS（`_InMemoryVFS`）已按 path 存 dict，天然支持多路径；主要补：index 文件夹具、迁移路径用例。
- 新增用例：
  - 迁移正确性（旧单文件 → 拆分后 facts 完整可读）；
  - 大文件不再触发截断的回归；
  - `rename_person` 跨文件合并 + index 同步。

---

## 七、涉及文件汇总

| 文件 | 改动 |
|------|------|
| `memory/master_profile.py` | 新增 IO 原语 + slug + 定位改造；各 API 降级为单人物读写；`_ensure_migrated` 懒迁移；`_load` 兼容 shim |
| `app/vfs/namespace.py` | 新增 `user_master_profile_dir` / `user_master_profile_index` / `user_master_profile_person(slug)` 路径拼接 |
| `test/test_master_profile_*.py` | 补 index 夹具、迁移用例、跨文件 rename 用例 |

---

## 八、实施顺序

1. `namespace.py` 加目录/索引/人物文件路径拼接函数。
2. `master_profile.py` 落 IO 原语 + slug + 定位改造。
3. 逐个 API 降级为单人物读写。
4. 加懒迁移 + `_load` 兼容 shim。
5. 补测试并回归。
