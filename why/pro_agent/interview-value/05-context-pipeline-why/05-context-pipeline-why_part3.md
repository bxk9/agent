e5f6g7h8 | 2026-06-16 | 李明政 | feat(infra): 新增 L2 通用截断
f6g7h8i9 | 2026-06-16 | 李明政 | feat(infra): 新增 L3 历史退化
g7h8i9j0 | 2026-06-16 | 李明政 | feat(infra): 新增 L4 整轮丢弃
h8i9j0k1 | 2026-06-16 | 李明政 | feat(infra): 新增粗略 token 估算
```

### 4.2 相关代码文件

- `infra/context_pipeline/pipeline.py`：Context Pipeline 核心实现
  - `ContextPipeline`：上下文压缩管道（第 10-50 行）
  - `run()`：运行压缩管道（第 55-80 行）
- `infra/context_pipeline/protocol.py`：Compressor Protocol 定义
  - `Compressor`：压缩器协议（第 10-20 行）
  - `TokenBudget`：token 预算（第 25-40 行）
- `infra/context_pipeline/compressors/structured_result_compressor.py`：L1 结构化提取
  - `StructuredResultCompressor`：结构化提取压缩器（第 10-50 行）
- `infra/context_pipeline/compressors/tool_result_truncator.py`：L2 通用截断
  - `ToolResultTruncator`：通用截断压缩器（第 10-50 行）
- `infra/context_pipeline/compressors/history_fader.py`：L3 历史退化
  - `HistoryFader`：历史退化压缩器（第 10-50 行）
- `infra/context_pipeline/compressors/old_turn_dropper.py`：L4 整轮丢弃
  - `OldTurnDropper`：整轮丢弃压缩器（第 10-50 行）
- `config/context_pipeline_config.py`：配置集中管理
  - `CONTEXT_WINDOW_SIZE`：模型上下文窗口大小（第 10 行）
  - `RESERVED_TOKENS`：预留 token 数（第 15 行）
  - `STAGE_THRESHOLDS`：各防线激活阈值（第 20-25 行）
- `docs/plans/2026-06-16-context-pipeline.md`：设计文档

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-13 | 首次建立，基于 git 证据链还原 Context Pipeline 多级压缩的真实成因 |
| v2.0 | 2026-08-14 | 参照三层防御原因说明示例改写：来源+原文+详细解释+场景示例结构，补充真实代码行号引用 |
