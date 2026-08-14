  2. 在返回列表里按 tool_name 与用户描述匹配（sheet_set_cell_value=写单元格 / sheet_merge_cell=合并 ...），定位 target_version；
  3. 调用 sheet_revert_revision(target_version=匹配到的 version) 完成回退。

【限制 / 注意】
  - 仅记录通过 MCP 写工具产生的编辑，前端 / 程序化 CommitRevision 等其他写不在内；
  - 记录在 SDK 实例存活期间累积，不需要任何前置注册（写时无感）；
  - 重新打开同一文件 (SheetEditor 实例重建) 后，旧记录会被清空；
  - 单文档最多保留最近 200 条，超出会自动淘汰最早的；
  - record_dir (可选): 提供后 SDK 把累积记录持久化到 `<record_dir>/<sanitize(file_id)>.jsonl`，之后写入会同步 mirror。不传则只读内存、不落盘。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] limit (integer): 返回条数，缺省 10，上限 50。
  [ ] record_dir (string): 可选；指定后 SDK 把累积记录持久化到该目录下的 jsonl 文件 (`<record_dir>/<sanitize(file_id)>.jsonl`)，并将后续写入同步 mirror。目录不存在时会被创建。不传则只读内存、不落盘。
  [ ] tool_name (string): 可选；按工具名精确过滤（例如 "sheet_set_cell_value" 只看写单元格记录）。
```

---

## sheet_merge_cell

```plaintext
# sheet_merge_cell

合并表格指定范围的单元格，支持全部合并、按行合并、按列合并（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] merge_type (string): 合并类型: all（默认）、columns、rows
```

---

## sheet_move_dimension

```plaintext
# sheet_move_dimension

在表格中移动一段连续的行或列到新的位置（SHEET）。index 表示要移动的起始行/列索引（0-based），count 表示要移动的行/列数量，to 表示移动到的目标位置索引（0-based，相对原表，移动语义与 Apps Script moveRows/moveColumns 一致）。

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] dimension_type (string): 行列类型: row | col
  [✓] index (integer): 待移动的起始索引（0-based）
  [✓] count (integer): 待移动的行/列数量
  [✓] to (integer): 目标位置索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_move_sheet

```plaintext
# sheet_move_sheet

移动表格中子表的顺序，按源位置和目标位置（均为0-based索引）调整子表排列（SHEET）

参数（✓=必填）：
  [✓] src_index (integer): 源位置索引（0-based）
  [✓] dst_index (integer): 目标位置索引（0-based）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_remove_conditional_format

```plaintext
# sheet_remove_conditional_format

按 cf_id 删除一条条件格式规则（SHEET）。is_remove_all=true 时忽略 cf_id，删除指定子表上的全部条件格式。

参数（✓=必填）：
  [✓] sheet_id (string): 默认子表 ID（ranges 字符串中未带 "SheetID$" 前缀时使用）
  [ ] cf_id (string): 条件格式 ID。is_remove_all=false 时必填；为 true 时被忽略
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] is_remove_all (boolean): true=删除当前子表上的全部条件格式（忽略 cf_id），默认 false
```

---

## sheet_remove_filter

```plaintext
# sheet_remove_filter

移除子表当前生效的工作表筛选（SHEET），无需传入筛选 ID

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_remove_pivot_table

```plaintext
# sheet_remove_pivot_table

删除指定的透视表（SHEET）。通过 pivot_table_id 定位目标透视表，删除后其关联的 pivot cache 会被清理。

参数（✓=必填）：
  [✓] pivot_table_id (string): 目标透视表ID（必填）
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_rename_sheet

```plaintext
# sheet_rename_sheet

重命名表格中指定的子表（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] name (string): 新的子表名称
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_replace

```plaintext
# sheet_replace

在表格中查找并替换文本（SHEET）；调用前先查 schema 获取匹配范围、正则和公式替换等参数。

参数（✓=必填）：
  [✓] search_term (string): 要查找并替换的文本，不能为空
  [✓] replace_text (string): 替换后的文本；可传空字符串表示删除匹配内容
  [ ] end_col (integer): 结束列索引（0-based，不传表示到最后一列）
  [ ] end_row (integer): 结束行索引（0-based，不传表示到最后一行）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] match_case (boolean): 大小写敏感（默认: false）
  [ ] match_entire_cell (boolean): 整单元格匹配（默认: false）
  [ ] match_formulas (boolean): 替换公式文本而不是计算结果（默认: false）；替换后会按公式重新解析
  [ ] max_cells (integer): 最多替换的匹配单元格数（默认: 1000；0 表示不限制）
  [ ] sheet_name (string): 限定替换的子表名称，不指定则全表替换
  [ ] start_col (integer): 起始列索引（0-based，不传表示从0开始）
  [ ] start_row (integer): 起始行索引（0-based，不传表示从0开始）
  [ ] use_regex (boolean): 将 search_term 作为正则表达式（默认: false）；replace_text 支持 $1 等正则捕获引用
```

---

## sheet_revert_revision

```plaintext
# sheet_revert_revision

反向指定版本号(target_version)的 revision 改动（SHEET）。从 revision_manager_ 取目标 revision 的 forward SheetCommand → 每个 mutation 通过 core::sheet::ReverseMutation 生成反向 mutation → 拼成新 SheetCommand → CommitRevision 提交。

失败原因可能是：(1) 目标 revision 包含暂不支持反向计算的 mutation 类型（会立即报错，不静默丢改动）；(2) 反向命令在当前 workbook 上无法合法执行（例如目标 sheet 已被后续删除）；(3) 目标 revision 不在本地历史窗口内。

成功后写入一条新的 revision（version 递增），并通过 SSE 广播；反向操作产生的 undo_commands 会推入 undo_stack_，因此用户可以继续 Undo 撤销本次 revert。

参数（✓=必填）：
  [✓] target_version (integer): 要反向的那条 revision 对应的 version 号（必须 > 0 且 <= 当前 version）。可从 sheet_list_recent_ai_edits 或其他写工具返回的 `version` 字段记录。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_set_border

```plaintext
# sheet_set_border

设置表格指定区域单元格的边框样式（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）
  [✓] start_col (integer): 起始列索引（0-based）
  [✓] end_row (integer): 结束行索引（0-based）
  [✓] end_col (integer): 结束列索引（0-based）
  [✓] border_positions (array<integer>): 边框位置: 0=上 1=下 2=左 3=右 4=内部竖线 5=内部横线
  [ ] border_color (string): RGB hex, 如 FF0000
  [ ] border_style (integer): 线型: 0=无 1=细线 2=中等 3=虚线 4=点线 5=粗线 6=双线 7=极细线
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_set_cell_style

```plaintext
# sheet_set_cell_style

设置表格指定范围单元格的样式，包括字体、颜色、对齐等（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] start_row (integer): 起始行索引（0-based）,闭区间,包含此行
  [✓] start_col (integer): 起始列索引（0-based）,闭区间,包含此列
  [✓] end_row (integer): 结束行索引,闭区间,包含此行
  [✓] end_col (integer): 结束列索引,闭区间,包含此列
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] format (object): 样式属性
  [ ] is_clear (boolean): 是否清除格式（默认 false）。false 时按 format 的键值对设置对应属性；true 时清除 format 中**列出的键**对应的属性，值被忽略，未列出的键不变；format 缺省或为空对象时不清除任何属性
```

---

## sheet_set_cell_value

```plaintext
# sheet_set_cell_value

设置表格指定单元格的值，支持文本、数字、布尔等类型（SHEET）

参数（✓=必填）：
  [✓] sheet_id (string): 子表 ID(必填)
  [✓] cell (object):
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## sheet_set_data_validation

```plaintext
# sheet_set_data_validation
