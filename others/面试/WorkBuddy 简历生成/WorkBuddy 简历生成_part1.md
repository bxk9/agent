## 一、总入口：两种 docx 方案的选择

WorkBuddy 内有两套做 docx 的能力，**简历任务几乎都走 tencent-docx**（Anthropic 官方通用 docx 插件只命中过一次）：

| 对比 | docx（通用，Anthropic） | **tencent-docx（腾讯，简历走这条）** |
| --- | --- | --- |
| 实现 | docx-js 生成 + 解压 XML 直接编辑 | 编排流水线 orchestrator→writer→formatter→converter |
| 工具链 | pandoc / LibreOffice / docx-js | editor_sdk MCP、html-to-docx、design-token |
| 风格 | 底层代码级操作 | 高层 AI 编排，不写代码，靠 skill 链 |
| 场景 | 简单/确定的 docx 生成 | 复杂专业文档创作（简历即属此类） |

## 二、Stage 0：orchestrator 意图判断

WorkBuddy 处理本地 Office 文件有**两层路由**，分别定义在两个文件中：

| 文件 | 层 | 职责 |
| --- | --- | --- |
| `tencent-docs-routing/SKILL.md` | 全局路由网关 | 所有本地 Office 文件的第一道闸门，按文件类型和任务性质分发 |
| `tdoc-orchestrator/SKILL.md` | tencent-docx 内部编排器 | 只用query生成一个简历用这个 承接创作/美化任务，决策走 full_pipeline 还是 beautify_only |

### 2.1 第一层：tencent-docs-routing（全局网关）

路径：`~/.workbuddy/plugins/marketplaces/workbuddy-builtin/skills/tencent-docs-routing/SKILL.md`

这是**所有本地 Office/WPS 文件操作的首个入口**。按文件类型 + 任务性质分发：

```plaintext
用户请求涉及本地 Office 文件
  └ tencent-docs-routing (第一道闸门)
       ├ 新建 DOCX（生成/写/起草/撰写/重写）
       │   → tencent-docx 插件 → 内部 tdoc-orchestrator 接管
       │
       ├ 整篇美化已有 DOCX（抽象排版诉求，无具体样式值）
       │   → tencent-docx 插件 → 内部 tdoc-orchestrator 接管
       │
       ├ 已有 DOCX 的局部编辑 / 润色 / 具体样式修改
       │   → tencent-local-office-edit（editor_sdk）
       │
       ├ 已有 PPT 的编辑
       │   → tencent-local-office-edit
       │
       ├ 从素材新建 PPT
       │   → tencent-pptx
       │
       ├ 简单表格操作（读/写/格式化/排序）
       │   → tencent-local-office-edit
       │
       └ 复杂表格操作（数据分析/透视表/公式/条件格式）
           → tencent-docs-sheetagent
```

**关键判别**：是"新建文档"还是"编辑已有文档"——这是第一层就决定的分叉。

### 2.2 第二层：tdoc-orchestrator（tencent-docx 内部编排）

路径：`~/.workbuddy/plugins/marketplaces/workbuddy-builtin/builtin-plugins/tencent-docx/skills/tdoc-orchestrator/SKILL.md`

当 `tencent-docs-routing` 判定为"新建 DOCX"或"整篇美化"后，任务进入 tencent-docx 插件，由 `tdoc-orchestrator` 做**第二层决策**：

```plaintext
tencent-docx 插件
 └ tdoc-orchestrator Stage 0 判断
      ├ 创作动词（写/起草/撰写/生成/重写）
      │   → full_pipeline：S1 writer → S2 formatter → S3 converter
      │   → 产出：md → html → docx
      │
      ├ 抽象美化（美化一下/更专业/更好看，无具体样式值）
      │   → beautify_only：S2 formatter → S3 converter
      │   → 产出：html → docx（复用已有文档内容作输入）
      │
      └ 编辑/润色/具体样式修改
          → 本 skill 不承接，转回 tencent-docs-routing 重新路由
```

**美化 vs 编辑的分界**：

- 抽象诉求（"好看点""专业点"）→ 美化（走 beautify_only，S2→S3）
- 具体目标值（"宋体五号""1.5倍行距""改标题"）→ 编辑（转 tencent-docs-routing）
- "润色/优化表达" → 编辑（保原意与结构，只改表达）

### 2.3 简历场景的路由决策

```plaintext
用户说"帮我生成一份简历"
  → tencent-docs-routing："新建 DOCX" → 路由到 tencent-docx
  → tdoc-orchestrator："创作" → full_pipeline (S1→S2→S3)
  → S1 writer(md) → S2 formatter(html) → S3 converter(docx) → 预览

用户说"把这段经历加到简历里"
  → tencent-docs-routing："已有 DOCX 局部编辑" → 路由到 tencent-local-office-edit
  → editor_sdk 直接操作 .docx

用户说"美化一下简历"
  → tencent-docs-routing："整篇美化" → 路由到 tencent-docx
  → tdoc-orchestrator："美化" → beautify_only (S2→S3)

用户说"把标题改成宋体五号"
  → tencent-docs-routing："具体样式修改" → 路由到 tencent-local-office-edit
```

### 2.4 编排原则（铁律）

tdoc-orchestrator 有 6 条铁律，其中最关键的是：

1. **弹性入口**：每次请求先判意图，不默认走完整链路
2. **链路不可中断**：一旦组合，必须顺序执行到 S3 结束
3. **真委派**：通过角色切换加载 `agents/<name>.md` 执行，禁止读了 agent 定义后"顺手做"
4. **中间产物不展示**：S1 的 md、S2 的 html 只给路径，不贴正文、不预览；只有 S3 的 docx 强制 `present_files` 打开
5. **编辑意图不承接**：识别到编辑意图后，不创建 pipeline 目录、不写 pipeline-state、不派 stage，直接转 tencent-docs-routing

## 三、三段流水线（简历生成主链路）

| Agent | Stage | 职责 | 产出 |
| --- | --- | --- | --- |
| **doc-writer** | Stage 1 | 匹配 Expert Skill 驱动创作，调度 Critic 审查 | `.md`（中间产物） |
| **doc-formatter** | Stage 2 | 选模板/仿写参考版式，排版美化 | `.html`（中间产物） |
| **doc-converter** | Stage 3 | HTML→DOCX 转换，强制 present_files 打开预览 | `.docx`（最终交付） |

每个 Agent 只做自己一环，不越界。也遇到过跳过中间态、直接 HTML→Word 的情况。

## 四、Stage 1 内部：Expert 路由（简历命中 general-writer）

doc-writer 写 Markdown 时按关键词匹配 9 个 Expert，只加载命中的那个 SKILL.md：

- **L2 专业 Expert（8 个）**：legal-contract / stock-research-report / business-copy / tech-blog / academic-paper / science-writing / work-report / poetry-prose
- **L1 兜底**：`general-writer`（简历不命中任何 L2，走此 Expert）

流程：

```plaintext
关键词匹配 → 加载命中 Expert SKILL.md → Expert 产出 Markdown
→ doc-writer 做 Critic 审查 → 产出 final_draft.md → 交给 Stage 2
```

### 4.1 Critic 审查机制（doc-writer 核心环节）

Expert 产出 draft 后，doc-writer 负责 Critic 全生命周期编排。Expert 只负责"写作 + 输出 `critic_config` 声明"，审查调度完全由 doc-writer 执行。

#### 4.1.1 总体流程

```plaintext
Expert 产出 draft + critic_config
  │
  ├─ 按风险分档表决策：命中 skip？
  │   ├─ Yes → 跳过 Critic，直接写入终稿
  │   └─ No  → 进入 Critic 编排
  │
  └─ Critic 编排：
      1. 解析 critic_config YAML
      2. 生成 critic 参数文件 → output/params/critic.yaml
      3. 驱动 Critic 引擎 → 产出审查决策
      4. 决策分支：
         ├─ PASS      → 终稿返回 Orchestrator
         ├─ REVISE    → doc-writer 携带 P0 修订指令，重新驱动 Expert 重写对应部分 → 复审
         ├─ DEGRADED  → 终稿 + 未解决问题列表返回 Orchestrator
         └─ REJECT    → doc-writer 携带审查报告，重新驱动 Expert 整体重写 → 复审
      5. 循环上限：max_loops 次未达 PASS → 降级为 DEGRADED
```

#### 4.1.2 风险分档表（决定是否跑 Critic）

设计原则：同模型自审对事实/创意/表达类问题存在同源盲区，价值有限；只对**必备要素可枚举**的高风险文体强制跑。

| 风险档 | genre | 默认模式 | 理由 |
| --- | --- | --- | --- |
| 高风险 | `legal-contract` | `per-section` | 缺条款 = 出事 |
| 高风险 | `stock-research` | `per-section` | 缺风险提示/数据披露 = 合规问题 |
| 高风险 | `academic-paper` | `once` | 学术格式强制 |
| 中风险 | `work-report` | `once` | 汇报要素可核 |
| 中风险 | `business-copy` | `once` | Slogan/CTA 结构可核 |
| **低风险** | `**general**` | `**skip**` | **L1 通用兜底，默认不跑** |
| 低风险 | `science-writing` | `skip` | 同源盲区，自审形式主义 |
| 低风险 | `tech-blog` | `skip` | 主观表达为主 |
| 低风险 | `poetry-prose` | `skip` | 创意表达无法用 rubric 评 |

**简历命中 **`**general**`** → 低风险 → 默认 **`**skip**`**，不跑 Critic。**

#### 4.1.3 三种 Critic 模式

| 模式 | 触发节奏 | 适用 |
| --- | --- | --- |
| `once` | 全文写完 → 全文审一次 | 中/高风险且非长文 |
| `per-section` | 每章写完 → 审该章 → 全文再审 | 高风险长文 |
| `skip` | 不调用 Critic | 低风险文体默认 |

#### 4.1.4 如果跑 Critic，评分标准是什么

Critic 引擎加载 Expert 提供的 `rubrics_files`（评分尺规），general-writer 的尺规是 `quality-framework.md`，按 **7 个维度独立打分**（0-100），加权求总分：

| 维度 | 权重 | 考查内容 |
| --- | --- | --- |
| D1 事实准确性 | 20% | 数据、引用是否准确，来源是否标注 |
| D2 逻辑严密性 | 20% | 论点间因果、递进、对比是否自洽 |
| D3 结构清晰度 | 15% | 起承转合、段落划分、中心句 |
| D4 语言精炼度 | 15% | 冗余、啰嗦、单句长度 |
| D5 风格一致性 | 10% | 人称、语气、中英混用 |
| D6 受众适配度 | 10% | 表达是否符合目标读者认知水平 |
| D7 创新与洞察 | 10% | 是否有独特观点、类比、见解 |

```plaintext
总分 = D1×0.20 + D2×0.20 + D3×0.15 + D4×0.15 + D5×0.10 + D6×0.10 + D7×0.10
```

- **通过阈值**：总分 ≥ 75
- **单维度否决**：任一维度 < 60，即使总分达标也必须重写对应段落

#### 4.1.5 对简历的实际影响

由于简历走 `general-writer`，风险分档为低风险，**Critic 默认 skip**。这意味着：

- Excel 生成的简历 draft 不会经过 7 维打分审查
- 不会触发 REVISE/REJECT 的修订循环
- draft 直接作为 `final_draft.md` 进入 Stage 2 (doc-formatter)
