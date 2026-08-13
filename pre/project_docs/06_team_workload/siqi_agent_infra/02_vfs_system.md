# 02 · VFS 云空间系统

## 一句话概括

司棋独立设计并实现的**BlueClaw 云 VFS 接入模块**——把整个项目的文件读写从"轩辕存储 + 火山文档库 + 本地"三套异构方案统一到 VFS。从 06-11 首建到 08-05 收尾，是**基础设施级重构**。

---

## 核心数据卡片

| 文件 | 修改次数 | 归属 |
|:---|---:|:---|
| `app/vfs/client.py` | **22** | Owner（blame 56%） |
| `app/vfs/tools.py` | 15 | Owner |
| `app/vfs/namespace.py` | 4 | Owner |
| `app/vfs/uri.py` | 1 | Owner |
| `app/vfs/file_id.py` | 1 | Owner |

---

## 背景与问题

早期项目文件读写有三套：
1. **轩辕存储**：老方案
2. **火山文档库**：短暂尝试
3. **本地 tmp**：CI/CD 磁盘溢出风险

问题：
- 三套鉴权体系
- 三套 URL 格式（火山 / claw:// / 内网 lan）
- 用户权限无法跨会话
- 记忆无法持久化

---

## 时间线（4 个阶段）

### P1 · VFS 首建（06-11）

- Commit：`feat(vfs): 新增 BlueClaw 云 VFS 接入模块（不接入 agent）`
- Commit：`refactor(file): 移除轩辕存储与火山文档库，文件管理统一到 BlueClaw VFS`
- Commit：`chore(docs): 删除过时的 agent文件管理设计.md`
- **一次性完成**：新方案接入 + 旧方案清理 + 文档同步

### P2 · URL 治理（06-11 → 06-15）

- `fix(vfs): 默认 base_url 改为内网 vivo.lan:8080`
- `feat(vfs): 自动重写下载 url 为公网域名 + write_file 直接返回下载链接`
- `fix: 简历下载链接改写为公网域名(.com.cn)，避免返回内网.lan host`
- `fix: 录音复盘两处修复 - claw:// 音频URI正确签发share短链 + ASR空结果不再误判为失败`

### P3 · namespace 与用户中心化（06-24 → 06-30）

- `feat(vfs): 新增 namespace 常量模块作为路径单一真理源`
- `feat(vfs): 所有 sub-agent 产物迁移到 /interview_agent/ 命名空间`
- `feat(memory): 简历记忆索引迁移到 VFS（含本地 fallback + 后台迁移 + 单测）`
- `feat(vfs): 用户中心化存储改造 Phase 1 - users/{uid}/ + shared/cache/`
- `docs(vfs): 决策1（sid=user_id）经评审永久放弃，更新架构文档至 v1.1`
- `feat(vfs): 自产数据改用固定tenant(interview_agent)实现跨会话记忆持久化`

### P4 · 三头统一 + 请求日志（07-16 / 08-04-05）

- `feat(vfs): 统一 VFS 请求头(X-Api-Key/X-User-Id/X-Trace-Id) + 文档Agent产物转存云空间`
- `fix(vfs): API-Key 默认不发送，避免 dev 环境 secret 不匹配导致 share_url 401`
- `fix(vfs): 恢复 X-Api-Key 默认必传 + 补 share_url_sync 漏传的鉴权头`
- `fix(vfs): 增强 vfs_get_share_url 路径校验与文档说明`
- `feat(vfs): VFS 调用加请求日志，包含 url/trace_id/tenant/user/body`
- `feat(vfs): 所有 VFS 接口加请求日志`
- `fix(vfs): _upload_with_path 和 _vfs_json 修复 user_id 漏传，加请求日志`
- `fix: 所有 VFSClient/build_vfs_headers 调用补充 user_id 参数`

---

## 方案 / 代码证据

### VFS 分层设计

```
app/vfs/
├── client.py       ← HTTP 客户端（三头统一：X-Api-Key/X-User-Id/X-Trace-Id）
├── tools.py        ← 高层 API（upload/download/share_url/list）
├── namespace.py    ← 路径单一真理源（tenant/users/{uid}/shared/...）
├── uri.py          ← claw:// URI 解析与签名
├── file_id.py      ← file_id 生成与解析
└── __init__.py
```

### 路径分层（namespace.py 单一真理源）

```
/interview_agent/                      ← tenant 固定值（跨会话）
    ├── users/{user_id}/                ← 用户私有区
    │     ├── resumes/
    │     ├── recordings/
    │     └── ...
    ├── shared/cache/                   ← 跨用户缓存
    └── uploads/{session_id}/            ← 会话上传区（读取用）
```

### 三头协议

| 头 | 用途 |
|:---|:---|
| `X-Api-Key` | 服务鉴权 |
| `X-User-Id` | 用户身份 |
| `X-Trace-Id` | 全链路追踪 |

---

## 量化成果

| 维度 | 成果 |
|:---|:---|
| 迁移前 | 3 套异构存储方案 |
| 迁移后 | 统一 BlueClaw VFS，client.py 56% blame 归司棋 |
| 用户中心化 | Phase 1 完成，users/{uid}/ 目录规范 |
| 跨会话记忆 | tenant 固定值方案，简历/复盘记忆均持久化 |
| 请求日志 | 100% VFS 接口覆盖 ctx_log |

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="司棋" -- app/vfs/ --pretty=format:"%ad|%s" --date=short
```
