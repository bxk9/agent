---

## 1. 概述

云 VFS 为 Agent 提供会话级虚拟文件系统能力，支持两种接入方式：

| 接入方式 | 协议 | 适用场景 |
| --- | --- | --- |
| **MCP** (Model Context Protocol) | JSON-RPC over HTTP | LLM 直接操作文本文件（读/写/搜索/编辑） |
| **REST** | HTTP/JSON + multipart | Handler 代码上传/下载二进制、签发分享链接 |

### 1.1 资源统一标识

系统内所有文件引用使用统一 URI 格式：

```plaintext
claw://workspace/{agent_id}/{path}
```

- `{agent_id}`：Agent 标识（如 `agent_main`、`agent_code` 等），由系统分配
- `{path}`：文件路径（不含前导 `/`）
示例：

```plaintext
claw://workspace/agent_main/output/report.pdf
claw://workspace/agent_main/imgs/chart_01.png
claw://workspace/agent_code/tmp/draft.txt
```

在调用云 VFS 接口时，`{path}` 部分作为接口中的 `path` 参数传入（以 `/` 开头的绝对路径）。

**URI ↔ 接口路径转换规则**：

```plaintext
claw://workspace/{agent_id}/output/report.pdf
                            └── 接口 path = "/output/report.pdf"
```

### 1.2 会话隔离

- 每个请求必须携带 HTTP 头 `X-Tenant-Id: {sid}`
- `sid` 为会话标识，由云 Agent 侧生成并全链路透传
- 不同 sid 之间严格隔离，互不可见
- sid 字符集：`[A-Za-z0-9_.-]{1,64}`
### 1.3 服务地址

| 环境 | Base URL | 说明 |
| --- | --- | --- |
| 预发（内网） | `http://blueclaw-gateway-test.vivo.lan:8080` | 仅内网可访问 |
| 办公网 / 公网 | `http://blueclaw-gateway-test.vivo.com.cn` | 办公网或外部可访问 |

> 生产环境地址另行通知。

---

## 2. MCP 接口

### 2.1 端点

```plaintext
POST {base_url}/workspace/mcp/
Content-Type: application/json
X-Tenant-Id: {sid}
```

请求体为标准 MCP JSON-RPC 报文（参见 [modelcontextprotocol.io](https://modelcontextprotocol.io)）。

### 2.2 工具列表

| # | 工具名 | 用途 | 关键入参 |
| --- | --- | --- | --- |
| 1 | `vfs_list_dir` | 列目录 | `path`, `recursive`, `max_items` |
| 2 | `vfs_read_file` | 读文本文件（UTF-8） | `path`, `max_lines`, `read_from_end` |
| 3 | `vfs_write_file` | 写文本文件（UTF-8） | `path`, `content`, `overwrite`, `append` |
| 4 | `vfs_edit_file` | 精确字符串替换 | `path`, `old_string`, `new_string`, `replace_all` |
| 5 | `vfs_delete_file` | 删除文件/目录 | `path`, `recursive` |
| 6 | `vfs_move_file` | 移动/重命名 | `path`, `to`, `overwrite` |
| 7 | `vfs_file_glob` | 按文件名通配符搜索 | `path`, `pattern`, `max_results` |
| 8 | `vfs_file_grep` | 按内容字面量搜索 | `path`, `query`, `file_pattern`, `max_results` |
| 9 | `vfs_file_stat` | 获取文件元数据 | `path` |
| 10 | `vfs_get_share_url` | 签发临时下载链接 | `path`, `ttl` |

> 注：`vfs_get_share_url` 仅用于向**外部渠道**（浏览器、邮件、微信等无法解析 `claw://` 的消费端）签发 HTTPS 下载链接。Agent 系统之间传递文件引用应直接使用 `claw://workspace/{agent_id}/{path}` URI。

### 2.3 工具详细 Schema

#### 2.3.1 vfs_list_dir

列出指定目录下的文件和子目录。

**输入**

```json
{
  "path": "/output",
  "recursive": false,
  "max_items": 100
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | - | 目录绝对路径（以 `/` 开头） |
| `recursive` | boolean | 否 | `false` | 是否递归展开子目录 |
| `max_items` | integer | 否 | `100` | 最大返回条目数 |

**输出**

```json
{
  "path": "/output",
  "recursive": false,
  "total": 3,
  "returned": 3,
  "truncated": false,
  "entries": [
    { "path": "/output/report.pdf", "is_dir": false, "size": 28341, "modified_at": "2026-05-25T08:00:00+00:00" },
    { "path": "/output/summary.md", "is_dir": false, "size": 512, "modified_at": "2026-05-25T08:01:00+00:00" },
    { "path": "/output/charts", "is_dir": true, "size": null, "modified_at": null }
  ]
}
```

---

#### 2.3.2 vfs_read_file

读取 UTF-8 文本文件内容。**仅支持文本文件**，二进制文件会报错。

**输入**

```json
{
  "path": "/output/summary.md",
  "max_lines": 200,
  "read_from_end": false
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | - | 文件绝对路径 |
| `max_lines` | integer | 否 | `200` | 最大返回行数 |
| `read_from_end` | boolean | 否 | `false` | `true` = tail 模式（从末尾读） |

**输出**

```json
{
  "path": "/output/summary.md",
  "encoding": "utf-8",
  "modified_at": "2026-05-25T08:01:00+00:00",
  "total_lines": 25,
  "returned_lines": 25,
  "from_end": false,
  "content": "# 月度总结\n\n## 要点\n..."
}
```

**错误场景**

| 情况 | 错误信息 |
| --- | --- |
| 文件不存在 | `File '/xxx' not found` |
| 二进制文件 | `二进制读写不通过 MCP 暴露给 LLM...`（引导使用 REST 接口） |

---

#### 2.3.3 vfs_write_file

创建或写入 UTF-8 文本文件。

**输入**

```json
{
  "path": "/output/notes.md",
  "content": "# 今日笔记\n\n- 要点一\n- 要点二\n",
  "overwrite": false,
  "append": false
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | - | 目标文件绝对路径 |
| `content` | string | 是 | - | UTF-8 文本内容 |
| `overwrite` | boolean | 否 | `false` | `true` = 允许覆盖已存在文件 |
| `append` | boolean | 否 | `false` | `true` = 追加到末尾（隐含 overwrite） |

**输出**

```json
{
  "path": "/output/notes.md",
  "size": 48,
  "encoding": "utf-8",
  "append": false,
  "overwrite": false
}
```

> 写入成功后返回 `path`。若需分享链接，请调用 `vfs_get_share_url`。

**错误场景**

| 情况 | 错误信息 |
| --- | --- |
| 文件已存在且未带 `overwrite=true` | `File '/xxx' already exists` |

---

#### 2.3.4 vfs_edit_file

对已有文件执行精确字符串替换。

**输入**

```json
{
  "path": "/output/notes.md",
  "old_string": "要点一",
  "new_string": "要点一（已完成）",
  "replace_all": false
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | - | 目标文件绝对路径 |
| `old_string` | string | 是 | - | 被替换的原文（逐字符精确匹配，含缩进换行） |
| `new_string` | string | 是 | - | 替换后的新文本 |
| `replace_all` | boolean | 否 | `false` | `false` 时 `old_string` 必须在文件中唯一出现 |

**输出**

```json
{
  "path": "/output/notes.md",
  "occurrences": 1
}
```

**错误场景**

| 情况 | 错误信息 |
| --- | --- |
| 文件不存在 | `File '/xxx' not found` |
| old_string 未匹配 | `old_string not found in '/xxx'` |
| 多处匹配但 replace_all=false | `old_string is not unique (3 matches)` |

---

#### 2.3.5 vfs_delete_file

删除文件或目录。

**输入**

```json
{
  "path": "/tmp/draft.txt",
  "recursive": false
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | - | 目标绝对路径 |
| `recursive` | boolean | 否 | `false` | `true` = 允许删非空目录 |

**输出**

```json
{
  "path": "/tmp/draft.txt",
  "removed": 1
}
```

---

#### 2.3.6 vfs_move_file

移动或重命名文件/目录。

**输入**

```json
{
  "path": "/tmp/draft.md",
  "to": "/output/final.md",
  "overwrite": false
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | - | 源路径 |
| `to` | string | 是 | - | 目标路径 |
| `overwrite` | boolean | 否 | `false` | `true` = 允许覆盖目标 |

**输出**

```json
{
  "path": "/tmp/draft.md",
  "to": "/output/final.md",
  "moved": true
}
```

---

#### 2.3.7 vfs_file_glob

按 glob 模式搜索文件名。支持 `*`（单层）、`**`（跨层）、`?`（单字符）。

**输入**

```json
{
  "path": "/",
  "pattern": "**/*.pdf",
  "max_results": 100
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | - | 搜索起始目录 |
| `pattern` | string | 是 | - | glob 表达式 |
| `max_results` | integer | 否 | `100` | 最大返回数 |

**输出**

```json
{
  "matches": [
    { "path": "/output/report.pdf", "is_dir": false, "size": 28341, "modified_at": "..." }
  ],
  "total": 1,
  "truncated": false
}
```

---

#### 2.3.8 vfs_file_grep

在文件内容中搜索字面量文本。

**输入**

```json
{
  "path": "/output",
  "query": "月度",
  "file_pattern": "*.md",
  "max_results": 50
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | - | 搜索起始目录 |
| `query` | string | 是 | - | 搜索的字面量字符串（非正则） |
| `file_pattern` | string | 否 | - | 可选文件名过滤（如 `*.md`） |
| `max_results` | integer | 否 | `50` | 最大返回匹配数 |

**输出**

```json
{
  "matches": [
    { "path": "/output/summary.md", "line": 1, "text": "# 月度总结" }
  ],
  "total": 1,
  "truncated": false
}
```

> `line` 为 1-indexed。

---

#### 2.3.9 vfs_file_stat

获取文件或目录元数据。

**输入**

```json
{
  "path": "/output/report.pdf"
}
```

**输出**

```json
{
  "info": {
    "path": "/output/report.pdf",
    "is_dir": false,
    "size": 28341,
    "modified_at": "2026-05-25T08:00:00+00:00"
  }
}
```

---

#### 2.3.10 vfs_get_share_url

为已有文件签发临时可访问的 HTTPS 下载链接。

**输入**

```json
{
  "path": "/output/report.pdf",
  "ttl": 86400
}
```

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `path` | string | 是 | - | 目标文件绝对路径 |
| `ttl` | integer | 否 | 服务端默认（7天） | URL 有效期（秒），上限 30 天 |

**输出**

```json
{
  "path": "/output/report.pdf",
  "url": "https://vfs.example.com/workspace/blob/eyJl...",
  "expires_at": "2026-05-26T08:00:00+00:00",
  "ttl": 86400
}
```

---

### 2.4 MCP 错误约定
