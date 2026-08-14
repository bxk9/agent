  [✓] idx (integer): 表格内任意 cell 的 DOC 坐标
  [✓] col (integer): 1-based 列号，新列将克隆该列的样式（tcPr + 列宽）。范围 [1, col_count]。与 doc_get_table_info 返回的 col 一致，直接传入即可
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] inserted_back (boolean): true=在该列后方插入（默认），false=在该列前方插入
```

---

## doc_insert_table_row

```plaintext
# doc_insert_table_row

在表格中插入一行（DOC）。idx 为表格内任意 cell 的 GCP 位置，row 为 1-based 行号（指定从哪行克隆样式），insert_below=true 在该行下方插入，false 在上方插入。新行克隆源行的 trPr 和每个 cell 的 tcPr/段落/文本属性。使用前先调用 doc_get_table_info 获取表格结构和行号。

参数（✓=必填）：
  [✓] idx (integer): 表格内任意 cell 的 DOC 坐标
  [✓] row (integer): 1-based 行号，新行将克隆该行的样式。范围 [1, row_count]。与 doc_get_table_info 返回的 row 一致，直接传入即可
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] insert_below (boolean): true=在该行下方插入（默认），false=在该行上方插入
```

---

## doc_insert_text

```plaintext
# doc_insert_text

在指定位置插入文本（DOC）。idx 是 DOC 坐标，必须来自查询结果或上一次写操作返回值；不要按肉眼字符数、段落序号或行号手算。注意：如果需要插入换行，应该要插入段落，而不是在文本里插入换行符号。
返回值：成功响应中包含 `last_edit_index` 与 `position`（两者同值），表示**本次插入完成后可直接用于下一次插入的 idx**（语义：= 原 idx + 插入文本的 UTF-16 字符数）。可将该值直接作为下一次 `doc_insert_text` 的 idx 进行链式追加，**无需**再次查询位置。

参数（✓=必填）：
  [✓] idx (integer): 插入位置的 DOC 坐标，来自查询结果或上一次写操作返回值；不是段落序号。
  [✓] text (string): 要插入的文本内容
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_insert_word_art

```plaintext
# doc_insert_word_art

在指定位置插入一段艺术字（带变形样式的文本），返回 wordart_idx 用于后续读/改属性。

参数（✓=必填）：
  [✓] idx (integer): 插入位置的 DOC 坐标
  [✓] style (string): 艺术字视觉效果（40 种可选）：
        拱形/圆环：arch_up / arch_down / arch_up_pour / arch_down_pour / circle / circle_pour / ring_inside / ring_outside
        波浪：wave1 / wave2 / double_wave1 / wave4
        三角/箭头：triangle / triangle_inverted / chevron / chevron_inverted / stop
        曲线/罐形：curve_up / curve_down / can_up / can_down / button / button_pour
        膨胀/收缩：inflate / deflate / inflate_top / inflate_bottom / deflate_top / deflate_bottom / deflate_inflate / deflate_inflate_deflate
        淡入/斜切/阶梯：fade_left / fade_right / fade_up / fade_down / slant_up / slant_down / cascade_up / cascade_down
        普通：plain
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] height_px (integer): 高度像素，默认 120
  [ ] text (string): 艺术字文字内容，可选
  [ ] width_px (integer): 宽度像素，默认 400
```

---

## doc_list_recent_ai_edits

```plaintext
# doc_list_recent_ai_edits

列出当前 editor 实例最近通过 MCP 写工具产生的编辑（DOC），返回每条记录的 version + tool_name + time（按时间倒序，最新在前）。

【典型用法】
当用户要求“撤销刚才的某次操作”（如删图、插表）时：
  1. 调用本工具（limit 默认 10），拿到最近若干次 AI 编辑；
  2. 在返回列表里按 tool_name 与用户描述匹配（replace_image=换图 / insert_text=插文字 ...），定位 target_version；
  3. 调用 doc_revert_revision(target_version=匹配到的 version) 完成回退。

【限制 / 注意】
  - 仅记录通过 MCP 写工具产生的编辑，前端 / 程序化 CommitRevision 等其他写不在内；
  - 记录在 SDK 实例存活期间累积，不需要任何前置注册（写时无感）；
  - 重新打开同一文件 (DocEditor 实例重建) 后，旧记录会被清空；
  - 单文档最多保留最近 200 条，超出会自动淘汰最早的；
  - record_dir (可选): 提供后 SDK 把累积记录持久化到 `<record_dir>/<sanitize(file_id)>.jsonl`，之后写入会同步 mirror。建议优先用 system prompt 注入的会话工作目录拼 `<work_dir>/ai_edits/`，找不到就用 `./ai_edits/` (进程 cwd 相对路径)。不传则只读内存，不落盘。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] limit (integer): 返回条数，缺省 10，上限 50。
  [ ] record_dir (string): 可选；指定后 SDK 把累积记录持久化到该目录下的 jsonl 文件 (`<record_dir>/<sanitize(file_id)>.jsonl`)，并将后续写入同步 mirror。目录不存在时会被创建。不传则只读内存、不落盘。
  [ ] tool_name (string): 可选；按工具名精确过滤（例如 "doc_replace_image" 只看换图记录）。
```

---

## doc_merge_table_cells

```plaintext
# doc_merge_table_cells

合并表格单元格（DOC）。将 (row, col) 起始的 row_span×col_span 矩形区域合并为一个单元格。idx 为表格内任意 cell 的 DOC 坐标。row/col 为 1-based（与 doc_get_table_info 返回的 row/col 一致，直接传入即可）。合并后所有被合并单元格的文本会拼接到起始单元格中。row_span=1 且 col_span>1 为横向合并；row_span>1 且 col_span=1 为纵向合并；两者均>1 为混合合并。使用前先调用 doc_get_table_info 获取表格结构和 cell 坐标。

参数（✓=必填）：
  [✓] idx (integer): 表格内任意 cell 的 DOC 坐标
  [✓] row (integer): 合并区域起始行的 1-based 行号。与 doc_get_table_info 返回的 row 一致
  [✓] col (integer): 合并区域起始列的 1-based 列号。与 doc_get_table_info 返回的 col 一致
  [✓] row_span (integer): 纵向合并的行数（≥1）。1 表示仅横向合并
  [✓] col_span (integer): 横向合并的列数（≥1）。1 表示仅纵向合并
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_modify_paragraph

```plaintext
# doc_modify_paragraph

修改已有段落的属性（DOC），支持对齐、间距、精确缩进、任意段落样式、分页控制、制表位、引用与编号。本工具用于在原有段落上修改属性，如需添加新的待办事项内容请使用 insert_tasks_with_content，如需添加新的列表项目请使用 doc_insert_paragraph。paragraph_id 与 ranges 至少传一个；paragraph_id 来自 doc_resolve_document_structure。paragraph_id 只保证在当前打开的 editor 实例内用于定位，不保证保存后或重新打开文档仍保持不变。一旦传入 paragraph_id，将按 ID 精确定位唯一段落并忽略 ranges；找不到或重复会报错。未传 paragraph_id 时，ranges 为段落范围列表，每项包含 begin 和 end（DOC 坐标）。坐标必须是当前文档版本的 GCP：每次写文档内容后后续段落坐标会漂移，批量修改前请重新 doc_resolve_document_structure / doc_get_document_content 取最新 start_index/end_index。除定位参数外，至少传入一个需要修改的属性或操作；未传入的属性保持原样。不要传 paragraph_index 或手算字符数。【互斥】indent / block_quote / numbering / highlight_block 四者互斥；且均不能与 jc、spacing_*、line_spacing*、heading_lvl 同包（会报错，不会静默忽略）。需要「编号 + 间距/对齐」等组合时，分多次调用，每次只带一类属性。【示例·接编号】ranges 取 doc_resolve_document_structure 该段 start_index/end_index：{"ranges":[{"begin":675,"end":705}],"numbering":"decimal","numbering_level":1}【示例·再改间距】第二次调用，勿与 numbering 同包：{"ranges":[{"begin":675,"end":705}],"spacing_before":7.8,"spacing_after":7.8}【示例·对齐+行距】jc/spacing/line_spacing/heading_lvl 可同包：{"ranges":[{"begin":0,"end":15}],"jc":"center","line_spacing":1.5,"line_spacing_rule":1}

参数（✓=必填）：
  [ ] alignment (): jc 的 python-docx 风格别名；不可与 jc 同时传入。
  [ ] block_quote (boolean): 设置或取消段落引用样式。true=设置引用（段落左侧显示蓝色竖线），false=取消引用
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] first_line_indent (): 首行缩进（pt）。正数为首行缩进，负数也会作为精确 OOXML 值写入；需要悬挂缩进请使用 hanging_indent。null 恢复继承。与 first_line_indent_chars 二选一，同时传入时 chars 优先。与 indent、block_quote、numbering、highlight_block 互斥。
  [ ] first_line_indent_chars (): 首行缩进（字符数）。例如 2 表示首行缩进 2 个字符（中文排版常用）。null 恢复继承。与 first_line_indent 二选一，同时传入时本参数优先。与 indent、block_quote、numbering、highlight_block 互斥。
  [ ] hanging_indent (): 悬挂缩进（pt），例如 18 表示除首行外其余行缩进 18pt；null 恢复继承。不可与 first_line_indent/first_line_indent_chars 同时设置具体值。
  [ ] heading_lvl (): 段落样式级别。取值：1~9=Heading1..Heading9（一级 ~ 九级标题）；10=正文（Normal，把段落恢复为正文）；11=标题（Title）；12=副标题（Subtitle）。用于把段落设置为对应的内置段落样式；不传则不修改段落样式。注意：设置引用请使用 block_quote 参数。null 删除段落样式；与 paragraph_style 二选一。