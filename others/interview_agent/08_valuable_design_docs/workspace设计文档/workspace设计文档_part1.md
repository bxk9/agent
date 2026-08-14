## 1. 概述

### 1.1 什么是工作区

为 AI Agent 准备的一个"工作桌面"—— Agent 在沙箱里执行任务时，所有文件读写、代码运行、命令执行都发生在这个目录里。

Workspace 是 Agent 工具链的公共总线，承担三个角色：

1. **输入层**：用户上传的文件、联网搜索的资料，统一落盘到 workspace。
2. **加工层**：code_interpreter、文档处理、图片编辑、Office 编辑等工具，都在 workspace 中读取源文件、写回处理结果。
3. **产出层**：PDF/HTML/图片等最终交付物存放于此，供用户下载。
每个工具从 workspace 拿输入、往 workspace 写输出，文件即数据流，**串联起整条执行链路**。

### 1.2 实际用例

用例：云端生成办公文档

```shell
用户：「帮我把这份会议录音整理成会议纪要，输出 Word 和 PPT」

编排流程：
  ① 用户上传 meeting.mp3 → workspace/meeting.mp3
  ② Agent: code_interpreter → 调用语音识别 → workspace/transcript.txt
  ③ Agent: document_summary → 对转录文本做结构化摘要
  ④ Agent: word编辑 → 生成 workspace/会议纪要_0508.docx
  ⑤ Agent: ppt编辑 → 生成 workspace/会议要点汇报.pptx
  ⑥ 产出物推送给用户下载

Workspace 里的文件：
  📁 workspace/
  ├── meeting.mp3          (用户上传)
  ├── transcript.txt       (中间产物)
  ├── 会议纪要_0508.docx   (最终产出)
  └── 会议要点汇报.pptx    (最终产出)

```

### 1.3 总体设计图

Workspace 依赖沙箱环境，提供命令行、文件、浏览器、代码执行 等工具进行 Workspace 的访问。总体图如下：

![4.svg](http://veditor.vivo.xyz/api/v1/attachment/file/8Bhg2CRo_s86FrALIYstRCZuT6G15jVEQECZyVJhYwL8ukO7TXbBW2gtgAS1CnPh "4.svg")

### 1.4 设计目标

- **简洁**：所有文件统一放在一个目录下，不做过度分区
- **持久化**：基于 AGENT_ID + OPEN_ID + SESSION_ID 隔离存储，有效期内会话数据不丢失
- **透明**：Agent 只感知 `/home/user/.blueclaw/workspace`，底层映射对其透明
- **安全**：非 root 执行，目录权限受控

---

## 2. 存储架构

### 2.1 路径映射关系

![1.svg](http://veditor.vivo.xyz/api/v1/attachment/file/um3A8TKKwfJ2W9uXpXbOmtBawJ4Yxx_vfr4xlxUp83DubK8BKV3pK9V0sl8yjVcN?__veditor_img_replace__=1778157751271 "1.svg")

### 2.2 目录说明

| 路径 | 类型 | 说明 |
| --- | --- | --- |
| `/home/user/.blueclaw/workspace` | symlink | 这种目录形式更加符合Linux 用户空间惯例， |
| `/data/workspace/file` | 挂载点 | symlink 的目标，沙箱内的挂载路径 |
| `/data/${AGENT_ID}/${OPEN_ID}/${SESSION_ID}/workspace` | 物理路径 | 实际存储位置，按 Agent+用户+会话 三级隔离 |

### 2.3 文件过期策略

Workspace 中的文件设有自动过期机制，用于控制存储成本和清理不活跃会话数据。

● 过期时间：文件创建/最后修改后 24 小时（1 天）自动过期 （参考小V文件过期时间）

● 过期粒度：按 SESSION_ID 维度整体过期（即整个会话 workspace 目录一起清理）

● 清理方式：后台定时任务扫描，删除超过 TTL 的 workspace 目录

● 续期规则：会话内任何文件操作（创建/修改/上传）会刷新该会话的过期时间

● Agent 无感知：过期清理对 Agent 透明，Agent 不需要处理过期逻辑

---

## 3. 工具接口设计

BlueClaw 暴露给 Agent 的工具分为三组：**终端工具组**、**文件工具组**、**浏览器工具组**、**代码执行工具**。

### 3.1 终端工具组 (Shell)

用于执行与管理命令行任务。

| 工具名 | 功能 | 关键参数 |
| --- | --- | --- |
| **ShellExec** | 执行 bash 命令 | `command`、`work_dir`、`id`（会话ID） |
| **ShellView** | 查看终端会话的输出内容 | `id`（会话ID） |
| **ShellWait** | 等待命令执行完成 | `id`、`timeout` |

**设计要点**：

- 支持多会话并发，通过 `id` 区分不同终端
- 长时间命令需后台运行（`nohup` / `&`），通过 `ShellView` 轮询结果
- `ShellWait` 返回三种状态：
  - `DONE`：命令已完成
  - `RUNNING`：仍在执行中
  - `BLOCKED`：等待用户输入
- 支持发送 `Ctrl+C` 中断运行中的进程
- 默认工作目录为 `/home/user/.blueclaw/workspace`
### 3.2 文件工具组 (File)

用于本地文件的创建、编辑、读取与上传。

| 工具名 | 功能 | 关键参数 |
| --- | --- | --- |
| **LocalCreateFile** | 创建/覆盖写入文件 | `path`（绝对路径）、`content` |
| **LocalStrReplace** | 替换文件中的指定内容 | `path`、`old_str`、`new_str`、`mode`（first/all） |
| **FileView** | 读取文件内容 | `path`、`offset`、`limit`、`thumbnail` |
| **FileBatchUpload** | 批量上传文件获取公网链接 | `paths`（文件路径数组） |

**设计要点**：

- 所有路径必须为绝对路径，且在 `/home/user/.blueclaw/workspace` 下
- `LocalCreateFile`：文件不存在则创建，存在则覆盖
- `LocalStrReplace`：
  - `mode: "first"`：只替换第一个匹配
  - `mode: "all"`：替换所有匹配
  - 如果 `old_str` 未找到，返回错误
- `FileView`：
  - 支持分页读取（`offset` + `limit`，基于字符数）
  - 支持缩略图模式（`thumbnail: "small" | "medium" | "large"`），用于图片预览
- `FileBatchUpload`：将本地文件上传到 CDN，返回公网可访问 URL
- 文件名限制：不允许包含空格或中文字符
**接口示例**：
```json
// LocalCreateFile
{
    "tool": "LocalCreateFile",
    "params": {
        "path": "/home/user/.blueclaw/workspace/script.py",
        "content": "import pandas as pd\ndf = pd.read_csv('data.csv')\nprint(df.describe())"
    }
}

// LocalStrReplace
{
    "tool": "LocalStrReplace",
    "params": {
        "path": "/home/user/.blueclaw/workspace/script.py",
        "old_str": "print(df.describe())",
        "new_str": "df.describe().to_csv('result.csv')\nprint('Done')",
        "mode": "first"
    }
}

// FileView
{
    "tool": "FileView",
    "params": {
        "path": "/home/user/.blueclaw/workspace/result.csv",
        "offset": 0,
        "limit": 5000
    }
}
```

### 3.3 浏览器工具组 (Browser)

用于无头浏览器的网页交互操作，所有鼠标操作基于坐标定位。

| 工具名 | 功能 |
| --- | --- |
| **open_url_in_browser** | 在浏览器中打开指定 URL |
| **take_screenshot** | 对当前页面截图 |
| **click** | 鼠标左键单击 |
| **left_double** | 鼠标左键双击 |
| **right_single** | 鼠标右键单击 |
| **drag** | 鼠标拖拽 |
| **scroll** | 页面滚动 |
| **move_to** | 鼠标移动到指定位置 |
| **mouse_down** | 鼠标按下 |
| **mouse_up** | 鼠标松开 |
| **type** | 输入文本内容 |
| **hotkey** | 按下快捷键组合 |
| **press** | 按下指定按键 |
| **release** | 释放指定按键 |
| **wait** | 等待页面加载 |
| **AskHumanToControlBrowser** | 请求用户接管浏览器（登录/验证码等） |

**操作闭环**：Agent 通过"截图 → 视觉理解 → 操作 → 再截图验证"形成交互闭环。

浏览器下载的文件自动保存到 `/home/user/.blueclaw/workspace/Downloads/`。

### 3.4 代码执行工具 (Code Execution)

用于直接执行代码片段，提供类似 Jupyter Cell 的交互式执行环境。

| 工具名 | 功能 | 关键参数 |
| --- | --- | --- |
| **CodeExecute** | 执行代码片段并返回执行结果 | `language`、`code`、`timeout` |

**设计要点**：

- 支持语言：`python`、`javascript`、`bash`、`java`
- 执行环境有状态：同一会话内的多次 `CodeExecute` 调用共享变量上下文（类似 Jupyter Notebook 的多个 Cell）
- 支持图表输出：matplotlib / plotly 等生成的图片自动保存到 workspace 并返回文件路径
- 执行超时：默认 30s，最长 300s
- 输出限制：stdout/stderr 各最大 100KB，超出截断
- 与 `ShellExec` 的区别：
  - `ShellExec`：通用命令行，面向系统操作（安装依赖、管理进程等）
  - `CodeExecute`：面向代码逻辑执行，有状态环境，支持富输出（图表、DataFrame 等）
**返回结构**：
```json
{
        "exit_code": 0,
        "stdout": "Hello, World!\n",
        "stderr": "",
        "output_files": ["/home/user/.blueclaw/workspace/plot_001.png"],
        "display_data": []
}
```

**接口示例**：

```json
// CodeExecute - Python 数据分析
{
  "tool": "CodeExecute",
  "params": {
    "language": "python",
    "code": "import pandas as pd\ndf = pd.read_csv('/home/user/.blueclaw/workspace/data.csv')\nprint(df.describe())",
    "timeout": 60
  }
}

// CodeExecute - 生成图表
{
  "tool": "CodeExecute",
  "params": {
    "language": "python",
    "code": "import matplotlib.pyplot as plt\nplt.plot([1,2,3],[4,5,6])\nplt.savefig('/home/user/.blueclaw/workspace/chart.png')\nprint('图表已保存')",
    "timeout": 30
  }
}
```

## 4. 小V文件上传同步

用户通过客户端上传的文件（图片、文档等），自动同步到当前会话的 workspace 中。

此处上传不创建沙箱实例，在服务器挂载存储资源写入挂载路径中。

**同步流程**：

![3.svg](http://veditor.vivo.xyz/api/v1/attachment/file/nuMa5lVtQhqVUU3-I1WjUoVmgNotZQqEhZgpuR8OvGxcKN5qcfw88-XidQoPJh1y?__veditor_img_replace__=1778157751271 "3.svg")

**接口定义**（非 Agent 工具）：

```json
// 文件上传接口 (客户端 → Gateway → Sandbox)
POST /api/v1/sandbox/{sandbox_id}/upload
Content-Type: multipart/form-data

Response:
{
  "files": [
    {
      "original_name": "数据报表.xlsx",
      "saved_path": "/home/user/.blueclaw/workspace/uploads/数据报表.xlsx",
      "size": 1048576,
      "mime_type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    }
  ]
}

```

---

## 5. 内置 skills
