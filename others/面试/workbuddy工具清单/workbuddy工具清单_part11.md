  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] include_formula (boolean): true时正常返回计算值的同时，为函数单元格附带 formula 字段（值+公式一次返回）
  [ ] return_csv (boolean): true返回csv_data，false返回cells结构化数据
  [ ] return_formula (boolean): true时只获取函数公式内容（不含计算值），非函数单元格不返回
```

---

## sheet_get_cell_style

```plaintext
# sheet_get_cell_style

获取表格指定区域单元格的样式信息，包括背景色（background_color）、字体颜色（font_color）、字号（font_size）、字体（font_family）和数字格式（number_format）。返回每个单元格的位置和样式字段，未设置该样式时对应字段为空（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_get_charts

```plaintext
# sheet_get_charts

获取表格指定子表下的所有图表信息（SHEET）。每个元素含 drawing_id/sheet_id/chart_type/title；可选 data_range（数据源区域，形如 "SheetID$A1:B2"）、options（仅含实际设置过的样式，勿原样回写）、location（位置/尺寸，单位同 add/update_chart 入参）。
location 子字段：row_index/col_index 为锚定单元格行列（0-based），horizontal_offset/vertical_offset 为格内偏移（像素），width/height 为宽高（像素）。width/height 仅 one_cell_anchor 图表返回；two_cell_anchor 不返回，此时只有位置可信。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_get_conditional_format

```plaintext
# sheet_get_conditional_format

获取在线表格上指定子表的条件格式列表（SHEET）。支持两种过滤方式：①只传 sheet_id 返回该子表上全部条件格式；②同时传 ranges，则只返回与 ranges 中任一条相交的条件格式（多 ranges 取并集去重）。一期返回 cf_id + priority + ranges（priority=0 表示最高优先级，序号越小优先级越高）。

参数（✓=必填）：
  [✓] sheet_id (string): 默认子表 ID（ranges 字符串中未带 "SheetID$" 前缀时使用）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] ranges (array<string>): 作用区域，每项形如 "BB08J2$A1:B100" 或 "A1:B100"（省略 SheetID 时使用顶层 sheet_id）
```

---

## sheet_get_dimension_size

```plaintext
# sheet_get_dimension_size

读取表格指定行的行高或指定列的列宽（SHEET），返回单位为像素。未显式设置时会按当前子表的默认值兜底（行高默认 20px，列宽默认约 64px，与 Apps Script 行为一致）。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] dimension_type (string): 行列类型: row | col
  [✓] index (integer): 行/列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_get_merged_cells

```plaintext
# sheet_get_merged_cells

获取表格指定区域内与该区域相交的合并单元格信息（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_get_object_list

```plaintext
# sheet_get_object_list

获取表格指定子表上的对象列表，包括图表(chart)、透视表(pivot_table)、结构化表格(table)、浮动图片(float_image)。支持按对象类型、显示区域、名称模糊匹配过滤。返回每个对象的 ID、类型、名称、显示区域、数据来源区域以及类型相关的简要信息（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [ ] end_col (integer): 过滤区域结束列
  [ ] end_row (integer): 过滤区域结束行
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] filter_by_range (boolean): 为true表示根据过滤区域过滤，仅返回与该区域有交集的对象，不传则默认为false，不根据区域过滤
  [ ] name_pattern (string): 对象名称模糊匹配模式，留空表示不按名称过滤
  [ ] object_types (array<string>): 对象类型过滤列表，仅返回过滤列表类型的对象，留空表示返回所有类型。支持的字符串值: chart(图表), pivot_table(透视表), table(结构化表格), float_image(浮动图片)
  [ ] start_col (integer): 过滤区域起始列（0-based）
  [ ] start_row (integer): 过滤区域起始行（0-based）
```

---

## sheet_get_pivot_table_detail

```plaintext
# sheet_get_pivot_table_detail

读取指定透视表的详细配置（数据源、行/列/值/筛选、锚点位置、ID 等），用于展示或回显，不会修改文档。pivot_table_id 与 pivot_table_name 至少传一个，id 优先。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] pivot_table_id (string): 目标透视表ID（与 pivot_table_name 二选一，id 优先）
  [ ] pivot_table_name (string): 目标透视表显示名称（与 pivot_table_id 二选一）
```

---

## sheet_get_selection

```plaintext
# sheet_get_selection

Get the current client-side selection snapshot from the sheet editor, including the active sheet_id, the list of selected cell ranges, and the list of selected drawing ids (charts / float images / sparkline groups).

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_get_sheet_info

```plaintext
# sheet_get_sheet_info

获取表格的子表信息，包括子表ID、名称、类型、行列数量（SHEET）

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_get_used_range

```plaintext
# sheet_get_used_range

获取指定子表的已使用区域（SHEET）。返回 0-based、闭区间的行列边界及 A1 表示；已使用区域包含单元格内容/公式、样式、数据验证、条件格式结果和透视表数据等。该范围是引擎维护的包围范围，清空边界单元格后可能保留历史边界。空白子表返回 is_empty=true、used_range=null。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_insert_dimension

```plaintext
# sheet_insert_dimension

在表格指定位置插入行或列（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] dimension_type (string): 行列类型: row | col
  [✓] index (integer): 实际插入起始索引（0-based）；在索引 N 的行/列之后插入时传 N+1
  [✓] count (integer): 插入数量
  [ ] direction (string): 插入方向及属性继承侧：before（默认）继承原 index 处行/列，after 继承原 index-1 处行/列；index 始终表示实际插入位置
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_insert_image

```plaintext
# sheet_insert_image

在表格指定单元格插入一张图片（SHEET）。image 字段支持两种形式：
  1. data URI（data:image/<mime>;base64,<payload>），引擎会落盘到编辑器的 image_dir 并生成内部 URL；
  2. 本地绝对路径（可选 file:// 前缀），会被拷贝到 image_dir。
注意：远程 URL（http / https）不被支持——导出时引擎不会去拉取远程图片，图片会静默丢失。
content / image_id 为兼容旧调用方的别名，效果等同于 image。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] row_index (integer): 行索引（0-based）
  [✓] col_index (integer): 列索引（0-based）
  [ ] content (string): （兼容）图片 data URI，等价于 image 字段
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] height (integer): 图片高度（像素，可选，默认 0）
  [ ] image (string): 图片来源：data URI 或本地绝对路径（可选 file:// 前缀）
  [ ] image_id (string): （兼容）图片本地绝对路径，等价于 image 字段
  [ ] width (integer): 图片宽度（像素，可选，默认 0）
```

---

## sheet_insert_range

```plaintext
# sheet_insert_range

在表格指定区域插入空白单元格，通过插入行或列实现选中区域的右移或下移。dimension_type=col 时按列插入，将选中区域及其右侧单元格右移；dimension_type=row 时按行插入，将选中区域及其下方单元格下移（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 插入位置的行索引（0-based）
  [✓] start_col (integer): 插入位置的列索引（0-based）
  [✓] end_row (integer): 结束行索引
  [✓] end_col (integer): 结束列索引
  [✓] dimension_type (string): 移动方式,col表示按列插入（选中区域右移）, row表示按行插入（选中区域下移）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_list_recent_ai_edits

```plaintext
# sheet_list_recent_ai_edits

列出当前 editor 实例最近通过 MCP 写工具产生的编辑（SHEET），返回每条记录的 version + tool_name + time（按时间倒序，最新在前）。

【典型用法】
当用户要求“撤销刚才的某次操作”时：
  1. 调用本工具（limit 默认 10），拿到最近若干次 AI 编辑；