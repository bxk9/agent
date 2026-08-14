  [ ] title (string): Axis title text. Empty string clears the axis title. NOTE: passing this field on pie, doughnut, or radar charts is rejected with an error (those types have no axis title); call slide_change_chart_type first to switch to a type with axis titles (e.g. clusteredColumn, line).
  [ ] title_font (object): Font properties of the axis title text. All inner fields are optional; omit a field to keep its current value.
  [ ] title_overlay (boolean): true makes the axis title overlay the plot area instead of taking its own space. Defaults to false. If omitted, current setting is preserved.
  [ ] title_visible (boolean): false hides only the axis title (the axis itself stays visible). Different from hidden, which hides the entire axis. If omitted, current setting is preserved.
  [ ] visible (boolean): Visibility flag. true shows the axis; false hides the entire axis (ticks and labels). Cannot be passed together with hidden. If omitted, current visibility is preserved.
```

---

## slide_update_chart_data

```plaintext
# slide_update_chart_data

Replace the data (categories and series) of an existing chart shape while keeping its current chart_type intact (a bar chart stays a bar chart, a line chart stays a line chart, etc.). Axes, title, legend, and per-series style overrides are not affected.

Key usage rules:
  1. The chart_type cannot be changed here — use slide_change_chart_type for that.
  2. The number of series after the call equals series.length: extra existing series are dropped, missing series are appended. Series order maps 1:1 to legend order.
  3. categories length must match every series[i].values length. If categories is omitted, the new chart has no category labels (mainly useful for pie or scatter).
  4. For pie/doughnut charts (single-series families), only series[0] is used; extra series are silently ignored.
  5. Per-series colors, markers, and line widths are reset to defaults. To re-apply custom styles, follow up with slide_update_chart_series_style.

Not supported by this tool: switching chart_type (use slide_change_chart_type); style/color/marker overrides (use slide_update_chart_series_style); legend, axis title, or gridlines (use slide_update_chart_legend / slide_update_chart_axis / slide_update_chart_gridlines); bubble/stock/surface/ofPie variants (recreate the chart with slide_add_chart); chart shape position/size (use slide_set_shape_properties).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID to update. Typically obtained from slide_add_chart's response or slide_get_shape_info.
  [✓] series (array<object>): One or more data series. Each series becomes a column, bar, line, or slice depending on the chart's existing type. For pie/doughnut only the first series is rendered; extra series are silently ignored.
  [ ] categories (array<string>): New category-axis labels (x-axis). For pie/doughnut these become slice labels. Length must match every series.values length when present. NOTE: omitting this field clears the category labels (it does NOT preserve existing labels). For bar/column/line charts, omitting it makes the x-axis labels disappear. To preserve existing labels, pass them explicitly. Only omit when category labels are not meaningful (scatter, bubble, pie).
  [ ] sub_chart_index (integer): 0-based index of the target sub-chart inside the chart. Defaults to 0. Slides do not support combo charts in the editor, so this is almost always 0; supply a non-zero value only if you have explicitly constructed a multi-sub-chart layout.
```

---

## slide_update_chart_data_labels

```plaintext
# slide_update_chart_data_labels

Hide, show, or configure data labels on the chart.

Use this when the user wants to toggle data labels on/off, set their position, or pick which sub-fields (value, category, series name, percent, legend key) to show. Applies to all chart types (rendering of percent only makes sense on pie/doughnut, and bubble size only on bubble charts).

Field semantics:
  - series_index: -1 (default) applies to ALL series (chart-wide); 0 or higher targets a single series.
  - visible: if omitted, keeps current visibility; true ensures data labels are visible (if currently hidden, this shows them with default settings; combine with show_*/position to configure further); false hides data labels for the target series. When both visible=false and other show_*/position fields are passed, visible wins and the other fields are ignored.
  - show_value / show_category / show_series_name / show_legend_key: per-field toggles for label content.
  - show_percent: only meaningful on pie/doughnut charts; passing this on bar, line, area, radar, or scatter charts is rejected with an error.
  - show_bubble_size: only meaningful on bubble charts.
  - position: 'ctr', 'inEnd', 'inBase', 'outEnd', 'bestFit', 't', 'b', 'l', 'r'.
  - format_type / number_format: number format applied to the data label values — see field descriptions below. format_type is the recommended friendly enum.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID.
  [ ] format_type (string): Recommended friendly enum for the data label number format. Allowed values: 'general' (常规), 'text' (文本), 'number' (数值 0.95), 'number_2d' (数值 0.00), 'number_thousands' (数值 千分位 1,234), 'number_thousands_2d' (数值 千分位两位小数 1,234.00), 'percent' (百分比 90%), 'percent_2d' (百分比 90.00%), 'fraction' (分数 1/2), 'scientific' (科学记数 9.50E-01), 'currency_cny' (人民币 ¥5.00), 'currency_hkd' (港币 HK$5.00), 'currency_usd' (美元 $5.00), 'date_short' (短日期 2018/4/18), 'date_m_d' (月日 4月18日), 'date_y_m' (年月 2018年4月), 'date_full' (完整日期 2018年4月18日), 'datetime' (日期时间 2018/4/18 14:30:30), 'time' (时间 14:30:30). format_type takes precedence over number_format.
  [ ] number_format (string): Advanced raw number format code (Excel-style) applied to the data label values, e.g. 'General', '0%', '#,##0.00', 'yyyy-mm-dd'. Used only when format_type is not provided or does not match the enum.
  [ ] position (string): Label position: 'ctr', 'inEnd', 'inBase', 'outEnd', 'bestFit', 't', 'b', 'l', 'r'.
  [ ] series_index (integer): Target series. -1 (default) applies to ALL series (chart-wide); 0 or higher targets a single series.
  [ ] show_bubble_size (boolean): Show bubble size on each data point. Only meaningful on bubble charts.
  [ ] show_category (boolean): Show the category-axis label on each data point.
  [ ] show_legend_key (boolean): Show the legend key (color marker) inside the label.
  [ ] show_percent (boolean): Show percentage on each data point. Only meaningful on pie/doughnut charts; passing this on bar, line, area, radar, or scatter charts is rejected with an error (use show_value there, or call slide_change_chart_type first).
  [ ] show_series_name (boolean): Show the series name on each data point.
  [ ] show_value (boolean): Show numeric value on each data point.
  [ ] text_style (object): Font properties of the data label text. All inner fields are optional; omit a field to keep its current value.
  [ ] visible (boolean): Visibility flag. true ensures data labels are visible (combine with show_*/position to configure further); false hides data labels for the target series. When both visible=false and show_*/position are passed, visible wins. If omitted, current visibility is preserved.
```

---

## slide_update_chart_gridlines

```plaintext
# slide_update_chart_gridlines

Hide or show major gridlines on the value (Y) axis.

Use this when the user wants to toggle major value-axis gridlines on the chart. Applies to bar, column, line, area, and scatter charts (and 3D variants). NOT supported on pie, doughnut, or radar — calling on these types returns an error suggesting to switch via slide_change_chart_type first.

Field semantics:
  - visible: if omitted, keeps current visibility; true shows major gridlines (equivalent to show_major=true); false hides them.
  - show_major (legacy): same effect as visible. Cannot be passed together with visible.

Minor gridlines, category-axis gridlines, and per-line color/width are not supported yet.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID.
  [ ] show_major (boolean): Legacy flag. true shows major gridlines on the value axis, false hides them. Prefer visible for new code; do not pass both.
  [ ] visible (boolean): Visibility flag. true shows major gridlines; false hides them. Cannot be passed together with show_major. If omitted, current visibility is preserved.
```

---

## slide_update_chart_legend

```plaintext
# slide_update_chart_legend

Modify or hide/show the chart's legend (position, overlay, font).

Use this when the user wants to move the legend, toggle overlay vs reserved space, hide/show the legend, or change the legend font. Applies to all chart types that render a legend (i.e. all charts with at least one series).

Field semantics:
  - visible: if omitted, keeps current visibility; true shows the legend (defaults to 'bottom' when position is not also passed); false hides the legend (equivalent to position='none').
  - position: if omitted, keeps current position; allowed values are 'bottom', 'top', 'left', 'right', 'tr' (top-right corner), 'none' (hide). When both visible and position are passed, position wins.
  - overlay: if omitted, keeps current setting; true makes the legend overlay the plot area; false makes it take its own space.
  - text_style: optional font sub-object (color, size_pt, bold, italic, name) applied to the legend text.

Per-series legend item visibility is not supported yet.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on