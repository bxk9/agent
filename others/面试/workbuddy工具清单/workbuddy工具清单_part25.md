  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID.
  [ ] overlay (boolean): true = legend overlays the plot area; false = legend takes its own space. If omitted, current setting is preserved.
  [ ] position (string): Legend position. Allowed values: 'bottom', 'top', 'left', 'right', 'tr', 'none' (hide). Takes precedence over visible when both are passed. If omitted, current position is preserved.
  [ ] text_style (object): Font properties of the legend text. All inner fields are optional; omit a field to keep its current value.
  [ ] visible (boolean): Visibility flag. true shows the legend (defaults to 'bottom' when position is not given); false hides the legend (equivalent to position='none'). When position is also passed, position wins. If omitted, current visibility is preserved.
```

---

## slide_update_chart_series_style

```plaintext
# slide_update_chart_series_style

Update the visual style of a single chart series identified by series_index (0-based). Each style field is optional; omit a field to keep its current value. To recolor multiple series, call this tool once per target series. Markers (marker_style and marker_size) only take effect on chart types that carry markers (line, scatter, radar); they are silently ignored on bar, column, area, and pie.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID.
  [✓] series_index (integer): 0-based index of the target series. Out-of-range values are ignored.
  [ ] fill_color (string): Hex fill color (6 chars, no '#'). Applies to bar, column, area, and pie-slice body.
  [ ] line_color (string): Hex line/border color (6 chars, no '#'). For line charts this is the line color; for bar, area, and pie it is the outline color.
  [ ] line_width_emu (integer): Line/border width in EMU (1pt = 9525, 1.5pt = 14288, 2pt = 19050). Only effective when line_color is also passed. 0 = keep.
  [ ] marker_size (integer): Marker size in points (2-72). Only effective when marker_style is not 'none'.
  [ ] marker_style (string): Marker shape: 'none', 'circle', 'square', 'diamond', 'triangle', 'star', 'plus', 'x'. Effective only on line, scatter, and radar charts.
```

---

## slide_update_chart_title

```plaintext
# slide_update_chart_title

Modify or hide/show the chart's title (text, overlay, font).

Use this when the user wants to set, clear, hide, or show the chart-level title text, toggle whether the title overlays the plot area, or change the title font (color, size, bold, italic, family). All chart types support a title.

Field semantics:
  - text: if omitted, keeps the current title; empty string clears the title (equivalent to visible=false — the title box cannot be visible with empty text); any other string sets the title.
  - visible: if omitted, keeps current visibility; true ensures the title is visible (use text to set the actual content); false hides the title. When both visible=false and text are passed, visible wins and text is ignored.
  - overlay: if omitted, keeps the current setting; true makes the title overlay the plot area; false makes the title take its own space.
  - text_style: optional font sub-object (color, size_pt, bold, italic, name) applied to the title text.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID.
  [ ] overlay (boolean): true = title overlays the plot area; false = title takes its own space. If omitted, the current setting is preserved.
  [ ] text (string): New chart title text. Empty string clears the title (equivalent to visible=false). If omitted, the current title is preserved.
  [ ] text_style (object): Font properties of the title text. All inner fields are optional; omit a field to keep its current value.
  [ ] visible (boolean): Visibility flag. true ensures the title is visible (use text to set the content); false hides the title. When both visible=false and text are passed, visible wins. If omitted, current visibility is preserved.
```

---

## slide_update_chart_trendline

```plaintext
# slide_update_chart_trendline

Add, modify, or remove a trendline on a single chart series.

Use this when the user wants to overlay a regression or moving-average curve on a series, change its style, or remove an existing trendline. Applies to bar, column, line, area, and scatter charts (and 3D variants). NOT supported on pie, doughnut, or radar — calling on these types returns an error suggesting to switch via slide_change_chart_type first.

Field semantics:
  - series_index (required): 0-based index of the target series.
  - visible: if omitted, keeps current state; true is equivalent to action='add'; false is equivalent to action='remove'. Cannot be passed together with action.
  - action (legacy): 'add' (default) creates or updates the trendline; 'remove' deletes it. Prefer visible for new code.
  - trendline_type: regression family ('linear', 'log', 'poly', 'power', 'exp', 'movingAvg'). Required when adding (action='add' or visible=true).
  - poly_order / moving_period: only meaningful when trendline_type is 'poly' or 'movingAvg' respectively.
  - display_equation / display_r_squared: overlay the equation or R² on the chart.
  - line_color / line_width_emu / line_dash: trendline visual style.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The chart shape ID.
  [✓] series_index (integer): 0-based index of the target series.
  [ ] action (string): Legacy flag. 'add' (default) creates or updates the trendline; 'remove' deletes it. Prefer visible for new code; do not pass both.
  [ ] display_equation (boolean): true shows the regression equation on the chart.
  [ ] display_r_squared (boolean): true shows the R² coefficient on the chart.
  [ ] line_color (string): Trendline color (6 hex chars, no '#'). If omitted, the default color is used.
  [ ] line_dash (string): Trendline dash style: 'solid', 'dot', 'dash', 'dashDot', 'lgDash', 'lgDashDot', 'lgDashDotDot', 'sysDash', 'sysDot', 'sysDashDot', 'sysDashDotDot'.
  [ ] line_width_emu (integer): Trendline width in EMU (1pt = 9525). Only effective when line_color is also passed.
  [ ] moving_period (integer): Moving-average period, integer >= 2. Required when trendline_type == 'movingAvg'; ignored otherwise.
  [ ] poly_order (integer): Polynomial order, integer in [2, 6]. Required when trendline_type == 'poly'; ignored otherwise.
  [ ] trendline_type (string): Regression type: 'linear' (default), 'log', 'poly', 'power', 'exp', 'movingAvg'. Required if action == 'add'.
  [ ] visible (boolean): Visibility flag. true is equivalent to action='add'; false is equivalent to action='remove'. Cannot be passed together with action. If omitted, current state is preserved.
```

---

## slide_update_group_shape_properties

```plaintext
# slide_update_group_shape_properties

Apply the same visual and/or transform properties to all child shapes inside a group in a single atomic operation. Mirrors the front-end 'update group' behaviour: one SetShapeProperties mutation per child shape, all packed into one SlideCommand. Visual changes (fill_color / border_color / border_width) are applied to every child shape. Transform changes (x / y / w / h / rotation) are applied to the group shape itself. Only specified properties are updated; omitted ones remain unchanged.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] group_id (string): The ID of the group shape to update.
  [ ] border_color (string): Hex border color applied to all child shapes (e.g. "000000"). Set to "none" to remove border. Omit to keep.
  [ ] border_width (number): Border width in points applied to all child shapes. Omit to keep.
  [ ] fill_color (string): Hex fill color applied to all child shapes (e.g. "FF0000"). Set to "none" to remove fill. Omit to keep.
  [ ] h (number): New height of the group in points (pt; 1pt = 12700 EMU). Omit to keep.
  [ ] rotation (number): Rotation of the group in degrees. Omit to keep.
  [ ] w (number): New width of the group in points (pt; 1pt = 12700 EMU). Omit to keep.
  [ ] x (number): New X position of the group in points (pt; 1pt = 12700 EMU). Omit to keep.
  [ ] y (number): New Y position of the group in points (pt; 1pt = 12700 EMU). Omit to keep.
```

---

## slide_update_guide_lists

```plaintext
# slide_update_guide_lists

Atomically update the presentation-level slide guide list together with per-master / per-layout guide lists. All guide updates are packed into a single undo unit. Guide positions are in EMU (English Metric Units, 1 pt = 12700 EMU). This is the operation triggered internally when changing the slide aspect ratio (e.g. 16:9 → 4:3) and the guide line positions need to be recalculated for all master and layout pages.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] presentation_guides (array<object>): Guide lines for the presentation level. Each entry has orient, pos, and optional color.
  [✓] page_guides (array<object>): Per-master / per-layout guide lists. Each entry specifies a page and its guide lines.
```

---