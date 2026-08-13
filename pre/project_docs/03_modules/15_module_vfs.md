# 15 · 模块 · VFS 抽象层 `app/vfs/`

## 1. 模块定位

VFS（Virtual File System）层是对 **BlueClaw 云 VFS HTTP API** 的 Python 封装。所有跨请求/跨用户可见的产物（简历 HTML/PDF、报告、录音、头像、AI 标记 JSON、索引）都通过 VFS 落地。跨模块引用一律用 `file_id`（详见 `40_key_conventions.md`）。

一句话：**VFS 是持久层唯一出口**。

## 2. 文件清单

| 文件 | 职责 |
|------|------|
| `client.py` | 底层 HTTP client：上传/下载/移动/删除/存在性；处理鉴权、重试、超时 |
| `tools.py` | 上层便捷 API：`put_json`、`get_json`、`put_text`、`put_bytes`、`ensure_dir` 等 |
| `uri.py` | `vfs://` URI 与实际路径的编解码 |
| `file_id.py` | file_id 生成 / 校验 / 与 URI 的相互转换 |
| `namespace.py` | 命名空间与用户路径规划：`users/{uid}/<domain>/<version>/<filename>` |
| `pdf_augment.py` | PDF 附加处理（水印/加密/合并/元信息，视需要） |
| `__init__.py` | 对外仅导出 `client`、`tools`、`uri`、`file_id`、`namespace` |

## 3. 对外契约

```python
from app.vfs import tools as vfs_tools
from app.vfs.namespace import build_user_path
from app.vfs.file_id import to_file_id

path = build_user_path(user_id, domain="resume", version="v3", name="my_resume.html")
file_id = to_file_id(await vfs_tools.put_text(path, html_str))

# 读取
html = await vfs_tools.get_text_by_file_id(file_id)
json_obj = await vfs_tools.get_json_by_file_id(file_id)
```

主要 API：

| API | 用途 |
|-----|------|
| `put_text(path, text)` / `put_json(path, obj)` / `put_bytes(path, data)` | 上传 |
| `get_text_by_file_id(fid)` / `get_json_by_file_id(fid)` / `get_bytes_by_file_id(fid)` | 下载 |
| `exists(path)` / `list_dir(prefix)` / `move(src, dst)` / `delete(path)` | 管理 |
| `build_user_path(uid, domain, version, name)` | 生成路径 |
| `to_file_id(path)` / `from_file_id(fid)` | id 编解码 |

## 4. 核心设计理念（模块级）

1. **user_id 是路径前缀，不进 body**  
   `users/{uid}/...` 天然实现用户隔离；不依赖后端权限中间件也能保证"看不到别人的路径"。

2. **file_id 是不可变引用**  
   前后端、跨模块传递一律 `file_id`；即使后台移动了实际路径（例如重命名 domain），`file_id` 保持稳定。

3. **不做本地缓存**  
   本层只是**代理**。缓存策略下沉给业务：
   - 简历相关走 `utils/recent_resume_cache.py`（进程内、会话内）；
   - 素材库自带懒加载（`memory/master_profile/`）。

4. **同步语义 + 异步实现**  
   API 全部 `async`（因为底层 HTTP），但**语义**保持"上传成功即持久化"，不返回后台任务 ID。

5. **domain 是软约定，不做 schema 强校验**  
   `resume / report / recording / master_profile / marks / …` 每个业务自行约定；VFS 只保证路径唯一。

## 5. 命名空间约定

```
users/{uid}/
  resume/
    v{N}/                       # 版本号
      raw.pdf                   # 原始上传
      parsed.txt                # 上游解析文本
      parsed.html               # 上游解析 HTML
      schema.json               # 中间层结构化数据
      final_sidebar.html/pdf    # 各模板渲染产物
      final_docx.docx
      final_rebuilt.html/pdf
  resume_index.json             # 用户简历版本索引
  master_profile.json           # 素材库
  marks/{person_id}.json        # AI 标记（跨轮持久化）
  error_book/
    index.json
    q_{qid}.json
  review_reports/
    index.json
    r_{rid}.html
  voice_sessions/
    s_{sid}/                    # 语音面试单场
      record.txt / .md
      audio_{i}.pcm             # 若开启录音
```

## 6. 典型调用链

```
tool: resume_export.export_pdf
  ↓
  html_bytes = vfs.get_bytes_by_file_id(html_fid)
  pdf = html_to_pdf(html_bytes)
  path = namespace.build_user_path(uid, "resume", "v3", "final_sidebar.pdf")
  pdf_fid = to_file_id(await vfs_tools.put_bytes(path, pdf))
  return {"pdf_file_id": pdf_fid}
  ↓
memory.resume_index.append({"version": 3, "pdf_file_id": pdf_fid, ...})
```

## 7. 扩展点与注意事项

| 场景 | 做法 |
|------|------|
| 新增业务域 | 在 `namespace.build_user_path` 中约定新的 `domain`；无需改 client |
| 需要签名 URL | 目前不做（前端直接 VFS SDK 下载）；如需加，走 `client.py` 上层 wrapper |
| 大文件（>100MB） | 走 `put_bytes` 的分块上传（若网关支持）；避免在 LLM 上下文里出现 |
| 需要跨用户共享 | 显式复制到共享 domain（如 `shared/templates/...`），不共用 uid 前缀 |

**易踩坑**：
- `file_id` 与 `path` 不要混用作为参数；工具签名应明确注明其中之一。
- 删除操作**没有回收站**——`delete()` 立即生效；索引层应先"逻辑删除"。
- 上传后**不要**假设 file_id 可以立即被搜索索引到（如果未来加了搜索层）。

## 8. 与 memory/ 的边界

- **memory/** 存的是**索引 JSON**（结构化元数据），也**落 VFS**；
- **VFS** 存的是**内容本体**（HTML/PDF/DOCX/PNG）；
- 索引里通过 `file_id` 指向内容。
