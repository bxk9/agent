## sheet_add_pivot_table

```plaintext
# sheet_add_pivot_table

在表格中创建透视表（SHEET）。anchor 指定透视表放置位置（左上角单元格），source_range 指定数据源区域，pivot_table_id 由调用方生成并保持唯一。

参数（✓=必填）：
  [✓] pivot_table_id (string): 透视表唯一ID（必填，由调用方生成）
  [✓] source_sheet_id (string): 数据源所在子表ID（必填）
  [✓] source_range (object): 数据源区域
  [ ] anchor_col (integer): 锚点列索引（0-based），默认0
  [ ] anchor_row (integer): 锚点行索引（0-based），默认0
  [ ] anchor_sheet_id (string): 锚点（透视表左上角）所在子表ID。create_new_sheet=false 时必填；true 时忽略，由引擎新建子表
  [ ] create_new_sheet (boolean): 是否新建子表放置透视表（可选，默认false）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] name (string): 透视表显示名称（可选）
  [ ] new_sheet_id (string): 新建子表的 ID（可选，create_new_sheet=true 时使用）
```

---

## sheet_add_sheet

```plaintext
# sheet_add_sheet

在表格中添加一个新的子表，支持指定子表名称和位置（SHEET）

参数（✓=必填）：
  [✓] name (string): 子表名称，最多31字符
  [ ] append_index (boolean): 是否追加到末尾
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] index (integer): 子表位置索引（0-based）
```

---

## sheet_add_table

```plaintext
# sheet_add_table

将已有单元格区域转换为结构化表格（table）（SHEET）。范围使用 0-based 闭区间，首行作为表头，且必须至少包含一行数据；本工具不会写入主体数据。空白或重复表头会被规范化，范围内的合并单元格会取消合并。table_id 由服务端生成并返回。table 自带筛选与 sheet_set_filter 管理的普通工作表筛选相互独立

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行（0-based，表头行）
  [✓] start_col (integer): 起始列（0-based）
  [✓] end_row (integer): 结束行（0-based，闭区间），必须大于 start_row
  [✓] end_col (integer): 结束列（0-based，闭区间）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] include_filter (boolean): 是否启用该 table 自带的列筛选按钮，默认 true
  [ ] style_name (string): 内置表格样式名（可选，默认 TableStyleMedium2）：TableStyleLight1-21、TableStyleMedium1-28 或 TableStyleDark1-11
```

---

## sheet_audit_formula_consistency

```plaintext
# sheet_audit_formula_consistency

审计某区域内公式结构的一致性：把每个公式归一化为 R1C1（位置无关）后按结构分组，找出与多数派结构不一致的单元格（outliers）以及本应有公式却为空的空档（gaps）。适合定位「同一行/列里被改坏的公式」。请把区域指向公式聚集的一行或一列（SHEET）

参数（✓=必填）：
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] sheet_id (string): 子表 ID，不指定则使用当前活动子表
```

---

## sheet_calculate_formulas

```plaintext
# sheet_calculate_formulas

批量试算表格中的多个公式，单次返回所有结果而不修改文档内容（SHEET）

参数（✓=必填）：
  [✓] formulas (array<object>): 待计算的公式列表，长度 1..1000
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] sheet_id (string): 工具级默认子表 ID；每个 entry 可单独覆盖
```

---

## sheet_calculate_single_formula

```plaintext
# sheet_calculate_single_formula

试算表格中的公式，返回计算结果而不修改文档内容（SHEET）

参数（✓=必填）：
  [✓] formula (string): 公式字符串，如=SUM(A1:A10)
  [ ] anchor_col (integer): 锚点列索引（0-based），影响相对引用，默认0
  [ ] anchor_row (integer): 锚点行索引（0-based），影响相对引用，默认0
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] sheet_id (string): 子表 ID，不指定则使用当前活动子表
```

---

## sheet_clear_border

```plaintext
# sheet_clear_border

清除表格指定区域单元格的边框（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] border_positions (array<integer>): 要清除的边框位置列表（不传则清除全部）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_clear_link

```plaintext
# sheet_clear_link

清除表格指定单元格的超链接（SHEET）。不传 link_id 时清除该单元格所有链接；传入 link_id 时只清除匹配链接。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] row (integer): 单元格行索引（0-based）
  [✓] col (integer): 单元格列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] link_id (string): 链接 ID（可选）；为空则清除该单元格所有链接
```

---

## sheet_clear_range_all

```plaintext
# sheet_clear_range_all

清除表格指定区域内所有单元格的内容和样式，等同于同时执行 sheet_clear_range_cells 和 sheet_clear_range_style（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_clear_range_cells

```plaintext
# sheet_clear_range_cells

清除表格指定区域内所有单元格的内容，包括值、公式、超链接和扩展内容（如图片、复选框等），但不清除样式。如需同时清除样式请使用 sheet_clear_range_all（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_clear_range_style

```plaintext
# sheet_clear_range_style

清除表格指定区域内所有单元格的样式（如字体、颜色、背景色、对齐、数字格式等），但不清除单元格内容。如需同时清除内容请使用 sheet_clear_range_all（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_copy_sheet

```plaintext
# sheet_copy_sheet

复制表格中的子表，生成一个内容相同的副本子表（SHEET）。sheet_id 为待复制的源子表 ID（必填，必须是 worksheet）；new_name 为副本子表名称（可选，最多31字符）；不传或与已有子表重名时，由本工具自动按 "<源名>-副本"/"<源名>-副本2"/... 规则生成不重名的名称。返回新生成的副本子表 ID（sheet_id）。

参数（✓=必填）：
  [✓] sheet_id (string): 待复制的源子表 ID（必填，必须是 worksheet）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] new_name (string): 副本子表名称（可选，最多31字符）
```

---

## sheet_delete_chart

```plaintext
# sheet_delete_chart

删除表格中指定的图表（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] drawing_id (string): 图表标识ID
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_delete_dimension

```plaintext
# sheet_delete_dimension

删除表格指定位置的行或列（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] dimension_type (string): 行列类型: row | col
  [✓] index (integer): 起始索引（0-based）
  [✓] count (integer): 删除数量
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_delete_range

```plaintext
# sheet_delete_range

在表格指定区域删除单元格，通过删除行或列实现后续单元格的左移或上移。dimension_type=col 时按列删除，将选中区域右侧单元格左移以填补；dimension_type=row 时按行删除，将选中区域下方单元格上移以填补（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 插入位置的行索引（0-based）
  [✓] start_col (integer): 插入位置的列索引（0-based）
  [✓] end_row (integer): 结束行索引
  [✓] end_col (integer): 结束列索引
  [✓] dimension_type (string): 移动方式,col表示按列删除（选中区域左移）, row表示按行删除（下方单元格上移）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_delete_sheet

```plaintext
# sheet_delete_sheet

删除表格中指定的子表（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_get_cell_data

```plaintext
# sheet_get_cell_data

获取表格指定区域的单元格数据，支持返回CSV格式或结构化单元格数据（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)