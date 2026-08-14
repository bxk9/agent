---

## 1. 概述

端侧 VFS 为运行在 Android 设备上的 Agent 提供统一虚拟文件系统能力，支持本地文件、云端 workspace、临时文件、ContentResolver 及 PC 远程文件的透明访问。

| 接入方式 | 协议 | 适用场景 |
| --- | --- | --- |
| **Tool 调用** | Agent ReAct 循环内工具调用 | LLM 在推理过程中读/写/搜索/编辑文件 |
| **VFS API** | Kotlin `IClawVFS` 接口 | Handler/模块代码直接操作文件（非 LLM 场景） |

### 1.1 资源统一标识

系统内所有文件引用使用统一 URI 格式：

```plaintext
claw://{authority}/{path}
```

支持的 Authority：

| Authority | 格式 | 说明 |
| --- | --- | --- |
| `local` | `claw://local/{path}` | 设备本地文件（映射到 `/sdcard/blueclaw/`） |
| `workspace` | `claw://workspace/{agent_id}/{path}` | Agent 持久 workspace（本地优先 + 云端异步同步） |
| `workspace.cloud` | `claw://workspace.cloud/{agent_id}/{path}` | 直接读写云端 workspace（跳过本地缓存） |
| `temp` | `claw://temp/{scope_id}/{path}` | 临时文件（任务/会话结束自动清理） |
| `content` | `claw://content/{content_uri}` | Android ContentResolver（相册/文档等） |
| `pc` | `claw://pc/{device_id}/{path}` | PC 远程文件（局域网直连） |

示例：

```plaintext
claw://local/blueclaw/output/report.pdf
claw://workspace/agent_main/docs/meeting_notes.md
claw://workspace.cloud/agent_main/uploads/chart.png
claw://temp/task_abc123/intermediate.json
```

### 1.2 会话隔离

- workspace 按 `agent_id` 隔离，不同 Agent 的 workspace 互不可见
- temp 按 `scope_id` 隔离（通常为 taskId 或 sessionId），作用域结束自动清理
- local 为设备全局共享，通过 `FileAccessManifest` 控制 Tool 可访问范围

### 1.3 与云 VFS 的关系

| 维度 | 端侧 VFS | 云 VFS |
| --- | --- | --- |
| 运行环境 | Android 设备 | 云端服务器 |
| 协议 | Kotlin API + Tool 调用 | MCP JSON-RPC + REST HTTP |
| 会话标识 | agent_id / scope_id | X-Tenant-Id (sid) |
| 存储后端 | 本地文件系统 + 云端同步 | OSS 对象存储 |
| 互通方式 | workspace.cloud Authority ↔ 云端 REST API | — |

**端云互通**：端侧通过 `claw://workspace.cloud/` 写入的文件，云端 Agent 可通过 `claw://workspace/{agent_id}/` 读取（同一 OSS 后端）。

---

## 2. 工具列表

| # | 工具名 | 用途 | 关键入参 |
| --- | --- | --- | --- |
| 1 | `read_file` | 读取文件（文本/图片/二进制） | `file_path`, `max_lines`, `read_from_end` |
| 2 | `write_file` | 创建/覆盖/上传文件 | `file_path`, `content`, `append` |
| 3 | `edit_file` | 精确字符串替换 | `file_path`, `old_string`, `new_string`, `replace_all` |
| 4 | `save_file` | 保存到用户可见位置 | `source_path`, `file_name` |
| 5 | `list_dir` | 列目录 | `dir_path`, `recursive`, `max_items` |
| 6 | `file_glob` | 按文件名通配符搜索 | `dir_path`, `pattern`, `max_results` |
| 7 | `file_grep` | 按内容字面量搜索 | `dir_path`, `query`, `file_pattern`, `max_results` |
| 8 | `file_stat` | 获取文件元数据 | `path` |

---

## 3. 工具详细 Schema

### 3.1 read_file

读取指定路径的文件内容。根据文件类型自动采用不同处理策略：
- **文本文件**：返回 UTF-8 内容（默认前 150 行）
- **图片文件**：压缩后注入视觉上下文，供 Agent 识别分析
- **二进制文件**：上传到 workspace 并返回下载链接

**输入**

```json
{
  "file_path": "claw://workspace/agent_main/docs/report.md",
  "max_lines": 150,
  "read_from_end": false
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `file_path` | string | 是 | — | 文件路径。支持 claw:// URI、绝对路径（/sdcard/...）、http/https URL |
| `max_lines` | integer | 否 | `150` | 最大读取行数 |
| `read_from_end` | boolean | 否 | `false` | `true` = tail 模式（从末尾读） |

**输出（文本文件）**

```
--- 文件 [claw://workspace/agent_main/docs/report.md] ---
总行数: 25 | 显示: 1-25

# 月度总结

## 要点
...
```

**输出（图片文件）**

返回多模态内容：文本描述 + base64 JPEG 图片（压缩至 <300KB），同时上传到 workspace。

```
[ContentItem.Text] "以下是图片内容（已压缩为JPEG）："
[ContentItem.Image] base64 JPEG data
```

**输出（二进制文件）**

```
文件已上传到 workspace。
download_url: https://vfs.example.com/workspace/blob/eyJl...
```

**特殊行为**

| 场景 | 处理方式 |
| --- | --- |
| HTTP/HTTPS URL | 自动下载后按文件类型处理 |
| 图片压缩 | JPEG 质量从 85 递减（步长 10），直到 <300KB，最低 20 |
| 二进制文件（PDF/音视频/压缩包） | 上传到 `claw://workspace/agent_main/uploads/{fileName}?sync=on` 并返回下载链接 |
| 文件不存在 | 返回错误信息 |

**错误场景**

| 情况 | 错误信息 |
| --- | --- |
| 文件不存在 | `执行失败：文件不存在 - {path}` |
| 权限不足 | `执行失败：无读取权限 - {path}` |
| URI 格式非法 | `执行失败：无法解析路径 - {path}` |

---

### 3.2 write_file

创建新文件、覆盖写入或上传文件到云端。支持文本和二进制（base64 编码）。

**输入**

```json
{
  "file_path": "claw://workspace/agent_main/output/notes.md",
  "content": "# 今日笔记\n\n- 要点一\n- 要点二\n",
  "append": false
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `file_path` | string | 是 | — | 目标文件路径（claw:// URI 或绝对路径） |
| `content` | string | 是 | — | 写入的文本内容。二进制文件用 base64 编码并在路径追加 `?upload=true` |
| `append` | boolean | 否 | `false` | `true` = 追加到末尾，`false` = 覆盖写入 |

**输出**

```
成功覆盖写入 48 字符到: claw://workspace/agent_main/output/notes.md (size=48B)
download_url: https://vfs.example.com/workspace/blob/eyJl...
```

> `download_url` 仅在 workspace 启用同步（`?sync=on`）或写入 `workspace.cloud` 时返回。

**二进制上传示例**

```json
{
  "file_path": "claw://workspace.cloud/agent_main/uploads/chart.png?upload=true",
  "content": "iVBORw0KGgoAAAANSUhEUgAA...(base64)...",
  "append": false
}
```

**存储域选择指南**

| 存储域 | URI 前缀 | 适用场景 |
| --- | --- | --- |
| Agent workspace | `claw://workspace/{agentId}/` | Agent 持久数据，加 `?sync=on` 可跨设备同步 |
| 云端 workspace | `claw://workspace.cloud/{agentId}/` | 直接上传云端，供云 Agent 读取 |
| 设备本地 | `claw://local/` | 本地持久存储（`/sdcard/blueclaw/` 下） |
| 临时文件 | `claw://temp/{scopeId}/` | 中间产物，任务结束自动清理 |

**错误场景**

| 情况 | 错误信息 |
| --- | --- |
| 目录不存在 | 自动创建（mkdirs），不报错 |
| 磁盘空间不足 | `执行失败：存储空间不足` |
| 路径非法 | `执行失败：路径格式错误 - {path}` |

---

### 3.3 edit_file

对已有文件执行精确字符串替换。

**输入**

```json
{
  "file_path": "claw://workspace/agent_main/output/notes.md",
  "old_string": "要点一",
  "new_string": "要点一（已完成）",
  "replace_all": false
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `file_path` | string | 是 | — | 目标文件路径（文件必须已存在） |
| `old_string` | string | 是 | — | 被替换的原文（必须与原文完全一致，含缩进换行） |
| `new_string` | string | 是 | — | 替换后的新文本 |
| `replace_all` | boolean | 否 | `false` | `true` = 全部替换，`false` = 仅第一个匹配 |

**输出**

```
成功编辑文件: claw://workspace/agent_main/output/notes.md (增加了 6 字符)。请使用 read_file 确认修改结果。
```

**错误场景**

| 情况 | 错误信息 |
| --- | --- |
| 文件不存在 | `执行失败：文件不存在 - {path}` |
| old_string 未匹配 | `执行失败：在文件中未找到 old_string。请检查缩进、换行、空格是否与原文完全一致。` |
| old_string 为空 | `执行失败：old_string 不能为空` |

---

### 3.4 save_file

保存文件到设备本地用户可见位置（相册/文档/下载目录）。自动按文件类型分类存储。

**输入**

```json
{
  "source_path": "claw://workspace/agent_main/output/report.pdf",
  "file_name": "月度报告.pdf"
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `source_path` | string | 是 | — | 源文件路径。支持 claw:// URI、content://、file:// 或绝对路径 |
| `file_name` | string | 否 | 从源路径解析 | 保存的目标文件名（可选） |

**输出**

```
成功保存文件「月度报告.pdf」到 /sdcard/Documents/BlueClaw/月度报告.pdf (28.3 KB)
```

**自动分类规则**

| 文件类型 | 扩展名 | 目标目录 |
| --- | --- | --- |
| 图片 | jpg, jpeg, png, webp, gif, bmp | `Pictures/BlueClaw/` |
| 视频 | mp4, 3gp, mkv, avi, mov, webm | `Movies/BlueClaw/` |
| 文档 | pdf, doc, docx, xls, xlsx, ppt, pptx, txt, csv, rtf, odt, ods, odp | `Documents/BlueClaw/` |
| 其他 | — | `Download/BlueClaw/` |

**错误场景**

| 情况 | 错误信息 |
| --- | --- |
| 源文件不存在 | `执行失败：读取源文件失败 - {error}` |
| 写入失败 | `执行失败：保存文件失败 - {error}` |
| 无法解析文件名 | 自动生成 `save_{timestamp}.bin` |

---

### 3.5 list_dir

列出指定目录下的文件和子目录。

**输入**

```json
{
  "dir_path": "claw://workspace/agent_main/",
  "recursive": false,
  "max_items": 100
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `dir_path` | string | 是 | — | 目录路径（以 `/` 结尾表示目录） |
| `recursive` | boolean | 否 | `false` | 是否递归展开子目录 |
| `max_items` | integer | 否 | `100` | 最大返回条目数 |

**输出**

```
--- 目录 [claw://workspace/agent_main/] ---
共 5 项（仅显示前 100 项）

[DIR] docs
[DIR] output
[FILE] config.json (512 B)
[FILE] README.md (1.2 KB)
[FILE] todo.txt (256 B)
```

---

### 3.6 file_glob
