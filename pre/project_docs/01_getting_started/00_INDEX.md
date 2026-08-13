# 00 · 文档集导航（INDEX）

> 所有相对路径以 `project_docs/` 为根书写。

## 阅读路径

### 🎯 我是新加入的后端工程师
1. `01_getting_started/01_overview.md` — 了解项目做什么
2. `02_architecture/02_architecture.md` — 建立整体架构心智
3. `03_modules/12_module_agent_core.md` — 看 Agent 主循环
4. `03_modules/13_module_skills.md` + `03_modules/14_module_tools.md` — 看能力扩展点
5. `05_references/50_debugging_guide.md` — 学会自助定位问题

### 🧭 我要接入协议 / 前端
1. `03_modules/10_module_claw_protocol.md` — WebSocket + JSON-RPC + Envelope
2. `03_modules/19_module_messages.md` — FlatBuffers 消息
3. `04_data_flows/31_data_flow_voice.md`（若涉及语音）

### 📄 我要维护简历渲染
1. `03_modules/18_module_resume_pipeline.md` — 上游解析（离线）
2. `03_modules/20_module_resume_templates.md` — 6 套模板体系
3. `04_data_flows/30_data_flow_resume.md` — 10 步在线渲染主流水线
4. `04_data_flows/32_data_flow_ai_marks.md` — `<<<...>>>` 标记生命周期

### 🎙 我要维护语音面试
1. `03_modules/17_module_voice.md`
2. `04_data_flows/31_data_flow_voice.md`

### 💾 我要维护存储
1. `03_modules/15_module_vfs.md` — VFS 抽象
2. `03_modules/16_module_memory.md` — 素材库 / 索引 / AI 标记
3. `05_references/40_key_conventions.md` — 路径与 file_id 约定

### 🧪 我要调试线上问题
1. `05_references/50_debugging_guide.md` — 症状速查表
2. `02_architecture/02_architecture.md` — 调用链定位
3. 项目根 `ARCHITECTURE.md` — 更细的运行手册

## 全文档树（分类归档后）

```
project_docs/
├── README.md                       文档集入口
│
├── 01_getting_started/
│   ├── 00_INDEX.md                 本文件
│   └── 01_overview.md              项目总览
│
├── 02_architecture/
│   ├── 02_architecture.md          整体架构
│   └── 03_design_philosophy.md     整体设计理念（10 条原则）
│
├── 03_modules/                     单模块文档
│   ├── 10_module_claw_protocol.md
│   ├── 11_module_llm.md
│   ├── 12_module_agent_core.md
│   ├── 13_module_skills.md
│   ├── 14_module_tools.md
│   ├── 15_module_vfs.md
│   ├── 16_module_memory.md
│   ├── 17_module_voice.md
│   ├── 18_module_resume_pipeline.md
│   ├── 19_module_messages.md
│   └── 20_module_resume_templates.md
│
├── 04_data_flows/                  跨模块数据流
│   ├── 30_data_flow_resume.md
│   ├── 31_data_flow_voice.md
│   └── 32_data_flow_ai_marks.md
│
└── 05_references/                  约定 & 调试
    ├── 40_key_conventions.md
    └── 50_debugging_guide.md
```

## 每个模块文档的统一结构

所有 `03_modules/*.md` 都遵循相同六段式：

1. **模块定位** — 一句话说明"是什么、为谁服务"
2. **文件清单** — 表格：文件 → 职责
3. **对外契约** — 供其他模块调用的入口 API / 事件 / 数据结构
4. **核心设计理念** — 该模块特有的设计选择与权衡
5. **典型调用链** — 该模块在实际请求中的位置
6. **扩展点与注意事项** — 如何新增/修改，容易踩的坑

## 与项目根 `ARCHITECTURE.md` 的关系

| 维度 | `ARCHITECTURE.md`（根） | `project_docs/`（本目录） |
|------|-----------------------|-------------------------|
| 定位 | 运行手册 / 症状速查 | 结构知识 / 设计理念 |
| 粒度 | 面向"改问题" | 面向"建心智" |
| 更新时机 | bug / 症状新增 | 结构 / 模块 / 约定变更 |
| 优先级 | 线上问题第一手 | 新人 / 评审第一手 |

两者互补，不冗余：本文档集**不**再复述 ARCHITECTURE.md 的症状表，只在 `05_references/50_debugging_guide.md` 中给出**指针**。
