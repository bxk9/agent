MCP 工具调用失败时，响应的 `isError=true`，`content` 中包含错误文本描述。对接方无需解析 HTTP 状态码，只需判断 MCP 响应中的 `isError` 字段。

---

## 3. REST 接口

以下 HTTP 接口用于 **Handler 代码**（非 LLM）操作二进制文件和签发链接。

### 3.1 通用约定

- Base URL：参见 §1.3 服务地址
- 必填头：`X-Tenant-Id: {sid}`
- 缺失或为空 → HTTP `400`
- 响应模型（除 `/workspace/blob` 直接返回字节外）：
```json
{
  "<业务字段>": "...",
  "error": null
}
```

- 成功：`error == null`
- 业务失败：HTTP `200` + `error` 为非空字符串
- 协议失败：HTTP `4xx/5xx` + `{ "detail": "..." }`
### 3.2 POST /workspace/upload — 二进制文件上传

上传任意二进制文件，返回文件路径和签名下载 URL。

**Content-Type**：`multipart/form-data`

**表单字段**

| 字段 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `file` | file | 是 | - | 二进制文件 |
| `path` | string | 否 | `/uploads/<uuid>.<ext>` | 目标绝对路径（建议显式指定） |
| `overwrite` | boolean | 否 | `false` | `true` 允许覆盖同名文件 |
| `ttl` | integer | 否 | `604800`（7天） | 返回 URL 有效期（秒），上限 30 天 |

**成功响应** `200`

```json
{
  "path": "/output/report.pdf",
  "size": 28341,
  "mime": "application/pdf",
  "sha256": "9b74c9897bac770ffc029102a200c5de...",
  "url": "https://vfs.example.com/workspace/blob/eyJl...",
  "expires_at": "2026-06-01T08:00:00+00:00",
  "error": null
}
```

**错误码**

| HTTP | 触发条件 |
| --- | --- |
| `400` | 缺失 `X-Tenant-Id` / `path` 格式非法 |
| `409` | `path` 已存在且未设 `overwrite=true` |
| `413` | 超过单文件上限（默认 50 MiB） |
| `501` | 服务端未配置签名密钥 |

**curl 示例**

```bash
curl -X POST http://blueclaw-gateway-test.vivo.com.cn/workspace/upload \
  -H "X-Tenant-Id: sid_abc123" \
  -F "file=@./report.pdf" \
  -F "path=/output/report.pdf" \
  -F "overwrite=true"
```

**上传后构造 claw URI**：

```plaintext
响应 path = "/output/report.pdf"
→ claw://workspace/{agent_id}/output/report.pdf
```

---

### 3.3 GET /workspace/blob/{token} — 签名 URL 下载

将 `/workspace/upload` 或 `get_share_url` 返回的 `url` 直接 GET，即可下载文件字节。

**特性**：

- ❌ **不需要** `X-Tenant-Id` 头（身份已编入 token）
- ✅ HMAC-SHA256 防篡改
- ⏰ 有时效（默认 7 天，最大 30 天）
- 🔁 无状态（服务端不保存 token，重启后 URL 仍有效）
**响应**

| HTTP | 含义 |
| --- | --- |
| `200` | 返回二进制流 + `Content-Type` + `Content-Disposition` |
| `403` | token 非法 / 已过期 / 签名错误 |
| `404` | token 合法但文件已被删除 |

**curl 示例**

```bash
curl -OJ "http://blueclaw-gateway-test.vivo.com.cn/workspace/blob/eyJlIjoxNzc5OTQ4..."
```

---

### 3.4 GET /workspace/download — 直接下载文件

按 `X-Tenant-Id` + `path` 直接下载文件原始字节，无需预签 URL。适用于系统内部 Agent/Handler 之间拉取文件。

**Query 参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `path` | string | 是 | 文件绝对路径（以 `/` 开头） |

**必填 Header**：`X-Tenant-Id: {sid}`

**响应**

| HTTP | 含义 |
| --- | --- |
| `200` | 返回二进制流 + `Content-Type` + `Content-Disposition` |
| `400` | 缺失 `X-Tenant-Id` / `path` 格式非法 |
| `404` | 文件不存在 |
| `501` | 后端不支持二进制读取 |

**curl 示例**

```bash
curl -OJ "http://blueclaw-gateway-test.vivo.com.cn/workspace/download?path=/output/report.pdf" \
  -H "X-Tenant-Id: test_session_001"
```

**与 **`**/workspace/blob/{token}**`** 的区别**

|  | `/workspace/download` | `/workspace/blob/{token}` |
| --- | --- | --- |
| 认证 | `X-Tenant-Id` Header | token 自带身份 |
| 场景 | 内部系统间拉文件 | 外部消费端（浏览器/邮件） |
| 预签 | 不需要 | 需要先调 share_url/upload |

---

### 3.5 其他 REST 端点一览

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/workspace/read_file` | 读文本文件（JSON body: `path`, `offset`, `limit`） |
| POST | `/workspace/write_file` | 写文本文件（JSON body: `path`, `content`） |
| POST | `/workspace/share_url` | 事后补签下载 URL（JSON body: `path`, `ttl`） |
| POST | `/workspace/ls` | 列目录 |
| POST | `/workspace/edit_file` | 精确字符串替换 |
| POST | `/workspace/glob` | glob 搜索 |
| POST | `/workspace/grep` | 内容搜索 |
| POST | `/workspace/stat` | 文件元数据 |
| POST | `/workspace/execute` | 沙箱执行命令（需白名单授权） |
| GET | `/health` | 健康检查 |

> 这些端点的请求/响应格式与 MCP 工具参数一一对应，字段名相同。具体 schema 参见 §2.3 各工具详述。

---

## 4. 路径规范

### 4.1 规则

- 必须以 `/` 开头（绝对虚拟路径）
- 不允许 `..` 段
- 大小写敏感
- 文件名字符集：`[A-Za-z0-9._-]+`
### 4.2 推荐目录结构

```plaintext
/
├── output/          最终产物（PDF、图片、报告）
├── imgs/            图片类文件
├── input/           用户上传的原始素材
└── tmp/             临时文件（短 TTL，会被自动清理）
```

### 4.3 URI 转换

```python
# claw URI → 接口 path
def claw_to_path(uri: str) -> str:
    # uri = "claw://workspace/{agent_id}/output/report.pdf"
    # 去掉 scheme + workspace + agent_id 前三段，保留路径部分
    parts = uri.split("/", 4)  # ['claw:', '', 'workspace', '{agent_id}', 'output/report.pdf']
    return "/" + parts[4]  # → "/output/report.pdf"

# 接口 path → claw URI
def path_to_claw(agent_id: str, path: str) -> str:
    # path = "/output/report.pdf"
    return f"claw://workspace/{agent_id}{path}"
```

---

## 5. HTTP 状态码汇总

| 状态码 | 含义 |
| --- | --- |
| `200` | 请求合法（业务成败由 body `error` 字段区分） |
| `400` | 参数非法 / 缺失 `X-Tenant-Id` / path 格式错误 |
| `403` | 签名 URL token 无效或过期 |
| `404` | `/workspace/blob` 文件已被删除 |
| `409` | `/workspace/upload` 路径冲突 |
| `413` | 上传超过大小限制 |
| `422` | JSON 字段缺失或类型错误 |
| `500` | 服务端内部错误 |
| `501` | 该能力未启用（如未配置签名密钥） |

---

## 6. 限额与配置

| 项 | 默认值 | 说明 |
| --- | --- | --- |
| 单文件上传上限 | 50 MiB | 超过 → HTTP `413` |
| 签名 URL 默认 TTL | 7 天 |  |
| 签名 URL 最大 TTL | 30 天 | 超过会被截断为 30 天 |
| `vfs_read_file` 默认行数 | 200 行 | MCP；REST 为 2000 行 |
| `vfs_list_dir` 默认条目 | 100 条 |  |
| `vfs_file_grep` 默认结果 | 50 条 |  |
| `tmp/` 目录 TTL | 由部署策略决定 | **不要用于存放最终产物** |

---

## 7. 对接流程

### 7.1 对接前，从云 VFS 团队获取

- 服务 Base URL — 参见 §1.3（预发已就绪，生产另行通知）
- 测试用 sid
- 是否启用签名 URL（决定 `upload` / `blob` / `share_url` / `get_share_url` 是否可用）
- 单文件上传上限（是否需要调整）
- 联调对接人 / 故障联系方式
### 7.2 联调验证用例

| # | 场景 | 预期 |
| --- | --- | --- |
| 1 | `vfs_write_file` 写文本 → `vfs_read_file` 读回 | 内容一致 |
| 2 | `upload` 上传 PDF → 用返回的 `url` GET 下载 | 字节一致 |
| 3 | 同一 path 两次 upload，第二次无 `overwrite=true` | HTTP `409` |
| 4 | 同一 path + `overwrite=true` 再次 upload | `200`，sha256 更新 |
| 5 | sid=A 写的文件，sid=B 读取 | 报错 not found |
| 6 | 上传超限文件（>50 MiB） | HTTP `413` |
| 7 | 篡改 blob URL 中 token 字段后 GET | HTTP `403` |
| 8 | URL 过期后 GET | HTTP `403` |

### 7.3 健康检查

```bash
curl http://blueclaw-gateway-test.vivo.com.cn/health
# → {"status": "ok"}
```

---

## 8. 使用建议

### 8.1 LLM 视野原则

- LLM 可以通过 MCP 直接读写**文本**文件
- LLM **不应**接触二进制内容（bytes / base64）
- 二进制产物由 Handler 通过 REST `upload` 落盘，仅将 `claw://` URI 传入 LLM 上下文
### 8.2 幂等写入

对于可能重试的场景，建议：

- 使用确定性文件名（如基于输入内容的 hash）
- 设 `overwrite=true`
- 确保同一次 Handler 调用不会产生多份冗余文件
### 8.3 临时文件

- 中间产物放 `/tmp/` 目录
- **最终产物必须放 **`**/output/**` —— `tmp` 会被定期清理

---

## 9. 附录：完整调用示例

### 9.1 Python — Handler 上传二进制并返回 claw URI

```python
import httpx

VFS_BASE = "http://blueclaw-gateway-test.vivo.com.cn"

async def upload_and_get_uri(sid: str, agent_id: str, pdf_bytes: bytes, filename: str) -> str:
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{VFS_BASE}/workspace/upload",
            headers={"X-Tenant-Id": sid},
            files={"file": (filename, pdf_bytes, "application/pdf")},
            data={"path": f"/output/{filename}", "overwrite": "true"},
        )
        resp.raise_for_status()
        data = resp.json()
        # 构造 claw URI 返回
        return f"claw://workspace/{agent_id}{data['path']}"
```

### 9.2 Python — MCP 客户端调用

```python
from mcp.client.streamable_http import streamablehttp_client
from mcp import ClientSession

async def mcp_write_example(base_url: str, sid: str):
    async with streamablehttp_client(
        f"{base_url}/workspace/mcp/",
        headers={"X-Tenant-Id": sid},
    ) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # 写文件
            result = await session.call_tool("vfs_write_file", {
                "path": "/output/notes.md",
                "content": "# 会议纪要\n\n- 议题一\n- 议题二\n",
            })
            print(result)
```

### 9.3 curl — 完整流程

```bash
SID="test_session_001"
BASE="http://blueclaw-gateway-test.vivo.com.cn"

# 1) 写文本
curl -X POST $BASE/workspace/write_file \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: $SID" \