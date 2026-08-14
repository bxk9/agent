Find and replace text in all standalone shapes (SHAPE_TYPE_SHAPE) on a slide page. For each shape that contains at least one occurrence of 'search', the tool computes the fully-replaced new text and re-emits it as a single SetTextDataMutation per shape (integral text rewrite, atomic per shape). Pass replace="" to delete every occurrence of 'search'. IMPORTANT: each affected shape's run-level styling (bold / italic / color / font / size etc.) is reset to default; only language=zh-CN is preserved. Use slide_set_text_property afterwards if precise per-character styles are required. Group shapes / table cells / chart text are NOT traversed by this tool.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page. Must be an integer.
  [✓] search (string): The text string to search for (UTF-8).
  [✓] replace (string): The replacement text string (UTF-8). Pass an empty string to delete every match.
```

---

## slide_get_chart_info

```plaintext
# slide_get_chart_info

Query the full structure of an existing chart shape.

Returns a JSON object with the following key fields:
  - chart_type: top-level chart type name (e.g. 'clusteredColumn', 'stackedBar', 'line', 'pie'), aligned with the names accepted by slide_add_chart and slide_change_chart_type.
  - sub_chart_count, sub_charts: per sub-chart breakdown. Each entry contains chart_type (use this when calling other tools), array_index (use this when targeting a specific sub-chart in update calls), series_count, category_count, and axes_count.
  - categories, series: from the first sub-chart. Each series object contains name, values, style?, and optionally data_labels (when that series has its own label settings that differ from the chart-level defaults).
  - series.style: { fill_color?, line_color?, line_width_emu?, marker_style?, marker_size? }. fill_color/line_color are hex strings (e.g. '4472C4'); marker_style is one of 'circle','dash','diamond','dot','none','picture','plus','square','star','triangle','x'.
  - title: { visible, text?, overlay?, text_style? }. visible=false means the chart title is hidden; text may be empty when the title box exists but its text is cleared.
  - legend: { visible, position?, overlay?, text_style? }. position is one of 'bottom', 'top', 'left', 'right', 'tr'.
  - data_labels (when configured): { visible, position?, show_value?, show_category?, show_series_name?, show_percent?, show_bubble_size?, show_legend_key?, number_format?, format_type?, text_style? }. Absent when no data labels are configured. visible=false means data labels are not shown.
  - data labels hierarchy: the chart-level data_labels acts as the default template; each series may override it via series[i].data_labels. When a series has its own data_labels those settings take precedence; otherwise the chart-level defaults apply.
  - display_blanks_as, plot_vis_only: chart-level display flags when set.
  - category_axis (when the first sub-chart has a category axis): { title?, hidden?, title_visible?, title_overlay?, number_format?, format_type?, tick_label_font?, title_font? }. title_visible=false when axis delete_keyword is true (entire axis hidden). tick_label_font and title_font are { color?, size_pt?, bold?, italic?, family? }.
  - value_axis (when the first sub-chart has a value axis): same fields as category_axis.
  - show_major_gridlines: boolean (backward compat, = gridlines.value_major).
  - gridlines: { value_major, value_minor, category_major }. Each is a boolean indicating whether that gridline type is shown.

Note on shape_id persistence: shape_id is stable within a single editing session. After save, close, and reopen, the shape ID may be reassigned (e.g. 'jr3sa8' -> '000069'). To operate on a chart across sessions, re-query slide_get_page_info to obtain the current shape_id.

Use this when you need the chart's full structure (e.g. to edit it). If you only need to identify the chart type, slide_get_shape_info already includes a lightweight chart summary in its response.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID. Typically obtained from slide_add_chart's response or slide_get_shape_info.
```

---

## slide_get_group_info

```plaintext
# slide_get_group_info

Query the children of a group shape on a slide page. Returns the list of direct child shapes (id, type, name, position, size) inside the specified group. Nested groups are expanded recursively with a 'children' field. Use this tool to discover child shape IDs before calling slide_get_shape_info or slide_set_shape_properties on individual children.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] group_id (string): The ID of the group shape to inspect.
```

---

## slide_get_info

```plaintext
# slide_get_info

Get metadata and status of the current presentation. Returns: is_open, slide_count, ordered slide_ids (page IDs), slide dimensions (width/height in EMU and points; 1pt = 12700 EMU), editor version, is_dirty flag, and file_path (when available). Use this to understand the structure before adding or editing slides.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
```

---

## slide_get_master_info

```plaintext
# slide_get_master_info

Get information about slide master(s) in the presentation. Returns master page details including: master_id, header/footer toggle states (sld_num, dt, ftr, hdr), layout list (with layout_id, layout_type, matching_name), and all shapes on the master page (including placeholder shapes for page number, date/time, footer). When page_index is provided, returns only the master associated with that specific slide (resolved via slide -> layout -> master chain). When page_index is omitted, returns all masters in the presentation. Use this to understand master configuration before adjusting page layouts or placeholder fields.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [ ] page_index (integer): Optional. 0-based slide index. When provided, returns only the master associated with this slide. When omitted, returns all masters.
```

---

## slide_get_notes_text

```plaintext
# slide_get_notes_text

Read the plain-text content of the notes page attached to a slide. Returns the body text (UTF-8) and its UTF-16 length, with the trailing paragraph terminator U+000D stripped. If the slide has no notes page yet, returns an error — call slide_add_notes first. Run/paragraph-level rich-text properties of the notes body are NOT exposed by this tool; use slide_get_text on the notes body shape if such detail is required.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the slide whose notes text should be read.
```

---

## slide_get_page_info

```plaintext
# slide_get_page_info

Get a concise summary of all shapes and animations on a slide page. Each shape includes: id, type (shape/picture/group/...), preset geometry name (geom, e.g. 'rect' / 'ellipse' / 'roundRect' — only for drawable shapes), position (x/y in pt), size (w/h in pt; 1pt = 12700 EMU), rotation, text content, fill color (hex) and fill_alpha (0..100, omitted when fully opaque; 'fill' = 'none' means the shape is explicitly transparent), border color/width and border_alpha (0..100, omitted when fully opaque; NOTE: alpha values represent transparency — 0 = opaque, 100 = transparent), image embed id. Groups have nested 'children'. Designed for quick layout understanding before editing.
Each animation includes: shape_id (the animated shape), index (0-based position in the trigger's sequence), seq_type (clickEffect / withEffect / afterEffect / mainSeq / interactiveSeq), trigger_id (which trigger owns this animation — 'kDefaultTriggerId' for mainSeq, or a shape_id for interactive triggers), preset_class (1=entrance, 2=exit, 3=emphasis, 4=call, 5=media), preset_id (OOXML PresetId), preset_subtype (OOXML PresetSubType — direction/sub-kind). anim_count is the total number of animations on this page.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
```

---

## slide_get_sections

```plaintext
# slide_get_sections

Get all sections in the presentation. Returns an ordered list of sections, each with section_id, name, first_slide_index (the 0-based index of the first slide belonging to that section; -1 means the section has no bound slide, i.e. it is an empty trailing section), and slide_count (number of slides in that section). Also returns total_slide_count for the whole presentation. The last section in the returned array is the last section. Use this to understand the section structure before adding, moving, or removing sections.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
```

---

## slide_get_shape_info

```plaintext
# slide_get_shape_info

Get detailed information about a specific shape. Returns full bounds (points, plus rotation/flip), text + first-run font style (color/family/size), fill type/color/alpha, border (color/width/dash/alpha), geometry type, style.corner_radius (exact OOXML adjustment, 0..50000), and style.shadow/reflection/glow/soft_edge effect parameters, placeholder status, name, parent_id, image embed_id, and chart summary. For SHAPE_TYPE_SHAPE, also returns `body_pr` with text-body properties: autofit_type (spAutoFit/normAutofit/noAutofit), wrap, anchor, anchor_ctr, l_ins/t_ins/r_ins/b_ins (EMU), rot_deg, vert (text orientation), from_word_art (WordArt flag), has_prst_tx_warp. Use this when you need precise style or text-body details for a specific shape — e.g. to determine whether the shape is auto-fit, is a WordArt, has custom insets, etc.

参数（✓=必填）：