  [ ] chart_type (string): 图表类型名称（驼峰式字符串）或整数枚举值，不传则保持原类型。以下类型暂不支持，会直接返回错误：regionMap(24), wireframeSurface(56), stackedAreaAndClusteredColumnCombo(62), clusteredBar3D(12), surface(16), surface3D(17), boxWhisker(20), column3D(21), funnel(22), sunburst(25), treemap(26), paretoLine(23), waterfall(27), stackedBar3D(31), percentStackedBar3D(32), stackedColumn3D(35), percentStackedColumn3D(36), stackedArea3D(44), percentStackedArea3D(45), bubble3D(52), wireframeSurface3D(57), histogram(47)。可识别的字符串名称：area(1), area3D(2), line(3), line3D(4), highLowCloseStock(5), radar(6), scatter(7), pie(8), pie3D(9), doughnut(10), clusteredBar(11), clusteredBar3D(12), clusteredColumn(13), clusteredColumn3D(14), pieOfPie(15), surface(16), surface3D(17), bubble(18), customCombo(19), boxWhisker(20), column3D(21), funnel(22), paretoLine(23), regionMap(24), sunburst(25), treemap(26), waterfall(27), wordCloud(28), stackedBar(29), percentStackedBar(30), stackedBar3D(31), percentStackedBar3D(32), stackedColumn(33), percentStackedColumn(34), stackedColumn3D(35), percentStackedColumn3D(36), stackedLine(37), percentStackedLine(38), markerLine(39), stackedMarkerLine(40), percentStackedMarkerLine(41), stackedArea(42), percentStackedArea(43), stackedArea3D(44), percentStackedArea3D(45), barOfPie(46), histogram(47), smoothLineAndMarkerScatter(48), smoothLineScatter(49), straightLineAndMarkerScatter(50), straightLineScatter(51), bubble3D(52), openHighLowCloseStock(53), volumeHighLowCloseStock(54), volumeOpenHighLowCloseStock(55), wireframeSurface(56), wireframeSurface3D(57), markerRadar(58), filledRadar(59), clusteredColumnAndLineCombo(60), clusteredColumnAndLineOnSecondaryAxisCombo(61), stackedAreaAndClusteredColumnCombo(62)
  [ ] data_range (object): 图表数据源区域；不传则保持原数据源。注意：参与图表数值系列的数据单元格应尽量是数值类型；如果来源数据是纯字符串（即使内容看起来像数字），可能无法被识别为数值，从而影响图表系列、坐标轴刻度、数据标签等数据表达。只要该区域会参与图表数据部分，调用前都应确认单元格值类型。data_range 不能包含隐藏行或隐藏列；隐藏行列中的数据可能不会被图表读取，导致系列、分类或图表数据缺失。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] first_column_as_category (boolean): 第一列是否作为分类轴
  [ ] first_row_as_header (boolean): 第一行是否作为表头
  [ ] location (object): 图表在子表中的位置和尺寸；未传字段保持原值
  [ ] options (object): 图表样式选项，采用 patch 语义：仅更新传入的字段，未传字段保持原值。
      注意：get_charts 返回的 options 中只包含图表实际设置过的字段，未设置的字段不会出现。
      因此不要把 get_charts 的返回值原样回写——只传你想修改的字段即可。
      
      完整可用字段列表：
      
      ■ chartSpace（整张图表背景/边框/圆角）：
        - fill (string): 背景色，hex 如 "#FF0000" 或 "FF0000"，空串=透明
        - border (object): {color: hex 边框色, width: number 磅数}
        - roundedCorners (bool): 是否圆角
        - style (int): OOXML 内置配色样式编号 1~48
      
      ■ plotArea（绘图区背景/边框，与 chartSpace 不交叉）：
        - fill (string): 绘图区背景色，hex
        - border (object): {color: hex, width: number 磅数}
      
      ■ title（图表标题）：
        - visible (bool): 是否显示标题
        - text (string): 标题文本
        - overlay (bool): 标题是否覆盖绘图区
        - textStyle (object): {bold, italic, fontSize, fontFamily, color}
      
      ■ legend（图例）：
        - visible (bool): 是否显示图例
        - position (string): BOTTOM/TOP/LEFT/RIGHT/TOP_RIGHT
        - overlay (bool): 图例是否覆盖绘图区
        - textStyle (object): {bold, italic, fontSize, fontFamily, color}
      
      ■ xAxis（X轴/分类轴）：
        - visible (bool): 是否显示轴
        - labelPosition (string): NEXT_TO/HIGH/LOW/NONE
        - majorTickMark (string): NONE/CROSS/INSIDE/OUTSIDE
        - minorTickMark (string): NONE/CROSS/INSIDE/OUTSIDE
        - numberFormat (string): 轴标签数字格式代码
        - gridlines (bool): 是否显示主网格线
        - minorGridlines (bool): 是否显示次网格线
        - textStyle (object): 轴标签字体 {bold, italic, fontSize, fontFamily, color}
        - title (object): 轴标题 {text, textStyle}
      
      ■ yAxis（Y轴/主纵轴，含 scale）：
        - visible (bool): 是否显示轴
        - labelPosition (string): NEXT_TO/HIGH/LOW/NONE
        - majorTickMark (string): NONE/CROSS/INSIDE/OUTSIDE
        - minorTickMark (string): NONE/CROSS/INSIDE/OUTSIDE
        - numberFormat (string): 轴标签数字格式代码，如 General/#,##0/0%
        - gridlines (bool): 是否显示主网格线
        - minorGridlines (bool): 是否显示次网格线
        - scale (object): {min: number 最小值, max: number 最大值, orientation: MIN_MAX/MAX_MIN}
        - majorUnit (number): 主刻度间隔
        - minorUnit (number): 次刻度间隔
        - textStyle (object): 轴标签字体
        - title (object): 轴标题 {text, textStyle}
      
      ■ secondaryYAxis（次纵轴，字段同 yAxis）：
        仅组合图存在次坐标轴时有效，字段与 yAxis 完全相同。
      
      ■ dataLabel（plot/subChart 级数据标签默认配置）：
        对没有独立 dataLabel 的系列生效；已有 series[i].dataLabel 优先。
        若要执行与前端“显示/隐藏全部数据标签”等价的操作，应同时设置本字段和每个 series[i].dataLabel，避免已有系列级配置遮蔽外层默认值。
        可用字段与 series[i].dataLabel 相同。
      
      ■ series（数据系列样式数组，按位置对应各系列）：
        每项可包含：
        - type (string): 系列子图类型，仅组合图生效。可选：COLUMN/STACKED_COLUMN/LINE/MARKER_LINE/AREA/STACKED_AREA
        - axis (string): 系列绑定纵轴，仅组合图。可选：PRIMARY/SECONDARY
        - color (string): 系列颜色，hex 如 #FF0000
        - dataLabel (object): 数据标签设置
            - visible (bool): 是否显示
            - showValue (bool): 显示数值
            - showPercentage (bool): 显示百分比
            - showCategoryName (bool): 显示分类名
            - showSeriesName (bool): 显示系列名
            - position (string): BEST_FIT/CENTER/INSIDE_BASE/INSIDE_END/OUTSIDE_END/ABOVE/BELOW/LEFT/RIGHT
            - numberFormat (string): 数值格式化代码
            - textStyle (object): {bold, italic, fontSize, fontFamily, color}
        - trendlines (array): 趋势线数组，每项：
            - type (string): linear/log/poly/power/exp/movingAvg
            - name (string): 趋势线名称
            - order (int): 多项式阶数（type=poly 时）
            - period (int): 移动平均周期（type=movingAvg 时）
            - forward/backward (number): 前推/后推周期数
            - intercept (number): 截距
            - dispEq (bool): 显示公式
            - dispRSqr (bool): 显示 R²
            - lineColor (string): 趋势线颜色 hex
            - lineWidth (number): 趋势线宽度（磅）
        - dataPoints (array): 数据点颜色数组（仅饼图/环形图有效）；饼图/环形图都是 single-series family，图表只使用 series[0]，请统一把扇区颜色写在 series[0].dataPoints。每项：
            - index (int): 数据点索引（0-based，对应扇区顺序）
            - color (string): 数据点颜色，hex 如 #FF0000
  [ ] title (string): 图表标题
  [ ] use_column_as_series (boolean): 是否以列作为数据系列
```

---

## sheet_update_conditional_format

```plaintext
# sheet_update_conditional_format

按 cf_id 更新一条已存在的条件格式规则（SHEET）。cf_id 必填（由 add_conditional_format 返回）。ranges 为新作用区域（替换语义），rule 为新规则。支持的规则类型、参数与样式要求与 sheet_add_conditional_format 一致。

参数（✓=必填）：
  [✓] sheet_id (string): 默认子表 ID（ranges 字符串中未带 "SheetID$" 前缀时使用）
  [✓] cf_id (string): 条件格式 ID（必填）
  [✓] ranges (array<string>): 作用区域，每项形如 "BB08J2$A1:B100" 或 "A1:B100"（省略 SheetID 时使用顶层 sheet_id）
  [✓] rule (object): 条件格式规则定义（rule 大类 + 各类型独有参数 + 命中样式）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_update_filter

```plaintext
# sheet_update_filter

更新表格已有筛选的范围和/或列筛选项。is_update_range=true 时使用 start_row/start_col/end_row/end_col 作为新的筛选范围（此时 4 个字段必填），否则忽略这 4 个字段、保留原有筛选范围。columns 中每个元素描述一列的筛选项，col 为列索引（0-based，相对整个子表），visible_values 为该列保留可见的值列表（不在该列表内的值会被隐藏，传空列表代表隐藏该列全部值）；columns 为空时不修改原列筛选项。当前列筛选项仅支持值筛选（FILTER_CRITERIA_VALUE）（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [ ] columns (array<object>): 列筛选项列表，每个元素描述一列的值筛选条件；为空时不修改原列筛选项。当前仅支持值筛选（FILTER_CRITERIA_VALUE）
  [ ] end_col (integer): 新的数据区域结束列，仅当 is_update_range=true 时生效
  [ ] end_row (integer): 新的数据区域结束行，仅当 is_update_range=true 时生效
  [ ] file_id (string): The file_id of the editor to operate on