  [✓] to_section_index (integer): 0-based target position in the section list.
```

---

## slide_move_slide

```plaintext
# slide_move_slide

Move one or more slide pages to a new position within the presentation. IMPORTANT: call slide_get_sections and slide_get_info first to get the current section list and slide indices — both may have changed since the last query.
Provide exactly ONE of before_slide_index or after_section_id to indicate where the moved slides should land.
- before_slide_index: 0-based slide index. The moved slides are inserted right before the slide currently at this index (i.e. the first moved slide ends up at this index). To move slides to the START of section i, pass the first_slide_index of section i (the moved slides become the new first slides of that section, pushing the previous first slide back). Range: [0, slide_count]; passing slide_count appends at the very end.
- after_section_id: ID of an existing section. The moved slides are appended to the END of that section. Pass empty string "" to move the slides to the very beginning of the presentation (start of the first section). Note: appending to section i's end and inserting before section (i+1)'s first slide are NOT the same — the former binds to section i, the latter binds to section (i+1). Use slide_get_sections to obtain valid section IDs.
Returns the new total slide count.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_indices (array<integer>): REQUIRED. Non-empty array of 0-based slide indices to move.
  [ ] after_section_id (string): ID of an existing section. The moved slides are appended to the END of that section. Works for both non-empty and EMPTY sections — use after_section_id whenever the target section has no slides yet (empty sections have no first_slide_index, so before_slide_index cannot target them accurately). Pass empty string "" to move slides to the very beginning of the presentation. Mutually exclusive with before_slide_index.
  [ ] before_slide_index (integer): 0-based slide index. The moved slides are inserted right before the slide currently at this index. To move slides to the START of a section, pass that section's first_slide_index (from slide_get_sections). Range: [0, slide_count]; slide_count appends at the very end. Mutually exclusive with after_section_id.
```

---

## slide_remove_anim

```plaintext
# slide_remove_anim

Remove a single animation node from a shape on a slide page. The animation is located by (page_index, shape_id, index) where `index` is its 0-based slot in the default trigger's animation sequence (the same `index` echoed back from a prior `slide_add_anim` call). One MCP call = one SlideCommand = one undo unit / one SSE event. Note: backend dispatches a single RemoveAnimationMutation here; unlike the front-end commit_data sample (set_animation_properties + remove_animation), the editor-sdk does not produce the leading set_animation_properties because the backend applier rejects an empty time_node — the visible effect on the timing tree is identical.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The ID of the shape whose animation is being removed. Must be a non-empty existing shape on the page.
  [✓] index (integer): 0-based animation index in the default trigger's anim_node_list. Use the value previously returned by `slide_add_anim` (or look it up via `slide_get_shape_info`).
```

---

## slide_remove_section_with_slides

```plaintext
# slide_remove_section_with_slides

Remove a section AND all its slides in one atomic command. The section and every slide that belongs to it are removed together as a single undo unit. Use slide_get_sections first to obtain the section_id.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] section_id (string): The ID of the section to remove along with its slides.
```

---

## slide_remove_sections

```plaintext
# slide_remove_sections

Remove one or more sections by their IDs. The slides inside the removed sections are NOT deleted — they are absorbed into the preceding section. Use slide_get_sections first to obtain valid section_ids.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] section_ids (array<string>): Array of section IDs to remove. Must be non-empty.
```

---

## slide_remove_shapes

```plaintext
# slide_remove_shapes

Remove (delete) one or more shapes from a slide page. Provide the page index and the IDs of shapes to remove. Use slide_get_info first to discover available shape IDs.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_ids (array<string>): Array of shape IDs to remove.
```

---

## slide_remove_slide

```plaintext
# slide_remove_slide

Remove (delete) a slide page from the presentation. Provide the 0-based index of the slide to remove.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the slide to remove.
```

---

## slide_rename_section

```plaintext
# slide_rename_section

Rename an existing section (update its display name).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] section_id (string): ID of the section to rename.
  [✓] name (string): New name for the section.
```

---

## slide_reorder_shape

```plaintext
# slide_reorder_shape

Change the Z-order (stacking order) of shapes on a slide. Supports four operations: send to back, send backward, bring forward, bring to front. Accepts one or more shape IDs to reorder together.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_ids (array<string>): Array of shape IDs to reorder.
  [✓] op (integer): Reorder operation: 0 = send to back (置于底层), 1 = send backward (下移一层), 2 = bring forward (上移一层), 3 = bring to front (置于顶层).
```

---

## slide_reorder_shapes_in_group

```plaintext
# slide_reorder_shapes_in_group

Reorder child shapes inside a group to a new z-order position. Moves all shapes in shape_ids to to_index within the group identified by group_id, preserving their relative order among themselves. All shape_ids must be direct children of the specified group.

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] group_id (string): The ID of the group shape that owns the child shapes.
  [✓] shape_ids (array<string>): Array of child shape IDs to reorder. All must be direct children of group_id.
  [✓] to_index (integer): Target z-order index (0 = bottom) within the group.
```

---

## slide_set_anim_properties

```plaintext
# slide_set_anim_properties

Replace the TimeNode bound to an existing animation slot on a shape (i.e. change the animation kind / direction without changing its position in the sequence). The animation is located by (page_index, shape_id, index) where `index` is its 0-based slot in the default trigger's animation sequence. The new TimeNode is rebuilt from (anim_type, anim_subtype, shape_id) using the same builder as `slide_add_anim`, so only the animation kinds returned by `slide_list_anim_types` are accepted. One MCP call = one SlideCommand = one undo unit / one SSE event (CommandType=Empty, matching the front-end commit_data sample for set_animation_properties). Cross-trigger replacement is NOT exposed — the trigger is fixed to the default trigger (mainSeq).

参数（✓=必填）：
  [✓] file_id (string): The file_id of the editor to operate on
  [✓] page_index (integer): 0-based index of the target slide page.
  [✓] shape_id (string): The ID of the shape whose animation is being replaced. Must be a non-empty existing shape on the page, and the animation at `index` must currently belong to this shape.
  [✓] index (integer): 0-based animation index in the default trigger's anim_node_list. Must already exist; use `slide_get_shape_info` (or the value previously returned by `slide_add_anim`) to look it up.
  [✓] anim_type (integer): New animation kind, encoded as the integer value of the C++ AnimType enum. Use `slide_list_anim_types` to discover the supported (value, name, description) triples — only those values are accepted here.
  [ ] anim_subtype (integer): Animation direction / sub-kind. Currently consumed by FLY_IN / FLY_OUT only; other anim_types ignore it. Allowed values: 1=RIGHT, 2=TOP, 3=TOP_RIGHT, 4=BOTTOM (default for FLY_IN/OUT when omitted), 6=BOTTOM_LEFT, 8=LEFT, 10=TOP_LEFT, 12=BOTTOM_RIGHT. Pass 0 to fall back to the per-anim default.
```

---

## slide_set_anim_trigger

```plaintext
# slide_set_anim_trigger
