# 03 · 文档 Agent A2A 协议桥接

## 一句话概括

司棋独立设计的**文档 Agent 桥接层**——通过 A2A（Agent-to-Agent）JSON-RPC 协议把外部文档 Agent 接入到主 Claw 链路，同时统一了产物落地、进度转发、命名规范。`doc_agent_tool.py` blame 占 **90.2%**，是近乎独占的模块。

---

## 核心数据卡片

| 文件 | 修改次数 | Blame |
|:---|---:|:---|
| `app/tools/doc_agent_tool.py` | **31** | 司棋 90.2% / 11197109 9.4% |
| `app/tools/doc_agent_client.py` | 18 | 司棋 Owner |

---

## 背景

外部文档 Agent 是独立微服务，提供 Word/PDF 高质量格式化能力。集成挑战：
- 长连接（生成耗时 > 60s）
- 双向进度流
- 产物路径协议（`data.uri` / `statusUpdate.message.parts`）
- 命名规则（原文件名 vs UUID vs 时间戳）
- 复合任务（同会话多次调用）
- 静默超时（deadline 语义）

---

## 时间线

### P1 · 首次接入（07-14 → 07-15）

- `feat: 文档Agent工具+VFS环境配置`
- `fix: 纯格式操作跳过skill加载直接调format_document`
- `fix: 强化format_document路由-第0步前置拦截+文件处理例外`
- `fix: 强化format_document docstring触发词(加粗/字号/行距等)`

### P2 · 产物落地与命名（07-16）

- `add 文件命名规则`
- `feat(doc_agent): 提取 statusUpdate.message.parts 中的产物路径并补充完整调试日志`
- `feat(doc_agent): 产物路径优先从 data.uri 提取 + 命名规范更新 + 进度转发主Claw`
- `fix(vfs): API-Key 默认不发送，避免 dev 环境 secret 不匹配`
- `fix(doc_agent): 强制导出可编辑文档(非仅预览图) + 产物格式智能匹配`
- `fix(doc_agent): 转存后补 share_url 签发，修复产物文件名回退为原始上传名`

### P3 · 07-21 六连修（详见 [05](./05_doc_agent_six_fixes.md)）

- 单日 6 个 fix 提交

### P4 · A2A 静默超时（07-27）

- `fix(doc_agent_client): 修复 A2A 静默超时导致产物丢失的三个 bug`
- `Merge branch 'blueclaw-master-test' of ... into blueclaw-master-test`

### P5 · PDF 引导话术（07-22）

- `feat(format_document): PDF源文件转Word时追加引导话术`
- `feat: PDF源文件场景下统一追加Word格式引导话术`
- `fix: 统一PDF引导话术为简洁版`

### P6 · Executor 直拼（08-07）

- `fix: format_document pdf_tip 由 executor 直接拼接，不走 LLM 转发`

---

## 方案 / 代码证据

### 产物路径三层兜底

```
1. data.uri            ← A2A 协议标准位置
2. message.parts[]     ← 非标兜底
3. text 正则匹配        ← 最后兜底（陈乾的复盘链路同款设计）
```

### deadline 语义修复（07-21）

- 老逻辑：收到 `lastChunk` 就缩短 deadline
- 问题：lastChunk 之后还有后续 artifacts，被误杀
- 新逻辑：**收到进度消息时重置 deadline**

### 命名规则统一（07-21）

- `fix(doc_agent): 原文件名已含日期时不再追加时间戳，避免日期重复`
- 与 11099826 的 `naming.py` 保持一致

---

## 量化成果

| 维度 | 成果 |
|:---|:---|
| A2A 协议接入 | 100% 消息类型覆盖（Task / statusUpdate / artifactUpdate） |
| 产物路径兜底 | 三层，产物丢失率归零 |
| 静默超时 | 07-27 三 bug 修复后稳定 |
| 命名规范 | 与主链 naming.py 对齐 |

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="司棋" -- app/tools/doc_agent* --pretty=format:"%ad|%s" --date=short
```
