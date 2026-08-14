  [✓] latex (string): LaTeX 数学表达式（必填，非空）。支持常用语法：\frac{a}{b}（分式）、x^{2}（上标）、x_{i}（下标）、\sqrt{x}（根号）、\sum_{i=1}^{n}（求和）、\int（积分）、\alpha/\beta（希腊字母）、嵌套结构如 \frac{x^{2}}{\sqrt{y+1}}。空字符串或无效语法 ⇒ 返回错误，不会写入文档。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_insert_normal_link

```plaintext
# doc_insert_normal_link

插入普通链接（DOC）。这是在 idx 位置插入一个链接字段，不是给已有文本范围设置链接；显示文本由 text/file_name 决定。idx 是 DOC 坐标，使用查询结果或写操作返回值，不要手算。

参数（✓=必填）：
  [✓] idx (integer): 插入位置的 DOC 坐标，来自查询结果或上一次写操作返回值；不是段落序号。
  [✓] link (string): 链接URL
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] file_name (string): 链接显示文件名（可选）
  [ ] independent_render (boolean): 是否独立渲染
  [ ] layout_type (string): 布局类型
  [ ] text (string): 链接显示文本（可选）
```

---

## doc_insert_page_break

```plaintext
# doc_insert_page_break

在指定位置插入分页符（DOC）。idx 是 DOC 坐标，使用查询结果或写操作返回值，不是段落序号。

参数（✓=必填）：
  [✓] idx (integer): 插入位置的索引
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_insert_paragraph

```plaintext
# doc_insert_paragraph

在指定 idx 处插入一个「段落分隔符」（paragraph break），并对「该分隔符之前的文本」应用段落级样式。⚠️ 本接口不写入任何文本内容，仅修饰段落属性。⚠️ 这是拆分当前段落的底层接口：idx 之后的段落会保留原段落属性。在编号段末尾调用会得到一个继续编号的空段；不要用本接口创建独立的普通空段，应使用 `doc_insert_paragraph_with_text(idx=段落end_index, text="", type=0)`。
🔗 相关接口：
  - 「插入带文本的标题/编号段落」请使用 `doc_insert_paragraph_with_text`（一步完成、原子写入）
  - 「只写入纯文本」请使用 `doc_insert_text`
  - 「批量插入富文本（包含多级标题 / 表格 / 样式）」请使用 `doc_insert_html_content`
  - 「改变现有段落的行距 / 缩进 / 对齐」请使用 `doc_modify_paragraph` / `doc_update_line_spacing`
典型两步式用法：
  1. doc_insert_text(idx=N, text="一级标题")            → 写入文本
  2. doc_insert_paragraph(idx=N+len, level=1)        → 把上述文本所在段落标为 H1
语义：idx 指向「已有文本的末尾」，分隔符插在 idx 处后；前一个段落（即刚写入的文本）继承本次设置的 level/type/numbering_lvl 等属性；idx 之后的部分作为下一个段落。idx 必须是 DOC 坐标，可使用查询结果或写操作返回值；不要传 paragraph_index 或手算字符数。

参数（✓=必填）：
  [✓] idx (integer): 段落分隔符的插入位置（DOC 坐标）。来自查询结果或写操作返回值；不是段落序号。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] indent_count (integer): 编号前的缩进空格数；仅在 type 为 1/2（带项目符号 / 数字编号）时生效，普通段落传了不会生效。该值会随当前编号项一起渲染（与所选 numbering_lvl 一致），但不会作为段落自身的缩进字段返回；doc_get_paragraph_property 的 indent 字段不包含该值。
  [ ] level (): 标题级别：0=普通段落（非标题），1~9=Heading1~Heading9。为保持向后兼容，同时接受整数（推荐）与数字字符串 '0'..'9'。
  [ ] numbering_lvl (): 编号级别（1~9，对应 1~9 级编号）。同时接受整数（推荐）与数字字符串。
  [ ] type (): 编号类别（默认 0，无编号）。同时接受整数（推荐）与数字字符串。
        0=无编号
        1=圆点项目符号 ●
        2=数字编号 1、（中文逗号样式）
        3=待办事项（仅 1 级）
        4=数字编号 1.（有序列表常用）
        5=箭头项目符号 ➢
        6=空心圆项目符号 ○
        7=多级数字编号 1./1.1./1.1.1.
        8=中文数字编号 一、/1、/a)
        9=大写字母编号 A./a./i.
```

---

## doc_insert_paragraph_with_text

```plaintext
# doc_insert_paragraph_with_text

一步插入「带文本的段落」（DOC），新增段落继承上一段属性。在 idx 指定的段落之后插入一个新段落，包含指定的文本和段落属性。推荐调用方首选此接口而非「doc_insert_text + doc_insert_paragraph」两步调用，该接口避免两步之间的位置漂移。
典型用法：
  doc_insert_paragraph_with_text(idx=N, text="第一章 引言", level=1)  → 一步得到 H1 标题段落
  doc_insert_paragraph_with_text(idx=N, text="项 1", type=4, numbering_lvl=1)  → 一步得到数字编号条目
返回值：成功响应中包含新段落的 end_index，可将该值直接作为下一次 doc_insert_paragraph_with_text 的 idx 进行链式追加，下一次插入会落到本次新段落之后；无需再次调用 doc_resolve_document_structure。
编号复用：连续插入同 type 的编号段落时，引擎自动将它们归入同一个 NumberingList （共享 num_id），无需手动管理编号组归属。
🔗 相关接口：
  - 「只插入纯文本」请用 `doc_insert_text`
  - 「插入一整段富文本（多级标题 / 表格 / 多个段落）」请用 `doc_insert_html_content` 或 `doc_insert_markdown`
  - 「仅修改现有段落的样式」请用 `doc_modify_paragraph` / `doc_update_line_spacing`

参数（✓=必填）：
  [✓] idx (integer): 目标段落的 end_index。新段落将插入在该段落之后。取自查询结果或上一次写操作返回值。不要传 paragraph_index；传入 -1 表示在文档最开头插入新段落。
  [✓] text (string): 要写入的段落文本（不包含换行）。允许为空字符串，此时退化为单独插入段落分隔符
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] indent_count (integer): 编号前缩进空格数；仅在 type=1 或 2 时生效，其他 type 传了不会生效。该值随当前编号项一起渲染，但不会作为段落自身的缩进字段返回；doc_get_paragraph_property 的 indent 字段不包含该值。
  [ ] level (): 标题级别：0=普通段落，1~9=Heading1~Heading9。默认 0。同时接受整数（推荐）与数字字符串。
  [ ] numbering_lvl (): 编号级别（1~9）。与 type 配合使用，type=0 时无效。type=3（待办）仅支持 1 级；其余 type 支持 1~9 级多级编号。同时接受整数（推荐）与数字字符串。
  [ ] type (): 编号类别（默认 0，无编号）。同时接受整数（推荐）与数字字符串，必须和numbering_lvl配合使用。
        0=无编号
        1=圆点项目符号 ●（无序列表常用）
        2=数字编号 1、（中文逗号样式）
        3=待办事项（任务清单常用，仅 1 级）
        4=数字编号 1.（有序列表常用）
        5=箭头项目符号 ➢
        6=空心圆项目符号 ○
        7=多级数字编号 1./1.1./1.1.1.（适合论文/合同章节）
        8=中文数字编号 一、/1、/a)
        9=大写字母编号 A./a./i.
```

---

## doc_insert_section_break

```plaintext
# doc_insert_section_break

在指定 DOC/UTF-16 坐标插入分节符。idx 之前的内容保留在前一节，idx 及其后的内容进入后一节；拆分后的前后两节完整继承原节的节级属性，仅后一节的起始类型改为 start_type。段中/段尾插入时，分节前的内容保留原段落属性；段首插入使用干净的结构承载段。不会额外插入段落回车。start_type 可选，默认 new_page。插入后文档坐标和节索引会变化，继续操作前应重新查询。

参数（✓=必填）：
  [✓] idx (integer): 插入位置的 DOC/UTF-16 坐标，使用查询结果或上一次写操作返回值；不是段落序号。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] start_type (string): 分节起始类型：下一页、下一栏、连续、偶数页或奇数页；默认 new_page。
```

---

## doc_insert_table_by_csv

```plaintext
# doc_insert_table_by_csv

以 CSV 内容一次性建表并填充（DOC）。**推荐用法**：调用方无需自己数每个 cell 的 idx —— 只要给 idx（表格插入位置）和 csv_data，工具会按 CSV 的行/列自动创建对应大小的表格并把每格文本写入。CSV 必须是规整二维表：每一行列数一致；空单元格请用连续逗号显式表示；最多 200 行、63 列，单元格文本不超过 8KB。CSV 语法遵循 RFC4180：逗号分隔、双引号包字段、字段内 `""` 表示单个双引号、支持 `\r\n`/`\n`/`\r` 三种换行。注意：Cell 内文本会作为纯文本插入（换行符不会展开为多段落）。建表成功后，如需设置表格样式（边框/对齐/宽度/列宽等），请使用 doc_set_table_properties / doc_set_table_layout；如需修改单元格字体样式，请用 doc_modify_table_region 在 table_block_json 中写入 text_property。

参数（✓=必填）：
  [✓] idx (integer): 插入位置的 DOC 坐标，来自查询结果或上一次写操作返回值；不是段落序号。
  [✓] csv_data (string): CSV 格式的表格内容；必须每行列数一致，空单元格用连续逗号表示；最多 200 行、63 列，单元格文本不超过 8KB。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_insert_table_column

```plaintext
# doc_insert_table_column

在表格中插入一列（DOC）。idx 为表格内任意 cell 的 GCP 位置，col 为 1-based 列号（指定从哪列克隆样式），inserted_back=true 在该列后方插入，false 在前方插入。插入后自动调整列宽。使用前先调用 doc_get_table_info 获取表格结构和列号。

参数（✓=必填）：