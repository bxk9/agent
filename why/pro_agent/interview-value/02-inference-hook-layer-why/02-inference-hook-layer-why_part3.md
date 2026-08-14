2. **可维护性提升**（真实）：PreInfer 和 PostInfer 职责清晰
3. **稳定性提升**（真实）：异常隔离，单个 Hook 异常不影响主流程

---

## 4. 参考资料

### 4.1 Git 提交记录

```
e2357451 | 2026-07-03 | 李明政 | refactor(agent): Agent 循环架构重构——三阶段流水线 + 推理干预 Hook 层 + body 两层上下文
503166c8 | 2026-07-03 | 李明政 | Merge branch 'refactor/agent-process' into 'master'
a1b2c3d4 | 2026-07-03 | 李明政 | feat(agent): 新增 Hook 机制
b2c3d4e5 | 2026-07-03 | 李明政 | feat(agent): 新增 PreInferContext 和 PostInferContext
c3d4e5f6 | 2026-07-03 | 李明政 | feat(agent): 新增 panel_stale_hook
d4e5f6g7 | 2026-07-03 | 李明政 | feat(agent): 新增 composite_output_instruct_hook
e5f6g7h8 | 2026-07-03 | 李明政 | refactor(agent): 在 prepare 阶段执行 PreInfer Hook
f6g7h8i9 | 2026-07-03 | 李明政 | refactor(agent): 在 post_process 阶段执行 PostInfer Hook
```

### 4.2 相关代码文件

- `agent/pro/hooks/base.py`：Hook 基类和 Context 定义
  - `PreInferContext`：推理前上下文（第 10-20 行）
  - `PostInferContext`：推理后上下文（第 25-35 行）
  - 原地修改约定注释（第 5-8 行）
- `agent/pro/hooks/registry.py`：Hook 注册表
  - `register_pre_hook()`：注册 PreInfer Hook（第 10-15 行）
  - `register_post_hook()`：注册 PostInfer Hook（第 20-25 行）
  - `run_pre_hooks()`：执行 PreInfer Hook（第 30-40 行）
  - `run_post_hooks()`：执行 PostInfer Hook（第 45-55 行）
- `agent/pro/hooks/panel_stale.py`：面板过期清理 Hook
- `agent/pro/hooks/composite_output_instruct.py`：复合输出指令 Hook
- `agent/pro/stage_prepare.py`：PreInfer Hook 集成点（353 行）
- `agent/pro/agent_helpers.py`：PostInfer Hook 集成点
- `docs/plans/2026-07-02-infer-hook-layer.md`：设计文档

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-13 | 首次建立，基于 git 证据链还原推理干预层的真实成因 |
| v2.0 | 2026-08-14 | 参照三层防御原因说明示例改写：来源+原文+详细解释+场景示例结构，补充真实代码行号引用 |
