6. **面试复盘**：`agent → interview_review.md → review_report_tool → memory/review_report_index → VFS`

## 6. 记忆模型

- **短期（对话内）**：`MemorySaver`（内存 checkpointer），键为 `thread_id`（= `context_id`）。**同一 A2A 上下文（一次会话）所有请求共享**。进程重启即丢。
- **长期（跨会话）**：`memory/` 下的 JSON 索引 + `master_profile/`（素材库），落 VFS。**按 `user_id` 隔离**。
- **AI 标记**：介于两者之间——按 `user_id → person_id` 双层隔离，跨轮/跨天保持，但可被"确认/覆盖"清除。

## 7. 部署视图

- 单进程 Uvicorn 即可，端口默认 8000。
- 无独立 DB；所有持久化都通过 BlueClaw VFS HTTP API。
- 无独立缓存；`app/utils/recent_resume_cache.py` 是**进程内**内存缓存（重启失效，用于同一会话内跳过重复解析）。
- 模型全部走外部网关，本地无 GPU 要求。

## 8. 阅读下一站

- `03_design_philosophy.md` — 为什么如此分层？
- `12_module_agent_core.md` — Agent 循环细节
- `30_data_flow_resume.md` — 最复杂的一条数据流拆解
