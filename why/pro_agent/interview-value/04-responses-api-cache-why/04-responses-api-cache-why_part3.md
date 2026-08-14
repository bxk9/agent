f6g7h8i9 | 2026-07-17 | 李明政 | feat: 新增模型切换后强制降级
```

### 4.2 相关代码文件

- `agent/pro/stage_infer.py`：Responses API 缓存优化核心实现（613 行）
  - `_prefix_hash()`：SHA256 前缀哈希校验（第 100-110 行）
  - 三条路径判断逻辑（第 200-230 行）
  - 透明降级逻辑（第 300-320 行）
  - response_id 透传逻辑（第 400-410 行）
- `model/xuanji/__init__.py`：stream_responses 方法实现（1123 行）
  - `stream_responses()`：Responses API 流式推理（第 500-600 行）
- `model/base.py`：Model 抽象基类（35 行）
  - `stream_responses()`：抽象方法定义（第 20-25 行）
- `model/stream_events.py`：StreamMeta 数据结构
  - `response_id`：Responses API 返回的 response_id
- `docs/plans/2026-07-16-responses-api-intra-turn-cache.md`：设计文档

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-13 | 首次建立，基于 git 证据链还原 Responses API 缓存优化的真实成因 |
| v2.0 | 2026-08-14 | 参照三层防御原因说明示例改写：来源+原文+详细解释+场景示例结构，补充真实代码行号引用 |
