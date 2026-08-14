  [ ] is_update_range (boolean): 是否更新筛选范围,- true：使用 start_row/start_col/end_row/end_col 作为新的筛选范围（4 个字段必填）；false：保留原有筛选范围
  [ ] start_col (integer): 新的数据区域起始列（0-based），仅当 is_update_range=true 时生效
  [ ] start_row (integer): 新的数据区域起始行（0-based），仅当 is_update_range=true 时生效
```

---

## sheet_update_pivot_table

```plaintext
# sheet_update_pivot_table

更新已有透视表的字段配置（行分组、列分组、数据值、筛选、计算字段）。替换语义：每次调用整体替换字段配置，未传入的分类视为清空。

参数（✓=必填）：
  [✓] sheet_id (string): 透视表所在子表ID（必填）
  [✓] pivot_table_id (string): 目标透视表ID（必填，AddPivotTable时由调用方分配）
  [ ] calculated_values (array<object>): 计算字段列表（替换语义）
  [ ] column_groups (array<object>): 列分组字段列表（替换语义）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] filters (array<object>): 页字段筛选器列表（替换语义）
  [ ] pivot_values (array<object>): 数据值字段列表（替换语义）
  [ ] row_groups (array<object>): 行分组字段列表（替换语义）
```

---

## shutdown

```plaintext
# shutdown

Shut down the editor SDK server. All editors must be closed first, unless force=true. If any editor has unsaved changes and force is not set, returns an error listing the dirty files.

参数（✓=必填）：
  [ ] force (boolean): If true, force shutdown even with open/dirty editors (default: false)
```

---

## slide_add_anim

```plaintext
# slide_add_anim

Bind an entrance/exit animation onto a single shape on a slide page. Each call appends one animation node into the shape's animation sequence (one MCP call = one SlideCommand = one undo unit / one SSE event). The supported animation kinds are returned by `slide_list_anim_types`; calling with an unsupported `anim_type` is rejected up front. Note: this tool exposes a single `shape_id` only — binding an animation to multiple shapes at once is not part of the public surface.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The ID of the shape to animate. Must be a non-empty existing shape on the page.
  [✓] anim_type (integer): Animation kind, encoded as the integer value of the C++ AnimType enum. Use `slide_list_anim_types` to discover the supported (value, name, description) triples — only those values are accepted here.
  [ ] anim_subtype (integer): Animation direction / sub-kind. Currently consumed by FLY_IN / FLY_OUT only; other anim_types ignore it. Allowed values: 1=RIGHT, 2=TOP, 3=TOP_RIGHT, 4=BOTTOM (default for FLY_IN/OUT when omitted), 6=BOTTOM_LEFT, 8=LEFT, 10=TOP_LEFT, 12=BOTTOM_RIGHT. Pass 0 to fall back to the per-anim default.
  [ ] index (integer): Starting slot in the animation sequence (0 = head). Default: 0. Callers that want to append should pass the current animation count for the shape.
```

---

## slide_add_chart

```plaintext
# slide_add_chart

Add a chart (column, bar, line, area, pie, scatter, radar, etc.) onto a slide page. The chart embeds its own data (categories and series) so the resulting file is self-contained and can be opened without any external data source. Coordinates and dimensions are in pixels at 96 DPI.

Returns: ok, shape_id (use this ID in subsequent chart-modifying calls), page_index, version, chart_type, sub_charts, title, legend, categories, series, and (when applicable) data_labels, category_axis, value_axis, show_major_gridlines, display_blanks_as, plot_vis_only.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] x (number): X position of the chart's top-left corner in points (1pt = 12700 EMU).
  [✓] y (number): Y position of the chart's top-left corner in points (1pt = 12700 EMU).
  [✓] w (number): Width of the chart in points (1pt = 12700 EMU).
  [✓] h (number): Height of the chart in points (1pt = 12700 EMU).
  [✓] series (array<object>): One or more data series. Each series becomes a column, bar, line, or slice depending on chart_type.
  [ ] bg_color (string): Hex color for the chart background fill (e.g. "FFFFFF" or "#F0F0F0"). A leading '#' is accepted. If omitted or empty, defaults to white. Ignored when transparent is true.
  [ ] categories (array<string>): Category-axis labels (x-axis). For pie/doughnut charts these become slice labels. Length must match each series.values length. Omit for XY-only charts like scatter.
  [ ] chart_type (string): Chart type. Allowed values: "clusteredColumn" (default), "stackedColumn", "percentStackedColumn", "clusteredBar", "stackedBar", "percentStackedBar", "line", "stackedLine", "markerLine", "pie", "doughnut", "area", "stackedArea", "scatter", "smoothLineScatter", "straightLineScatter", "bubble", "radar", "markerRadar", "filledRadar". Unknown values are rejected.
  [ ] title (string): Chart title. If omitted or empty, no title is shown.
  [ ] transparent (boolean): If true, the chart is rendered with no background fill so the slide background shows through, and bg_color is ignored. Defaults to false.
```

---

## slide_add_datetime

```plaintext
# slide_add_datetime

Add a date/time placeholder onto the specified slide page. Inserts an OOXML 'dt' placeholder shape (with a 'datetime1' field) and writes a single SlideCommand carrying 4 mutations (AddShape + SetShapeProperties + SetTextData + SetTextBodyProperties), so the insertion is one revision / one undo unit. Position, size, font and color are inherited from the slide layout / master and are NOT acceptedas parameters — this mirrors the behaviour of the front-end 'insert date/time' action and of PowerPoint / WPS. The caller decides the literal date format via display_text; the engine just renders whatever string is passed in.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [ ] display_text (string): Visible text inside the date/time placeholder, e.g. "2026/05/11". Default: empty string.
```

---

## slide_add_footer

```plaintext
# slide_add_footer

Add or remove a footer placeholder shape on the specified slide page. When show=true (default), inserts an OOXML 'ftr' placeholder shape carrying the given display_text. When show=false, removes any existing footer placeholder shape from the slide. Position, size, font and color are inherited from the slide layout / master and are NOT accepted as parameters. This mirrors the behaviour of the front-end 'insert footer' action and of PowerPoint / WPS.

⚠️ IMPORTANT: This tool and doc_insert_footer are MUTUALLY EXCLUSIVE with slide_set_page_properties for footer control. Calling this tool manages the footer placeholder independently.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [ ] display_text (string): Visible text inside the footer placeholder, e.g. "Confidential" or "© 2026 Acme Corp". Only used when show=true. Default: empty string.
  [ ] show (boolean): true (default) = add/show the footer placeholder shape; false = remove/hide the footer placeholder shape from the slide.
```

---

## slide_add_image

```plaintext
# slide_add_image

Add an image (picture) onto a slide page. The `image` field accepts either a data URI (data:image/<mime>;base64,<payload>) or a local absolute file path (optionally prefixed with file://). Local files and data-URI payloads are auto-copied into the session's image_dir (set at open time) before being registered as a resource, so the exported pptx always carries a valid src. Remote URLs (http/https) are NOT supported — the exporter does not fetch remote bytes, so such images would silently drop from the final pptx. Coordinates and dimensions are in points (1pt = 12700 EMU).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): REQUIRED. 0-based index of the target slide page.
  [✓] x (number): REQUIRED. X position of the image's top-left corner in points (1pt = 12700 EMU).
  [✓] y (number): REQUIRED. Y position of the image's top-left corner in points (1pt = 12700 EMU).
  [✓] w (number): REQUIRED. Width of the image in points (1pt = 12700 EMU).
  [✓] h (number): REQUIRED. Height of the image in points (1pt = 12700 EMU).
  [✓] image (string): REQUIRED. Image source. Accepts: (1) data URI (data:image/<mime>;base64,<payload>); (2) local absolute file path, optionally prefixed with file://. Local files are copied into the session's image_dir automatically. Remote URLs (http/https) are NOT supported.
  [ ] corner_radius (integer): OPTIONAL (default 0). Exact OOXML roundRect adjustment in range 0..50000. 0 creates a rectangular image; positive values create rounded corners. The physical radius is min(width,height) * corner_radius / 100000; 4376 matches the editor's previous rounded=true default.
  [ ] shadow_type (string): OPTIONAL (default none). When set, applies a drop shadow using the editor's default parameters (45° bottom-right, 3pt offset, 40% black). Values align with the underlying OOXML effect types: "outer" (outerShdw), "inner" (innerShdw), "preset" (prstShdw). Omit for no shadow.
```

---

## slide_add_line_shape

```plaintext
# slide_add_line_shape
