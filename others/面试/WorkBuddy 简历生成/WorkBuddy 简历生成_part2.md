如果某次简历生成需要质量审查，可以通过 `critic_config.force_mode: once` 覆盖默认行为。

## 五、任务状态管理：pipeline-state.yaml

全程用 `pipeline-state.yaml` 记录进度。每进一 Stage 都先校验前置状态，例如进 Stage 1 前会：

1. 读 `pipeline-state.yaml` 验证 `current_stage == 1` 且 `stage_0.status == completed`
2. 路由到 general-writer Expert
3. 加载 SKILL.md → 驱动创作 → 回写 `final_draft.md`

## 六、辅助尝试：A4 密度估算（未成功）

converter 后想量化"简历写了几页/页面填充度"，写了个 python 脚本（`~/.venv-html-to-docx` 环境）：

- 遍历 .docx 所有段落，中文按全角、英文按 0.55 倍宽估算每段宽度
- 对比 A4 可打印宽度 174mm 算每段折合行数
- A4 高 261mm ÷ 行高（字号×1.42）得每页容量
- 输出 `fill%` = 内容行数 / 每页容量

脚本运行成功，但实际密度估算并没达到预期效果。

## 总结

```plaintext
用户请求"帮我生成一份简历"
  → orchestrator 判为"创作"意图
  → doc-writer 匹配 general-writer Expert，产出 Markdown 草稿
  → doc-formatter 选模板排版，产出 HTML
  → doc-converter HTML→DOCX 转换并预览

用户请求"帮我把这段经历加到简历里"
  → orchestrator 判为"编辑"意图
  → tencent-docs-routing 路由分发
  → tencent-local-office-edit（editor_sdk 直接操作 .docx）
```

# doc工具

[https://docs.vivo.xyz/s/3nPnHTxs](https://docs.vivo.xyz/s/3nPnHTxs) 邀请您加入文档协作【workbuddy工具清单】

## editor_sdk DOC 工具分类（52 个）

> 来源：`tencent-local-office-edit/all_tools_schema.md`
> 坐标体系：DOC 的 idx/begin/end 是 UTF-16 code unit 坐标，不是段落序号或肉眼字符数

### 一、插入内容（11 个）

| 工具 | 说明 | 格式 |
| --- | --- | --- |
| `doc_insert_markdown` | Markdown 灌入，引擎自动转富文本 | Markdown |
| `doc_insert_html_content` | 粘贴 HTML 富文本 | HTML |
| `doc_insert_text` | 插入纯文本 | 纯文本 |
| `doc_insert_paragraph` | 插入空段落 | — |
| `doc_insert_paragraph_with_text` | 插入带文本的段落（可指定标题级别/编号） | 纯文本 + 样式参数 |
| `doc_insert_math` | 插入 LaTeX 数学公式 | LaTeX |
| `doc_insert_image` | 插入图片 | 图片 |
| `doc_insert_table_by_csv` | 插入 CSV 数据表格 | CSV |
| `doc_insert_page_break` | 插入分页符 | — |
| `doc_insert_section_break` | 插入分节符 | — |
| `doc_insert_word_art` | 插入艺术字 | — |

### 二、修改内容（5 个）

| 工具 | 说明 |
| --- | --- |
| `doc_replace_text` | 替换指定范围文本 |
| `doc_find_and_replace` | 查找 + 替换 |
| `doc_modify_paragraph` | 修改段落属性（对齐/间距/缩进/编号/引用） |
| `doc_modify_section` | 修改节属性（页边距/纸张/页眉页脚） |
| `doc_update_text_property` | 修改文字属性（字体/字号/颜色/加粗/斜体） |

### 三、表格操作（10 个）

| 工具 | 说明 |
| --- | --- |
| `doc_get_table_info` | 获取表格信息（行列数/尺寸） |
| `doc_insert_table_column` | 插入列 |
| `doc_insert_table_row` | 插入行 |
| `doc_delete_table` | 删除表格 |
| `doc_delete_table_column` | 删除列 |
| `doc_delete_table_row` | 删除行 |
| `doc_merge_table_cells` | 合并单元格 |
| `doc_unmerge_table_cells` | 拆分单元格 |
| `doc_modify_table_region` | 修改表格区域内容 |
| `doc_set_table_layout` | 设置表格行高/列宽 |
| `doc_set_table_properties` | 设置表格属性 |

### 四、查询/读取（10 个）

| 工具 | 说明 |
| --- | --- |
| `doc_resolve_document_structure` | 获取文档结构树（段落/标题/表格节点，三档 mode：outline/compact/full） |
| `doc_find` | 全文搜索 |
| `doc_get_outline` | 获取大纲（仅标题） |
| `doc_get_comments` | 获取批注列表 |
| `doc_get_images` | 获取图片列表 |
| `doc_get_paragraph_property` | 获取段落属性 |
| `doc_get_text_property` | 获取文字属性 |
| `doc_get_section_property` | 获取节属性 |
| `doc_get_last_operable_pos` | 获取文档末尾可写位置 |
| `doc_get_word_art_info` | 获取艺术字信息 |

### 五、删除（3 个）

| 工具 | 说明 |
| --- | --- |
| `doc_delete_paragraph` | 删除段落（不可删最后一个） |
| `doc_delete_comment` | 删除批注 |
| `doc_delete_table` | 删除表格 |

### 六、格式/样式（3 个）

| 工具 | 说明 |
| --- | --- |
| `doc_copy_format` | 复制格式 |
| `doc_insert_border` | 插入分隔线 |
| `doc_insert_normal_link` | 插入超链接 |

### 七、页眉页脚/批注（4 个）

| 工具 | 说明 |
| --- | --- |
| `doc_insert_header` | 插入页眉 |
| `doc_insert_footer` | 插入页脚 |
| `doc_insert_footnote` | 插入脚注 |
| `doc_insert_comment` | 插入批注 |
| `doc_set_page_number` | 设置页码 |

### 八、其他（7 个）

| 工具 | 说明 |
| --- | --- |
| `doc_replace_image` | 替换图片 |
| `doc_revert_revision` | 回退指定版本修订 |
| `doc_list_recent_ai_edits` | 列出最近 AI 编辑记录 |
| `doc_compare_documents` | 文档对比 |
| `doc_to_image` | 文档转图片 |

### 关键结论

- 只有 `doc_insert_markdown` 一个工具接受 Markdown 输入
- 其他格式路径：HTML（`doc_insert_html_content`）、纯文本（`doc_insert_text`）、CSV（`doc_insert_table_by_csv`）、LaTeX（`doc_insert_math`）
- **没有全量读取文本的工具**——`doc_resolve_document_structure` 只返回截断的 text_preview（compact 模式 10 字符，full 模式 50 字符），无法直接拿到完整段落文字
- 批量插入优先用 `doc_insert_markdown`，不要拆成大量 `doc_insert_text` / `doc_insert_paragraph` 调用