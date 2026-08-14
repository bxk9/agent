  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The ID of the shape to query.
```

---

## slide_get_table_info

```plaintext
# slide_get_table_info

Read-only query of an existing table shape's full layout. Returns: row_count / col_count; per-row heights row_heights[] and per-column widths col_widths[]; and a row-major fully-expanded cells[] array (length = row_count * col_count). Each cell carries: row / col / row_span / col_span / is_merge_continue (true for a swallowed cell of a merged region — callers should skip it) / text (plain UTF-8) / first-run font style (font_name / font_size / font_color / bold / italic) / cell properties (fill_color / vertical_align / margin_left/right/top/bottom) / 4-direction borders (border_left/right/top/bottom each color + width). ALL size/length values are in points (pt): row_heights / col_widths / font_size / margin_left/right/top/bottom / border_*_width. Colors are 6-digit RGB hex strings (no leading '#').

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] shape_id (string): The target table shape id (shape_type must be table).
```

---

## slide_get_text

```plaintext
# slide_get_text

Query the text content and formatting properties of a shape. Returns the full UTF-8 text, its UTF-16 length, an array of run (character-level) property segments, and an array of paragraph-level property segments. Each segment has 'start' and 'end' (UTF-16 offsets) plus the relevant properties. Each run segment also reports 'is_hyperlink' (bool); when true it additionally carries 'hyperlink' (the target URL) and optionally 'hyperlink_tooltip'. A top-level 'hyperlinks' array is also returned: it merges adjacent runs sharing the same URL into ranges, each with 'start'/'end' (UTF-16 offsets), 'url' and optional 'tooltip' — use it to directly know which text ranges are hyperlinks. Use this to inspect existing text (and detect hyperlinks) before calling slide_set_text_property or slide_set_hyperlink.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page. Must be an integer.
  [✓] shape_id (string): The shape ID to query.
```

---

## slide_get_themes

```plaintext
# slide_get_themes

List all themes embedded in the current presentation. Each entry contains theme_id and theme_name. Use this BEFORE slide_set_theme to obtain a valid theme_id for SWITCH mode.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
```

---

## slide_group_shapes

```plaintext
# slide_group_shapes

Group multiple shapes into a single group shape on a slide page. All shapes must be direct children of the page's shape tree (not already inside a group). Tables and placeholder shapes cannot be grouped. At least 2 shapes are required. Returns the newly-created group shape ID in 'group_id'.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_ids (array<string>): Array of shape IDs to group. Must contain at least 2 IDs.
```

---

## slide_insert_table_cols

```plaintext
# slide_insert_table_cols

Insert one or more columns into an existing table shape. The `index` parameter specifies the **gap position** (NOT an existing column index) where the new column(s) will be inserted. Gap semantics: for a table with M existing columns, valid index range is [0, M]. index=0 inserts at the very left (before the 1st column); index=1 inserts between the 1st and 2nd column (i.e. before the 2nd column); index=2 inserts between the 2nd and 3rd column (i.e. after the 2nd column / before the 3rd column); index=M inserts at the very right (after the last column). Existing columns at and after the gap are shifted right by `count`. Column width policy: all (M + count) columns are evenly redistributed; the table's total width is preserved unchanged (each column becomes total_width / (M + count)).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] shape_id (string): The table shape id.
  [✓] index (integer): Gap position to insert at. For a table with M columns, valid range is [0, M]. 0 = before the 1st column (very left); k = between column k-1 and column k; M = after the last column (very right). This is a gap index, not a column index.
  [ ] count (integer): Number of rows/columns to insert or delete. Default: 1. Must be > 0.
```

---

## slide_insert_table_rows

```plaintext
# slide_insert_table_rows

Insert one or more rows into an existing table shape. The `index` parameter specifies the **gap position** (NOT an existing row index) where the new row(s) will be inserted. Gap semantics: for a table with N existing rows, valid index range is [0, N]. index=0 inserts at the very top (before the 1st row); index=1 inserts between the 1st and 2nd row (i.e. before the 2nd row); index=2 inserts between the 2nd and 3rd row (i.e. after the 2nd row / before the 3rd row); index=N inserts at the very bottom (after the last row). Existing rows at and below the gap are shifted down by `count`. Row height policy: every newly inserted row's height is copied from the existing row at `reference_row_index`; the caller MUST explicitly pick which existing row's height to reuse.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] shape_id (string): The table shape id.
  [✓] index (integer): Gap position to insert at. For a table with N rows, valid range is [0, N]. 0 = before the 1st row (very top); k = between row k-1 and row k; N = after the last row (very bottom). This is a gap index, not a row index.
  [✓] reference_row_index (integer): 0-based index of an existing row whose height will be copied to every newly inserted row. Valid range: [0, current_row_count). Required — the Command layer does NOT pick a neighbour row automatically; the caller must choose explicitly.
  [ ] count (integer): Number of rows/columns to insert or delete. Default: 1. Must be > 0.
```

---

## slide_list_anim_types

```plaintext
# slide_list_anim_types

List the animation kinds currently supported by `slide_add_anim`. Returns an array of (value, name, description) entries where `value` is the integer to pass to `slide_add_anim.anim_type`, `name` is the C++ AnimType enum name (without the `AnimType_` prefix), and `description` is a short Chinese description. The list reflects the actual switch in core/slide/command/animation/timenode/time_node.h::BuildTimeNodeByAnimType — values not in this list will be rejected by `slide_add_anim`. `file_id` is required only for ticket validation; the result does not depend on which file is open.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
```

---

## slide_list_builtin_themes

```plaintext
# slide_list_builtin_themes

List all built-in (preset) themes provided by the backend. Each entry contains theme_id (e.g. builtin_office, builtin_feilengcui_lv) and theme_name (e.g. Office, 翡冷翠绿). The returned theme_id can be passed to slide_set_theme directly without theme_name / theme_elements: the backend will auto-load the corresponding ThemeElements from the static resource and emit a single SetTheme mutation. This avoids shipping the ~60KB themeElements payload over the wire each time.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
```

---

## slide_merge_table_cells

```plaintext
# slide_merge_table_cells

Merge a rectangular region of cells in an existing table shape. Content of the merged cell comes from the top-left cell of the region.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] shape_id (string): The table shape id.
  [✓] start_row (integer): 0-based top row of the merge region.
  [✓] start_col (integer): 0-based left column of the merge region.
  [✓] row_span (integer): Number of rows spanned. > 0.
  [✓] col_span (integer): Number of columns spanned. > 0.
```

---

## slide_move_anim

```plaintext
# slide_move_anim

Move a single animation node within the default trigger's animation sequence on a shape (i.e. reorder an existing animation in the mainSeq). The animation is located by (page_index, shape_id, from_index) and reinserted at to_index. One MCP call = one SlideCommand = one undo unit / one SSE event. Note: backend dispatches a single MoveAnimationMutation here (CommandType=Empty), matching the front-end commit_data sample for move_anim. `to_index` may equal the current animation count to append at the tail; cross-trigger moves are NOT exposed by this tool — both source and target trigger are the default trigger (mainSeq).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The ID of the shape whose animation is being moved. Must be a non-empty existing shape on the page, and the animation at `from_index` must currently belong to this shape.
  [✓] from_index (integer): 0-based source slot in the default trigger's anim_node_list. The animation at this position is the one being moved.
  [✓] to_index (integer): 0-based destination slot in the default trigger's anim_node_list. May equal the current animation count to append at the tail.
```

---

## slide_move_section

```plaintext
# slide_move_section

Move a section (and all its slides) to a new position in the section list. The to_section_index is the 0-based target position among sections.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] section_id (string): ID of the section to move.