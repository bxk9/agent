<td></td>
<td>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/q11lGxwcjNrlvdB_a-npij22FCrmkxlq86ZKGgA9votaS0k4Zuej74DgWSS2317d)</td>
<td>![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/Gmgiuy4vcNWuL6AaFW_RAeLf-BfGXA7fTu2WhZatycZtuMzcgs0B21OM7lXj6hRp)</td>
</tr>
</table>

录音的上传 - 媒体是支持上传上来； 不支持解析，解析可以场景先用录音机的技能。

端侧搜索工具--张莹-72220177/陈慧均

1 本地搜是否接入；

2 本地搜的能力上限是否可以支撑我们搜不带“面试简历”字样的文件（比如个人毕业证，个人实习证明等类似的）可以帮助生成简历的文件

---

## 五、云/PC Claw 工具

> PC Claw 负责人：黄卫兵/ 云 Claw：张硕/vfs：利军
> 打通节奏：云 Claw `web_fetch` 可用后开始接入；文件互传由利军负责

| 工具 | 触发场景 | 对应需求 |  |
| --- | --- | --- | --- |
| `browser.jd_fetch` | 用户提供招聘平台 URL / 关键词，云 Claw 抓取 JD 全文 | ① JD 与公司画像构建 | 待定 |
| `browser.experience_fetch` | search.dispatcher 缓存 miss，云 Claw 抓取面经 | ① JD 与公司画像构建 | 待定 |
| `resume.render`<br>`resume.render_diff` | 简历改写完成，云 Claw 渲染 PDF/DOCX并对比展示 | ③ 简历定向改写与渲染 | 待定 |
| `file.scan_local` | 用户首次进入简历场景，PC Claw /手机扫描本地目录找旧简历、简历可用文件 | 需求1（待定） | PC Claw/端claw |
| `file.cross_device_transfer` | PC /手机生成简历后，PC Claw和手机互相推送文件 | 需求4（本期基础版） | vfs |

## 七、文件管理策略

> 负责人：赵雪君（11170258）；vfs：利军

### 核心问题

如何让面试 Skill **详细记录面试细节**，同时让用户问其他问题时也能**保留面试相关记忆**？

**设计核心**：让"面试详情"留在 Skill 私有目录，把"面试摘要"提炼到 USER 域和 AIE 云端记忆。

### 需求

1. 存面试 Skill 场景过程中生成的文件、面试 timeline 长期记录
2. 用户在其他场景提到面试时，系统能感知并主动联动面试场景

---

### **1、BlueClaw 现有的记忆域分布**

BlueClaw 当前已有的记忆体系：

```
全局记忆（系统级，所有场景可见）
├── SOUL.md      — Agent 人设
  ├── USER.md      — 用户长期画像(姓名、昵称、偏好禁忌等)
├── RULES.md     — 记忆规则
└── IDENTITY.md  — 多重人设
​
云端 AIE Memory（跨设备/跨 Agent，由 session listener 自动上报）
├── core 记忆        — 预消化的索引（偏好/身份/关键事件/对话摘要）
├── structured 记忆  — 9 类结构化数据（家庭/办公地址/订单等）
└── universal 记忆   — 多策略检索兜底
​
```

```
Skill 私有文件（仅 Skill 内可见，通过 vfs_* Tool 读写）
└── workspace/{agentId}/{skill_domain}/
    ├── *.json   — 结构化数据
    └── *.md     — LLM 可读摘要
```

### **各域职责**

| **域** | **文件 / 接口** | **内容性质** | **来源** | **是否拼入 system prompt** |
| --- | --- | --- | --- | --- |
| `RULES` | `MEMORY_RULES.md` | 记忆系统规则 | 端侧静态 | 是（via `getMemoryRules()`） |
| `SOUL` | `SOUL.md` | Agent 人设 / 性格 | 云端动态刷新 | 是（via `<soul>`） |
| `USER` | `USER.md` | 用户画像 / 偏好 / 关系 | 云端动态刷新 | 是（via `<user>`） |
| `IDENTITY` | `IDENTITY.md` | 多重身份切换 | 端侧静态 | 按需 |
| Skill 私有目录 | workspace 文件 | 各 Skill 专属业务数据 | Skill 自己写 | 否（按需读） |
| AIE 云端 | ContentProvider | 全量对话 + 派生索引 | session listener 自动 | 否（按需检索） |

---

### **2、四层记忆架构**

```
┌──────────────────────────────────────────────────────────────┐
│  L1: 全局 prompt 注入层（始终在 system prompt）                │
│  ─ 由 MemoryManager.getAgentMemory() 注入                     │
│  ─ <user> 域含一句"该用户正在准备java面试，目标大厂"      │
│  ─ 任何场景的 LLM 都能看到，自然带入个性化                      │
│  容量：KB 级 / 时效：长期 / 写入方：MemoryManager（云端刷新）   │
├──────────────────────────────────────────────────────────────┤
│  L2: 系统级语义检索（LLM 主动调用）                             │
│  ─ search_user_memory(query, mode=core)                       │
│  ─ 用户问"周末安排啥" → LLM 主动检索 → 知道下周有面试           │
│  ─ 跨 Skill 共享、按需召回                                      │
│  容量：MB 级 / 时效：长期 / 写入方：AIE 云端（addMessage 派生） │
├──────────────────────────────────────────────────────────────┤
│  L3: Skill 私有详情（仅面试 Skill 激活时读）                    │
│  ─ vfs_read_file workspace/{agentId}/interview/...            │
│  ─ 题目、回答、追问、逐题评分、INSIGHTS 摘要                    │
│  ─ 详情不污染其他场景                                           │
│  容量：MB-GB 级 / 时效：长期 / 写入方：面试 Skill 直接 vfs_write│
├──────────────────────────────────────────────────────────────┤
│  L4: 云端冷数据（长期归档 + 派生索引）                           │
│  ─ session listener 自动 addMessage 上报                       │
│  ─ AIE 自己做 core/structured/universal 索引                   │
│  ─ 跨设备恢复、长期分析                                         │
│  容量：不可见 / 时效：长期 / 写入方：session listener 自动      │
└──────────────────────────────────────────────────────────────┘
```

### **各层职责矩阵**

| **层** | **存什么** | **谁写** | **谁读** | **Skill 是否需关心** |
| --- | --- | --- | --- | --- |
| L1 全局画像 | 1-3 句用户长期画像 | 面试 Skill 输出"画像建议" → 系统写入 USER 域 | 任何 LLM 调用 | 关心（要主动输出画像） |
| L2 主动检索 | 同 L1（云端镜像） | AIE 后台索引 | LLM 按需调 | 不关心 |
| L3 Skill 详情 | 题目/答案/评分原始数据 | 面试 Skill 直接写 | 仅面试 Skill | 关心（核心写入路径） |
| L4 云端归档 | 全量对话上报 | session listener 自动 | AIE 后台分析 | 不关心 |

---

### **3、Memory Strategy（面试相关的文件管理策略）**

**核心思路**：让"面试详情"留在 Skill 私有目录，把"面试摘要"提炼到 USER 域和 AIE 云端。

### **核心流程**

#### **读取记忆:**

```
激活时
   ↓
[L3] vfs_read_file workspace/{agentId}/interview/candidate.json
[L3] vfs_read_file workspace/{agentId}/interview/job.json
   ↓
出题前
   ↓
[L3] vfs_glob workspace/{agentId}/interview/history/*.json
[L3] 必要时 vfs_grep 搜某类题
   ↓
关心用户长期画像时
   ↓
[L2] search_user_memory(query="用户职业方向和学习目标", mode=core)
   ↓
（L1 全局画像已经在 system prompt 里，LLM 自动可见，无需主动读）
```

#### **写入文件:**

```
面试 Skill 执行完
   ↓
[L3] vfs_write_file → workspace/{agentId}/interview/history/{date}.json
     追加一条 InterviewRound 记录
     ⛔ 不写 USER 域、不写 INSIGHTS.md
​
每场结束（摘要 + 画像）⭐ 关键
   ↓
① [L3] vfs_write_file → workspace/{agentId}/interview/INSIGHTS.md
        累积洞察（弱项/进步轨迹），仅本 Skill 可见
   ↓
② [L1] 输出"画像更新建议"，由系统 MemoryManager 写入 USER 域
        例："建议更新用户画像：用户近期专注 Java 后端面试，已完成 N 场，
              优势 X，弱项 Y，目标月份 Z。"
​
对话本身（自动）
   ↓
[L4] session listener 自动调 AIE.addMessage（Skill 完全无感）
     AIE 后台自动派生 core / structured / universal 索引
```

### **4、面试 Skill 的文件管理策略**

### **SKILL.md 关键章节**

```markdown
## Memory Strategy（记忆策略）
​
### 读：分层读取
1. 激活时：vfs_read_file 读 workspace/{agentId}/interview/candidate.json + job.json
2. 出题前：vfs_glob workspace/{agentId}/interview/history/*.json，按弱项命中
3. 关心用户偏好时：search_user_memory(query="用户面试目标和职业方向", mode=core)
4. L1 全局画像无需手动读：system prompt 中的 <user_memory> 已自动注入
​
### 写：分层写入
1. 每轮答完（详情）：
   vfs_write_file → workspace/{agentId}/interview/history/{今日日期}.json
   仅追加，不覆盖；不写 USER 域
2. 每场结束（摘要 → 全局可见）— 核心：
   - 步骤 A：vfs_write_file 更新 INSIGHTS.md（本 Skill 私有累积洞察）
   - 步骤 B：在最终回答中明确输出一句"画像更新建议"，由系统写入 USER 域
   - 摘要必须 1-3 句、不含具体题目、突出方向和弱项
3. AIE 自动：对话由 session listener 自动 addMessage，Skill 不关心
​
```

### **5、用户问其他问题时，记忆如何被"看见"**

举三个具体场景：

### **场景 ① 用户问"周末有什么安排"**

```
LLM 看到 system prompt 中的 <user_memory>：