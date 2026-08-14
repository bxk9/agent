  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page. Must be an integer.
  [ ] shape_id (string): (Single-shape mode) The shape ID whose text to replace.
  [ ] shape_ids (array<string>): (Batch many-to-one mode) Array of shape IDs. The top-level 'text' is applied to all shapes.
  [ ] shapes (array<object>): (Batch one-to-one mode) Array where each entry has its own shape_id and text. All changes are applied as a single undo unit / SSE broadcast.
  [ ] text (string): New text content (UTF-8). Length is unconstrained.
```

---

## slide_set_text_property

```plaintext
# slide_set_text_property

在不修改文本内容的前提下，对形状内指定字符范围设置富文本样式（加粗、斜体、颜色、字号、超链接等）。index 和 count 以 UTF-16 码元为单位（与 slide_get_text 返回的单位一致）。仅传入的字段会被修改，未传入的字段保持原值不变。超链接：hyperlink 传非空 URL 表示把该范围文本设为超链接，传空字符串 "" 表示清除该范围的超链接。支持三种模式：(A) 单形状——传 shape_id + index + count + 样式属性；(B) 批量一对一——传 shapes 数组，每项含各自的 shape_id + index + count + 样式属性；(C) 批量多对一——传 shape_ids 数组 + 顶层 index + count + 样式属性，对所有形状统一应用。批量模式下所有变更合并为一个撤销单元 / 一次 SSE 广播。

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 目标幻灯片页面的从 0 起的索引。必须填入整数（integer）。
  [ ] baseline (integer): 基线偏移（OOXML 单位千分之一百分比，30% 上标 = 30000，-25% 下标 = -25000，0 为正常）。不传保持原值。
  [ ] bold (boolean): 粗体：true 加粗，false 取消加粗。不传保持原值。
  [ ] color (string): 文字颜色，6 位十六进制（不含 #，如 "FF0000" 表示红色）。不传保持原值。
  [ ] count (integer): 目标子串长度（UTF-16 码元）。-1 表示从 index 到文本末尾。单形状模式和多对一模式（shape_ids）必填。
  [ ] font_name (string): 字体名称（如 "Arial"），同时设置西文字体和中文字体。不传保持原值。
  [ ] font_size (number): 字号（磅，如 24 表示 24pt）。不传保持原值。
  [ ] hyperlink (string): 超链接 URL：传非空字符串（如 "https://docs.qq.com"）把 index/count 指定的文本范围设为超链接；传空字符串 "" 清除该范围的超链接。不传保持原值。
  [ ] hyperlink_tooltip (string): 超链接悬浮提示文字，仅在设置超链接（hyperlink 非空）时有意义。
  [ ] index (integer): 目标子串起始位置（UTF-16 码元，从 0 起）。单形状模式和多对一模式（shape_ids）必填。
  [ ] italic (boolean): 斜体：true 斜体，false 取消斜体。不传保持原值。
  [ ] letter_spacing (number): 字间距（磅，如 1.5）。内部以百分之一磅存储。不传保持原值。
  [ ] shape_id (string): （单形状模式）包含目标文本的形状 ID。
  [ ] shape_ids (array<string>): （批量多对一模式）形状 ID 数组。顶层的 index、count 及样式属性统一应用到数组中每个形状。
  [ ] shapes (array<object>): （批量一对一模式）每个形状独立配置的数组。每项须包含 shape_id、index、count 以及至少一个样式属性（bold/italic/underline/strikethrough/color/font_name/font_size/letter_spacing/baseline/hyperlink）。
  [ ] strikethrough (string): 删除线样式，可选值："none"、"single"、"double"。不传保持原值。
  [ ] underline (string): 下划线样式，可选值："none"、"single"、"double"、"heavy"、"dotted"、"dash"、"wavy"。不传保持原值。
```

---

## slide_set_theme

```plaintext
# slide_set_theme

Apply a theme to the presentation. Three modes:
  (1) SWITCH (only theme_id):
      The theme_id must come from slide_get_themes (i.e. an embedded theme of the current presentation). Reuses the embedded ThemeElements.
  (2) BUILT-IN (only theme_id):
      The theme_id must come from slide_list_builtin_themes (a preset theme provided by the backend, e.g. builtin_office / builtin_feilengcui_lv). The backend will auto-load theme_name and theme_elements from its static resource. A built-in theme_id always resolves as BUILT-IN (re-emitted as a SetTheme mutation), regardless of whether the same id is already embedded in the presentation.
  (3) ADD or OVERRIDE (theme_id + theme_name + theme_elements):
      Inserts a new theme when theme_id is not yet known, or overrides the ThemeElements of an existing theme. The theme_elements field must be a JSON object whose shape matches tencent.docs.model.CTBaseStyles (clr_scheme / font_scheme / fmt_scheme; same shape as themeElements in the front-end add-theme mutation).
All three modes emit exactly one SetTheme mutation. Note: shapes that reference theme scheme colors will follow the new theme automatically, but custom per-shape color transforms (lumMod / lumOff applied on master / layout shapes) are not migrated by this tool — that is a separate front-end side-effect.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] theme_id (string): ID of the target theme. For SWITCH mode, must come from slide_get_themes. For ADD/OVERRIDE mode, can be any non-empty string (existing id → override; new id → insert).
  [ ] theme_elements (object): JSON object matching tencent.docs.model.CTBaseStyles (clr_scheme / font_scheme / fmt_scheme). Required for ADD/OVERRIDE mode; ignored in SWITCH mode. Unknown fields are ignored during parsing.
  [ ] theme_name (string): Display name of the theme. Required for ADD/OVERRIDE mode; ignored in SWITCH mode.
```

---

## slide_ungroup_shapes

```plaintext
# slide_ungroup_shapes

Dissolve a group shape, restoring its children as direct children of the page's shape tree. The group shape itself is removed; the child shapes remain on the page.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] group_id (string): The ID of the group shape to dissolve.
```

---

## slide_unmerge_table_cells

```plaintext
# slide_unmerge_table_cells

Undo a previous merge over the given rectangular region.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based slide page index.
  [✓] shape_id (string): The table shape id.
  [✓] start_row (integer): 0-based top row of the region.
  [✓] start_col (integer): 0-based left column of the region.
  [✓] row_span (integer): Number of rows spanned. > 0.
  [✓] col_span (integer): Number of columns spanned. > 0.
```

---

## slide_update_chart_axis

```plaintext
# slide_update_chart_axis

Modify, hide/show, or restyle one chart axis (category=X, value=Y), including its axis title and tick labels.

Use this when the user wants to change the axis number format, axis title text, hide or show the axis, or tweak axis-title visibility/font or tick-label font. Applies to bar, column, line, area, scatter, and radar charts (and 3D variants). NOT supported on pie, doughnut, pie3D, ofPie — calling on these types returns an error suggesting to switch via slide_change_chart_type first.

Field semantics:
  - axis (required): which axis to modify, 'category' (X) or 'value' (Y).
  - visible: if omitted, keeps current visibility; true shows the axis; false hides the entire axis (ticks and labels). Cannot be passed together with hidden.
  - hidden (legacy): same effect as visible=false. Prefer visible for new code; do not pass both.
  - title: if omitted, keeps the current axis title; empty string clears it.
  - format_type / number_format: number format for the axis tick labels — see field descriptions below. format_type is the recommended friendly enum; number_format is the advanced raw format code.
  - title_visible / title_overlay / title_font: hide-only-the-axis-title / overlay flag / font of the axis title.
  - tick_label_font: font of the axis tick labels.

Min/max/major_unit/minor_unit and secondary axis are not supported yet.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID.
  [✓] axis (string): Which axis to modify: 'category' or 'value'.
  [ ] format_type (string): Recommended friendly enum for the axis number format. Allowed values: 'general' (常规), 'text' (文本), 'number' (数值 0.95), 'number_2d' (数值 0.00), 'number_thousands' (数值 千分位 1,234), 'number_thousands_2d' (数值 千分位两位小数 1,234.00), 'percent' (百分比 90%), 'percent_2d' (百分比 90.00%), 'fraction' (分数 1/2), 'scientific' (科学记数 9.50E-01), 'currency_cny' (人民币 ¥5.00), 'currency_hkd' (港币 HK$5.00), 'currency_usd' (美元 $5.00), 'date_short' (短日期 2018/4/18), 'date_m_d' (月日 4月18日), 'date_y_m' (年月 2018年4月), 'date_full' (完整日期 2018年4月18日), 'datetime' (日期时间 2018/4/18 14:30:30), 'time' (时间 14:30:30). format_type takes precedence over number_format. Values not in this enum are ignored — for custom formats use number_format instead.
  [ ] hidden (boolean): Legacy visibility flag. true hides the axis (ticks and labels). Prefer visible for new code; do not pass both.
  [ ] number_format (string): Advanced raw number format code (Excel-style), e.g. 'General', '#,##0', '0%', 'yyyy-mm-dd'. Used only when format_type is not provided or does not match the enum. Prefer format_type.
  [ ] tick_label_font (object): Font properties of the axis tick labels (the numbers or categories shown along the axis line). All inner fields are optional; omit a field to keep its current value.