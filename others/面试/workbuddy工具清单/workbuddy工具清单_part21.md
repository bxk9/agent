Change how an existing animation on a shape is triggered: either keep the default page-advance trigger (mainSeq), or rebind the animation so that it fires when another shape on the same slide is clicked (interactiveSeq). The animation is located by (page_index, shape_id, index); the source trigger / sequence is auto-resolved by the engine (default trigger first, then any interactive trigger that owns the slot — callers do NOT have to know whether the animation is currently in mainSeq or some interactive trigger). One MCP call = one SlideCommand = one undo unit / one SSE event (CommandType=Empty); the editor-sdk only emits a single MoveAnimationMutation, deliberately omitting the redundant set_animation_properties that the front-end commit_data sample carries (it rewrites the same timeNode in place, which has no observable effect on the timing tree and would otherwise force the engine to know the current animation kind). When trigger_shape_id is non-empty and the corresponding interactive trigger does not yet exist on the page, the engine creates it on the fly (as TimingManager::MoveAnimation does internally).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The ID of the shape whose animation is being rebound. Must be a non-empty existing shape on the page, and the animation at `index` on its current trigger must currently belong to this shape.
  [✓] index (integer): 0-based animation index in the *source* trigger's anim_node_list. The source trigger is auto-resolved: the engine first looks at the default trigger / mainSeq, then scans any interactive trigger to find the slot owned by `shape_id`.
  [ ] trigger_shape_id (string): The ID of the shape whose click should fire the animation. Pass an empty string (or omit) to restore the default page-advance trigger (mainSeq). When non-empty, the value must be an existing shape on the same page AND must differ from `shape_id`; the animation is moved to an interactiveSeq trigger whose trigger_id is `trigger_shape_id` (created on the fly if it does not yet exist).
```

---

## slide_set_cell_style

```plaintext
# slide_set_cell_style

Apply a partial visual-style patch to one table cell or a rectangular cell range. Omitted properties are preserved independently for every cell. Supports solid fill (or no fill), vertical text alignment, four inner margins, and border color/width on selected sides. start_row/start_col are 0-based; row_span/col_span default to 1. border_color/border_width apply to all four sides unless border_sides is provided. All target cells are committed in one SlideCommand / undo / SSE unit. Sizes are in points.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] shape_id (string): The target table shape id.
  [✓] start_row (integer): 0-based first target row.
  [✓] start_col (integer): 0-based first target column.
  [ ] border_color (string): 6-digit RGB hex (optional leading '#'), or lowercase 'none' to clear.
  [ ] border_sides (array<string>): Sides affected by border_color/border_width. Omit to affect all four sides.
  [ ] border_width (number): Border width in pt, at least 1 EMU (1/12700 pt).
  [ ] col_span (integer): Target column count.
  [ ] fill_color (string): 6-digit RGB hex (optional leading '#'), or lowercase 'none' to clear.
  [ ] margin_bottom (number): Cell inner margin in points (pt), >= 0.
  [ ] margin_left (number): Cell inner margin in points (pt), >= 0.
  [ ] margin_right (number): Cell inner margin in points (pt), >= 0.
  [ ] margin_top (number): Cell inner margin in points (pt), >= 0.
  [ ] row_span (integer): Target row count.
  [ ] vertical_align (string): Vertical text alignment; 'default' clears the direct cell override.
```

---

## slide_set_cell_text

```plaintext
# slide_set_cell_text

Write plain UTF-8 text into a single cell (row, col) of an existing table shape. Internally calls SlideEditor::SetTableCellText which dispatches to request::SetCellTextRequest → core/slide/command/table/BuildSetCellTextCommand. The mandatory '\r' paragraph terminator is appended automatically, so callers pass only the visible text. One user call = one SlideCommand = one SSE / undo unit.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] shape_id (string): The target table shape id.
  [✓] row (integer): 0-based row index of the target cell.
  [✓] col (integer): 0-based column index of the target cell.
  [✓] text (string): Plain UTF-8 text to write into the cell. May be empty. Do NOT include the trailing \r paragraph terminator — it is appended automatically.
```

---

## slide_set_default_font

```plaintext
# slide_set_default_font

Set the presentation's default font (latin typeface, east-asian typeface, and/or font size). This updates the presentation-level defaultTextStyle, which serves as the fallback font for all new text and for existing text that does not override these properties at the shape / run level.

All parameters are optional (beyond file_id). Only the parameters you provide are modified; omitted ones remain unchanged.

font_size is specified in **points** (e.g. 18 for 18pt). Internally converted to hundredths of a point for the OOXML data model.

font_color is a hex RGB string (e.g. "FF0000" for red, "000000" for black). A leading '#' is stripped automatically.

spacing is character spacing in **points** (e.g. 3 for 3pt, -1.5 for tighter). Internally converted to hundredths of a point (× 100).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [ ] bold (boolean): Set default text to bold (true) or not bold (false). Omit to keep the current value.
  [ ] ea_font (string): East-Asian typeface name (e.g. "宋体", "微软雅黑", "SimSun"). Sets the ea (East Asian) font on defRPr across all paragraph levels.
  [ ] font_color (string): Default font color as a hex RGB string (e.g. "FF0000" for red, "000000" for black). A leading '#' is stripped automatically. Sets solidFill on defRPr across all paragraph levels. Omit to keep the current value.
  [ ] font_size (number): Font size in points (e.g. 18 for 18pt, 12.5 for 12.5pt). Internally converted to hundredths of a point (× 100). Must be positive. Default: not changed.
  [ ] italic (boolean): Set default text to italic (true) or not italic (false). Omit to keep the current value.
  [ ] latin_font (string): Latin typeface name (e.g. "Calibri", "Arial", "Times New Roman"). Sets the latin font on defRPr across all paragraph levels of the presentation's defaultTextStyle.
  [ ] spacing (number): Character spacing in points (e.g. 3 for 3pt wider, -1.5 for tighter). Internally converted to hundredths of a point (× 100). Sets spc on defRPr across all paragraph levels. Omit to keep the current value.
```

---

## slide_set_hyperlink

```plaintext
# slide_set_hyperlink

自包含地在幻灯片上新建一个带超链接的文本框：工具内部先在 (x, y) 处按 width x height 新建一个文本框并写入链接文字 text，再对该整段文字挂上超链接 url。调用方无需（也无法）传入已有 shape_id。位置和尺寸单位均为磅（pt），与 slide_add_text / slide_add_shape 对齐。返回新建文本框的 shape_id。

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 目标幻灯片页面的从 0 起的索引。必须填入整数（integer）。
  [✓] x (number): 文本框左上角 X 坐标（磅，pt）。
  [✓] y (number): 文本框左上角 Y 坐标（磅，pt）。
  [✓] width (number): 文本框宽度（磅，pt）。
  [✓] height (number): 文本框高度（磅，pt）。
  [✓] text (string): 文本框内的链接文字（UTF-8，不可为空）。
  [✓] url (string): 超链接目标地址（不可为空），如 "https://docs.qq.com"。
  [ ] tooltip (string): 鼠标悬浮提示文字（可选）。
```

---

## slide_set_notes_text

```plaintext
# slide_set_notes_text

Replace the entire text content of the notes page attached to a slide. The notes page must already exist (use slide_add_notes first if needed). Passing an empty string clears the notes text while keeping the notes page. Note: once a notes page is created it cannot be deleted independently; it is only removed when its associated slide is deleted. Returns the updated editor version.
[Usage guidance]
(1) If you need to MODIFY existing notes (partial edit / re-format / replace some segment), FIRST call slide_get_notes_text to read the current content, edit it locally, then call this tool to write the full new text back in a single shot;
(2) If you only need to APPEND content to the end of the existing notes, use slide_append_notes_text directly — do NOT get-then-set;
(3) This tool fully OVERWRITES the current notes; calling it without first reading the original text will discard the existing content. Use with care.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the slide whose notes text should be replaced.
  [ ] text (string): New plain-text content for the notes page. Default: "" (empty, clears existing text).
```

---

## slide_set_page_properties

```plaintext
# slide_set_page_properties

Set page-level properties of a slide, including background fill and visibility. You can set background, visibility, or both in one call.

BACKGROUND (controlled by 'fill_type' parameter):
- "solid" (default): Set a solid color background via 'fill_color' (hex). Omit or pass empty 'fill_color' to clear the slide-level background so the layout/master shows through.
- "image": Set an image background via 'image' (data URI or local absolute file path). Optional 'stretch' (bool, default true) controls stretch vs tile mode. Remote URLs (http/https) are NOT supported.