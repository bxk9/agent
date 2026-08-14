  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_get_comments

```plaintext
# doc_get_comments

获取 DOC 文档中所有批注（DOC）。返回 `total` 与按 range_begin 升序排列的 `comments` 数组，每条包含：`id`（批注 id，与 doc_insert_comment 写入时一致）、`range_begin` / `range_end`（批注锚定范围的字符 idx，与 doc_get_last_operable_pos.position 同坐标系；begin == end 表示零长度的「点锚」批注，对应字段 `is_point_anchor=true`）、`text`（批注正文文本，已过滤其中的图片/表格等复杂内容，与 OOXML 视觉渲染对齐）、`reply_to`（同一对话线程首条批注的 id，仅回复批注才有；底层线程为扁平结构）、`author` / `date`（作者展示名与 Unix epoch 毫秒时间戳字符串，未设置时不返回）。主要用于对 doc_insert_comment 的结果做验证、以及在执行批注相关编辑前枚举现有批注。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_get_images

```plaintext
# doc_get_images

获取 DOC 文档中所有图片的信息（DOC）。返回数组中每一项包含以下字段：`source` (1 = drawing 嵌入图片，2 = field-attachment 字段附件图片)、`index` (图片在文档中的字符 idx，与 doc_insert_image / doc_replace_image 的 index 、doc_get_last_operable_pos.position 同一坐标系)、`image_url` (本会话的可寻址 URL，doc_replace_image 可拿来作为 old_image_url 使用)。数组按 index 升序返回；“第 N 张图”即为数组下标 +1，无需额外字段。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_get_last_operable_pos

```plaintext
# doc_get_last_operable_pos

获取DOC文档正文最后一个可操作位置的索引，以及该位置前面最多10个字符的内容。在需要向文档末尾追加内容时，可先调用此接口获取末尾可操作位置（DOC）。返回的 position 是可直接传给插入类工具的 DOC 坐标，不是可见字符序号。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_get_outline

```plaintext
# doc_get_outline

获取DOC文档大纲（DOC）,可以获取到文档标题、标题下内容范围，明确插入的位置

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_get_paragraph_property

```plaintext
# doc_get_paragraph_property

读取 DOC 文档指定位置 idx 所在「段落」的属性（与 doc_insert_paragraph 字段对称）：段落样式名（可读，如 heading 1 / Title / Normal）、大纲级别、推断出的 heading_level (1..9, 0=非标题)、是否带编号及编号级别 (1..9)、对齐方式、缩进（pt）、段前/后间距 (pt) 与行距。字段不存在表示未显式设置（继承默认值）。同时回读分页控制（keep_with_next/keep_together/page_break_before/widow_control）、自定义 tab_stops，以及 numbering_restart（当前 num_id 首段=true，续接=false）。主要用于对段落编辑结果做验证。

参数（✓=必填）：
  [✓] idx (integer): 要查询的位置 DOC 坐标；返回该 idx 所处「段落」的 CTPPr 属性。不要传 paragraph_index。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_get_section_property

```plaintext
# doc_get_section_property

读取 DOC 文档指定 section 的基础页面属性。section_index 为 0-based，与页眉页脚接口一致。返回 section 范围、总节数、页面方向和宽高、页边距、页眉页脚距离、装订线、分节起始类型以及是否首页页眉页脚不同。所有长度统一为 pt。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] section_index (integer): 节索引（0-based），默认 0。
```

---

## doc_get_table_info

```plaintext
# doc_get_table_info

获取 DOC 文档中指定位置 idx 或 table_locate 所在「表格」的整体信息（DOC）。⚠️ idx 必须落在表格内部（任意 cell 的 start_index / cell 内文本位置 / 表格起止均可）；若手上没有 idx，可用 table_locate.cell_match 按单元格文字定位（多格命中时报错 ambiguous_matches，请加长 match 或加 row/col hint）。仍可先 doc_resolve_document_structure 拿 cells[].start_index 作 idx。返回字段：`block`（与 doc_get_document_content 中 type=="table" 的 block 格式完全一致）、`block.id`（table_block_id；相邻表各不相同）、`table_start_index` / `table_end_index`（本次解析到的表 GCP 范围，供校验）、`resolved_idx`（入参 idx 或 cell 锚点 GCP）、`resolved_cell`（table_locate 时：{row,col}）`block.table.row_count` / `col_count`（行数与最大逻辑列数）、`block.table.alignment`（left/center/right）/ `width` / `style` / `cell_margin` / `border` 或 `borders`（6 向边框）、`block.table.cells[]`（满格展开的 cells 数组，含 grid_span 展开的占位格和 v_merge continue 占位格（`is_merge_continue: true`）。锚点格含 `text` / `text_property` / `paragraph_property` / `height_pt` / `height_rule`（行高挂每行第一个锚点格）)。典型用法：读表后调用 doc_modify_table_region(idx=resolved_idx 或 table_locate=..., table_block_json=...) 写回；也可不经本工具直接 modify 时传 table_locate。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] idx (integer): 表格内任意 GCP（与 table_locate 二选一）。
  [ ] table_locate (object): 按单元格可见文字定位表格（与 idx 二选一）。cell_match 须为某锚点格 text 的精确 UTF-8 子串（从 cells[].text 原样复制，可避免手填 idx 时的空格/符号问题）。row/col 为可选 1-based hint（best-effort）。命中多个格时报错 ambiguous_matches，无 occurrence；请加长 cell_match 或加 hint。
```

---

## doc_get_text_property

```plaintext
# doc_get_text_property

读取 DOC 文档指定位置 idx 处生效的文本属性（与 doc_update_text_property 字段对称）：加粗/斜体/下划线及线型/下划线颜色/单删除线/双删除线/小型大写/颜色/底纹(background_color)/高亮(highlight)/字号(pt)/字体/上下标等。响应中「字段不存在」表示该属性未在 run 上显式设置，应认为「继承自段落 / 样式默认值」。

参数（✓=必填）：
  [✓] idx (integer): 要查询的位置 DOC 坐标（包含该字符生效的运行属性）。使用查询结果里的真实坐标，不要手算。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_get_word_art_info

```plaintext
# doc_get_word_art_info

读取指定位置艺术字的属性。返回字段：wordart_idx（锚点位置）、style（视觉效果名）、text（艺术字文字）、width_px / height_px（外框尺寸）、text_range: {begin, end}（艺术字文字的 GCP range，可传给 doc_update_text_property.ranges 修改字号/颜色/字体等；空框艺术字不返回此字段）。

参数（✓=必填）：
  [✓] idx (integer): 艺术字锚点位置（doc_insert_word_art 返回的 wordart_idx）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_insert_border

```plaintext
# doc_insert_border

在指定位置插入分隔符（DOC）。通过设置段落底部边框来实现水平分隔线效果。⚠️ idx 必须是「分隔线上方那个段落」的 end_index（即该段落的段落分隔符 ¶ 的位置）。例如：想在第 2 段和第 3 段之间插入分隔线，应传第 2 段的 end_index。idx 是 DOC 坐标，不要按肉眼字符数或段落序号手算。支持多种边框样式（single/thick/dotted/dashed等）和自定义颜色。

参数（✓=必填）：
  [✓] idx (integer): 分隔线上方段落的 end_index。例如想在第 N 段底部画分隔线，传例如doc_resolve_document_structure 返回的段落 end_index
  [ ] border_type (string): 边框类型：single（单线，默认）、thick（粗线）、dotted（点线）、dashed（虚线）、double（双线）、dotDash（点划线）、wave（波浪线）等。Default: single.
  [ ] color (string): 边框颜色（十六进制），如 "000000" 表示黑色。Default: auto.
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] sz (integer): 边框粗细（1/8磅为单位），如 8 表示1磅。Default: 8.
```

---

## doc_insert_comment

```plaintext
# doc_insert_comment

插入批注（DOC）。接口返回中除 last_edit_index 外，还会多带一个 `position` 字段（插入后文档末尾可操作位置），避免调用方为了拿插入后的位置再去调 doc_get_last_operable_pos。说明：批注插入会为文档插入 commentRangeStart/End/Reference 等占位符，文档总长度会增加；后续操作请以 `position` 为准。

参数（✓=必填）：
  [✓] text (string): 非空批注内容
  [✓] range_begin (integer): 批注关联的文本范围起始位置（字符 idx）。允许 range_begin == range_end，此时为「点锚批注」（point-anchor comment，批注附着在单一位置上、不选中任何范围）。
  [✓] range_end (integer): 批注关联的文本范围结束位置（字符 idx）；与 range_begin 相等时为点锚批注
  [ ] author (string): （可选）批注作者展示名；会随批注一起持久化，并在 doc_get_comments 中以 `author` 字段返回。为空则不设置。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] ref_id (string): （已废弃别名，请优先使用 `reply_to`）同 `reply_to`。两者同时传入时以 `reply_to` 为准。