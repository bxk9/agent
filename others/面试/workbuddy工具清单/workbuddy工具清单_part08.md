反向指定版本号(target_version)的 revision 改动（DOC）。采用 git revert 风格：取目标 revision 的反向命令，作为新 revision 写入文档；不会真正删除任何历史 revision。失败原因可能是：(1) 目标 revision 包含暂不支持反向计算的 mutation 类型；(2) 反向命令在当前文档上无法合法执行；(3) 目标 revision 的全部改动已被后续编辑覆盖；(4) target 对应的 revision 不在本地历史窗口内（过早的 revision 被驱逐后无法回退）。

成功后会写入一条新的 revision 到历史（version 递增），并通过 SSE 广播给前端，行为与一次正常的写一致。本次 revert 自身也可被后续 revert 撤销。

参数（✓=必填）：
  [✓] target_version (integer): 要反向的那条 revision 对应的 version 号（必须 > 0 且 <= 当前 version）。可从 query 类工具返回的 `version` 字段记录。该 revision 必须仍在本地历史窗口内。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_set_page_number

```plaintext
# doc_set_page_number

设置页码（在页脚中插入 PAGE 字段）（DOC）。默认参数组合：页面底部右侧 + 1,2,3 格式 + 续前节 + 应用于整篇文档。调用前会自动切换为分页模式。position / format / continue_from_prev 均已支持；scope 目前仅支持 whole_doc，传入 from_here / current_section 会走空路径，不产生任何修订。

⚠️ 重要：本工具与 doc_insert_footer 互斥。调用本工具会清除已有的页脚文本内容。

参数（✓=必填）：
  [ ] continue_from_prev (boolean): true=续前节（默认）；false=使用 start 作为起始编号
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] format (string): 页码格式："decimal"(1,2,3，默认)、"romanLower"、"romanUpper"、"alphaLower"、"alphaUpper"
  [ ] position (string): 页码位置："right"(右对齐，默认)、"center"(居中)、"left"(左对齐)、"inside"、"outside"
  [ ] scope (string): 应用范围："whole_doc"(整篇文档，默认，目前仅支持此项)、"from_here"、"current_section"
  [ ] section_index (integer): 节索引，仅在 scope=current_section/from_here 时生效
  [ ] start (integer): 起始编号（continue_from_prev=false 时生效）
```

---

## doc_set_table_layout

```plaintext
# doc_set_table_layout

设置表格的行高 / 列宽（DOC）。通过表格内任意 cell 的 GCP 位置 idx 定位表格。idx 必须是表格内 DOC 坐标，不是第 N 张表。【两种模式】✅ mode=auto —— 列宽自适应页面宽度并均分：    后端从当前 section 的可用页宽 (pgSz.w - pgMar.left - pgMar.right) 自动算出每列宽度 = 可用页宽 / 列数，    所有列等宽铺满页面（即「自适应页宽 + 列宽均分」），用户传的 col_widths_dxa 会被完全忽略；    行高在 auto 模式下不改写（沿用原值）。    适用：表格越界 / 列宽混乱 / 想一键重置表格、用户说「均分列宽 / 自适应页宽 / 铺满 / 一键整理」时。✅ mode=manual —— 行高、列宽按 dxa 数组逐项指定：    row_heights_dxa[i] = 第 i 行行高；col_widths_dxa[j] = 第 j 列列宽；    任一项为 0 表示「该行/该列保持原值」（不写 mutation）；    数组长度短于行/列数时尾部按 0 处理，长于则静默截断。⚠️【manual 模式强制工作流】传 row_heights_dxa / col_widths_dxa 之前**必须**先调用 doc_get_table_info 获取当前表格的 row_count / col_count / 各行 height_pt / 各 cell width，再结合用户意图确认目标值。理由：（1）行数 / 列数未知时，传错数组长度会让尾部行 / 列被静默忽略；（2）想保留某些行高 / 列宽时必须传 0 占位（不传 0 会被当成「该行/该列改成 0」），    只有先 doc_get_table_info 才知道哪些位置该填实数、哪些该填 0；（3）单位 dxa 与用户口语 (cm / 磅 / 行) 之间需要换算 (1 inch = 1440 dxa)。auto 模式无需先查，可直接调用。单位：dxa（OOXML 标准单位，1 inch = 1440 dxa）。

参数（✓=必填）：
  [✓] idx (integer): 表格内任意 cell 的 DOC 坐标；不是表格序号。
  [✓] mode (string): 布局模式：auto（列宽自动均分到当前页可用宽度，行高不改；适用于「均分列宽 / 自适应页宽 / 表格越界一键整理」场景，row_heights_dxa / col_widths_dxa 被忽略）/ manual（按 row_heights_dxa / col_widths_dxa 逐项透传，0 = 沿用原值）
  [ ] col_widths_dxa (array<integer>): 每列的列宽（dxa，1 inch = 1440 dxa）。仅 mode=manual 时生效，auto 模式忽略；0 表示该列保持原值；长度不足时尾部列不修改。⚠️ 调用前必须先 doc_get_table_info 拿到 col_count + 各 cell 当前 width，再决定哪些位置填新值、哪些填 0 保留。如需「均分列宽 + 自适应页宽」，直接用 mode=auto（无需传本字段）。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] row_heights_dxa (array<integer>): 每行的行高（dxa，1 inch = 1440 dxa）。仅 mode=manual 时生效，auto 模式忽略；0 表示该行保持原值；长度不足时尾部行不修改。⚠️ 调用前必须先 doc_get_table_info 拿到 row_count + 各行当前 height_pt，再决定哪些位置填新值、哪些填 0 保留——不要不查就直接传整数组。
```

---

## doc_set_table_properties

```plaintext
# doc_set_table_properties

修改表格属性（DOC）。通过表格内任意 cell 的 GCP 位置 idx 定位表格，可同时设置边框、对齐、宽度、单元格内边距，以及按 9 种 condition 染色单元格。idx 必须是表格内 DOC 坐标，不是第 N 张表。全部字段可选，未提供的属性沿用原表格设置。cell_fills 中 condition 取值：whole_table / first_row / last_row / first_col / last_col / band_row_odd / band_row_even / band_col_odd / band_col_even。

参数（✓=必填）：
  [✓] idx (integer): 表格内任意 cell 的 DOC 坐标；不是表格序号。
  [ ] alignment (string): 表格对齐方式：left / center / right；空字符串表示不修改
  [ ] borders (object): 表格 6 个方向边框（每项可选）
  [ ] cant_split (boolean): 若 true，对所有行设置 cantSplit={val:false}（允许跨页断行）
  [ ] cell_fills (array<object>): 按 condition 命中单元格统一染色，可同时指定多组
  [ ] cell_margin (object): 默认单元格内边距（dxa 单位，1 dxa = 1/20 磅；每项可选，0 表示沿用)
  [ ] cell_v_align (string): 所有单元格垂直对齐方式：top / center / bottom；空字符串表示不修改
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] row_height_auto (boolean): 若 true，对所有行设置自动行高 (trHeight={val:0, hRule:auto})
  [ ] width (object): 表格宽度
```

---

## doc_to_image

```plaintext
# doc_to_image

将本地 DOC/DOCX 文档渲染为逐页图片（PNG）。流程：获取临时上传凭证 → 上传本地文件到 COS → 调用 slidetools /api/v6/slidetools/convert/doc_to_images 完成转换 → 把每页图片下载到本地目录。输入为 docx 文件的绝对路径（不需要先 open_file），返回每页图片的本地绝对路径与页数。无需登录态。适用于需要预览文档页面 / 做 OCR / 生成缩略图的场景（DOC）。如果 AI 需要查看编辑完文档后的视觉效果，可以调用该工具将文档转为图片进行确认。但不建议每次调用完编辑工具就立即转图查看，而是在单个会话的编辑任务全部完成之后，再统一调用一次转图查看最终效果，以避免不必要的性能开销。

参数（✓=必填）：
  [✓] file_path (string): 本地 doc/docx 文件的绝对路径（必填）。
  [ ] output_dir (string): 图片输出目录（绝对路径），不传则使用系统临时目录。目录下会生成 page-1.png、page-2.png ...
```

---

## doc_unmerge_table_cells

```plaintext
# doc_unmerge_table_cells

拆分表格单元格（DOC）。将 (row, col) 处的已合并单元格拆分为 row_num×col_num 个单元格。idx 为表格内任意 cell 的 DOC 坐标。row/col 为 1-based（与 doc_get_table_info 返回的 row/col 一致，直接传入即可）。row_num/col_num 为拆分后的目标行数/列数（≥1，=1 表示该方向不拆分）。如果单元格未合并（grid_span=1 且 v_merge 无），仍会按参数插入新单元格。使用前先调用 doc_get_table_info 确认单元格的 grid_span 和 v_merge 状态。

参数（✓=必填）：
  [✓] idx (integer): 表格内任意 cell 的 DOC 坐标
  [✓] row (integer): 要拆分的单元格的 1-based 行号。与 doc_get_table_info 返回的 row 一致
  [✓] col (integer): 要拆分的单元格的 1-based 列号。与 doc_get_table_info 返回的 col 一致
  [✓] row_num (integer): 拆分后的目标行数（≥1）。=1 表示不纵向拆分
  [✓] col_num (integer): 拆分后的目标列数（≥1）。=1 表示不横向拆分
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_update_text_property

```plaintext
# doc_update_text_property

更新指定字符范围内的文本属性（DOC）。仅修改样式，不改变文档内容长度，因此返回值不包含 position 字段（与其他 insert_* 接口不同）。支持加粗、斜体、下划线（含线型/颜色）、单删除线、双删除线、小型大写、文字色、底纹色、高亮、字号、字体、上下标，所有样式字段均为可选，未传的字段保持原样不变。background_color 是底纹颜色，highlight 是高亮文本，二者不同，同时设置时高亮会覆盖底纹。

参数（✓=必填）：
  [✓] ranges (array<object>): 需要更新属性的字符范围数组（半开区间 [begin, end)）；至少 1 段。直接使用查询返回的 DOC 坐标；不要手算。
  [ ] background_color (string): 底纹颜色，6 位 / 8 位 hex，如 "FFFF00" 或 "#FFFF00"
  [ ] bold (boolean): 是否加粗（true=加粗，false=取消加粗）