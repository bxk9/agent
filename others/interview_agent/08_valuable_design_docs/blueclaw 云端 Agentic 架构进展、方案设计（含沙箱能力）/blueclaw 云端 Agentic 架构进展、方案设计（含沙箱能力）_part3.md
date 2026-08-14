| ![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/CSmsRLDj-y-8dMfqHmGr8yqeaDTsd3SilnjdAOlb_dXXtdgN2ntOb7yNDXXsuJzV) | 1、旅行需求的深度研究（路线规划、酒店选择、时间安排、费用计算等等） |
| ![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/MV7YZOaMj9juR6e-RERZ4aqfDhg9qnzI9oae8-sV7JILiEVoCwTjkQNYf9422Ok0) | 当处理图片超过n张时，将任务交予云端处理 |

### 4.3、云 claw 义

[https://docs.vivo.xyz/s/LrLHwLLe](https://docs.vivo.xyz/s/LrLHwLLe) 邀请您加入文档协作【Cloud Claw Agent Schema】

**目前，云 claw 是以 tool 的形式，直接写死在端龙虾的工具列表中，从而实现技能的发现与调用。**

**后续，云 claw 是以 Agent Card 的形式在云网关暴露，还是以 Tool / Skill 的形式在技能平台暴露与发现，可以一起讨论下。**

## 5、沙箱能力建设@帅广应

### 5.1 沙箱基础能力

沙箱基础能力涵盖文件操作、Bash命令、代码执行、分布式存储挂载

| 能力项 | 说明 | 备注 |
| --- | --- | --- |
| **文件操作** | 文件创建、读取、写入、删除等文件系统常规操作 |  |
| **Bash 命令** | 支持常用 Linux 命令执行(含后台执行)；超时与资源限制 | pip npm依赖安装等 |
| **代码执行** | 支持 Python / Typescript 编程语言代码执行，支持自行安装依赖库 |  |
| **存储挂载** | 用户文件持久化；容量配额管理；NAS存储卷管理 | 按用户隔离workspace |
| **网络管控** | 集群内沙箱间网络隔离，沙箱粒度网络白名单限制； | 基础能力已具备 |
| 其他能力 | 浏览器沙箱、PC沙箱、mobile沙箱待规划 |  |

### 5.2 沙箱接入方案

综合行业"Sandbox as Agent"和"Sandbox As Tool"两种思路, 采用Sandbox As Tool方案。

| 列1 | 列2 |
| --- | --- |
| ![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/LfSsGsh5GO_64sYljwQeAWxWmPrQ_Ay5YoXwXi-mDCWiW6ZhgkLBfV5SwFtHzt8y "image.png")<br>Sandbox as Agent<br>优点<br>● 网络开销更低<br>缺点<br>● 工具小幅改动也需重新部署整个沙箱<br>● 缺乏工具级细粒度权限控制<br>● 一旦被攻破，安全暴露面更大（提示词注入、凭证泄露）<br>● 沙箱故障可能影响整个智能体状态<br>● 切换沙箱后端灵活性差<br>● 基本不支持工具并行执行 | ![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/lHjTG9XBKZI8o7hTV0gpKIQFy9P-O5vEyZdPS5z3FL4mL4iM2V0bsf74XoAtPv6e "image.png")<br>Sandbox as Tool<br>优点<br>● 可快速更新工具，无需重建沙箱镜像<br>● 支持按工具做细粒度 RBAC 权限控制<br>● 隔离性更强，降低提示词注入与凭证泄露风险<br>● 沙箱故障相互隔离，不影响智能体主体状态<br>● 更易切换沙箱后端<br>● 支持沙箱并行执行<br>缺点<br>● 频繁小额沙箱调用带来更高网络开销 |

### 5.3 沙箱服务架构

以对接AgentRuntime为例，Agent不感知具体的对接沙箱服务，只感知网关提供的接口能力。

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/WCnjLUG4FqiLzn0_G_Q3gm9S2FlXnll5WxErwk37az1tlw0Ij8zu9AsRgIeR3sle "image.png")

### 5.4 沙箱workspace设计

#### 什么是工作区

为 AI Agent 准备的一个"工作桌面"—— Agent 在沙箱里执行任务时，所有文件读写、代码运行、命令执行都发生在这个目录里。

Workspace 是 Agent 工具链的公共总线，承担三个角色：

1. **输入层**：用户上传的文件、联网搜索的资料，统一落盘到 workspace。
2. **加工层**：code_interpreter、文档处理、图片编辑、Office 编辑等工具，都在 workspace 中读取源文件、写回处理结果。
3. **产出层**：PDF/HTML/图片等最终交付物存放于此，供用户下载。
每个工具从 workspace 拿输入、往 workspace 写输出，文件即数据流，串联起整条执行链路。

#### 实际用例

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

#### 总体设计图

Workspace 依赖沙箱环境，提供命令行、文件、浏览器、代码执行 等工具进行 Workspace 的访问。总体图如下：

![4.svg](http://veditor.vivo.xyz/api/v1/attachment/file/8Bhg2CRo_s86FrALIYstRCZuT6G15jVEQECZyVJhYwL8ukO7TXbBW2gtgAS1CnPh "4.svg")

#### 设计目标

- **简洁**：所有文件统一放在一个目录下，不做过度分区
- **持久化**：基于 AGENT_ID + OPEN_ID + SESSION_ID 隔离存储，有效期内会话数据不丢失。即同一个会话，创建新的沙箱，历史的文件数据还在。
- **透明**：Agent 只感知 `/home/user/.blueclaw/workspace`，底层映射对其透明
- **安全**：沙箱基于虚拟硬件方案隔离保障不会穿透沙箱，沙箱内部用 root 执行，保障对对于临时任务需要安装package场景支持。
### 5.5 沙箱存储设计

#### 路径映射关系

![1.svg](http://veditor.vivo.xyz/api/v1/attachment/file/um3A8TKKwfJ2W9uXpXbOmtBawJ4Yxx_vfr4xlxUp83DubK8BKV3pK9V0sl8yjVcN?__veditor_img_replace__=1778157751271 "1.svg")

#### 目录说明

| 路径 | 类型 | 说明 |
| --- | --- | --- |
| `/home/user/.blueclaw/workspace` | symlink | 这种目录形式更加符合Linux 用户空间惯例， |
| `/data/workspace/file` | 挂载点 | symlink 的目标，沙箱内的挂载路径 |
| `/data/${AGENT_ID}/${OPEN_ID}/${SESSION_ID}/workspace` | 物理路径 | 实际存储位置，按 Agent+用户+会话 三级隔离 |

#### 文件过期策略

Workspace 中的文件设有自动过期机制，用于控制存储成本和清理不活跃会话数据。

● 过期粒度：按 SESSION_ID 维度整体过期（即整个会话 workspace 目录一起清理）

● 清理方式：后台定时任务扫描，删除超过 TTL 的 workspace 目录

● 续期规则：会话内任何文件操作（创建/修改/上传）会刷新该会话的过期时间

● Agent 无感知：过期清理对 Agent 透明，Agent 不需要处理过期逻辑

### 5.6 业务数据存储说明

当前规划两类业务数据：用户上传数据 和 内置skill数据。

#### 小V文件上传同步

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

#### 内置skill存储

Workspace 中预置 `skills/` 目录，用于存放 Agent 可调用的技能描述文件。Skills 在沙箱启动时从技能平台自动拉取**沙箱操作相关**的 skills，Agent 运行时可读取这些技能定义来增强自身能力。skills 放在 workspace 里，Agent 可以直接用 FileView 读取技能文件，不需要额外的"技能加载"工具。复用文件系统 = 零额外接口成本。

沙箱的核心价值是防止恶意代码逃逸到宿主环境，而不是保护放进去的文件不被读取。把敏感 skill 文件放进沙箱，等于主动把机密放到了用户的执行环境里。因此关于哪些skill能在沙箱中存储需要进行安全评估。

##### 目录位置

```plaintext
/home/user/.blueclaw/workspace/skills/
├── ppt_skill          # PPT操作skill
├── excel_skill        # Excel操作skill
├── doc_skill          # Doc操作skill
└── ...
```

##### 拉取机制

Skills 在沙箱启动阶段（容器 entrypoint）自动从技能平台同步：

| 阶段 | 动作 | 说明 |
| --- | --- | --- |
| 沙箱启动 | 调用技能平台 API 拉取 | 获取该沙箱绑定的技能列表 |
| 写入 workspace | 技能文件落盘到 `skills/` 目录 | Markdown 格式，包含技能描述、参数定义、使用示例 |
| Agent 运行时 | 按需读取 skills 文件 | Agent 通过 FileView 读取技能定义，动态加载能力 |

**启动时拉取流程**：

![10.svg](http://veditor.vivo.xyz/api/v1/attachment/file/UaQ0WEJN1S8aJQZTyW4rC_5ulaCHq0E4LqX6LI3frzP_eoqj1df6w07VESLhlssN "10.svg")

##### 接口定义

```json
// 技能拉取接口 (Sandbox entrypoint → Skills Platform)
GET /api/v1/skills/sandbox

Response:
skill's zip file
```

##### 设计要点

- **启动时一次性拉取**：不在运行时动态更新，避免技能定义中途变化导致 Agent 行为不一致
- **只读目录**：`skills/` 目录对 Agent 为只读，防止 Agent 篡改技能定义
- **降级策略**：若技能平台不可用，沙箱仍正常启动，`skills/` 目录为空，不阻塞主流程
##### 权限控制

| 路径 | 所有者 | 权限 | 说明 |
| --- | --- | --- | --- |
| `/home/user/.blueclaw/workspace/skills/` | root:user | 755 | Agent 可读不可写 |
| `/home/user/.blueclaw/workspace/skills/${SKILL_NAME}` | root:user | 644 | 技能文件只读 |

---

### 5.7 沙箱生命周期管理
