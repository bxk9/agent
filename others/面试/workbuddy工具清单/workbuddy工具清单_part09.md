  [ ] color (string): 文字颜色，6 位 / 8 位 hex，如 "FF0000" 或 "#FF0000"
  [ ] double_strike (boolean): 是否双删除线（Word w:dstrike），与 strikethrough 单删除线相互独立。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] font_family (string): 字体名，如 'Arial'、'宋体'、'Microsoft YaHei'；会同时应用到中、西文字体
  [ ] font_size (number): 字号，单位「磅(pt)」，例如 12 表示 12pt；Word 中常见取值 9~72
  [ ] highlight (string): 高亮文本颜色（与底纹不同），如 "yellow"；传入 "none" 可清除已有高亮。
  [ ] italic (boolean): 是否斜体
  [ ] small_caps (boolean): 是否小型大写（仅西文有效）
  [ ] strikethrough (boolean): 是否删除线
  [ ] underline (): 下划线。兼容旧写法 true=single、false=none；精细写法如 {"style":"double","color":"#FF0000"}。
  [ ] vertical_align (string): 上下标：superscript=上标 / subscript=下标 / baseline=正常基线（用于显式取消已有上下标）。不传该字段则保持原有上下标不变。
```

---

## find

```plaintext
# find

在表格中搜索指定文本，返回匹配的单元格位置。支持大小写敏感、整单元格匹配、正则表达式、搜索公式等选项。（SHEET）

参数（✓=必填）：
  [✓] search_term (string): 要搜索的文本
  [ ] end_col (integer): 结束列索引（0-based，不传表示到最后一列）
  [ ] end_row (integer): 结束行索引（0-based，不传表示到最后一行）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] match_case (boolean): 大小写敏感（默认: false）
  [ ] match_entire_cell (boolean): 整单元格匹配（默认: false）
  [ ] match_formulas (boolean): 搜索公式内容（默认: false）
  [ ] max_results (integer): 每页最大结果数（默认: 50）
  [ ] offset (integer): 分页偏移量（默认: 0）
  [ ] sheet_name (string): 限定搜索的子表名称，不指定则全表搜索
  [ ] start_col (integer): 起始列索引（0-based，不传表示从0开始）
  [ ] start_row (integer): 起始行索引（0-based，不传表示从0开始）
  [ ] use_regex (boolean): 将搜索文本作为正则表达式（默认: false）
```

---

## get_pool_status

```plaintext
# get_pool_status

Get the current status of the editor pool. Returns information about all open editors including file_id, file_path, editor type (doc/sheet/slide), and whether they have unsaved changes. Optionally pass `file_path` to look up a single editor by its registered local path (e.g. when the agent has the path but no longer remembers the file_id chosen at /localapi/open).

参数（✓=必填）：
  [ ] file_path (string): Optional. If set, only return the entry for the editor whose registered file_path equals this value. Returns an error if no such editor is open.
```

---

## open_file

```plaintext
# open_file

Open a file (sheet/doc/slide) by chunk-based streaming. Chunk data and open result are pushed to the SSE /stream endpoint for the same file_id. By default this performs a normal fresh open. Set open_with_existing=true only when the same file_path is already open and the caller wants doc/slide to reuse the existing in-memory model.

参数（✓=必填）：
  [✓] file_path (string): Local file path to open
  [ ] file_type (string): Editor type: sheet, doc, or slide. Auto-detected from file extension if omitted.
  [ ] image_dir (string): Directory for extracted images (optional)
  [ ] open_with_existing (boolean): Optional. When true, doc/slide may reuse an already-open editor for the same file_path via OpenWith; when omitted or false, open_file uses the normal fresh open path.
  [ ] password (string): File password (optional)
```

---

## save_file

```plaintext
# save_file

Save the current sheet/doc/slide to a local file (e.g. .xlsx / .docx / .pptx). If file_path is omitted, the file is saved back to its original path (file_id).

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to save
  [ ] file_path (string): Destination file path (optional, defaults to the opened file path)
```

---

## sheet_add_chart

```plaintext
# sheet_add_chart

在表格中添加图表（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] chart_type (string): 图表类型名称（驼峰式字符串）或整数枚举值。以下类型暂不支持，会直接返回错误：regionMap(24), wireframeSurface(56), stackedAreaAndClusteredColumnCombo(62), clusteredBar3D(12), surface(16), surface3D(17), boxWhisker(20), column3D(21), funnel(22), sunburst(25), treemap(26), paretoLine(23), waterfall(27), stackedBar3D(31), percentStackedBar3D(32), stackedColumn3D(35), percentStackedColumn3D(36), stackedArea3D(44), percentStackedArea3D(45), bubble3D(52), wireframeSurface3D(57), histogram(47)。可识别的字符串名称：area(1), area3D(2), line(3), line3D(4), highLowCloseStock(5), radar(6), scatter(7), pie(8), pie3D(9), doughnut(10), clusteredBar(11), clusteredBar3D(12), clusteredColumn(13), clusteredColumn3D(14), pieOfPie(15), surface(16), surface3D(17), bubble(18), customCombo(19), boxWhisker(20), column3D(21), funnel(22), paretoLine(23), regionMap(24), sunburst(25), treemap(26), waterfall(27), wordCloud(28), stackedBar(29), percentStackedBar(30), stackedBar3D(31), percentStackedBar3D(32), stackedColumn(33), percentStackedColumn(34), stackedColumn3D(35), percentStackedColumn3D(36), stackedLine(37), percentStackedLine(38), markerLine(39), stackedMarkerLine(40), percentStackedMarkerLine(41), stackedArea(42), percentStackedArea(43), stackedArea3D(44), percentStackedArea3D(45), barOfPie(46), histogram(47), smoothLineAndMarkerScatter(48), smoothLineScatter(49), straightLineAndMarkerScatter(50), straightLineScatter(51), bubble3D(52), openHighLowCloseStock(53), volumeHighLowCloseStock(54), volumeOpenHighLowCloseStock(55), wireframeSurface(56), wireframeSurface3D(57), markerRadar(58), filledRadar(59), clusteredColumnAndLineCombo(60), clusteredColumnAndLineOnSecondaryAxisCombo(61), stackedAreaAndClusteredColumnCombo(62)
  [✓] data_range (object): 图表数据源区域。注意：参与图表数值系列的数据单元格应尽量是数值类型；如果来源数据是纯字符串（即使内容看起来像数字），可能无法被识别为数值，从而影响图表系列、坐标轴刻度、数据标签等数据表达。只要该区域会参与图表数据部分，调用前都应确认单元格值类型。data_range 不能包含隐藏行或隐藏列；隐藏行列中的数据可能不会被图表读取，导致系列、分类或图表数据缺失。尽量不要把无关数据放进 data_range，避免生成不必要的系列、分类或坐标轴表达。
  [✓] drawing_id (string): 图表标识ID（必填）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] first_column_as_category (boolean): 第一列是否作为分类轴
  [ ] first_row_as_header (boolean): 第一行是否作为表头
  [ ] location (object): 图表在子表中的位置和尺寸
  [ ] options (object): 完整 ChartOptions，将真实写入图表模型并可由 sheet_get_charts 反解返回。常用子对象：
        - chartSpace：整张图表背景 / 边框 / 圆角。可用 key：
            fill (string, hex 如 "#FF0000" 或 "FF0000")：整张图表背景色
            border ({color: hex, width: 磅数})：图表外边框
            roundedCorners (bool)：是否圆角
            style (int 1～48)：OOXML 内置配色样式编号
        - plotArea：仅绘图区背景 / 边框（与 chartSpace 不交叉）。可用 key：
            fill (string, hex)：绘图区背景色
            border ({color, width})
        - dataLabel：所有系列共享的 plot 级默认数据标签；series[i].dataLabel 可覆盖。创建时 visible 只允许 true；不需要数据标签时省略 dataLabel。
        - title / legend / xAxis / yAxis / secondaryYAxis / series：与现有字段语义一致。
  [ ] title (string): 图表标题
  [ ] use_column_as_series (boolean): 是否以列作为数据系列
```

---

## sheet_add_conditional_format

```plaintext
# sheet_add_conditional_format

在在线表格指定区域添加条件格式规则（SHEET）。当前版本支持五种规则类型：CELL_IS（单元格值比较）、UNIQUE_VALUES（唯一值）、DUPLICATE_VALUES（重复值）、TOP10（TopK）、ABOVE_AVERAGE（高于/低于平均值）。其它规则类型（CONTAINS_TEXT / NOT_CONTAINS_TEXT / BEGINS_WITH / ENDS_WITH / CONTAINS_BLANKS / NOT_CONTAINS_BLANKS / CONTAINS_ERRORS / NOT_CONTAINS_ERRORS / TIME_PERIOD / EXPRESSION / DATA_BAR / COLOR_SCALE / ICON_SET）暂不开放。CELL_IS 参数：operator 取值 GT/LT/GTE/LTE/EQ/NEQ/BETWEEN/NOT_BETWEEN（大小写不敏感）；formulas 除 BETWEEN/NOT_BETWEEN 外均为 1 个元素，可传字面量（"100"）或公式（"=A1*0.8"）。TOP10 参数：rule.top10.rank（1-1000 整数，必填）、bottom（true=取后 K，默认 false）、percent（true=按百分比，默认 false）。ABOVE_AVERAGE 参数：rule.above_average.above_average（true=高于平均值，默认 true）、equal_average（true=包含等于，默认 false；std_dev>0 时本字段被忽略）、std_dev（标准差倍数 0-3 整数，0=不启用，默认 0）。UNIQUE_VALUES / DUPLICATE_VALUES 无独立参数，只需填 rule.type + rule.style。命中后的样式通过 rule.style 设置：font_color / bg_color （"#RRGGBB" 格式）/ bold / italic / underline / strikethrough 至少一项非默认。ranges 形如 "BB08J2$A1:B100" 或 "A1:B100"，省略 SheetID 时使用顶层 sheet_id。cf_id 由后端自动生成并在 Rsp 中返回，后续 update / remove 必传。

参数（✓=必填）：
  [✓] sheet_id (string): 默认子表 ID（ranges 字符串中未带 "SheetID$" 前缀时使用）
  [✓] ranges (array<string>): 作用区域，每项形如 "BB08J2$A1:B100" 或 "A1:B100"（省略 SheetID 时使用顶层 sheet_id）
  [✓] rule (object): 条件格式规则定义（rule 大类 + 各类型独有参数 + 命中样式）
  [ ] file_id (string): The file_id of the editor to operate on
```

---
