# 13 · 模块 · Skill Markdown 系统 `app/skills/`

## 1. 模块定位

Skill 系统是 Agent 的**能力路由与人格定义**。每个 `.md` 文件描述一个技能（角色、目标、可用工具、输出规范），`_loader.py` 在每轮请求开始时**按需**扫描组装出最终的 `system prompt`。

一句话：**改产品体感 = 改 md**。

## 2. 文件清单

| 文件 | 类型 | 触发场景 |
|------|------|---------|
| `_system_prompt.md` | 全局前缀 | 所有技能：角色定位 + 硬约束 |
| `_product_contract.md` | 全局前缀 | 所有技能：产品契约（对齐式反馈、不自造数字等） |
| `resume_generator.md` | Skill | 简历生成 / 优化 主流程 |
| `resume_opt_head.md` | 片段 | 简历优化的头部系统提示（与 generator 组合） |
| `mock_interview_word.md` | Skill | 文字模拟面试 |
| `mock_interview_voice.md` | Skill | 语音模拟面试 |
| `interview_review.md` | Skill | 面试复盘 |
| `error_review.md` | Skill | 错题复习（艾宾浩斯抽题 + 逐日计划） |
| `_loader.py` | 加载器 | 扫描目录、按技能选片段、拼接 system prompt |

命名约定：
- `_` 前缀：**全局片段**（不作为独立 skill 暴露）；
- 无前缀：**独立 skill**，文件名即技能标识（去 `.md`）。

## 3. 对外契约

```python
from app.skills._loader import build_system_prompt

sp = build_system_prompt(
    skill: str = "resume_generator",   # skill 标识
    context: dict = None,              # 变量注入（如 user_name, jd_summary）
)
# 返回单个 str，直接作为 SystemMessage 内容
```

`_loader.py` 组装顺序（示例，简历生成）：

```
_system_prompt.md
  + _product_contract.md
  + resume_opt_head.md     # 可选
  + resume_generator.md    # 主体
  + context 变量替换（Jinja2 风格 {{...}}）
```

## 4. 核心设计理念（模块级）

1. **Prompt 是配置，不是代码**  
   将 prompt 抽离到 `.md` 意味着：
   - 产品/运营可以直接改；
   - Git diff 清晰；
   - 单个技能改动不会碰到 Python 逻辑。

2. **组合优于继承**  
   全局片段（`_system_prompt.md` / `_product_contract.md`）**始终**作为前缀，避免每个技能重复 "你是一个 XX 助手…" 段落。

3. **变量注入用 `{{...}}` 风格**  
   便于工程师把动态信息（用户名、当前简历版本、JD 摘要）无侵入地嵌入 prompt。

4. **技能 = md + 工具白名单**  
   md 决定"怎么想"，工具白名单决定"能做什么"。两者在 Agent 层组合，构成一个完整 Skill。

5. **不做 Prompt 版本管理**  
   Git 已经是版本管理。若需要 A/B，走文件名后缀（`resume_generator.v2.md`）+ 环境变量切换即可。

## 5. 技能与工具白名单

（示意，具体白名单在 `agent.py` 的 `_agent_tools_for(skill)` 中维护）

| Skill | 主要暴露工具 |
|-------|------------|
| `resume_generator` | `resume_scope`、`master_profile_tool`、`resume_template_sidebar`、`resume_template_docx`、`resume_export`、`resume_memory_tool`、`jd_extractor`、`interview_search` |
| `mock_interview_word` | `interview_search`、`market_insight`、`error_book`、`voice_error_book_judge` |
| `mock_interview_voice` | 语音链路独立；主 Agent 仅在准备阶段用 `master_profile_tool` / `resume_memory_tool` |
| `interview_review` | `review_report_tool`、`review_report_check`、`error_book`、`review_tool` |
| `error_review` | `error_book`（读/写）、艾宾浩斯排期算法在 md 中描述 |

## 6. 典型调用链

```
agent.stream(skill="resume_generator", ...)
  → skills._loader.build_system_prompt("resume_generator", ctx)
       读 _system_prompt.md
       + _product_contract.md
       + resume_opt_head.md
       + resume_generator.md
       变量替换 {{user_name}} 等
  → SystemMessage(content=sp) + user messages
  → LangGraph
```

## 7. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增技能 | 新建 `skill_x.md`，在 `_loader.SKILL_RECIPES` 里登记组合关系；在 `agent._agent_tools_for` 加白名单 |
| 修改所有技能共有约束 | 只改 `_system_prompt.md` 或 `_product_contract.md` |
| 让某技能"更保守" | 在其 md 里加"若不确定，用 `<<<...>>>` 标记"这类硬约束，无需改代码 |
| A/B 测 prompt | `resume_generator.v2.md` + env `RESUME_PROMPT_VARIANT=v2` |

**易踩坑**：
- md 里如果出现 `{{ }}` 但**不是**变量意图（例如示例代码），需要转义或改成 `\{\{`，否则会被替换器吃掉。
- 全局片段变更影响面广，**必须**跑一遍所有技能的冒烟对话。
- 不要在 md 里放"绝对时间"（如 "现在是 2024 年"），会随日期失效；用变量注入 `{{today}}`。

## 8. 阅读下一站

- `14_module_tools.md` — 工具白名单的另一半
- `03_design_philosophy.md` 原则 2 — Skill 即 Markdown 的取舍
