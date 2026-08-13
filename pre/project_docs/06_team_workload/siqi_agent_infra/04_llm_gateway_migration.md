# 04 · LLM 网关迁移（玄机 → BlueClaw）

## 一句话概括

司棋在 07-17 完成的**跨项目基础设施级迁移**——所有 LLM 调用从"玄机"网关切换到"BlueClaw"网关，涉及全部 LLM 使用点，是一次典型的**"底层换血"**操作。

---

## 核心数据卡片

| 文件 | 修改次数 | Blame |
|:---|---:|:---|
| `app/llm/blueclaw_chat.py` | **10** | 司棋 68.4% / yitong 16.7% / 11099826 15.0% |
| `app/llm/vivo_chat.py`（旧网关） | 8 | 迁出方 |

---

## 背景

- **玄机（vivo_chat）**：旧网关，功能受限
- **BlueClaw（blueclaw_chat）**：新网关，支持 VLM 矩阵、更强流式、更全 usage

迁移挑战：
- 全项目 LLM 调用点必须同时切换
- 流式 API 差异
- usage_tokens 字段结构差异
- 错误码语义差异

---

## 时间线

| 日期 | Commit |
|:---:|:---|
| 06-09 → 07-16 | vivo_chat（玄机）持续维护，累计 8 次改动 |
| **07-17** | **feat(llm): 模型调用接口从玄机迁移到 BlueClaw 网关** |
| 07-27 | fix: 视觉模型调用支持 BLUECLAW_NETWORK 矩阵，修复上线 internal_error（11197109） |
| 07-29 | fix(llm): _last_msg_obj.get('choices', [{}]) 空列表兜底失效导致 list index out of range |
| 07-29 | fix(llm): 异常错误信息不再混入模型回复内容 |
| 07-29 | fix(logging): 补全 Agent stream 结束日志的 thread_id 和 blueclaw_chat._call_api 请求前日志 |

---

## 方案 / 代码证据

### 迁移的关键点

1. **接口对齐**：`blueclaw_chat._call_api` 与旧 `vivo_chat` 保持外部接口一致
2. **流式差异**：BlueClaw 支持更细粒度 chunk，需要新 stream 解析
3. **usage 结构**：BlueClaw 的 usage_tokens 字段位置与玄机不同（yitong 后续做了 5 次 usage_tokens 迭代）
4. **网络矩阵**：dev / pre / prd 三套环境（11197109 后续接入 VLM 时补齐）
5. **错误兜底**：`choices[0]` 空列表兜底、异常不混入模型内容（07-29 双修复）

### 后续影响

- **11197109**：07-27 补 `BLUECLAW_NETWORK` 矩阵
- **yitong**：usage_tokens 5 次迭代（详见 `06_workload_showcase/06_observability_and_telemetry.md`）
- **司棋自己**：07-29 双 fix 收官

---

## 量化成果

| 维度 | 成果 |
|:---|:---|
| 覆盖范围 | 全项目所有 LLM 调用点 |
| 迁移时长 | 07-17 单日主切 + 07-29 稳定收官 |
| 后续维护 | blueclaw_chat.py 68.4% blame 归司棋 |
| 关联下游 | VLM（11197109）、usage_tokens（yitong）复用底座 |

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="司棋" -- app/llm/ --pretty=format:"%ad|%s" --date=short
```
