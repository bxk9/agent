为在线表格指定范围或整列设置数据验证规则（SHEET）。入参与 sheetengine mcp.proto SetDataValidationReq 完全对齐。type（大小写不敏感）支持：LIST（下拉单选）/ WHOLE（整数区间校验）/ DECIMAL（小数区间校验）/ DATE（日期区间校验）/ TIME（时间区间校验）/ TEXT_LENGTH（文本长度区间校验）/ NONE（清除已设置的数据验证）。范围模式与列模式二选一，同时传时优先列模式（与底层 Builder 语义一致）。op（小写蛇形，大小写不敏感）仅 type ∈ {WHOLE, DECIMAL, DATE, TIME, TEXT_LENGTH} 时必填：between / not_between / equal / not_equal / greater_than / less_than / greater_than_or_equal / less_than_or_equal。formula1 / formula2 为字面量：WHOLE 传整数字符串（"60"）；DECIMAL 传小数字符串；TEXT_LENGTH 传非负整数字符串；DATE 传 yyyy-MM-dd / yyyy/MM/dd / yyyy年MM月dd日（严格 >= 1900-03-01），服务端自动转成 Excel 日期序列号并为目标单元格设置 "yyyy/m/d;@" 数字格式；TIME 传 HH:MM 或 HH:MM:SS（24h 制），服务端自动转成一天的分数（如 18:00 → 0.75）并为目标单元格设置 "h:mm:ss;@" 数字格式。select_options 仅 LIST 时生效，text_color / bg_color 为 "#RRGGBB" 6 位十六进制颜色。ignore_rows 仅列模式生效（用于跳过表头）。type=NONE 时忽略 op / formula* / select_options，只需给出 ranges 或 col_indexes 即可清除。本工具不做权限校验（editor-sdk 本地编辑上下文）。

参数（✓=必填）：
  [✓] type (string): LIST | WHOLE | DECIMAL | DATE | TIME | TEXT_LENGTH | NONE（大小写不敏感）
  [ ] col_indexes (array<object>): 列模式：数据验证写到列属性上，新写入的行自动继承。与 ranges 二选一，同时传时优先 col_indexes。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] formula1 (string): 第一个界值字面量，仅需要 formula 的 type 必填；DATE: yyyy-MM-dd / yyyy/MM/dd / yyyy年MM月dd日（>=1900-03-01）；TIME: HH:MM 或 HH:MM:SS（24h 制）；WHOLE/DECIMAL/TEXT_LENGTH: 数字字符串
  [ ] formula2 (string): 第二个界值字面量，仅 op=between / not_between 时必填；格式规则同 formula1
  [ ] ignore_rows (integer): 列模式下忽略前 N 行（一般跳过表头）；范围模式忽略
  [ ] op (string): between / not_between / equal / not_equal / greater_than / less_than / greater_than_or_equal / less_than_or_equal（大小写不敏感），仅 type ∈ {WHOLE, DECIMAL, DATE, TIME, TEXT_LENGTH} 时必填
  [ ] ranges (array<string>): 范围模式：要设置数据验证的单元格区域，每项形如 "BB08J2$A1:B100" 或 "A1:B100"（省略 SheetID 时使用顶层 sheet_id）。与 col_indexes 二选一，同时传时优先 col_indexes。
  [ ] select_options (array<object>): 下拉选项配置，仅 type=LIST 时生效
  [ ] sheet_id (string): 默认子表 ID（ranges 字符串中未带 "SheetID$" 前缀时使用）
```

---

## sheet_set_dimension_size

```plaintext
# sheet_set_dimension_size

批量设置表格指定行的行高或指定列的列宽（SHEET）。每一项表示一个连续的行/列区间（闭区间）设置为同一尺寸；同一次调用可包含多段，并可混合行与列。如需只改单行/单列，请传 start_index == end_index。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] dimensions (array<object>):
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_set_dimension_visible

```plaintext
# sheet_set_dimension_visible

批量设置表格指定行或列的可见状态（SHEET）。每一项表示一个连续的行/列区间（闭区间，包含结束索引）；visible=false 表示隐藏，visible=true 表示显示。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] dimensions (array<object>):
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_set_filter

```plaintext
# sheet_set_filter

为子表的指定数据区域设置普通工作表筛选（SHEET），无需传入筛选 ID

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 数据区域起始行（0-based）
  [✓] start_col (integer): 数据区域起始列（0-based）
  [✓] end_row (integer): 数据区域结束行
  [✓] end_col (integer): 数据区域结束列
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] header_end_row (integer): 表头区域结束行
  [ ] header_start_row (integer): 表头区域起始行（0-based）
```

---

## sheet_set_freeze

```plaintext
# sheet_set_freeze

设置表格的冻结行列数，传0可取消冻结（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] row_count (integer): 冻结行数（0 = 取消冻结行）
  [✓] col_count (integer): 冻结列数（0 = 取消冻结列）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_set_link

```plaintext
# sheet_set_link

为表格指定单个单元格设置超链接（SHEET）。display_text 可选；不传/传空时会沿用该单元格当前可见文本作为链接显示文本。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] row (integer): 单元格行（0-based）
  [✓] col (integer): 单元格列（0-based）
  [✓] url (string): 超链接 URL
  [ ] display_text (string): 链接显示文本（可选）；为空时沿用单元格当前可见文本。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_set_range_value

```plaintext
# sheet_set_range_value

批量设置表格多个单元格的值（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] values (array<object>): 单元格值列表
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_set_range_value_by_csv

```plaintext
# sheet_set_range_value_by_csv

以CSV格式批量插入数据到表格（SHEET）。CSV 必须是规整二维表：每一行列数一致；空单元格请用连续逗号显式表示；总单元格不超过 20000。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 左上角起始行索引（0-based）
  [✓] start_col (integer): 左上角起始列索引（0-based）
  [✓] csv_data (string): CSV格式数据内容；必须每行列数一致，空单元格用连续逗号表示；总单元格不超过 20000，单元格文本不超过 32KB。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_set_sheet_visible

```plaintext
# sheet_set_sheet_visible

设置表格中指定子表的可见状态（SHEET）。visible=false 表示隐藏子表，visible=true 表示显示子表。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] visible (boolean): 是否显示子表
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_sort_range

```plaintext
# sheet_sort_range

对表格指定区域按列排序，支持多列排序（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [✓] columns (array<object>): 排序列列表
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] has_header (boolean): 是否含表头
  [ ] table_id (string): 结构化表格（table）ID（可选）
```

---

## sheet_unmerge_cell

```plaintext
# sheet_unmerge_cell

取消表格指定区域的单元格合并（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_unset_freeze

```plaintext
# sheet_unset_freeze

删除表格指定子表的所有冻结行列（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_update_chart

```plaintext
# sheet_update_chart

更新表格中指定图表的类型、位置、尺寸、数据区域和标题（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] drawing_id (string): 图表标识ID