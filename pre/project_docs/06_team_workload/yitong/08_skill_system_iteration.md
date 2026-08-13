# 专题 08｜Skill 体系迭代

> 主战场：`app/skills/`（4074 行 markdown/py，14 个 skill 文件）
> 相关：`docs/design/Skill 化改造完整方案.md`
> 版本：v1.0

---

## 一、Skill 体系定位

Skill 是本项目**产品能力的正交切片**：每一项对用户可见的技能（简历优化、模拟面试、复盘、错题本查询…）都对应一个 `.md` 文件，通过 `_loader.py` 按需加载到 LLM 上下文。这是主 Agent 保持"多能力 + 低 token"的关键设计。

---

## 二、Skill 目录

| Skill 文件 | 我的修改次数 | 用途 |
|-----------|-------------|------|
| `_system_prompt.md` | 33 | 系统级人设与路由 |
| `_product_contract.md` | — | 产品级契约 |
| `_loader.py` | 14 | 动态加载器 |
| `mock_interview_word.md` | 67 | 文字模拟面试 |
| `mock_interview_voice.md` | 56 | 语音模拟面试 |
| `mock_interview.md` | 9 | 通用面试基类 |
| `resume_opt_head.md` | — | 简历优化技能 |
| `resume_gen_head.md` | — | 简历生成技能 |
| 其他若干 | — | 复盘、错题查询等 |

---

## 三、Skill 化改造背景

参见 `docs/design/Skill 化改造完整方案.md`。改造前的问题：
- 所有能力提示词打包到单个 `system_prompt` → token 占用极高
- 修改某个能力的话术会影响其他能力（耦合）
- 无法针对场景动态启用/禁用能力

改造后：
- **动态加载**：LLM 通过 `load_skill_detail(skill_name)` 工具按需拉取
- **按主题拆分**：每个 skill 独立 markdown，可独立版本
- **契约层**：`_product_contract.md` 沉淀跨技能通用规则

---

## 四、我在 Skill 体系上的主要工作

### 4.1 `_system_prompt.md`（33 次修改）

作为**系统人设与路由**的入口，每次调整都涉及：
- 主 Agent 应该在何时主动 load 哪些 skill
- 语音/文字通道的路由规则
- 错题本相关工具的触发时机

### 4.2 `mock_interview_voice.md`（56 次）+ `mock_interview_word.md`（67 次）

详见 [`02_mock_interview_prompt_engineering.md`](./02_mock_interview_prompt_engineering.md)。

### 4.3 `_loader.py`（14 次）

Skill 加载器的迭代包括：
- 支持相对路径 / 绝对路径
- 缓存机制（避免同一 session 重复 load）
- 错误处理（skill 不存在时给友好提示）
- 与 `_product_contract.md` 的自动合并

### 4.4 模拟面试 skill 版本与 pre 同步

```
07-23 11:22  模拟面试skill版本与pre同步
```

一次涉及预发和生产的话术同步动作，说明 Skill 已成为跨环境版本化管理的基本单位。

---

## 五、Skill 迭代与产品迭代的映射

| 产品迭代 | Skill 表现 |
|---------|-----------|
| 面试配置字段精简 | `mock_interview_*.md` 里的配置模板改动 |
| 引入错题本自动入册 | `mock_interview_voice.md` 增加 Judge 触发条件段落 |
| 追问上限 | 增加"每题最多 N 次追问"硬约束 |
| 深度追问默认 | `mock_interview_word.md` 默认策略切换 |

**核心观察**：Skill 文件的 git 历史 = 产品迭代的语义化 changelog。

---

## 六、量化成果

| 指标 | 数值 |
|------|------|
| 我修改 Skill 相关文件的总提交 | 165+ |
| 涉及 Skill 文件 | 5 个 |
| Skill 平均迭代次数 | 40+ |
| 最活跃单文件 | `mock_interview_word.md`（67 次） |

---

## 七、相关文档

- `docs/design/Skill 化改造完整方案.md` - 原始设计
- `../03_modules/13_module_skills.md` - Skill 模块架构
- `02_mock_interview_prompt_engineering.md` - Prompt 演进

---

## 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|---------|
| v1.0 | 2026-08-10 | 初版 |
