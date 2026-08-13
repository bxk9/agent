# 07 · scope 检测下沉到工具层

## 一句话概括

11099826 在 08-08 完成的一次架构级重构——把 scope（作用域）检测从 `agent_executor` 层下沉到工具层，解决了"executor 注入无效"的历史包袱，让 executor 保持纯净。

---

## 核心数据卡片

| 指标 | 数值 |
|:---|---:|
| 重构 commit | 08-08 单日 3 个连续提交 |
| 修改文件 | `agent_executor.py`、`resume_sidebar/markdown_scope.py`、工具层入口 |
| 收益 | executor 层减负，工具层可独立复用 scope 判断 |

---

## 背景与问题

历史上 scope 检测放在 `agent_executor` 层：

```
User Query → executor.detect_scope() → 注入到工具调用 → 工具执行
```

**问题**：
1. **注入无效**：某些工具路径绕过 executor，scope 丢失
2. **重复检测**：每个工具都要自己校验一遍
3. **架构分层不清**：业务逻辑（scope 语义）应该属于工具域

---

## 时间线（08-08 单日）

| 时间点 | Commit | 关键动作 |
|:---:|:---|:---|
| 08-08 | **refactor: scope检测逻辑迁移到工具层，修复agent_executor层注入无效问题** | 主重构 |
| 08-08 | feat: LLM scope意图分类兜底，company文件名去重，CSS修复 | LLM 兜底 |
| 08-08 | fix(scope): 拒绝渲染改为降级全量渲染 + basicInfo 嵌套容错 + 英文关键字中文化 | 降级策略 |

---

## 方案 / 代码证据

### 前后对比

**重构前**：
```
agent_executor.py:
  scope = detect_scope(query)
  tool_call(scope=scope, ...)  ← 部分路径丢失

resume_sidebar_tool.py:
  def render(data, scope=None):
      if scope is None:
          # 场景未知，可能拒绝渲染
          raise ScopeUnknownError()
```

**重构后**：
```
agent_executor.py:
  tool_call(...)  ← 纯净

resume_sidebar_tool.py:
  def render(data, query=None):
      scope = detect_scope_local(data, query)  ← 工具层内部判断
      if scope is None:
          scope = SCOPE_FULL  ← 降级全量而非拒绝
      # 继续渲染
```

### 三层降级

1. **精确 scope**：字段级修改（如"改一下姓名"）
2. **模块 scope**：模块级修改（如"重写工作经历"）
3. **降级全量**：无法判断 → 全量重渲染（08-08 拒绝改降级）

### LLM 意图分类兜底

- 08-08 同日：`LLM scope意图分类兜底`
- 当规则判断失败时，用 LLM 二次分类，兜底成功率高

---

## 量化成果与协作面

| 指标 | 修复前 | 修复后 |
|:---|:---:|:---:|
| scope 丢失率 | 有（少数路径） | 归零 |
| 拒绝渲染场景 | 存在 | 降级为全量 |
| executor 层职责 | 混合业务判断 | 纯执行调度 |

### 协作面

- **司棋（agent_executor Owner）**：清理路径 → 移除 executor 层的 scope 注入
- **yitong**：方法论互通（yitong 在错题本也强调"事前约束优于事后兜底"）

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="11099826" --grep="scope" --pretty=format:"%ad|%s" --date=short
```
