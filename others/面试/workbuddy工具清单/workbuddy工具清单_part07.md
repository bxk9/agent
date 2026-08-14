        width_pct — 表格宽度占版心宽度的百分比（1–100；省略或 100 = 满宽）
        col_widths_pct — 各列占表格宽度的百分比数组，长度须等于 col_count；每项为数字（合计须为 100）或 "auto"（全 auto 时均分）；row_count/col_count 变更后若数组长度不匹配会被忽略
        inherit_styles — bool；true 时剥离 payload 中的装饰字段，复用文档原样式，只应用 cells[].text 与合并拓扑。剥离 table 级：borders/border/cell_fills/alignment/style；cell 级：bg/text_property/para/width/height_*（width_pct/col_widths_pct 仍按省略=保留合并）
        ⚠️ 不支持 table.width（dxa/pct/auto 对象），用 width_pct；不支持 cells[].width，列宽只用 col_widths_pct
        style — 表格样式名（如 TableGrid）
        cell_margin — 默认单元格内边距(dxa)：top/left/bottom/right
        cell_fills — 按 condition 批量染色：[{condition, color}, ...]；condition 取值：whole_table / first_row / last_row / first_col / last_col / band_row_odd / band_row_even / band_col_odd / band_col_even
        border — 统一 4 向外边框简写（等价于 top/left/bottom/right 同值）；与 borders 二选一，需要 inside_h/inside_v 时用 borders
        borders.{top,left,bottom,right,inside_h,inside_v} — 6 向独立边框
          每向含：val(线型)/color(6位hex或auto，可省略)/sz(1/8pt)/space(间距pt)
        cells[] — 满格展开时须包含合并延续格；partial patch 可只列要改的 cell
      
      【字段含义 (cells[].)】
        row / col — 1-based 逻辑坐标
        text — cell 内纯文本（不含段落结束符和图片/公式等占位符）
        text_property / rpr — run 级别样式（rpr 为写入别名）：
          bold / italic / strikethrough / double_strike / small_caps (bool)
          underline: bool，或 {style,color}（如 {"style":"double","color":"FF0000"}）
          color / background_color — 6 位 hex 或 auto（可省略）；子 key 写 null 可清除
          highlight — OOXML 色名（yellow/cyan/red/...，不是 hex）
          font_size (pt) / font_family
          vertical_align — superscript / subscript / baseline
          整对象 null → 清除全部直设 run 样式（ClearStyle）
        para — 段落属性（读写短名 para；写入也接受 paragraph_property）：
          alignment — left / center / right / both（两端对齐；justify 同 both）
          spacing — before_pt / after_pt 单位为磅(pt)；
            line 含义随 line_rule：auto 时为行倍数(1.0=单倍行距, 1.5=1.5倍, 内部存为×240)；exact / atLeast 时 line 为磅(pt)
          indent — {first_line_pt, left_pt, right_pt, hanging_pt}
          省略子 key=不碰；整对象 null 暂无全清
        height_pt + height_rule — 行高(磅) + 规则 atLeast|exact|auto；挂在每行第一个锚点 cell（列宽请用 table.col_widths_pct）
        bg — 单元格底色(6位hex或auto；读写短名，写入也接受 background_color；null 清除)
      
      【合并 / 解并】
        横合并：锚点 grid_span≥2 + 右侧延续格 mc:true
        纵合并：锚点 v_merge=restart + 下方延续格 v_merge=continue
        解并：锚点去掉 grid_span/v_merge 即可；延续格 mc/v_merge 会自动清理
        ⚠️ partial patch 改锚点文本/样式时须保留 grid_span/v_merge，否则误触发解并
      
      【partial patch 规则】
        - 省略字段 = 保留原文；要清除须显式写 null（如 "bg":null、"text_property":null）
        - inherit_styles:true — 从 doc_get_table_info 复制满格 JSON 后只改字时推荐；自动丢弃 borders/bg/text_property/para 等装饰字段（见 table.inherit_styles 说明）
        - 只传要改的 cells，或只改 table.row_count/col_count / 表级属性
        - text_property 子 key：省略=保留；"color":null 清除该属性；整对象 null 清除全部直设 run 样式
        - para 子 key：省略=不碰；写出的 key 才更新（引擎 partial）；整对象 null 暂无全清 API（no-op）
        - 已列出的 cell 若含合并，须带上要保留的 grid_span/v_merge（省略=解并）
        - 不要手填内部坐标字段（idx/range 等）
        - 最外层须为 {"type":"table","table":{...}}，不要只传裸 cells 数组
      
      【partial 示例】
        // 只改字（推荐 partial；或满格 + inherit_styles）：
        {"type":"table","table":{"inherit_styles":true,"cells":[{"row":2,"col":4,"text":"已完成"}]}}
        // 只改字，保留原有 bold/color/bg/para：
        {"type":"table","table":{"cells":[{"row":2,"col":4,"text":"已完成"}]}}
        // 只加粗，保留原有 color（子 key 省略=保留）：
        {"type":"table","table":{"cells":[{"row":1,"col":4,"text_property":{"bold":true}}]}}
        // 清颜色、清底色、清全部 run 直设样式：
        {"type":"table","table":{"cells":[
          {"row":2,"col":4,"text_property":{"color":null}},
          {"row":1,"col":4,"bg":null},
          {"row":2,"col":3,"text_property":null}
        ]}}
        // 改列宽：在 table 级设置 col_widths_pct（数值合计 100 或全 auto）
        {"type":"table","table":{"col_widths_pct":[40,30,30]}}
        // 仅扩容：{"type":"table","table":{"row_count":4,"col_count":5}}
  [ ] table_locate (object): 按单元格可见文字定位表格（与 idx 二选一）。cell_match 须为某锚点格 text 的精确 UTF-8 子串（从 cells[].text 原样复制，可避免手填 idx 时的空格/符号问题）。row/col 为可选 1-based hint（best-effort）。命中多个格时报错 ambiguous_matches，无 occurrence；请加长 cell_match 或加 hint。
```

---

## doc_replace_image

```plaintext
# doc_replace_image

替换文档中已有图片为新图片（DOC）。必须同时传入 idx 和 old_image_url（均取自 doc_get_images 的返回值），二者缺一会返回参数错误。新图片来源 new_content 与 doc_insert_image 的 content 参数格式相同。替换成功后直接返回新图的 image_url，无需再调 doc_get_images 反查。

参数（✓=必填）：
  [✓] idx (integer): 被替换图片在文档中的字符 idx（必填，取自 doc_get_images 返回的 index 字段）
  [✓] old_image_url (string): 被替换图片的 image_url（必填，取自 doc_get_images 同一条目的 image_url 字段）
  [✓] new_content (string): 新图片内容：data URI（data:image/...;base64,...）或本地文件绝对路径（可选 file:// 前缀）。不支持纯 base64 字符串，也不支持 http(s) 远程 URL。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_replace_text

```plaintext
# doc_replace_text

替换 range 范围内的文本为指定文本（DOC）。begin/end 是 DOC 坐标，直接使用 doc_find 返回的 begin/end，不要手算。

参数（✓=必填）：
  [✓] text (string): 替换后的文本内容
  [✓] ranges (array<object>): 需要替换的文本范围数组，半开区间 [begin, end)。优先直接使用 doc_find 返回的 begin/end。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_resolve_document_structure

```plaintext
# doc_resolve_document_structure

获取文档结构树（DOC），返回扁平节点列表，用于在调用需要 idx/index/ranges 的写类工具前定位位置。DOC 的 idx/begin/end 是 UTF-16 code unit 坐标，包含段落结束符、表格、图片、字段等结构占位；不要按肉眼字符数、段落序号或行号手算。节点 type：Paragraph / Heading（heading_level 1..9）/ Title / Subtitle / Table；编号段的 numbering_type 与写接口一致，可为 bullet / decimal_comma / task / decimal / bullet_arrow / bullet_hollow_circle / multilevel_decimal / chinese_numbering / upper_letter；文字下划线/删除线/高亮通过 has_highlights 标志位 + highlight_spans 嵌入在 Paragraph 内.
paragraph_index（全局 1-based 节点序号）标注第几段（含标题）。paragraph_id 在段属性携带 ID 时返回；没有或为空时省略。该 ID 只保证在当前打开的 editor 实例内用于定位，不保证保存后或重新打开文档仍保持不变；重开后必须重新调用本工具获取。
三档 mode（默认 compact）：outline=只给 Heading / (Sub)Title 节点出 preview，骨架级；compact=每节点 10 字符 preview + has_highlights / row_count×col_count / children_count / is_numbering 等轻量信号位；full=highlight_spans / table cells / numbering 详情全部回填。
定位单段传 idx（自动按 full 回包，跳过分页）；超长文档用 offset/limit 分页（默认 limit=150）。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] idx (integer): 字符位置索引（GCP 坐标，同 doc_insert_text / doc_find 等）。传入则只返回包含该位置的单块，自动按 full 回填，跳过分页。注意这是查询接口返回的 DOC 坐标，不是段落序号、行号或肉眼字符序号。
  [ ] include_highlights (boolean): compact/outline 下回填 highlight_spans 详情（has_highlights 信号位始终输出）。
  [ ] include_table_cells (boolean): compact/outline 下回填 Table.table_rows[].cells[]（row_count/col_count 始终输出）。
  [ ] include_textbox_children (boolean): compact/outline 下回填 TextBox/CodeBlock/HighlightBlock.children[]（children_count 始终输出）。
  [ ] limit (integer): 顶层 nodes 最大数量，默认 150；0=不分页。idx 模式忽略。
  [ ] mode (string): 信息密度档位，默认 compact。
  [ ] offset (integer): 顶层 nodes 起始下标，默认 0。idx 模式忽略。
  [ ] text_preview_length (integer): text_preview 字符上限。不传走 mode 默认（outline=20 / compact=10 / full=50）；0=关闭；上限 200。
```

---

## doc_revert_revision

```plaintext
# doc_revert_revision
