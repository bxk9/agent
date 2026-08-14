  [ ] reply_to (string): （可选）已有批注 id：用于把本条批注作为「回复」追加到该批注所在的扁平对话线程。若不为空，必须对应 doc_get_comments 返回的某条批注 id；若该 id 不存在，接口会直接返回参数错误。如需创建顶层批注，请留空或不传。（向后兼容：字段名 `ref_id` 仍可用，但推荐使用 `reply_to` 以避免与其它 'ref' 语义混淆。）
```

---

## doc_insert_footer

```plaintext
# doc_insert_footer

设置页脚文本内容（DOC）。覆盖式写入：先清空已有页脚内容，再写入新文本。本工具一次只处理一个 section（由 section_index 指定）；如需对多个 section 都写入页脚，请按需多次调用本工具。首次插入时会为目标 section 独立创建页眉页脚 substory，打破该 section 与前一节"链接到上一节"的关系。

⚠️ 重要：本工具与 doc_set_page_number 互斥。调用本工具会清除已有的页码（PAGE 字段）。

参数（✓=必填）：
  [✓] text (string): 要写入的页脚文本内容
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] footer_type (string): 页脚类型："default"（默认页脚，应用于所有页）、"first"（首页页脚）、"even"（偶数页页脚）
  [ ] section_index (integer): 节索引（0-based），默认为 0
```

---

## doc_insert_footnote

```plaintext
# doc_insert_footnote

在指定位置插入脚注或尾注（DOC）。脚注显示在页面底部，尾注显示在文档末尾。idx 是 DOC 坐标，不要按肉眼字符数或段落序号手算。⚠️ idx 应该使用目标文本的最后一个字符位置（即段落的 end_index - 1，段落分隔符 ¶ 之前），这样脚注/尾注引用标记会出现在文本末尾而非中间。

参数（✓=必填）：
  [✓] idx (integer): 插入脚注/尾注引用标记的位置索引。应使用目标文本最后一个字符的位置（段落 end_index - 1），使引用标记出现在文本末尾
  [ ] content (string): 脚注/尾注的文本内容（可选）
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] type (integer): 类型：0=脚注（默认），1=尾注
```

---

## doc_insert_header

```plaintext
# doc_insert_header

设置页眉文本内容（DOC）。覆盖式写入：先清空已有页眉内容，再写入新文本。本工具一次只处理一个 section（由 section_index 指定）；如需对多个 section 都写入页眉，请按需多次调用本工具。首次插入时会为目标 section 独立创建页眉页脚 substory，打破该 section 与前一节"链接到上一节"的关系。

参数（✓=必填）：
  [✓] text (string): 要写入的页眉文本内容
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] header_type (string): 页眉类型："default"（默认页眉，应用于所有页）、"first"（首页页眉）、"even"（偶数页页眉）
  [ ] section_index (integer): 节索引（0-based），默认为 0
```

---

## doc_insert_html_content

```plaintext
# doc_insert_html_content

在指定 idx 处插入一段 HTML 富文本（DOC），引擎会按 HTML 标签 / 内联样式自动转为段落、标题、列表、表格、链接、加粗 / 斜体 / 下划线、文字色 / 背景色等富文本元素。本接口为批量解析模式，一次调用可插入多个段落 / 列表 / 表格。
适用场景：粘贴一整段富文本（网页片段 / Markdown 渲染产物等）到文档中；不适合「仅插入纯文本」（请用 doc_insert_text）或「单段标题 / 编号」（请用 doc_insert_paragraph_with_text）。
已知支持（最常用子集）：
  - 段落与标题：<p> / <h1>..<h6>（自动映射为 Heading1..6）
  - 文本样式：<b>/<strong>、<i>/<em>、<u>、<s>/<strike>、<sub>/<sup>、<span style="...">
  - 链接：<a href="...">；图片需走 doc_insert_image，HTML 内嵌 <img> 支持有限
  - 列表：<ul><li>、<ol><li>，支持基本嵌套
  - 表格：<table><tr><td>（仅基本网格，复杂样式可能丢失）
  - 分隔：<br>（行内换行）、<hr>（水平线）
已知不支持 / 易丢样式：
  - <script> / <style> 标签整体丢弃
  - position / float / flex / grid 等 CSS 布局属性
  - 自定义字体回退（fontFamily 仅按字体名匹配）
返回值：成功响应中包含 `last_edit_index` 与 `position`（两者同值），可作为下一次插入的 idx 继续追加内容。插入后产生的 block 列表（type / heading_level / 行列数等）暂未在响应中返回，调用方如需细粒度可通过 doc_resolve_document_structure 二次查询。
idx 是 DOC 坐标，应使用查询结果或写操作返回值，不要手算。

参数（✓=必填）：
  [✓] idx (integer): 插入位置索引。使用查询结果或写操作返回值里的 DOC 坐标。不要传 paragraph_index 或手算字符数。
  [✓] html_text (string): HTML 富文本内容（UTF-8 编码）。推荐使用结构化标签（<p>/<h1>~<h6>/<ul>/<ol>/<table> 等）。纯文本插入请改用 doc_insert_text。
  [ ] file_id (string): The file_id of the editor to operate on
```

---

## doc_insert_image

```plaintext
# doc_insert_image

在指定位置插入图片（DOC）。图片来源支持：data URI（data:image/...;base64,...）或本地文件绝对路径（可选 file:// 前缀）。不支持纯 base64 字符串（请加 data: 前缀），也不支持 http(s) 远程 URL。插入成功后直接返回新图的 image_url，无需再调 doc_get_images 反查。idx 是 DOC 坐标，需来自查询结果或上一次写操作返回值，不要按肉眼位置手算。

参数（✓=必填）：
  [✓] idx (integer): 插入位置的 DOC 坐标（与 doc_get_images.index / doc_find.begin 同坐标系）。不是第 N 张图片或段落序号。
  [✓] content (string): 图片内容：data URI（data:image/...;base64,...）或本地文件绝对路径（可选 file:// 前缀）。不支持纯 base64 字符串，也不支持 http(s) 远程 URL。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] h (integer): 图片高度（像素，96 DPI）。省略时使用图片原始高度。
  [ ] w (integer): 图片宽度（像素，96 DPI）。省略时使用图片原始宽度。
```

---

## doc_insert_markdown

```plaintext
# doc_insert_markdown

在指定位置插入 Markdown 格式内容（DOC），支持标题、列表、表格、链接、加粗 / 斜体等常见语法，引擎会自动将 Markdown 转换为文档富文本格式。一次调用可插入多个段落 / 列表 / 表格。
语义说明：按段落导入时，每个块级段落（如 <p>/标题/列表项）都会生成段落分隔符，因此最后一个段落通常也会以段落分隔符结束。
典型支持语法：
  - 标题：`# H1` / `## H2` / `### H3` ...（最多到 H6）
  - 列表：`- item`（无序）/ `1. item`（有序），支持缩进生成多级
  - 表格：`| 表头1 | 表头2 |` + `| --- | --- |` + 数据行
  - 行内样式：`**加粗**`、`*斜体*`、`~~删除线~~`、`` `code` ``、`[链接文字](url)`
返回值：成功响应中包含 `last_edit_index` 与 `position`（两者同值），可作为下一次插入的 idx 继续追加内容。
🔗 相关接口：
  - 「单段标题 / 编号」请用 `doc_insert_paragraph_with_text`（更精确的样式控制）
  - 「粘贴 HTML 富文本」请用 `doc_insert_html_content`
  - 「只插入纯文本」请用 `doc_insert_text`
idx 是 DOC 坐标，应使用查询结果或写操作返回值，不是段落序号、行号或肉眼字符序号。

参数（✓=必填）：
  [✓] idx (integer): 插入位置索引。使用查询结果或写操作返回值里的 DOC 坐标。不要传 paragraph_index 或手算字符数。
  [ ] base64_markdown (string): base64 编码的 Markdown 内容。优先级高于 markdown，与 markdown 二选一。当 Markdown 内容包含特殊字符或非 UTF-8 编码时使用此字段；常规场景优先使用 markdown 参数。
  [ ] file_id (string): The file_id of the editor to operate on
  [ ] markdown (string): Markdown 格式内容。也可改传「文件地址」以避免把整段长内容当调用字符串重新生成、浪费时间：
        - 直接传明文 markdown 文本；或
        - "file://<本地绝对路径>"：从该文件读取明文 markdown；或
        - "base64file://<本地绝对路径>"：从该文件读取 base64 编码的 markdown 并自动解码。
      与 base64_markdown 二选一，必须传其一。常规场景优先使用本字段。
```

---

## doc_insert_math

```plaintext
# doc_insert_math

在指定位置插入数学公式（DOC）。C++ 层将 LaTeX 解析为 OOXML OMML 后展开为完整公式：如 "\\frac{1}{2}"、"x^{2}"、"\\sqrt{x+1}"、"\\sum_{i=1}^{n} i" 等。
【行为】插入按 OMML 结构展开的 \x16/\x17 序列 + 公式文本字面 + 各层 CTOMathPr（分式 f、根号 rad、上下标 sSup/sSub、N 元运算 nary、矩阵 m、参数 e/num/den/sup/sub 等）。公式总长由实际 OMML 结构决定。
【返回值】成功响应中包含 `last_edit_index` 与 `position`（两者同值），即「下一个可写位置」。可直接作为下一次 doc_insert_text / doc_insert_math 等的 idx，**无需**再次调用 doc_resolve_document_structure。
【错误处理】latex 为空 / 语法错误 / OMML 解析失败 ⇒ 返回错误，不再自动回退到空白公式。调用方必须传入有效的 LaTeX 表达式。
【典型用法】
  1) doc_insert_text(idx=N, text="已知 ")           → idx 推进到 N+2
  2) doc_insert_math(idx=N+2, latex="\\frac{1}{2}") → 在文本之后插入分式
  3) doc_insert_text(idx=position, text=" 求解...")  → 用返回的 position 继续写文本
使用前请先调用 doc_resolve_document_structure 或 doc_get_last_operable_pos 获取文档结构以确定正确的插入位置索引。

参数（✓=必填）：
  [✓] idx (integer): 插入位置的 GCP 字符索引（必填）。可从 doc_resolve_document_structure 的 start_index/end_index、doc_find 的 position、或前一次插入接口返回的 last_edit_index 获取。