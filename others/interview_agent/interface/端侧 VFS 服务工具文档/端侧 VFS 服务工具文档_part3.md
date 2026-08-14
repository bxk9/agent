- 需要给用户分享链接时，写入 workspace.cloud 或加 ?sync=on，使用返回的 download_url

### 图片处理
- `read_file` 读取图片时自动压缩并注入视觉上下文，你可以直接分析图片内容
- 无需手动处理 base64 或压缩

### 写入注意事项
- 中间产物 → `claw://temp/{scopeId}/`（自动清理）
- 最终产物 → `claw://workspace/{agentId}/output/`
- 用户说"保存到手机" → 用 `save_file`
- `edit_file` 的 old_string 必须与原文完全一致（含缩进和换行）
```

---

## 10. 附录：端云工具名映射

| 端侧工具名 | 云 VFS MCP 工具名 | 参数差异 |
| --- | --- | --- |
| `read_file` | `vfs_read_file` | 端侧多支持图片/二进制/URL；端侧用 `file_path`，云端用 `path` |
| `write_file` | `vfs_write_file` | 端侧支持 base64+`?upload=true`；端侧用 `file_path`+`append`，云端用 `path`+`overwrite`+`append` |
| `edit_file` | `vfs_edit_file` | 参数一致（`old_string`/`new_string`/`replace_all`） |
| `save_file` | — | 端侧独有 |
| `list_dir` | `vfs_list_dir` | 参数一致 |
| `file_glob` | `vfs_file_glob` | 端侧用 `dir_path`+`pattern`，云端用 `path`+`pattern` |
| `file_grep` | `vfs_file_grep` | 端侧用 `dir_path`+`query`+`file_pattern`，云端用 `path`+`query`+`file_pattern` |
| `file_stat` | `vfs_file_stat` | 参数一致 |
| — | `vfs_delete_file` | 端侧暂未实现 |
| — | `vfs_move_file` | 端侧暂未实现 |
| — | `vfs_get_share_url` | 端侧通过 workspace sync 自动获取 |
