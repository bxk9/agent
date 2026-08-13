# 32 · 数据流 · AI 标记 `<<<...>>>` 全生命周期

## 1. 是什么

AI 标记是一段**用尖括号包裹**的简历/复盘内容，例如：

```
项目成果：<<<累计节省成本 300 万+，待用户确认具体数字>>>
```

它表示："这段是 AI 补全/推测的，可信度不高，请用户核对"。

- 前端渲染时高亮为浅黄色 + 悬浮提示；
- 存储层记录标记的**路径 / 提示词 / 来源 / 时间**，跨轮跨天保持；
- 用户"确认"或"覆盖"后标记自动清除。

## 2. 生命周期总览

```
① LLM 输出（含 <<<...>>> 段）
② Agent 后处理：扫描并抽取标记元数据
③ diff 上次持久化标记
④ 落 memory/ai_marks_store（VFS JSON）
⑤ 渲染 HTML 时套高亮 span
⑥ 前端展示 + 用户交互（确认/覆盖）
⑦ 下一轮 Agent 加载已存标记 → 注入 system prompt
⑧ LLM 感知"哪些还没被确认"，避免重复标记或错误清除
```

## 3. 各步骤细节

### ① LLM 输出

- `resume_generator.md` / `interview_review.md` 等 skill 明确要求："若字段来自推测/补全，用 `<<<内容>>>` 包裹"
- 允许嵌套简要提示：`<<<xxx | 待核实>>>`

### ② 后处理抽取

**模块**：`app/tools/resume_sidebar/pipeline.py`（或对应工具的最后阶段）

**动作**：
```python
for path, value in walk(schema_or_html):
    for match in RE_MARK.finditer(value):
        marks.append({
            "path": path,
            "text": match.group(1),
            "hint": parse_hint(match.group(1)),
            "source": "ai_generated",
            "created_at": now(),
        })
```

### ③ 与上次 diff

**模块**：`memory/ai_marks_store.py`

**策略**：
- 键 = `(user_id, person_id, path, text_hash)`
- 若已存在且用户尚未确认 → 保留原 `created_at`（避免"疑似"时间被刷新）
- 新增 / 消失均记入 diff，可用于埋点

### ④ 持久化

**存储**：`users/{uid}/marks/{person_id}.json`

```json
{
  "person_id": "alice",
  "updated_at": "2024-11-...",
  "marks": [
    {
      "path": "experiences[2].bullets[0]",
      "text": "累计节省成本 300 万+",
      "hint": "待用户确认具体数字",
      "source": "ai_generated",
      "created_at": "2024-11-01T...",
      "confirmed": false
    }
  ]
}
```

**person_id 的意义**：一个用户可能对多份"目标简历"分别优化（不同岗位、给不同联系人），标记必须隔离。默认使用 `basic.name` 归一化后的值。

### ⑤ HTML 高亮

Jinja2 模板通过一个自定义 filter 把 `<<<x>>>` 转成：

```html
<span class="ai-mark" data-hint="待用户确认具体数字">累计节省成本 300 万+</span>
```

`style.css` 里定义高亮样式（浅黄底色 + 下划虚线）。

### ⑥ 前端交互

- 悬浮：显示 `data-hint`
- 点击：弹"确认为事实 / 修改内容 / 忽略"三选一
- **确认为事实**：前端调 `SendMessage` 告知 Agent "path 已确认"，Agent 通过 `master_profile_tool` 把内容作为 `source=user_input` 落素材库，并从 marks 中移除。
- **修改内容**：等价于新一轮"局部改写"请求，走 `resume_scope` 主链路。
- **忽略**：把 `confirmed=true` 标位持久化，但**保留**内容（下次渲染仍显示为普通文字）。

### ⑦ 下一轮 Prompt 注入

**模块**：`agent.py` 组装 system prompt 时

```python
marks = memory.ai_marks_store.get_marks(uid, pid)
if marks:
    system_prompt += render_marks_section(marks)
    # "以下字段用户尚未确认，请在改写时保留 <<<...>>> 标记，除非用户明确提供了值"
```

**收益**：LLM 不会在下轮"覆盖"用户尚未确认的疑似字段。

### ⑧ 完整闭环

- 若用户从未确认，标记跨天保持；
- 若用户确认 → 落素材库 + 标记消失；
- 若用户修改内容 → 新内容不含 `<<<>>>` → diff 检测到消失 → 自动移除标记。

## 4. 与素材可信度闸门的联动

| 字段 source | 来源 | 优先级 | 是否带 AI 标记 |
|-----------|-----|-------|--------------|
| `user_input` | 用户在对话中明确说过 | 高（渲染优先） | ❌ |
| `ai_generated` | LLM 推测 / 补全 | 中（可展示） | ✅（`<<<...>>>`） |
| `deprecated` | 用户明确否定 | 低（不展示） | ❌ |

用户"确认"的动作 = 把该字段从 `ai_generated` 升级为 `user_input`；"忽略"则保留 `ai_generated` 但下次渲染不带 `<<<>>>`。

## 5. 常见边界与坑

| 场景 | 行为 |
|------|-----|
| LLM 忘记加标记 | 后处理无法感知；只能通过 skill 提示词强化约束 |
| LLM 加了错误的括号（如单尖） | 正则不匹配，按普通文字渲染；不阻塞 |
| 用户改了 person_id（改了姓名） | 标记会"分家"到新 pid；旧 pid 的标记保留但不再展示 |
| 多个字段有相同文本 | 按 `path` 隔离，互不影响 |

## 6. 关键文件索引

| 文件 | 作用 |
|------|-----|
| `app/skills/resume_generator.md` | 硬约束"必须用 `<<<>>>` 包裹推测" |
| `app/tools/resume_sidebar/pipeline.py` | 抽取标记、diff、注入高亮 |
| `memory/ai_marks_store.py` | 持久化 / 加载 / 清除 |
| `resume_templates/*/style.css` | `.ai-mark` 样式 |

## 7. 相关文档

- `03_design_philosophy.md` 原则 7 — 多层防御
- `16_module_memory.md` — 素材可信度闸门
- `30_data_flow_resume.md` Step 8 — 简历渲染中的标记环节
