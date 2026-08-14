  [ ] highlight_block (object): 将指定范围内的段落转换为高亮块/提示块。段落内容会被移入高亮块容器中。高亮块是一个带有背景色和边框色的独立容器，用于突出显示重要内容（类似 callout/admonition）。使用时 ranges 中只需传入一个 range，其 begin 和 end 应覆盖所有需要放入同一高亮块的段落。例如要将第2~4段放入高亮块，传入一个 range {begin: 第2段起始, end: 第4段结束} 即可。与 indent、block_quote、numbering 互斥，不可同时传入。
  [ ] indent (string): 缩进操作：increase（增加一级缩进）/ decrease（减少一级缩进）。每次增加/减少约2个字符宽度。修改的是段落左缩进（w:left），不是首行缩进。如需设置首行缩进请使用 first_line_indent 或 first_line_indent_chars。
  [ ] jc (): 段落对齐方式；支持常用 left/center/right/both/distribute，以及 start/end、justify_medium/high/low、thai_distribute。null 删除直接设置并恢复继承。
  [ ] keep_together (): 尽量保持段落内部不跨页；null 恢复继承。
  [ ] keep_with_next (): 与下一段保持同页；null 恢复继承。
  [ ] left_indent (): 精确左缩进（pt），允许负值；null 恢复继承。
  [ ] line_spacing (): 行间距数值，含义取决于 line_spacing_rule：当 rule=1(auto) 时，直接传入倍数值本身，例如：单倍行距传 1.0，1.5 倍行距传 1.5，双倍行距传 2.0。当 rule=2(exact) 或 rule=3(atLeast) 时为磅值（如 24 表示 24pt）。若不传 line_spacing_rule 则默认按 auto 模式处理；null 恢复继承。
  [ ] line_spacing_rule (): 行间距规则：1=auto（多倍行距，line_spacing 为倍数）/ 2=exact（固定值，line_spacing 为磅数）/ 3=atLeast（最小值，line_spacing 为磅数）。设置行间距时建议同时传入此参数以明确语义。
  [ ] numbering (string): 设置或取消段落编号/列表样式。可选值：bullet（●/○/■）/ decimal_comma（1、/a)/i)）/ task（待办事项）/ decimal（1./a./i.）/ bullet_arrow（➢/○/■）/ bullet_hollow_circle（○/■/◆）/ multilevel_decimal（1./1.1./1.1.1.）/ chinese_numbering（一、/1、/a)）/ upper_letter（A./a./i.）/ none（取消编号/列表/待办事项，移除段落的所有列表样式，包括 bullet、decimal、task）。取消编号时，只需传入一个 range 覆盖所有需要去除编号的连续段落即可，例如要去除第4~13位置的段落编号，传入 ranges: [{begin:4, end:13}]。独立操作：不可与 spacing_before/after、jc、heading_lvl 等同包。示例（普通段接入前文 decimal 列表，level 与上文一致）：{"ranges":[{"begin":675,"end":705}],"numbering":"decimal","numbering_level":1}
  [ ] numbering_level (integer): 编号层级（1-9）。显式传入时把所有选中段落强制设为该层级；省略时保留已有编号层级，未编号段落使用第1级。层级1为顶层编号，层级2为子编号，以此类推。仅在设置 numbering 时有效。
  [ ] numbering_restart (boolean): 编号是否重新开始。true=创建新的编号列表并从1开始；false=续接当前或前一个兼容的编号列表。省略时保持兼容行为（创建新列表）；仅在 numbering 不是 none 时有效。
  [ ] page_break_before (): 段落从新页开始；null 恢复继承。
  [ ] paragraph_id (string): 当前打开实例内的段落 ID，来自 doc_resolve_document_structure 的 paragraph_id。传入后优先于 ranges，只修改 ID 唯一匹配的段落；找不到或重复时整次操作报错。不保证保存后或重新打开文档仍保持不变；重开后必须重新解析结构获取新值。
  [ ] paragraph_style (): 任意现有段落样式的显示名或 styleId，如 Normal、Caption；null 删除直接样式并恢复继承。与 heading_lvl 二选一。
  [ ] ranges (array<object>): 可选段落范围列表，每项包含 begin 和 end（DOC 坐标）。未传 paragraph_id 时必填；传入 paragraph_id 时本参数会被忽略。须为当前版本坐标（改字后坐标会变）；用 doc_resolve_document_structure 等查询结果，勿用旧快照。
  [ ] right_indent (): 精确右缩进（pt），允许负值；null 恢复继承。
  [ ] spacing_after (): 段后间距（pt）；null 恢复继承。
  [ ] spacing_before (): 段前间距（pt）；null 恢复继承。
  [ ] tab_stops (): 自定义制表位列表；null 删除直接设置并恢复继承。
  [ ] widow_control (): 孤行控制；null 恢复继承。
```

---

## doc_modify_section

```plaintext
# doc_modify_section

修改 DOC 文档指定 section 的基础页面属性。section_index 为 0-based；未传字段保持不变，传 null 删除该直接设置并恢复 OOXML 默认。所有长度统一为 pt。orientation 单独设置时会自动交换现有页面宽高，使 portrait/landscape 立即生效；若同时传 page_width/page_height，则以显式尺寸为准。

参数（✓=必填）：
  [ ] bottom_margin (): 下页边距（pt），不得小于 0。
  [ ] different_first_page_header_footer (): 是否首页使用不同页眉页脚；null 清除直接设置。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] footer_distance (): 页脚距页面底端距离（pt）。
  [ ] gutter (): 装订线宽度（pt）。
  [ ] header_distance (): 页眉距页面顶端距离（pt）。
  [ ] left_margin (): 左页边距（pt），不得小于 0。
  [ ] orientation (): 页面方向：portrait / landscape；null 清除直接设置。
  [ ] page_height (): 页面高度（pt），必须大于 0。
  [ ] page_width (): 页面宽度（pt），必须大于 0。
  [ ] right_margin (): 右页边距（pt），不得小于 0。
  [ ] section_index (integer): 节索引（0-based），默认 0。
  [ ] start_type (): 分节起始类型：new_page / new_column / continuous / even_page / odd_page；null 清除。
  [ ] top_margin (): 上页边距（pt），不得小于 0。
```

---

## doc_modify_table_region

```plaintext
# doc_modify_table_region

修改 DOC 文档中的表格：单元格文本/样式、段落对齐、行高、列宽百分比、边框、底色、行列增删、合并/拆分；变更合并后一次写回。
table_block_json 字段、partial 规则、合并语法、JSON 示例 → 见本工具 table_block_json 参数的 schema 描述（调用前 edsdk.py schema）。
何时 partial/满格、table_locate 定位、从零建表、公文 inherit_styles、大 JSON 传参、常见报错 → 见 skill references/表格修改工作流.md。
扩行/改 merge 等结构变更推荐满格 cells（row_count×col_count），服务端可自动删表重建；仅改文字用 partial patch。

参数（✓=必填）：
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] idx (integer): 表格内任意 DOC 位置（与 table_locate 二选一；与 doc_get_table_info 的 idx 相同）。连续多次修改同一张表时可复用同一 idx。
  [ ] table_block_json (): 编辑后的表格块。推荐直接传 JSON 对象；字符串形式等价。
      大 payload 可用 edsdk.py：table_block_json=@/path/to/table.json 或 --json-file args.json（避免 shell 参数长度限制）。
      
      【完整示例】下面是一个 3×4 表格，涵盖所有可编辑字段：
        - 横合并: cell(1,1) grid_span=3 跨 3 列 + (1,2)(1,3) mc:true
        - 纵合并: cell(2,3) v_merge=restart 跨 2 行 + (3,3) v_merge=continue
        - 文本属性: bold / color / font_size (text_property)
        - 段落属性: alignment center/right (para)
        - 列宽行高: table.col_widths_pct / table.width_pct / height_pt+height_rule
        - 表属性: alignment / borders(6向) / cell_margin / cell_fills
        - 单元格底色: table.cell_fills 批量染色 + cells[].bg 单格染色
      
      {
        "type": "table",
        "table": {
          "row_count": 3,
          "col_count": 4,
          "alignment": "center",
          "cell_margin": {"top": 60, "left": 100, "bottom": 60, "right": 100},
          "borders": {
            "top":    {"val": "single", "color": "000000", "sz": 8},
            "left":   {"val": "single", "color": "000000", "sz": 8},
            "bottom": {"val": "single", "color": "000000", "sz": 8},
            "right":  {"val": "single", "color": "000000", "sz": 8},
            "inside_h": {"val": "single", "color": "CCCCCC", "sz": 4},
            "inside_v": {"val": "single", "color": "CCCCCC", "sz": 4}
          },
          "cell_fills": [
            {"condition": "first_row", "color": "E8EAF6"}
          ],
          "width_pct": 100,
          "col_widths_pct": [25, 25, 25, 25],
          "cells": [
            {"row":1,"col":1,"text":"季度报告","grid_span":3,
             "text_property":{"bold":true,"color":"3F51B5","font_size":14},
             "para":{"alignment":"center"},"height_pt":30},
            {"row":1,"col":2,"mc":true},
            {"row":1,"col":3,"mc":true},
            {"row":1,"col":4,"text":"状态","text_property":{"bold":true},
             "para":{"alignment":"center"},"bg":"C5CAE9"},
            {"row":2,"col":1,"text":"Q1","para":{"alignment":"center"}},
            {"row":2,"col":2,"text":"Q2","para":{"alignment":"center"}},
            {"row":2,"col":3,"text":"汇总","v_merge":"restart",
             "text_property":{"bold":true,"color":"D32F2F"}},
            {"row":2,"col":4,"text":"✅ 完成","text_property":{"color":"4CAF50"},"bg":"E8F5E9"},
            {"row":3,"col":1,"text":"1200","para":{"alignment":"right"}},
            {"row":3,"col":2,"text":"980","para":{"alignment":"right"}},
            {"row":3,"col":3,"v_merge":"continue"},
            {"row":3,"col":4,"text":"进行中","text_property":{"color":"FF9800"},"bg":"FFF3E0"}
          ]
        }
      }
      
      【字段含义 (table.)】
        row_count / col_count — 逻辑行列数。可单独修改（不必重传全部 cells），减小删行/列，增大在末尾追加空行/列。
        alignment — 表格水平对齐：left / center / right