Workspace 中预置 `skills/` 目录，用于存放 Agent 可调用的技能描述文件。Skills 在沙箱启动时从技能平台自动拉取**沙箱操作相关**的 skills，Agent 运行时可读取这些技能定义来增强自身能力。skills 放在 workspace 里，Agent 可以直接用 FileView 读取技能文件，不需要额外的"技能加载"工具。复用文件系统 = 零额外接口成本。

### 5.1 目录位置

```plaintext
/home/user/.blueclaw/workspace/skills/
├── ppt_skill          # PPT操作skill
├── excel_skill        # Excel操作skill
├── doc_skill          # Doc操作skill
└── ...
```

### 5.2 拉取机制

Skills 在沙箱启动阶段（容器 entrypoint）自动从技能平台同步：

| 阶段 | 动作 | 说明 |
| --- | --- | --- |
| 沙箱启动 | 调用技能平台 API 拉取 | 获取该沙箱绑定的技能列表 |
| 写入 workspace | 技能文件落盘到 `skills/` 目录 | Markdown 格式，包含技能描述、参数定义、使用示例 |
| Agent 运行时 | 按需读取 skills 文件 | Agent 通过 FileView 读取技能定义，动态加载能力 |

**启动时拉取流程**：

![10.svg](http://veditor.vivo.xyz/api/v1/attachment/file/UaQ0WEJN1S8aJQZTyW4rC_5ulaCHq0E4LqX6LI3frzP_eoqj1df6w07VESLhlssN "10.svg")

### 5.3 接口定义

```json
// 技能拉取接口 (Sandbox entrypoint → Skills Platform)
GET /api/v1/skills/sandbox

Response:
skill's zip file
```

### 5.4 设计要点

- **启动时一次性拉取**：不在运行时动态更新，避免技能定义中途变化导致 Agent 行为不一致
- **只读目录**：`skills/` 目录对 Agent 为只读，防止 Agent 篡改技能定义
- **降级策略**：若技能平台不可用，沙箱仍正常启动，`skills/` 目录为空，不阻塞主流程
### 5.5 权限控制

| 路径 | 所有者 | 权限 | 说明 |
| --- | --- | --- | --- |
| `/home/user/.blueclaw/workspace/skills/` | root:user | 755 | Agent 可读不可写 |
| `/home/user/.blueclaw/workspace/skills/${SKILL_NAME}` | root:user | 644 | 技能文件只读 |

---

## 6. 安全设计

### 6.1 路径限制

- 文件工具的 `path` 参数必须以 `/home/user/.blueclaw/workspace` 开头
- 禁止 `../` 路径遍历
- 终端命令的 `work_dir` 默认且限制在 workspace 范围内
### 6.2 权限控制

| 路径 | 所有者 | 权限 | 说明 |
| --- | --- | --- | --- |
| `/home/user/.blueclaw/workspace/` | user:user | 755 | Agent 工作目录 |
| `/data/workspace/file/` | user:user | 755 | 实际存储 |
| `/home/user/.blueclaw/` | user:user | 755 | blueclaw 根目录 |
| 系统目录 (`/etc`, `/usr`) | root | 只读 | Agent 不可写 |

### 6.3 命令过滤

- 黑名单命令列表（rm -rf /、mkfs、dd 等）
> 过滤在哪一层实现（blueclaw_server 应用层 or OS 层）

- 网络出站规则
可以借鉴Claude Code的权限设计： [https://vshare.vivo.xyz/article/208749](https://vshare.vivo.xyz/article/208749)
![v消息20260507-202601.jpg](http://veditor.vivo.xyz/api/v1/attachment/file/qUALBj9bUYZHnVGALXudoQtG7EoO4vq3cl_w1jTF4VZ5s9rt0eBDfLNmyNclM3a8?__veditor_img_replace__=1778157751271 "v消息20260507-202601.jpg")

---

## 7. 数据隔离模型

```plaintext
/data/                                  # 持久化存储根目录
├── ${AGENT_ID_1}/                      # Agent 1（如 blueclaw）
│   ├── ${OPEN_ID_A}/                   # 用户 A
│   │   ├── ${SESSION_ID_1}/workspace/  # 用户 A 的会话 1
│   │   ├── ${SESSION_ID_2}/workspace/  # 用户 A 的会话 2
│   │   └── ...
│   ├── ${OPEN_ID_B}/                   # 用户 B
│   │   ├── ${SESSION_ID_1}/workspace/  # 用户 B 的会话 1
│   │   └── ...
│   └── ...
├── ${AGENT_ID_2}/                      # Agent 2（如 file_agent）
│   └── ...
└── ...
```

**隔离粒度**：AGENT_ID（Agent 级）+ OPEN_ID（用户级）+ SESSION_ID（会话级）三层隔离。

- **不同 Agent** 之间数据完全隔离（如代码助手与数据分析助手各自独立）
- **同一 Agent 同一用户不同会话**之间数据互不可见（每个沙箱实例只挂载自己对应的 SESSION_ID 目录）

---

## 8. 沙箱生命周期管理

沙箱采用 **connect-first** 模式，整个生命周期只有四个阶段：

4. **首次创建**：会话第一次 tool_call → `sdk.connect(id)` 返回 null → 调用 `sdk.create(id, image, volumes, env)` 拉起容器 → 等待 healthz 通过 → 转发请求
5. **正常使用**：后续每次 tool_call → `sdk.connect(id)` 直接返回连接（同时自动续期 TTL）→ 转发请求
6. **自动回收**：长时间无请求 → 基建平台 TTL 到期 → 容器被回收（workspace 数据保留在宿主机）
7. **过期重建**：再次 tool_call → `sdk.connect(id)` 返回 null → 重新 `sdk.create` 挂载同一 workspace → 文件完好，Shell/Code 运行态重置
**核心要点**：

- SDK 有 `create` 和 `connect` 两个接口，无显式销毁
- 每次 connect 成功 = 续期，无额外心跳
- 沙箱可回收可重建，workspace 数据持久（持久时间见2.3过期策略）
下面是该生命周期的时序图：

![mermaid-diagram (32).svg](http://veditor.vivo.xyz/api/v1/attachment/file/zucmJwTj5j4KXsQjDYohMiWuuuk7a-jv4cKahBzSojhGqp67eUtHy4uM1T36WvWA "mermaid-diagram (32).svg")

## 9. 附录

### 9.1 Shell Tools Schema

```json
[
  {
    "name": "ShellExec",
    "description": "Execute a bash command in the terminal.\n    * Long running commands: For commands that may run indefinitely, it should be run in the background and the output should be redirected to a file, e.g. command = `python3 app.py > server.log 2>&1 &`.\n    * One command at a time: You can only execute one bash command at a time. If you need to run multiple commands sequentially, you can use `&&` or `;` to chain them together.\n    ",
    "parameters": {
      "type": "object",
      "properties": {
        "command": {
          "type": "string",
          "description": "The bash command to execute. Can be empty string to view additional logs when previous exit code is `-1`. Can be `C-c` (Ctrl+C) to interrupt the currently running process. Note: You can only execute one bash command at a time. If you need to run multiple commands sequentially, you can use `&&` or `;` to chain them together."
        },
        "exec_dir": {
          "type": "string",
          "description": "Working directory for command execution (must use absolute path)"
        },
        "id": {
          "type": "string",
          "description": "Unique identifier of the target shell session"
        }
      },
      "required": ["command", "id", "exec_dir"]
    }
  },
  {
    "name": "ShellView",
    "description": "该工具用于查看指定shell会话的执行内容，用于监控命令的输出结果。",
    "parameters": {
      "type": "object",
      "properties": {
        "id": {
          "type": "string",
          "description": "目标会话的唯一标识ID"
        }
      },
      "required": ["id"]
    }
  },
  {
    "name": "ShellWait",
    "description": "该工具用于在一个指定的 Shell session 中查看最近一条命令是否已运行完成，对于已完成的 session，可以返回执行结果。Returns: - shell_execution_result(str): 命令执行的结果。 - shell_execution_status(str): 命令执行状态：- “[COMPLETE]”代表执行已完成。- “[RUNNING]”开头的文本，代表仍在执行中。 - “[BLOCK]”开头的文本，代表被阻塞，未能得到结果",
    "parameters": {
      "type": "object",
      "properties": {
        "id": {
          "type": "string",
          "description": "目标会话的唯一标识ID"
        },
        "wait_time_out": {
          "type": "number",
          "description": "等待时长（秒），最长支持 300 秒"
        }
      },
      "required": ["id", "wait_time_out"]
    }
  }
]
```

### 9.2 File Tools Schema

```json
[
  {
    "name": "LocalCreateFile",
    "description": "该工具用于在虚拟机中创建代码文件或文本文件，这些在虚拟机中创建的文件不会直接展现给用户, 注意：使用LocalCreateFile工具生成新文件时，文件名不要使用中文或空格等特殊字符",
    "parameters": {
      "type": "object",
      "properties": {
        "file_path": {
          "description": "要写入的文件的绝对路径",
          "type": "string"
        },
        "content": {
          "description": "要写入的内容",
          "type": "string"
        }
      },
      "required": ["file_path", "content"]
    }
  },
  {
    "name": "LocalStrReplace",
    "description": "该工具用于替换本地文件中的指定内容，支持批量或单个替换。",
    "parameters": {
      "type": "object",
      "properties": {
        "file_path": {
          "description": "要替换内容的文件的绝对路径",
          "type": "string"
        },
        "old_str": {
          "description": "被替换的内容",
          "type": "string"
        },
        "new_str": {
          "description": "替换后的内容(可以是空字符串)",
          "type": "string"
        },
        "mode": {
          "description": "为替换的模式，ALL 表示替换匹配到的全部文本，FIRST 和 LAST 表示只替换匹配到的第一个和最后一个",
          "type": "string"
        }
      },
      "required": ["file_path", "old_str", "new_str"]
    }
  },
  {
    "name": "FileBatchUpload",
    "description": "批量上传本地文件到公网，获取可访问的资源链接。",
    "parameters": {
      "type": "object",
      "properties": {
        "path_list": {
          "type": "array",
          "items": {
            "description": "文件在虚拟机上的绝对路径，可以是多个文件路径。",
            "type": "string"
          }
        }
      },
      "required": ["path_list"]
    }
  },
  {
    "name": "FileView",
    "description": "本地/虚拟机文件内容获取工具，不适用其他网页/文件的读取。",
    "parameters": {
      "type": "object",
      "properties": {
        "path": {