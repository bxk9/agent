- "gradient": Set a gradient background via 'gradient_stops' (array of {color, pos}) and optional 'gradient_angle'. Requires at least 2 stops.

VISIBILITY:
- 'visible' (bool): true = show (default state), false = hide the slide from slideshow playback. Hidden slides remain in the presentation structure.

NOTE: For placeholder fields (page number, date/time, footer), use the dedicated tools: slide_add_page_number, slide_add_datetime.

BACKGROUND TRANSPARENCY (fill_alpha):
- fill_alpha (0..100): 0 = fully opaque (no transparency), 100 = fully transparent (invisible).
- Can be used together with fill_type (solid/image/gradient) to set transparency at the same time as changing the fill.
- Can also be used alone (without fill_type) to adjust the current background's transparency regardless of its fill type.

BEHAVIOR:
- Only the properties you provide are modified; omitted ones remain unchanged.
- If both background and visibility are specified, both are applied in one call.
- To only change visibility without touching background, just pass page_index + visible.
- To only change background without touching visibility, just pass page_index + fill_type/fill_color/etc.
- To only change background transparency without touching visibility, just pass page_index + fill_alpha.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): REQUIRED. 0-based index of the target slide page.
  [ ] fill_alpha (integer): Background transparency in percent (0..100). 0 = fully opaque (default), 100 = fully transparent.
  [ ] fill_color (string): For fill_type=solid: Hex color (e.g. "FFFF00" or "#FFFF00"). Empty string or omitted clears the slide-level background (inherits from layout/master).
  [ ] fill_type (string): Background fill type. One of: "solid" (default), "image", "gradient". When omitted and no fill-related params are given, background is not modified.
  [ ] gradient_angle (integer): For fill_type=gradient: Linear gradient angle in 1/60000 degrees. 0=left-to-right, 5400000=top-to-bottom. Default: 0.
  [ ] gradient_stops (array<object>): For fill_type=gradient: REQUIRED. Array of at least 2 gradient stops.
  [ ] image (string): For fill_type=image: data URI (data:image/<mime>;base64,<payload>) or local absolute file path (optionally prefixed with file://). Remote URLs (http/https) are NOT supported.
  [ ] stretch (boolean): For fill_type=image: if true (default), stretches the image to fill the slide. If false, tiles the image.
  [ ] tile_alignment (string): For fill_type=image with stretch=false: tile alignment anchor point. One of: "tl" (top-left, default), "t" (top-center), "tr" (top-right), "l" (middle-left), "ctr" (center), "r" (middle-right), "bl" (bottom-left), "b" (bottom-center), "br" (bottom-right). Default: "tl".
  [ ] tile_flip (string): For fill_type=image with stretch=false: tile flip mode. One of: "none" (default), "x" (flip horizontally), "y" (flip vertically), "xy" (flip both). Default: "none".
  [ ] tile_sx (integer): For fill_type=image with stretch=false: horizontal scale in 1/100000 units (100000 = 100%). Default: 100000.
  [ ] tile_sy (integer): For fill_type=image with stretch=false: vertical scale in 1/100000 units (100000 = 100%). Default: 100000.
  [ ] tile_tx (integer): For fill_type=image with stretch=false: horizontal offset in EMU. Default: 0.
  [ ] tile_ty (integer): For fill_type=image with stretch=false: vertical offset in EMU. Default: 0.
  [ ] visible (boolean): Slide visibility. true = show (default state), false = hide from slideshow playback. Omit to leave visibility unchanged.
```

---

## slide_set_shape_properties

```plaintext
# slide_set_shape_properties

修改幻灯片中一个或多个形状的属性。支持三种使用模式：
  (A) 单形状模式：传入 shape_id + 属性字段（位置/尺寸/旋转/填充/边框/圆角/效果）。
  (B) 批量一对一模式：传入 shapes 数组，每项包含 shape_id 及各自的属性（位置/尺寸/旋转/填充/边框/圆角/效果）。视觉属性变更合并为一次撤销单元，transform 变更合并为另一次撤销单元。
  (C) 批量多对一模式：传入 shape_ids 数组 + 顶层属性，所有形状统一应用相同的位置/尺寸/旋转/填充/边框/圆角/效果变更。
未指定的属性保持不变。
形状类型支持说明：
  - 普通形状(shape)：支持 fill_color / fill_alpha / border_color / border_alpha / border_width / border_dash / shadow / reflection / glow / soft_edge / 位置尺寸旋转；rect/roundRect 还支持 corner_radius。
  - 连接线(connector)：支持 border_color / border_alpha / border_width / border_dash / 位置尺寸旋转；不支持填充、圆角或 shape 效果。
  - 图片形状(picture)：支持 fill_alpha（控制整张图片透明度）/ border_color / border_alpha / border_width / border_dash / corner_radius / shadow / reflection / glow / soft_edge / 位置尺寸旋转；不支持 fill_color（图片颜色由图片本身决定）。
  - 其他类型（表格、图表等）：仅支持位置/尺寸/旋转，不支持 fill/border 或 shape 效果。

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 目标幻灯片页的从 0 开始的索引。
  [ ] border_alpha (integer): 边框透明度，百分比 0-100（0=完全不透明，100=完全透明）。设置 border_color 时若不传则默认 0。不传则保持不变。普通形状和图片形状均支持。
  [ ] border_color (string): 十六进制边框色（如 "000000"）。传 "none" 移除边框。不传则保持不变。普通形状和图片形状均支持。
  [ ] border_dash (string): 边框线型：solid/dot/dash/lgDash/dashDot/lgDashDot/lgDashDotDot/sysDash/sysDot/sysDashDot/sysDashDotDot。不传则保持不变。
  [ ] border_width (number): 边框宽度，单位磅（1pt=12700 EMU）。不传则保持不变。
  [ ] corner_radius (integer): 圆角 adjustment，范围 0-50000。0 取消圆角并恢复直角；正值对应短边的 corner_radius/100000（4376 兼容原 rounded=true 默认值）。不传保持不变。单形状模式作用于 shape_id，多对一模式作用于 shape_ids。仅图片及 rect/roundRect 普通形状支持。
  [ ] fill_alpha (integer): 填充透明度，百分比 0-100（0=完全不透明，100=完全透明）。对普通形状(shape)控制 solidFill 透明度；对图片形状(picture)控制图片整体透明度（alphaModFix）。设置 fill_color 时若不传则默认 0。不传则保持不变。
  [ ] fill_color (string): 十六进制填充色（如 "FF0000"）。传 "none" 设为无填充。单形状模式作用于 shape_id，多对一模式作用于 shape_ids。不传则保持不变。图片形状不支持此属性。
  [ ] glow (object): 形状发光。enabled=false 删除发光；alpha 为透明度。
  [ ] h (number): 新的高度，单位磅。单形状模式作用于 shape_id，多对一模式作用于 shape_ids。不传则保持不变。
  [ ] reflection (object): 形状映像。enabled=false 删除映像；否则写入完整参数。alpha 字段均为透明度。
  [ ] rotation (number): 旋转角度（度）。单形状模式作用于 shape_id，多对一模式作用于 shape_ids。不传则保持不变。
  [ ] shadow (object): 自定义阴影。enabled=false 删除阴影；否则写入一套完整阴影参数。alpha 是透明度（0 不透明，100 全透明）。不能与 shadow_type 同时使用。
  [ ] shadow_type (string): 兼容旧调用的固定阴影：outer/inner/preset。写入固定默认参数（45°右下、3pt 偏移、约 3.15pt 模糊、黑色 40% 不透明度）。preset 在当前前端可能不渲染；新调用应使用 shadow。二者不能同时传。
  [ ] shape_id (string): 单形状模式 (A)：要修改的形状 ID。
  [ ] shape_ids (array<string>): 批量多对一模式 (C)：形状 ID 数组，所有形状统一应用顶层的位置/尺寸/旋转/填充/边框/圆角/阴影属性。与 shape_id、shapes 互斥。
  [ ] shapes (array<object>): 批量一对一模式 (B)：对象数组，每项包含 shape_id 及其独立的位置/尺寸/旋转/填充/边框/圆角及 shape 效果属性。与 shape_id、shape_ids 互斥。
  [ ] soft_edge (object): 柔化边缘。enabled=false 删除效果。
  [ ] w (number): 新的宽度，单位磅。单形状模式作用于 shape_id，多对一模式作用于 shape_ids。不传则保持不变。
  [ ] x (number): 新的 X 坐标，单位磅。单形状模式作用于 shape_id，多对一模式作用于 shape_ids。不传则保持不变。
  [ ] y (number): 新的 Y 坐标，单位磅。单形状模式作用于 shape_id，多对一模式作用于 shape_ids。不传则保持不变。
```

---

## slide_set_slide_size

```plaintext
# slide_set_slide_size

Set the slide size (aspect ratio) of the presentation. Only two presets are supported: 1 (4:3) and 2 (16:9). All shapes across every page (masters, layouts, and slides) will be re-scaled according to the specified scale_mode.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] aspect_ratio (number): Slide aspect ratio: 1 = 4:3, 2 = 16:9.
  [ ] scale_master_layout (boolean): When true AND scale_mode is "default", also scale master/layout page styles and placeholder transforms. Default: false.
  [ ] scale_mode (string): How to handle element scaling: "default" (uniform proportional), "no_scale" (keep sizes, centre), "enlarge" (scale toward enlarging direction). Default: "default".
```

---

## slide_set_text

```plaintext
# slide_set_text

Replace the text content of a shape on a slide (pure content replacement). Length is unconstrained (the new text may differ in UTF-16 length from the existing text). IMPORTANT: this resets per-character styling (bold / italic / color / font / size) to defaults; the shape's overall paragraph alignment (e.g. shape-default centered, textbox-default left) is preserved through OOXML style inheritance. Use slide_set_text_property afterwards to apply per-character styling on a sub-range.

参数（✓=必填）：