  [ ] layout_index (integer): 0-based index into the first slide master's layout list. 0 = title slide, 1 = title+content, etc. (default: 0).
```

---

## slide_add_slides

```plaintext
# slide_add_slides

Batch-add multiple new slide pages at a single position in one call. All pages share the same layout template (layout_index). The pages are added contiguously starting at `index` (or at the tail when index == -1). Returns the total slide_count after add and the number of pages that were added.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] count (integer): Number of slide pages to add. Must be >= 1.
  [ ] index (integer): 0-based starting add position. -1 (default) appends at the end. When count > 1, pages are added at index, index+1, ... contiguously.
  [ ] layout_index (integer): 0-based index into the first slide master's layout list, applied to every newly added page. Default: 0.
```

---

## slide_add_table

```plaintext
# slide_add_table

Create a new empty table (n rows × m columns) onto a slide page. Internally calls SlideEditor::AddTable which dispatches to request::AddTableRequest → core/slide/command/table/BuildAddTableCommand. One user call = one SlideCommand = one SSE / undo unit. Coordinates are in points (1pt = 12700 EMU).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] x (number): Top-left X in points (pt; 1pt = 12700 EMU).
  [✓] y (number): Top-left Y in points (pt; 1pt = 12700 EMU).
  [✓] w (number): Total width in points (pt; 1pt = 12700 EMU), divided evenly across columns.
  [✓] h (number): Total height in points (pt; 1pt = 12700 EMU), divided evenly across rows.
  [✓] rows (integer): Number of rows, > 0.
  [✓] cols (integer): Number of columns, > 0.
```

---

## slide_add_text

```plaintext
# slide_add_text

Create a brand-new textbox at an arbitrary position on a slide page. USE THIS when you need to place a new text element somewhere on the slide — it creates a new shape with its own shape_id. Do NOT use this to edit the text of an existing shape; for that use slide_set_text (replace all), slide_append_text (add at end), slide_insert_text (insert at position), or slide_find_replace_text (search & replace). By default the textbox is rendered with NO fill (transparent background) and NO border; to draw a visible border the caller must explicitly pass border_color (e.g. "000000"). Optional text is written into the box and optional font styling (color / family / size) is applied uniformly over the whole text. Optionally pass 'url' to turn the whole text into a hyperlink (with optional 'tooltip'). Coordinates and dimensions are in points (1pt = 12700 EMU).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] x (number): X position of the textbox's top-left corner in points (1pt = 12700 EMU).
  [✓] y (number): Y position of the textbox's top-left corner in points (1pt = 12700 EMU).
  [✓] w (number): Width of the textbox in points (1pt = 12700 EMU).
  [✓] h (number): Height of the textbox in points (1pt = 12700 EMU).
  [ ] border_color (string): Hex border color (e.g. "000000"). Omit (or "none") for no border (transparent line).
  [ ] border_dash (string): Border line dash type: "solid", "dot", "dash", "dashDot", "lgDash", "lgDashDot". Default: "solid". Only takes effect when border_color is set.
  [ ] border_width (number): Border width in points. Default: 1. Only takes effect when border_color is set.
  [ ] fill_color (string): Hex fill color for the box background (e.g. "FFFF00"). Omit for no fill (transparent).
  [ ] font_color (string): Hex color for the text (e.g. "333333"). Omit for theme default.
  [ ] font_name (string): Font family name (e.g. "Arial", "微软雅黑"). Omit for theme default.
  [ ] font_size (integer): Font size in points (e.g. 14). Omit or 0 for theme default.
  [ ] text (string): Initial text content of the textbox. Omit or empty to create an empty textbox.
  [ ] tooltip (string): Optional hover tooltip for the hyperlink. Only takes effect when url is set.
  [ ] url (string): Optional hyperlink target (e.g. "https://docs.qq.com"). When set, the whole text becomes a clickable hyperlink. Omit for a plain textbox.
```

---

## slide_add_texts

```plaintext
# slide_add_texts

Batch-add multiple texts onto a single slide in one call. All texts are added via a single internal batch (one command / SSE broadcast), which is significantly more efficient than calling slide_add_text repeatedly. Each entry in the `texts` array has the same fields as slide_add_text (minus file_id and page_index, which live at the top level). Returns an array of shape_ids in the same order as the input texts.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] texts (array<object>): Array of text specs. Must contain at least one entry.
```

---

## slide_append_notes_text

```plaintext
# slide_append_notes_text

Append text to the end of the notes page attached to a slide. Internally implemented as 'read current notes text -> concatenate -> re-emit via slide_set_notes_text' (clears all notes body shapes, then writes the combined text onto the first text shape; same on-wire form as slide_set_notes_text). The notes page must already exist (use slide_add_notes first if needed). IMPORTANT: this resets per-character styling (bold / italic / color / font / size) of the notes body to defaults — the notes page only preserves plain text + language tag. Returns the updated editor version, the UTF-16 length of the appended text and of the combined text.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the slide whose notes text should be appended.
  [✓] text (string): Text content (UTF-8) to append at the end of the notes page's existing text.
```

---

## slide_append_text

```plaintext
# slide_append_text

Append text to the end of an existing shape's text content. Unlike slide_set_text which requires equal UTF-16 length, this inserts new text at the end.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page. Must be an integer.
  [✓] shape_id (string): The shape ID to append text to.
  [✓] text (string): Text content to append at the end of the shape's existing text.
```

---

## slide_change_chart_type

```plaintext
# slide_change_chart_type

Change the chart type of an existing chart shape on a slide. The chart's existing categories and series data are preserved; only the chart's geometry/axes are rebuilt for the new type.

Allowed new_chart_type values: "clusteredColumn", "stackedColumn", "percentStackedColumn", "clusteredBar", "stackedBar", "percentStackedBar", "line", "stackedLine", "markerLine", "pie", "doughnut", "area", "stackedArea", "radar", "markerRadar", "filledRadar".

Not supported (rejected with an error): scatter, smoothLineScatter, straightLineScatter, bubble — to create a chart of these types from scratch, use slide_add_chart instead. 3D variants, stock charts, pieOfPie/barOfPie and combo charts are also rejected.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID to change. Typically obtained from slide_add_chart's response or slide_get_shape_info.
  [✓] new_chart_type (string): Target chart type. Allowed: "clusteredColumn", "stackedColumn", "percentStackedColumn", "clusteredBar", "stackedBar", "percentStackedBar", "line", "stackedLine", "markerLine", "pie", "doughnut", "area", "stackedArea", "radar", "markerRadar", "filledRadar". Rejected: "scatter", "smoothLineScatter", "straightLineScatter", "bubble" — use slide_add_chart for those types.
```

---

## slide_delete_table_cols

```plaintext
# slide_delete_table_cols

Delete one or more columns from an existing table shape starting at `index`.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] shape_id (string): The table shape id.
  [✓] index (integer): First column to delete. index + count must be <= current_col_count.
  [ ] count (integer): Number of rows/columns to insert or delete. Default: 1. Must be > 0.
```

---

## slide_delete_table_rows

```plaintext
# slide_delete_table_rows

Delete one or more rows from an existing table shape starting at `index`.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] shape_id (string): The table shape id.
  [✓] index (integer): First row to delete. index + count must be <= current_row_count.
  [ ] count (integer): Number of rows/columns to insert or delete. Default: 1. Must be > 0.
```

---

## slide_duplicate_slide

```plaintext
# slide_duplicate_slide

Duplicate (deep-copy) one or more slide pages. Each duplicated page preserves all shapes, text, animations, and styling. By default, duplicated pages are inserted immediately after the last duplicated page. Use target_page_index to specify a custom insertion position. Returns the new total slide count.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_indexes (array<integer>): REQUIRED. Non-empty array of 0-based slide indices to duplicate. Each slide is deep-copied.
  [ ] target_page_index (integer): 0-based index specifying where the duplicated pages should be inserted. For example, target_page_index=2 means the first duplicated page will become page at index 2. Default: insert after the last duplicated page.
```

---

## slide_find_replace_text

```plaintext
# slide_find_replace_text
