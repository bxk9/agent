Add a line shape onto a slide page. Unlike filled shapes, a line shape has no fill — only line color, dash pattern, and width. The line is defined by start and end points (in points; 1pt = 12700 EMU). Supports plain lines and arrow lines. This is the correct tool for drawing a directional ARROW LINE between two custom points (use line_type="arrow" for a single-end arrow, "doubleArrow" for both ends). Do NOT use slide_add_shape for this — slide_add_shape only supports preset arrow-shaped blocks ("rightArrow" / "leftArrow") with a fixed orientation.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] x1 (number): X coordinate of the line start point in points (1pt = 12700 EMU).
  [✓] y1 (number): Y coordinate of the line start point in points (1pt = 12700 EMU).
  [✓] x2 (number): X coordinate of the line end point in points (1pt = 12700 EMU).
  [✓] y2 (number): Y coordinate of the line end point in points (1pt = 12700 EMU).
  [ ] color (string): Hex color for the line (e.g. "000000" for black, "FF0000" for red). Default: "000000".
  [ ] dash (string): Line dash type: "solid", "dot", "dash", "dashDot", "lgDash", "lgDashDot". Default: "solid".
  [ ] line_type (string): Line type: "line" (plain, no arrows, default), "arrow" (arrow at the end point), "doubleArrow" (arrows at both ends).
  [ ] w (number): Line width in points (e.g. 1.0, 2.5). Default: 1.
```

---

## slide_add_line_shapes

```plaintext
# slide_add_line_shapes

Batch-add multiple line shapes onto a single slide in one call. All lines are added via a single internal batch (one command / SSE broadcast), which is significantly more efficient than calling slide_add_line_shape repeatedly. Each entry in the `lines` array has the same fields as slide_add_line_shape (minus file_id and page_index, which live at the top level). Returns an array of shape_ids in the same order as the input lines. This is the correct tool for batch-inserting directional ARROW LINES between custom start/end points (use line_type="arrow" / "doubleArrow"). slide_add_shapes only supports preset arrow-shaped blocks ("rightArrow" / "leftArrow").

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] lines (array<object>): Array of line-shape specs. Must contain at least one entry.
```

---

## slide_add_notes

```plaintext
# slide_add_notes

Create a speaker-notes (演讲者备注) page bound to the specified slide and write `text` into its body placeholder. Emits a single SlideCommand (CommandType=Empty) carrying 7 mutations (add_page + set_page_properties + add_shape + set_shape_properties + transform_shape + set_text_data + set_text_body_properties), so the insertion is one revision / one undo unit and is fully aligned with the front-end 'add speaker notes' behaviour and PowerPoint / WPS. The notes page id, its shape-tree root id and the body placeholder shape id are generated internally; callers only need to supply the target slide and the notes content. Position, size, font and color of the body placeholder are inherited from the notes layout / master and are NOT accepted as parameters here.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide whose notes page is being created.
  [ ] text (string): Speaker-notes content (UTF-8). May be empty. Do NOT append a trailing newline — the engine always appends the paragraph terminator (U+000D) automatically. Default: empty string.
```

---

## slide_add_page_number

```plaintext
# slide_add_page_number

Add a slide-number placeholder onto the specified slide page. Inserts an OOXML sldNum placeholder shape (with the '‹#›' page-number field). Position, size, font and color are inherited from the slide layout / master and are NOT accepted as parameters. This mirrors the behaviour of the front-end 'insert page number' action and of PowerPoint / WPS.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
```

---

## slide_add_section

```plaintext
# slide_add_section

Add a new section at the specified position. Provide exactly ONE of before_slide_index or after_section_id to indicate where the new section should be inserted.
- before_slide_index: The new section will OWN the target slide and all subsequent slides up to the next section boundary. The section that previously owned the target slide will be rebound to the next slide.
- after_section_id: The new section is inserted as an EMPTY section right after the specified section. It does not take ownership of any slides.
Returns the generated section_id.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] name (string): Human-readable name for the new section.
  [ ] after_section_id (string): ID of an existing section. The new section is inserted as an empty section right after it (it does NOT take ownership of any slides). Pass empty string "" to insert an empty section at the very beginning (before the first section). Mutually exclusive with before_slide_index. Use slide_get_sections to obtain valid section IDs.
  [ ] before_slide_index (integer): 0-based slide index. The new section will be inserted immediately before this slide and will OWN it (the slide becomes the first slide of the new section). The section that previously contained this slide will be rebound to start from the next slide. Mutually exclusive with after_section_id.
```

---

## slide_add_shape

```plaintext
# slide_add_shape

Add a shape element onto a slide page. Coordinates and dimensions are in points (1pt = 12700 EMU). Supports preset block shapes (rect, ellipse, triangle, flowchart shapes, etc.), fill color with opacity, and border styling (color, dash pattern, width, opacity). IMPORTANT: at least one of fill_color or border_color MUST be provided, otherwise the shape is invisible to the user and the call will be rejected. When fill_color is set but border_color is omitted, the shape has no border by default. IMPORTANT — arrow disambiguation: this tool does NOT create directional arrow lines. It only supports two preset arrow-shaped BLOCKS: "rightArrow" and "leftArrow" (filled arrow blocks with a fixed orientation, sized via x/y/w/h). If the user wants a real arrow LINE drawn between two points (with a custom start and end), use slide_add_line_shape with line_type="arrow" or "doubleArrow" instead. When the user simply says "add an arrow", you MUST first ask whether they want a line-arrow (slide_add_line_shape) or a shape-arrow block (rightArrow / leftArrow).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] x (number): X position of the shape's top-left corner in points (1pt = 12700 EMU).
  [✓] y (number): Y position of the shape's top-left corner in points (1pt = 12700 EMU).
  [✓] w (number): Width of the shape in points (1pt = 12700 EMU).
  [✓] h (number): Height of the shape in points (1pt = 12700 EMU).
  [ ] border_alpha (integer): Border transparency in percent (0..100). 0 = fully opaque (default), 100 = fully transparent.
  [ ] border_color (string): Hex border color (e.g. "000000" for black). Omit for no border.
  [ ] border_dash (string): Border line dash type: "solid", "dot", "dash", "dashDot", "lgDash", "lgDashDot".
  [ ] border_width (number): Border width in points.
  [ ] fill_alpha (integer): Fill transparency in percent (0..100). 0 = fully opaque (default), 100 = fully transparent.
  [ ] fill_color (string): Hex fill color (e.g. "FF0000" for red). Omit for no fill. When set, shape defaults to no border unless border_color is also specified.
  [ ] shape_type (string): Preset shape type: "rect", "roundRect", "ellipse"/"circle", "triangle", "diamond", "pentagon", "hexagon", "star5", "heart", "rightArrow", "leftArrow", "cloud", "line", "plus", "donut", "arc", "pie", "flowChartProcess", "flowChartDecision". Default: "rect". Note: "rightArrow" / "leftArrow" are preset arrow-shaped BLOCKS (fixed orientation, sized by x/y/w/h) — they are the ONLY arrow-like values this tool supports. To draw a directional arrow LINE between two points (with a custom start/end), use slide_add_line_shape with line_type="arrow" / "doubleArrow" instead.
```

---

## slide_add_shapes

```plaintext
# slide_add_shapes

Batch-add multiple shapes onto a single slide in one call. All shapes are added via a single internal batch (one command / SSE broadcast), which is significantly more efficient than calling slide_add_shape repeatedly. Each entry in the `shapes` array has the same fields as slide_add_shape (minus file_id and page_index, which live at the top level). Returns an array of shape_ids in the same order as the input shapes. IMPORTANT: each shape must have at least one of fill_color or border_color set, otherwise the shape is invisible to the user and the call will be rejected. IMPORTANT — same arrow disambiguation as slide_add_shape: arrow-like values are limited to the preset BLOCKS "rightArrow" / "leftArrow". To insert directional arrow LINES between custom start/end points, use slide_add_line_shapes (with line_type="arrow" / "doubleArrow") instead.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shapes (array<object>): Array of shape specs. Must contain at least one entry.
```

---

## slide_add_slide

```plaintext
# slide_add_slide

Add a new slide page into the presentation. You can specify the add position and the layout template. Returns the new total slide count and the editor version.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [ ] index (integer): 0-based add position. -1 (default) appends at the end.