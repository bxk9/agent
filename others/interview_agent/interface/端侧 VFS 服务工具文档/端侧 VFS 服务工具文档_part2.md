按 glob 模式递归搜索文件名。支持 `**`（跨层目录）、`*`（单层）、`?`（单字符）。

**输入**

```json
{
  "dir_path": "claw://workspace/agent_main/",
  "pattern": "**/*.pdf",
  "max_results": 100
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `dir_path` | string | 是 | — | 搜索起始目录 |
| `pattern` | string | 是 | — | glob 表达式 |
| `max_results` | integer | 否 | `100` | 最大返回数 |

**输出**

```
--- glob [**/*.pdf] in [claw://workspace/agent_main/] ---
匹配 2 项

claw://workspace/agent_main/output/report.pdf (28341B)
claw://workspace/agent_main/docs/spec.pdf (15200B)
```

---

### 3.7 file_grep

在文件内容中搜索字面量文本。

**输入**

```json
{
  "dir_path": "claw://workspace/agent_main/",
  "query": "月度",
  "file_pattern": "*.md",
  "max_results": 50
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `dir_path` | string | 是 | — | 搜索起始目录 |
| `query` | string | 是 | — | 搜索的字面量字符串（非正则） |
| `file_pattern` | string | 否 | — | 可选文件名过滤（如 `*.md`） |
| `max_results` | integer | 否 | `50` | 最大匹配行数 |

**输出**

```
--- grep [月度] in [claw://workspace/agent_main/] ---
匹配 2 行

claw://workspace/agent_main/output/notes.md:
  1: # 月度总结
  15: 本月度完成了...
```

> 行号为 1-indexed。结果按文件分组显示。

---

### 3.8 file_stat

获取文件或目录的元数据。

**输入**

```json
{
  "path": "claw://workspace/agent_main/output/report.pdf"
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | — | 目标文件或目录路径 |

**输出**

```
--- stat [claw://workspace/agent_main/output/report.pdf] ---
名称: report.pdf
类型: 文件
大小: 27.7 KB
MIME: application/pdf
修改时间: 2026-05-25 08:00:22
权限: read, write
URI: claw://workspace/agent_main/output/report.pdf
```

---

## 4. 路径规范

### 4.1 规则

- `claw://` URI 路径部分大小写敏感
- 不允许 `..` 段（安全管控拦截）
- 文件名字符集：`[A-Za-z0-9._\-\u4e00-\u9fa5]+`（支持中文）
- 传统绝对路径（`/sdcard/...`）自动映射为 `claw://local/` URI

### 4.2 路径自动解析

| 输入格式 | 解析结果 |
| --- | --- |
| `claw://local/blueclaw/test.txt` | 原样使用 |
| `/sdcard/blueclaw/test.txt` | → `claw://local/blueclaw/test.txt` |
| `/sdcard/Download/file.pdf` | → `claw://local/Download/file.pdf` |
| `claw://workspace/agent_main/file.md` | 原样使用 |
| `https://example.com/file.pdf` | 下载后临时存储 |

### 4.3 推荐目录结构

```plaintext
claw://workspace/{agent_id}/
├── output/          最终产物（报告、总结、生成文件）
├── docs/            文档类文件
├── uploads/         上传到云端的文件（read_file 自动上传二进制时使用）
└── tmp/             临时中间文件

claw://local/blueclaw/
├── output/          用户明确要求保存的文件
├── workspace/       workspace 本地缓存
└── {module}/        各模块私有存储
```

### 4.4 URI ↔ 设备路径映射

| URI | 设备路径 / 后端 | 说明 |
| --- | --- | --- |
| `claw://local/{path}` | `/sdcard/blueclaw/{path}` | 设备公共存储，其他应用可见 |
| `claw://workspace/{id}/{path}` | `/sdcard/blueclaw/workspace/{id}/{path}`（公共）<br>`/data/data/com.vivo.ai.gptagent/files/workspace/{id}/{path}`（私有加密） | 公共模式：用户/小V可直接访问<br>私有模式：锁屏加密目录，仅本应用可读 |
| `claw://workspace.cloud/{id}/{path}` | 云端 OSS：`https://vfs-api.example.com/workspace/{id}/{path}` | 跳过本地缓存，直连云端读写 |
| `claw://temp/{scope}/{path}` | `/sdcard/blueclaw/.temp/{scope}/{path}` | 临时文件，scope 结束自动清理 |
| `claw://content/{provider}/{path}` | Android ContentResolver：`content://{provider}/{path}` | 访问系统 ContentProvider（相册/文档等） |
| `claw://pc/{device_id}/{path}` | 局域网 HTTP：`http://{device_ip}:{port}/vfs/{path}` | PC 远程文件，通过局域网直连 |

**绝对路径自动映射规则**

| 输入路径 | 映射后 URI | 说明 |
| --- | --- | --- |
| `/sdcard/{path}` | `claw://local/{path}` | blueclaw 根目录下的文件 |
| `/sdcard/Download/{path}` | `claw://local/Download/{path}` | 下载目录 |
| `/sdcard/DCIM/{path}` | `claw://local/DCIM/{path}` | 相册目录 |
| `/sdcard/Documents/{path}` | `claw://local/Documents/{path}` | 文档目录 |
| `/sdcard/Pictures/{path}` | `claw://local/Pictures/{path}` | 图片目录 |
| `/sdcard/Movies/{path}` | `claw://local/Movies/{path}` | 视频目录 |
| `/sdcard/Music/{path}` | `claw://local/Music/{path}` | 音乐目录 |
| `/storage/emulated/0/{path}` | `claw://local/{path}` | 内部存储等价映射 |

**跨模块访问转换**

```plaintext
小V/外部应用 访问 workspace 文件：
  claw://workspace/{id}/{path}
    → claw://local/workspace/{id}/{path}        （转为公共路径供外部读取）
    → /sdcard/blueclaw/workspace/{id}/{path}    （实际设备路径）
    → file:///sdcard/blueclaw/workspace/...     （file URI，供 Intent 传递）
    → content://com.vivo.ai.gptagent.vfs/{path} （ContentProvider 对外暴露）

云端同步链接：
  claw://workspace/{id}/{path}?sync=on
    → 本地写入 + 异步上传 OSS
    → 返回 download_url: https://vfs-cdn.example.com/blob/{token}
```

---

## 5. 安全管控

### 5.1 SecurityGate

每次 VFS 操作前经过 `VFSSecurityGate` 检查：

| 检查项 | 说明 |
| --- | --- |
| 路径遍历 | 拒绝 `..` 段 |
| 范围隔离 | Tool 只能访问其 `FileAccessManifest` 声明的路径 |
| 敏感目录 | `/data/data/`、`/system/` 等系统目录禁止访问 |
| 大小限制 | 写入操作检查磁盘空间 |

### 5.2 风险等级

| 工具 | 风险等级 | 说明 |
| --- | --- | --- |
| `read_file` | 动态评估 | 本地敏感路径为 HIGH，workspace/temp 为 LOW |
| `write_file` | HIGH | 所有写入操作固定 HIGH |
| `edit_file` | 动态评估 | 同 read_file 路径风险规则 |
| `save_file` | HIGH | 写入用户可见目录固定 HIGH |
| `list_dir` | 动态评估 | 按路径风险评估 |
| `file_glob` | 动态评估 | 按路径风险评估 |
| `file_grep` | 动态评估 | 按路径风险评估 |
| `file_stat` | 动态评估 | 按路径风险评估 |

---

## 6. 与云 VFS 的差异对比

| 能力 | 端侧 VFS | 云 VFS | 说明 |
| --- | --- | --- | --- |
| 文本读写 | ✅ | ✅ | 参数基本一致 |
| 图片直接分析 | ✅ 自动注入视觉上下文 | ❌ 仅返回二进制错误 | 端侧有 VLM 能力 |
| 二进制上传 | ✅ write_file + base64 | ✅ REST multipart | 协议不同 |
| 保存到用户目录 | ✅ save_file | ❌ 不适用 | 端侧独有 |
| 签名下载链接 | ✅ workspace sync 后自动返回 | ✅ vfs_get_share_url | 端侧通过同步获取 |
| 移动/重命名 | ❌ 暂未实现 | ✅ vfs_move_file | 计划 Wave 2 补齐 |
| 删除文件 | ❌ 暂未实现 | ✅ vfs_delete_file | 计划 Wave 2 补齐 |
| HTTP URL 下载 | ✅ read_file 直接支持 | ❌ 不支持 | 端侧独有 |
| 沙箱执行 | ❌ 不适用 | ✅ /workspace/execute | 云端独有 |

---

## 7. 限额与配置

| 项 | 默认值 | 说明 |
| --- | --- | --- |
| `read_file` 默认行数 | 150 行 | 可通过 `max_lines` 调整 |
| `list_dir` 默认条目 | 100 条 | 可通过 `max_items` 调整 |
| `file_glob` 默认结果 | 100 条 | 可通过 `max_results` 调整 |
| `file_grep` 默认结果 | 50 条 | 可通过 `max_results` 调整 |
| 图片压缩上限 | 300 KB | JPEG 渐进压缩（质量 85→20） |
| workspace 存储上限 | 由设备存储决定 | 无硬性限制 |
| temp 文件 TTL | 任务/会话结束 | TempFSCleaner 自动清理 |
| workspace.cloud 单文件上限 | 50 MiB | 与云 VFS 一致 |

---

## 8. 使用建议

### 8.1 读取策略

- **文本文件**：直接读取，大文件用 `max_lines` 分段读
- **图片文件**：`read_file` 自动压缩+注入视觉上下文，无需额外处理
- **二进制文件**：`read_file` 自动上传 workspace 并返回下载链接，Agent 不直接处理字节

### 8.2 写入策略

- 中间产物写入 `claw://temp/{scopeId}/`（自动清理）
- 最终产物写入 `claw://workspace/{agentId}/output/`（持久保存）
- 需要跨设备/跨 Agent 共享时使用 `claw://workspace.cloud/` 或 `?sync=on`
- 用户明确要求"保存到手机"时使用 `save_file`（自动分类到相册/文档/下载）

### 8.3 搜索策略

- 已知文件名/类型 → `file_glob`（如 `**/*.pdf`）
- 已知内容关键词 → `file_grep`（如搜索"报错信息"）
- 浏览目录结构 → `list_dir`
- 检查文件是否存在 → `file_stat`

### 8.4 端云协作

```
端侧 Agent 产出文件 → write_file 到 workspace.cloud → 云 Agent 通过 claw://workspace/ 读取
云端 Agent 产出文件 → 端侧通过 read_file 读取 claw://workspace.cloud/ → 自动下载
```

---

## 9. System Prompt 推荐片段

以下是建议嵌入端侧 Agent System Prompt 的文件系统操作指引：

```markdown
## 文件系统（端侧 VFS）

你拥有一个设备级虚拟文件系统，通过以下工具操作：

| 工具 | 用途 |
|------|------|
| `read_file` | 读取文件（文本返回内容、图片自动分析、二进制上传后返回链接） |
| `write_file` | 创建/写入文件（支持文本和 base64 二进制） |
| `edit_file` | 精确替换已有文件中的文本片段 |
| `save_file` | 保存到用户可见位置（相册/文档/下载） |
| `list_dir` | 列目录 |
| `file_glob` | 按文件名模式搜索 |
| `file_grep` | 按内容搜索 |
| `file_stat` | 获取文件元数据 |

### 路径规范
- 使用 claw:// URI：`claw://workspace/{agent_id}/{path}`（持久）、`claw://temp/{scope}/{path}`（临时）
- 也支持绝对路径如 /sdcard/Download/file.txt（自动转换为 claw://）
- 不允许 `..`

### 文件引用
- Agent 之间传递文件使用 `claw://` URI