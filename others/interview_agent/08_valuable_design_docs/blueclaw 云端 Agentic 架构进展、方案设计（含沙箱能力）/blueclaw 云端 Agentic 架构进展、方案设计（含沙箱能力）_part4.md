![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/YOL_dBcOrqKexc0o6QnWpYW8qArtZAlpYcyQHHtDXxlWpyvJmY6Mb46W117eZxT5 "image.png")

沙箱采用 **connect-first** 模式，整个生命周期只有四个阶段：

4. **首次创建**：会话第一次 tool_call → `sdk.connect(id)` 返回 null → 调用 `sdk.create(id, image, volumes, env)` 拉起容器 → 等待 healthz 通过 → 转发请求
5. **正常使用**：后续每次 tool_call → `sdk.connect(id)` 直接返回连接（同时自动续期 TTL）→ 转发请求
6. **自动回收**：长时间无请求 → 基建平台 TTL 到期 → 容器被回收（workspace 数据保留在宿主机）
7. **过期重建**：再次 tool_call → `sdk.connect(id)` 返回 null → 重新 `sdk.create` 挂载同一 workspace → 文件完好，Shell/Code 运行态重置
**核心要点**：

- SDK 有 `create` 和 `connect` 两个接口，无显式销毁
- 每次 connect 成功 = 续期，无额外心跳
- 沙箱可回收可重建，workspace 数据持久
1、沙箱有自动过期销毁策略，开启的沙箱5~30分钟内无访问请求即释放沙箱(待跟产品沟通对齐策略)。

2、由于沙箱挂载分布式存储，沙箱本身无状态。

3、沙箱内部会预装skill用到的package, 运行过程中安装的package随沙箱销毁而释放。

下面是该生命周期的时序图：

![mermaid-diagram (32).svg](http://veditor.vivo.xyz/api/v1/attachment/file/zucmJwTj5j4KXsQjDYohMiWuuuk7a-jv4cKahBzSojhGqp67eUtHy4uM1T36WvWA "mermaid-diagram (32).svg")

**沙箱存储清理**

1、沙箱挂载的workspace，需定期清理，保留时长可配置。清理逻辑为整个workspace转储到大数据存储，然后删除整个workspace。这样保障冷数据不占用空间的同时，也保留数据恢复的能力。(由基础平台负责开发相关能力)

### 5.8 沙箱与Agent集成

1、system_prompt中需增加对对沙箱调用的业务场景说明

```
f"- If skill declares execution=`isolated` and SKILL.md asks to run script/command steps, "
f"execute with sandbox_bash or sandbox_fs instead of `bash`. "
f"For scripts in the skill directory, read the content first with `read`, "
f"then inject via sandbox_bash  (e.g. python3 -c '<content>') without uploading the script file."
```

2、新增SandboxFsTool/SandboxBashTool/SandboxCodeTool，提供给Agent。

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/nFFXvajICmTL8FCpro93PWEIi-iMLvjoP3vxMtZxDsVB0_tekaDE8tiFFzYFGMg8 "image.png")

3、新增SKILL: 命名为vivo-sandbox , skill.md描述样例如下

```
---
name: sandbox
description: 在隔离环境中安全执行代码、脚本或文件操作。当任务涉及执行不可信代码、
  用户提供的脚本、需要与宿主环境隔离的计算任务时触发。
mode: default
---

# 隔离执行指南

## 可用工具

运行时注册的隔离执行工具由部署环境决定，通常为：

| 工具 | 用途 |
|------|------|
| `sandbox_bash`（云端）| 在远端沙箱中执行 shell 命令或 Python 代码 |
| `sandbox_fs`（云端） | 在远端沙箱中进行文件读写、目录操作 |
| `bash`（PC 端）      | 本地进程执行（PC 本身即隔离环境）|

## 执行规则

### 规则 1：优先使用内容注入方式执行脚本

当需要执行一个 Skill 目录中的脚本文件时，**不要上传脚本文件到执行环境**，
应先读取脚本内容，再通过命令参数注入执行：

**正确做法：**
```
# 1. 用 read 工具读取脚本内容
# 2. 通过隔离执行工具注入
sandbox_bash: python3 -c "<script_content>"
```

**错误做法：**
```
# ❌ 不要将脚本文件写入执行环境
sandbox_fs: write /workspace/script.py <content>
sandbox_bash: python3 /workspace/script.py
```

### 规则 2：多步执行串行复用 Session

多步骤之间需保持状态（已安装依赖、中间文件、环境变量）时，
在同一执行会话中串行执行，避免环境重置：

```
步骤 1（安装依赖）：sandbox_bash "pip install pandas -q"
步骤 2（处理数据）：sandbox_bash "python3 -c 'import pandas...'"
步骤 3（读取结果）：sandbox_fs read /workspace/output.csv
```

### 规则 3：路径约定

| 用途 | 推荐路径 |
|------|---------|
| 用户输入数据 | `/workspace/input/` |
| 执行输出结果 | `/workspace/output/` |
| 临时文件 | `/tmp/` |

### 规则 4：超时设置

| 任务类型 | 建议 timeout_s |
|---------|--------------|
| 简单脚本 | 30（默认）|
| 数据处理 | 120 |
| 编译/构建 | 300（上限）|
```

4、对于需要在沙箱中执行的业务skill，需要新增execution: isolated标识，保障Agent能够识别是需要在隔离环境中执行的技能。

### 5.9 技术选型

并发预估：

蓝心小v日活400万，按日人均请求次数3~5次预估，**常规场景**：按流量高峰集中在晚高峰 19:00-21:00，通常峰值流量占全天 15%～20%，QPS=400万*4次*0.2/2小时=400左右。

**发布会场景**：发布会集中时段30 分钟，基础QPS=1600左右，极端突发再乘 2 倍瞬时脉冲（发布会开场、官宣瞬间），QPS=3200左右。

蓝心小v入口-> Pro模式入口-> 沙箱服务入口，按10%流量到沙箱预估：QPS=320左右。

技术选型：

Python: 单容器QPS预估200左右；需要2个节点。

Java：并发能力能达到Python 3~5倍左右，需要2个节点。

| 对比维度 | Python | Java | 选型结论 |
| --- | --- | --- | --- |
| **单实例 QPS (常规 CRUD)** | 200～400 | 500～800 | Java 性能碾压 |
| 320** QPS 所需容器** | 2 核 4G × 2 台 | 2 核 4G × 2 台 | Java 资源成本 （成本低，可忽略） |
| **并发模型** | 同步受 GIL 限制，异步框架有限 | 多线程 + 线程池，高并发天然适配 | 高并发选 Java |
| **流量抗波动** | 高峰延迟飙升、易雪崩 | 吞吐稳定，抗节日 3~5 倍突增 | 大流量节点优先 Java |
| **开发迭代效率** | 语法简洁、代码量少、上线快 | 语法严谨、代码冗余、开发周期长 | 内部低并发系统选 Python |
| **可维护性 & 规范** | 弱类型，大型项目易混乱 | 强类型、工程化规范、微服务生态成熟 | 长期核心业务选 Java |
| **运维复杂度** | 实例多、扩缩容频繁、资源开销大 | 实例少、运行稳定、故障少 | 运维成本 Java 更低 |
| **生态适配** | 数据分析、AI、脚本、轻量化服务 | 分布式、中间件、事务、限流熔断、微服务 | 复杂分布式架构选 Java |
| **数据库 / 事务** | 事务支持弱，高并发 DB 压力难承载 | 连接池优化、分布式事务、锁机制完善 | 涉及数据读写核心选 Java |
| **适用业务场景** | 后台管理、内部工具、低 QPS、AI 业务、离线任务 | 核心 C 端接口、高并发 CRUD、用户服务、交易链路 | 核心 C 端必选 Java |

考虑到当前vivo内部基建Java更成熟，综合选择JAVA。

### 5.10 风险&举措

**1、 高可用保障：**当前沙箱能力建设中，蓝心小v服务C端用户，需沙箱服务年度服务可用性需达到99.95%以上，低于99.95% C端投诉、舆情、用户流失风险陡增，需要沙箱灾备/降级/限流方案，保障服务可用性。

**2、 阿里云文件存储：**当前存储规划接入阿里云NAS，需要存储挂载稳定性、配额限制、读写性能、数据隔离相关保障方案，保障用户使用体验和跨用户文件访问安全。

**3、关键节点值班保障：**新品发布会、大促、节假日营销节点、功能放量会导致用户流量突增情况，需要有节点流量突增应对方案。

**4、安全性保障：**确保安全沙箱的网络隔离、资源等隔离措施有效性，完善安全监控和风险监测机制，确保沙箱环境安全 。

## 6、核心接口

云 claw 主要和端 claw 对接，因此核心接口是提供给端 claw 的基于 A2A 协议的 Websocket 接口。

### 6.1、接口URL

【测试环境】

  - 办公网域名：ws://copilot-agent-test.vmic.xyz/ws/agent
  - 机房域名：ws://copilot-agent-test.vmic.xyz/ws/agent
【预发环境】

  - 办公网域名：ws://copilot-agent-pre.vmic.xyz/ws/agent
  - 机房域名：ws://copilot-agent-pre.vivo.lan:8080/ws/agent
【线上环境】

  暂未申请

### 6.2、A2A 的对接协议

参考下面文档中的第二章节

[https://docs.vivo.xyz/s/LpaZXAEG](https://docs.vivo.xyz/s/LpaZXAEG) 邀请您加入文档协作【claw云网关协议】    by 金绍杰

## 7、当前卡点

- 记忆这块接口是有变动的，现在改成走端去存储了。给云端用的接口还在开发中。预计完成的时间点暂时还给不了。这块是一个风险点，后续要持续跟进下了。
- ~~技能平台尚未打通，当前正在对接中，晓光把能力提供出来了后，云 claw对接问题不大。~~
- 沙箱环境尚未稳定，这个强依赖基础平台部的进度，风险会比较大。