# 团队协作矩阵 · 基于 git blame 的行级 Ownership

> **本文定位**：前面 6 篇按人绘制画像用的是 `git log`（**提交量视角**），本篇用 `git blame`（**存活行视角**）从**代码文件维度**反向验证 Ownership。两个视角互相印证，是判断"真实责任人"的双重证据。
>
> **数据口径**：`git blame --line-porcelain <file> | grep '^author ' | sort | uniq -c`——统计当前 HEAD 每文件"存活代码行"的原始作者归属。**这不是"改动量"，而是"当前留存的行"**。

---

## 一、行级 Ownership 全景表

### 核心业务文件

| 文件 | 总存活行 | 首要 Owner | 占比 | 次要 Contributor | 占比 |
|:---|---:|:---|---:|:---|---:|
| `app/agent_executor.py` | 1,961 | **11099826** | 40.3% | 司棋 28.7% / yitong 18.0% / 陈乾 12.4% / 11197109 0.6% |
| `app/tools/resume_sidebar/pipeline.py` | 4,008 | **11099826** | **95.2%** | 11197109 3.2% / 司棋 1.7% |
| `app/tools/resume_sidebar/normalize.py` | 4,009 | **11099826** | **96.4%** | 11197109 3.6% |
| `app/tools/resume_parser.py` | 3,372 | **11099826** | 63.8% | **11197109 31.3%** / 司棋 4.9% |
| `app/vfs/client.py` | 713 | **司棋** | 55.5% | 11099826 41.1% / 11197109 3.4% |
| `app/tools/doc_agent_tool.py` | 766 | **司棋** | **90.2%** | 11197109 9.4% |
| `app/skills/_system_prompt.md` | 302 | **司棋** | 73.8% | 11099826 15.6% / yitong 6.3% / 陈乾 4.3% |
| `app/llm/blueclaw_chat.py` | 768 | **司棋** | 68.4% | yitong 16.7% / 11099826 15.0% |
| `app/voice/interview_ws.py` | 552 | **yitong** | 66.3% | 司棋 25.0% / 陈妮 6.9% / 11099826 1.8% |
| `app/voice/interview_prompts.py` | 426 | **yitong** | 74.6% | **陈妮 19.7%** / 张梦宇 4.7% / 司棋 0.2% |
| `app/skills/mock_interview_voice.md` | 244 | **yitong** | **99.6%** | 张梦宇 0.4% |
| `app/skills/interview_review.md` | 330 | **陈乾** | **90.6%** | 司棋 8.2% / 11099826 1.2% |
| `app/tools/error_book.py` | 1,032 | **yitong** | **95.3%** | 司棋 4.3% / 11099826 0.4% |
| `app/tools/review_report_tool.py` | 257 | **陈乾** | **99.2%** | 司棋 0.8% |
| `app/tools/audio_tools.py` | 338 | **陈乾** | **83.7%** | 司棋 16.3% |
| `memory/voice_session_store.py` | 356 | **yitong** | **98.0%** | 司棋 1.1% / 张梦宇 0.8% |
| `resume_html_gen_code/.../avatar_extractor.py` | 227 | unknown | 77.1% | 11099826 19.4% / 11197109 3.5% |

---

## 二、结论：客观 Owner 归属校验

将 `git log 视角` 与 `git blame 视角` 对齐，得到最终 Ownership 判定：

| 文件/域 | git log 视角推断 | git blame 存活行验证 | 最终判定 |
|:---|:---|:---|:---:|
| `agent_executor.py` | 司棋 47 次改动 | 11099826 40.3% 行存活 | **共享文件**（无绝对 Owner） |
| `resume_sidebar/pipeline.py` | 11099826 100 次 | 11099826 95.2% | ✅ 11099826 |
| `resume_sidebar/normalize.py` | 11099826 71 次 | 11099826 96.4% | ✅ 11099826 |
| `resume_parser.py` | 11099826 23 次 | 11099826 63.8% + 11197109 31.3% | ✅ 11099826 主 + 11197109 副 |
| `vfs/client.py` | 司棋 22 次 | 司棋 55.5% + 11099826 41.1% | ✅ 司棋主 + 11099826 深度参与 |
| `doc_agent_tool.py` | 司棋 31 次 | 司棋 90.2% | ✅ 司棋 |
| `_system_prompt.md` | 司棋 18 次 | 司棋 73.8% | ✅ 司棋 |
| `blueclaw_chat.py` | 司棋 10 次 | 司棋 68.4% | ✅ 司棋 |
| `voice/interview_ws.py` | yitong 主 | yitong 66.3% | ✅ yitong |
| `voice/interview_prompts.py` | 陈妮 5 次 | **yitong 74.6% + 陈妮 19.7%** | ⚠️ yitong 建基 + 陈妮迭代（提交视角低估了 yitong 的贡献） |
| `mock_interview_voice.md` | yitong 主 | yitong 99.6% | ✅ yitong |
| `interview_review.md` | 陈乾 32 次 | 陈乾 90.6% | ✅ 陈乾 |
| `error_book.py` | yitong 主 | yitong 95.3% | ✅ yitong |
| `review_report_tool.py` | 陈乾 7 次 | 陈乾 99.2% | ✅ 陈乾 |
| `audio_tools.py` | 陈乾 4 次 | 陈乾 83.7% | ✅ 陈乾 |

---

## 三、关键洞察

### 洞察 1：`agent_executor.py` 是真正的**共享文件**

- 4 位主要贡献者都在该文件占比 > 10%（11099826 40% / 司棋 29% / yitong 18% / 陈乾 12%）
- 提交量视角看似"司棋 47 次改动是 Owner"，但**存活行首推 11099826**，说明 11099826 在早期建立了大部分骨架，后续所有人在其之上扩展
- 这也是该文件为何频繁出现在**每个人的 TOP 5 高频文件**中的根本原因

### 洞察 2：`interview_prompts.py` 的"提交视角"低估了 yitong

- 提交视角：陈妮 5 次是最高
- 存活行视角：**yitong 74.6% + 陈妮 19.7%**
- 结论：yitong 建立了 Prompt 骨架（318 行），陈妮在其上迭代（84 行修改集中在出题策略、槽位）
- **展示工作量时不能只看 commit 数，要看存活行**

### 洞察 3：极致 Ownership 的 6 个文件（占比 > 90%）

| 文件 | Owner | 占比 |
|:---|:---|---:|
| `interview_review.md` | 陈乾 | 90.6% |
| `doc_agent_tool.py` | 司棋 | 90.2% |
| `error_book.py` | yitong | 95.3% |
| `resume_sidebar/pipeline.py` | 11099826 | 95.2% |
| `resume_sidebar/normalize.py` | 11099826 | 96.4% |
| `voice_session_store.py` | yitong | 98.0% |
| `review_report_tool.py` | 陈乾 | 99.2% |
| `mock_interview_voice.md` | yitong | 99.6% |

**结论**：项目内主要贡献者都有**至少一个 90%+ 独占的文件**，这是"真正的 Owner"标志。

### 洞察 4：跨 Owner 深度协作的 4 个文件

| 文件 | 组合 | 特征 |
|:---|:---|:---|
| `agent_executor.py` | 11099826 40% + 司棋 29% + yitong 18% + 陈乾 12% | 四人共治 |
| `resume_parser.py` | 11099826 64% + 11197109 31% | 业务侧 + VLM 侧 |
| `vfs/client.py` | 司棋 56% + 11099826 41% | 基础设施 + 使用方 |
| `_system_prompt.md` | 司棋 74% + 11099826 16% + yitong 6% + 陈乾 4% | 全局 skill 联合作者 |

---

## 四、方法论：如何用 blame 验证工作量

**推荐组合看法（评审 / 汇报时）**：

1. **广度**：`git log` 提交数、涉及文件数 → 反映活跃度
2. **深度**：`git blame` 存活行占比 → 反映真实 Ownership
3. **趋势**：月度提交热力图 → 反映持续投入
4. **精度**：TOP 高频文件 → 反映聚焦度

单看任何一个维度都可能被误判。本项目里：
- 陈妮如果只看 blame（19.7%）会被低估，但提交数（11 次专注度）能补足
- 司棋如果只看 blame（`agent_executor.py` 只有 29%）会被低估，但提交数（该文件 47 次改动是最高）能补足
- 11197109 提交数只有 26 次看似不多，但在 `resume_parser.py` 存活行占 31.3%，是真实"深度参与"

---

## 五、版本历史 & 取数命令

### 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次基于 git blame 建立行级 Ownership 矩阵 |

### 取数命令

```bash
# 单文件行级 Ownership
git blame --line-porcelain <file> | grep "^author " | sort | uniq -c | sort -rn

# 批量核心文件
for f in "app/agent_executor.py" "app/tools/resume_sidebar/pipeline.py" ...; do
  echo "===== $f ====="
  git blame --line-porcelain "$f" | grep "^author " | sort | uniq -c | sort -rn
done
```
