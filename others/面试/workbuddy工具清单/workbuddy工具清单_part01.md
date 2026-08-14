# editor_sdk 全部工具 Schema 文档

共 199 个工具 包含doc sheet 和slide

## close_file

```plaintext
# close_file

Close an opened file editor. If the file has unsaved changes, returns an error unless force=true. Closing releases the editor from the pool and stops its SSE event stream.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to close
  [ ] force (boolean): If true, close even if there are unsaved changes (default: false)
```

---

## create_doc

```plaintext
# create_doc

Create a brand-new empty word document from the in-binary blank.docx template. Returns the file_id (and file_path of the per-call temp copy) that subsequent doc tools (doc_insert_text / save_file / ...) should use. The embedded template bytes are never written back to disk; each call materialises a fresh isolated copy under the editor's upload dir.

参数（✓=必填）：
  [ ] file_id (string): Optional file_id to assign. If omitted or '_default', a unique id is generated automatically.
```

---

## create_sheet

```plaintext
# create_sheet

Create a brand-new empty spreadsheet from the in-binary blank.xlsx template. Returns the file_id (and file_path of the per-call temp copy) that subsequent sheet tools (sheet_set_cell_value / save_file / ...) should use. The embedded template bytes are never written back to disk; each call materialises a fresh isolated copy under the editor's upload dir.

参数（✓=必填）：
  [ ] file_id (string): Optional file_id to assign. If omitted or '_default', a unique id is generated automatically.
```

---

## create_slide

```plaintext
# create_slide

Create a brand-new empty presentation from the in-binary blank.pptx template. Returns the file_id (and file_path of the per-call temp copy) that subsequent slide tools (slide_insert_text / save_file / ...) should use. The embedded template bytes are never written back to disk; each call materialises a fresh isolated copy under the editor's upload dir.

参数（✓=必填）：
  [ ] file_id (string): Optional file_id to assign. If omitted or '_default', a unique id is generated automatically.
```

---

## doc_compare_documents

```plaintext
# doc_compare_documents

对比两个已打开的 DOC 文档的内容和格式差异。返回段落级别的差异列表，包括新增/删除/内容修改/格式修改。两个文档必须都已通过 open_file 打开。当前文档作为基准（source），通过 other_file_id 指定对比目标（target）。差异类型：added（目标新增）、deleted（源文档删除）、modified_content（内容变化）、modified_format（格式变化，如对齐方式、标题级别、段落样式等）。还支持对比页眉页脚、文本框（textbox/代码块/高亮块）、表格、批注和页面设置（页边距/页面尺寸）的差异。文本框对比：返回 textbox_diffs 字段，每项包含 type（code_block/highlight_block/textbox）标识类型，即使两个文档中同一位置的代码块 placeholder ID 不同也能按位置匹配识别为同一个代码块的内容修改。表格以原子单元对比：返回 table_diffs 字段，diff_type 包括 added/deleted/modified（维度不同）/modified_content（维度相同但单元格内容不同）/modified_format（维度和内容相同但单元格格式不同，如背景色）。cell_diffs 列出具体差异的单元格坐标（1-based），每个 cell diff 包含 diff_type（modified_content/modified_format）、source_text/target_text（内容差异时）、source_fill_color/target_fill_color（格式差异时，hex 颜色值）。用户可进一步调用 resolve_document_structure 获取表格内部详细结构。性能优化：当一篇文档正文明显更长时，长文档尾部段落不逐段对比。页眉页脚、文本框、批注始终完整对比，不受正文截断影响。

参数（✓=必填）：
  [ ] compare_mode (string): 对比模式，可选值："content"（仅对比文本内容）、"format"（仅对比格式）、"all"（全部对比，包括正文内容、格式、页眉页脚、文本框和批注，默认值）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] other_file_id (string): 要对比的另一个文档的 file_id（必须已通过 open_file 或前端打开）。当前 file_id 为基准文档(source)，other_file_id 为目标文档(target)。差异以 source→target 的视角描述：added 表示 target 新增，deleted 表示 source 中有但 target 中没有。也可以传入 file_path，工具内部会自动解析为对应的 file_id。
  [ ] other_file_path (string): 要对比的另一个文档的本地文件路径（作为 other_file_id 的替代）。工具内部会将路径解析为已打开的 file_id。如果同时传了 other_file_id 和 other_file_path，优先使用 other_file_id。
```

---

## doc_copy_format

```plaintext
# doc_copy_format

格式刷（DOC）：将源范围的段落属性和文本属性复制到目标范围。读取 source_range 起始位置处生效的段落格式（对齐、缩进、间距、样式等）和文本格式（加粗、斜体、字号、字体、颜色等），然后应用到 target_ranges 指定的所有范围上。适用于快速统一多个段落/文本的格式。
【坐标】默认 source_range / target_ranges 为文档绝对 GCP（左闭右开 [begin,end)）。
【段落锚点】提供 anchor 时，区间为相对 para_begin 的 GCP 偏移（与 doc_get_document_content 的 content[].range 对齐）：绝对 GCP = anchor.idx（或 locate 解析出的 para_begin）+ range.begin/end。

参数（✓=必填）：
  [✓] source_range (object): 格式来源范围。无 anchor 时为文档绝对 GCP；有 anchor 时为相对 para_begin 的 GCP 偏移。通常指定参考 run 的 [start,end)。
  [✓] target_ranges (array<object>): 目标范围列表。无 anchor 时为文档绝对 GCP；有 anchor 时为相对 para_begin 的 GCP 偏移。
  [ ] anchor (object): 段落锚点：与 doc_get_document_content 的段内坐标系对齐。提供 anchor 时，source_range / target_ranges 的 begin/end 为相对 para_begin 的 GCP 偏移（与 content[].range 一致），非文档绝对坐标。
  [ ] copy_paragraph_format (boolean): 是否复制段落格式（对齐、缩进、间距、样式等）。默认 true。
  [ ] copy_text_format (boolean): 是否复制文本格式（加粗、斜体、字号、字体、颜色等）。默认 true。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_delete_comment

```plaintext
# doc_delete_comment

删除单条批注（DOC）。`id` 来自 doc_get_comments 返回的批注 id。若同一锚点仍有其他批注或回复，只删除指定批注正文并保留锚点；若这是该锚点的最后一条批注，则同时移除对应的 commentRange/Reference。不会删除被批注的文档正文。删除会改变 DOC 坐标，后续操作请重新获取位置。

参数（✓=必填）：
  [✓] id (string): 要删除的单条批注 id，必须取自 doc_get_comments 返回的 id 字段。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_delete_paragraph

```plaintext
# doc_delete_paragraph

删除 idx 所在的整个段落（DOC）。只需要传光标所在位置 idx；底层会自动定位该段落的完整范围并删除，包含该段落结束符。idx 必须是 DOC 坐标；不要传 paragraph_index 或手算字符数。删多段须从后往前逐次调用并重新查询 idx；不可删除主文档最后一个段落。

参数（✓=必填）：
  [✓] idx (integer): 光标所在位置的字符 idx；将删除该 idx 所在段落
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_delete_table

```plaintext
# doc_delete_table

删除整张表格（DOC）。idx 只需传表格内任意位置（包括表头/表尾占位、任一单元格位置）。删除后表格后面的内容位置会发生偏移，请谨慎使用删除工具，需要先获取用户确认再使用。idx 是表格内 DOC 坐标，不是第 N 张表。

参数（✓=必填）：
  [✓] idx (integer): 表格内任意位置索引（可以是 tblBegin / tblEnd 占位、任一单元格起始位置）。后端会自动反查整张表的范围并删除；不要传表格序号。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_delete_table_column

```plaintext
# doc_delete_table_column

删除表格中的一列（DOC）。idx 为表格内任意 cell 的 GCP 位置，col 为 1-based 列号。如果删除所有列则整个表格被删除。使用前先调用 doc_get_table_info 获取表格结构。

参数（✓=必填）：
  [✓] idx (integer): 表格内任意 cell 的 DOC 坐标
  [✓] col (integer): 1-based 列号。与 doc_get_table_info 返回的 col 一致，直接传入即可
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_delete_table_row

```plaintext
# doc_delete_table_row

删除表格中的一行（DOC）。idx 为表格内任意 cell 的 GCP 位置，row 为 1-based 行号。如果该行包含 vMerge 合并单元格会自动处理。如果删除所有行则整个表格被删除。使用前先调用 doc_get_table_info 获取表格结构。

参数（✓=必填）：
  [✓] idx (integer): 表格内任意 cell 的 DOC 坐标
  [✓] row (integer): 1-based 行号。与 doc_get_table_info 返回的 row 一致，直接传入即可
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_find

```plaintext
# doc_find

查找文本所在位置（DOC），返回所有匹配位置的 begin/end 索引及上下文。返回的 begin/end 是可直接回填到 doc_replace_text / doc_update_text_property 的 DOC 坐标；不要按肉眼字符数、段落序号或行号手算位置。

参数（✓=必填）：
  [✓] text (string): 要查找的文本
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_find_and_replace

```plaintext
# doc_find_and_replace

查找并替换文本（DOC）

参数（✓=必填）：
  [✓] old_text (string): 要查找的原文本
  [✓] new_text (string): 替换为的新文本