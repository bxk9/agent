# 专题 03｜错题本系统建设

> 主要文件：
> - `app/tools/error_book.py`（23 次修改，主 CRUD 工具集）
> - `app/tools/voice_error_book_judge.py`（12 次修改，LLM Judge）
> - `memory/error_book_index.py`（11 次修改，持久化索引）
> - `error_book_template/template.html` + `style.css`（各 7 次，渲染模板）
> - `app/skills/mock_interview_word.md` / `mock_interview_voice.md` 中错题本相关章节
> 时间跨度：2026-07-15 → 2026-08-07
> 版本：v1.0

---

## 一、系统定位

错题本是本项目**唯一**具备"跨 session 持久化 + LLM Judge 自动写入 + 用户可交互增删"的记忆子系统。设计目标：

1. **自动化**：用户不需要显式说"记入错题本"，系统在语音答题结束后自动判断。
2. **可检索**：主 Agent 复盘时能按 session / 按用户 / 按公司 / 按岗位查询。
3. **可维护**：用户能批量删除、批量恢复、单题编辑。
4. **可渲染**：错题本能导出为独立 HTML 文档（`error_book_template/`）。

---

## 二、迭代时间线

### 阶段 A：session 维度化（07-15 → 07-16）

| 日期 | 提交 | 内容 |
|------|------|------|
| 07-15 | `feat(voice-session): 主 Agent session_id 透传 + context 双维度查询 + 复盘链路修复` | 语音 session 与错题本索引绑定 |
| 07-15 | `超链名字与错题本标题保持一致` | 前端展示统一 |
| 07-16 | `feat(voice-session): add-dialogue 后台 LLM judge 自动入册错题本` | **核心特性上线** |
| 07-16 | `fix(voice-error-book): 补齐 VFS sid 绑定，修复入册报「缺少会话标识」` | 上线首个 Bug 修复 |
| 07-17 | `错题本url，下发二次校验` | URL 有效性校验 |

### 阶段 B：Prompt 联动（07-23 → 07-29）

| 日期 | 提交 | 内容 |
|------|------|------|
| 07-23 | `错题本增加session id的记录；更加按照session获取错题本的工具` | 双维度查询：session / user |
| 07-26 | `解决无法语音复习错题的bug` | 复习链路修复 |
| 07-29 | `更新语音加入错题本的prompt的逻辑` | Prompt 里明确 Judge 触发条件 |
| 07-29 | `语音错题本入册强化问题答案边界` | 边界识别（如答案未说完就切题） |
| 07-29 | `语音add-dialogue增加按时间排序，错题本同样增加排序` | 顺序稳定性 |

### 阶段 C：批量操作（07-31）

```
07-31 11:20  增加批量删除和恢复错题本功能，解决大量单题删除引起的limit限制
```

**问题**：用户可能一次要清空 30+ 条错题，若逐条调用 API 会触发限流。

**方案**：新增 `error_book.batch_delete / batch_restore` 工具，支持一次传入 ID 列表；索引层用"软删除"标记，可 undo。

### 阶段 D：稳定性收尾（08-04 → 08-07）

| 日期 | 提交 | 内容 |
|------|------|------|
| 08-04 | `强化错题本的调用和追问只问一题` | 规则约束 |
| 08-07 | `语音错题本识别增加重试机制` | LLM Judge 三次重试 + 指数退避 |

另外多次修复：
- `get_session_error_book对答案进行升序排列`
- `解决query_error_book返回错误vfs链接问题`

---

## 三、关键技术设计

### 3.1 LLM Judge 异步入册流程

```
       语音会话 add-dialogue
              │
              ▼
      落盘（VFS）+ 触发后台任务
              │
              ▼   （不阻塞用户交互）
    ┌─────────────────────┐
    │  voice_error_book_  │
    │  judge.py           │
    │                     │
    │  1. 拼装 prompt     │
    │  2. 调 LLM Judge    │
    │  3. 输出 JSON 决策  │
    │     {入册: bool,     │
    │      理由, 分类,     │
    │      标准答案摘要}   │
    │  4. 失败重试 3 次    │
    └─────────────────────┘
              │
              ▼
       是否入册？───否──► 结束
              │
              是
              ▼
       写入 error_book_index
              │
              ▼
       主 Agent 复盘时可查询
```

### 3.2 索引结构（`memory/error_book_index.py`）

```
error_book_index/
  ├── user_id/                    # 用户维度
  │   └── person_id/              # 人物维度（一个用户可多简历人物）
  │       └── entries: [
  │             {
  │               "eb_id": ...,
  │               "session_id": ...,   ← session 维度检索
  │               "question": ...,
  │               "user_answer": ...,
  │               "standard_answer": ...,
  │               "category": ...,
  │               "created_at": ...,
  │               "deleted": false,     ← 软删除
  │             }
  │           ]
```

### 3.3 双维度查询

| 场景 | 查询键 | 用途 |
|------|-------|------|
| "本次面试哪些题错了" | `session_id` | 单次复盘 |
| "我最近所有错题" | `user_id + person_id` | 长期错题库 |
| "关于 XX 公司的错题" | `user_id + company` | 精准复习 |

---

## 四、量化成果

| 指标 | 数值 |
|------|------|
| 相关代码文件 | 5 个（含 HTML/CSS 模板） |
| 相关提交 | 约 25 次 |
| 相关 Prompt 修改 | 约 8 次 |
| 特性数 | 6（自动入册 / 双维查询 / 批量删恢 / 排序 / URL 校验 / 重试） |
| 关联 Bug 修复 | 4 处（见上表） |

---

## 五、后续可扩展方向

1. **错题本分类模型精细化**：目前 Judge 只输出粗分类，未来可接入 LangGraph 独立子图做 tag 化。
2. **错题相似度聚合**：多次同类错误自动聚合成"高频薄弱点"。
3. **错题冷启动**：新用户尚无错题时给出示例引导。

---

## 六、相关文档

- `../03_modules/16_module_memory.md` - Memory 层架构
- `../03_modules/14_module_tools.md` - Tools 总览
- `01_voice_interview_module.md` - 语音链路（Judge 触发点）
- `02_mock_interview_prompt_engineering.md` - Prompt 联动

---

## 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|---------|
| v1.0 | 2026-08-10 | 初版 |
