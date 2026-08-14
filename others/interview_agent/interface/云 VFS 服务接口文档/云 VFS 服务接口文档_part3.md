  -d '{"path": "/output/hello.txt", "content": "hello world"}'

# 2) 读文本
curl -X POST $BASE/workspace/read_file \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: $SID" \
  -d '{"path": "/output/hello.txt"}'

# 3) 上传二进制
curl -X POST $BASE/workspace/upload \
  -H "X-Tenant-Id: $SID" \
  -F "file=@./chart.png" \
  -F "path=/imgs/chart.png" \
  -F "overwrite=true"

# 4) 用返回的 url 直接下载（无需任何 header）
curl -OJ "https://vfs.example.com/workspace/blob/eyJl..."

# 5) 列目录
curl -X POST $BASE/workspace/ls \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: $SID" \
  -d '{"path": "/"}'
```

---

## 10. System Prompt 推荐片段

以下是建议嵌入 LLM System Prompt 的文件系统操作指引。云 Agent 团队可根据实际场景裁剪。

```markdown
## 文件系统（云 VFS）

你拥有一个会话级虚拟文件系统，通过以下 MCP 工具操作：

| 工具 | 用途 |
|------|------|
| `vfs_list_dir` | 列目录 |
| `vfs_read_file` | 读文本文件 |
| `vfs_write_file` | 写/创建文本文件 |
| `vfs_edit_file` | 精确替换已有文件中的文本片段 |
| `vfs_delete_file` | 删除文件/目录 |
| `vfs_move_file` | 移动/重命名 |
| `vfs_file_glob` | 按文件名模式搜索 |
| `vfs_file_grep` | 按内容搜索 |
| `vfs_file_stat` | 获取文件元数据 |
| `vfs_get_share_url` | 签发临时 HTTPS 下载链接（仅用于发给浏览器/邮件/微信等外部渠道） |

### 路径规范
- 所有路径以 `/` 开头（虚拟绝对路径）
- 推荐目录：`/output/`（最终产物）、`/imgs/`（图片）、`/tmp/`（临时文件，会被清理）
- 不允许 `..`

### 文件引用
- 在 Agent 系统内部引用文件时，使用统一 URI：`claw://workspace/{agent_id}/{path}`
- 示例：`claw://workspace/agent_main/output/report.pdf`
- **不要**在 Agent 之间传递签名 URL；签名 URL 仅用于无法解析 claw:// 的外部消费端

### 二进制文件
- MCP 工具仅处理 UTF-8 文本
- 二进制文件（PDF/图片等）由 Handler 通过 REST 接口上传，你只需知道其 `claw://` URI
- 若需要将二进制文件发送给用户（浏览器等），调用 `vfs_get_share_url` 获取临时链接

### 写入注意事项
- `vfs_write_file`：默认不覆盖已有文件，需设 `overwrite: true`
- `vfs_edit_file`：用于小范围精确替换，`old_string` 必须在文件中唯一匹配
- 写入后如需告知其他 Agent，传递 `claw://` URI 即可
```

> **定制建议**：

- 若 Agent 不需要搜索能力，可移除 `vfs_file_glob` / `vfs_file_grep` 行
- 若 Agent 不涉及对外分享，可移除 `vfs_get_share_url` 行
- `{agent_id}` 替换为系统实际分配给该 Agent 的标识