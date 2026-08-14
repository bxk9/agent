- [x] `refresh_share_urls`：按需重签短链（1 天 TTL），超 7 天打 `expired`，无持久路径打 `needs_regenerate`（存量老记录降级）
- [x] `_is_expired`：7 天生命周期判定（远期改 90 天）
- [x] `list_grouped_resumes`：按 group_key 聚合的产品视图（组内 version 倒序）
- [x] `query_my_resumes` 输出前重签 + 展示 v{N} + 过期/降级提示
- [x] 索引写入前留 `.bak` 备份（防 JSON 写坏）
- [x] 导出文件名改为 `{姓名}-{岗位}-v{N}-{时间}`（`peek_next_version`）

### 验证
- [x] 单测（`test/test_master_profile.py`，15/15 通过）：
  - P0~P3：timeline 追加 / source 分流 / active 过滤 / confirm 转正 / deprecate / 成长检测 / 人物隔离 / version 自增 / 三级选取
  - P4：peek_next_version / 90天过期判定 / 分组视图 / 重签降级 / 超期标记
- [ ] 端到端：模拟 4→5→6 月 RAG 演进，验证不丢素材 + AI 内容隔离（需真实 VFS + LLM 环境，留待联调）

---

## 七、复用现有基建对照

| 需求 | 复用现有 |
|------|---------|
| 可信度标记 | `ai_marks.py` 的 `<<<>>>` 机制 |
| AI 内容转正触发 | `accept_ai_marks()` @tool |
| 人物隔离 | `_extract_person_id`（双层隔离键） |
| 持久化模式 | 参照 `ai_marks_store.py` JSON 落盘 |
| 历史查询 | `query_my_resumes` @tool（列表展示保留） |