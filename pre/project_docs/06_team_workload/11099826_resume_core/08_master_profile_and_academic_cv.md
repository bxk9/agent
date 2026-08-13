# 08 · Master Profile 素材库 与 学术 CV 场景扩展

## 一句话概括

11099826 独立设计的**"人物粒度素材库"**（Master Profile）——用户简历数据不再存单份，而是按"人"聚合，支持历史版本管理、姓名纠正联动、跨会话复用。2026-08-10 又扩展学术 CV 场景，8+ 个学术字段一次性加入。

---

## 核心数据卡片

| 阶段 | 时间 | 关键 commit | 涉及文件 |
|:---:|:---:|:---|:---|
| **P1 素材库建立** | 07-01 | `feat: 素材库(Master Profile) + 历史简历版本管理 + resume_sidebar 包拆分` | `memory/resume_index.py` |
| **P2 硬钩子落库** | 07-06 | `feat: 素材库自动落库硬钩子 & 姓名纠正联动迁移` | resume_index / naming |
| **P3 按人物粒度重构** | 07-11 | `refactor(master_profile): 拆分为多文件模块，按人物粒度存储` | master_profile 系列 |
| **P4 学术 CV 扩展** | **08-10** | **feat: 新增学术CV字段** | Schema + 模板 |

---

## 背景与问题

早期简历数据以"会话 ID"为主键，每次开新会话就是全新数据。问题：
- 用户改姓名后，历史简历全部失效
- 同一人多次上传（如换模板重生成）无法复用素材
- 不能形成"个人档案库"

---

## 时间线（关键交付）

### 07-01：素材库首建

Commit：`feat: 素材库(Master Profile) + 历史简历版本管理 + resume_sidebar 包拆分`

- 建立 `memory/resume_index.py` 索引层
- 每次生成结果自动落库（历史版本可回溯）
- 同日完成 sidebar 包拆分（见 [02](./02_resume_sidebar_pipeline.md)），一次完成三项大工程

### 07-06：硬钩子 + 姓名联动

Commit：`feat: 素材库自动落库硬钩子 & 姓名纠正联动迁移`

- **硬钩子**：所有生成路径**强制落库**，无法绕过
- **姓名纠正联动**：改姓名 → 自动迁移旧记录

### 07-11：人物粒度重构

Commit：`refactor(master_profile): 拆分为多文件模块，按人物粒度存储`

- 从"单文件混存"演进为"按人物 ID 分目录 + 多模块文件"
- 支持一人多简历版本

### 08-10：学术 CV 场景扩展

Commit：`feat: 新增学术CV字段 (research_interests, teaching_experience, academic_service, grants, citation_metrics, invited_talks, advising, professional_memberships)`

- **8 个学术字段**一次性加入 Schema
- 涵盖：研究方向 / 教学经历 / 学术服务 / 资助 / 引用指标 / 邀请报告 / 指导学生 / 学术会员
- 项目从"通用简历工具"扩展到"覆盖学术圈"

---

## 方案 / 代码证据

### 素材库分层

```
memory/
├── resume_index.py      ← 索引层：human_id → 简历版本列表
└── master_profile/      ← 存储层（07-11 拆分后）
    ├── <human_id_1>/
    │   ├── basic.json
    │   ├── experience.json
    │   ├── projects.json
    │   └── versions/     历史版本
    └── <human_id_2>/
        └── ...
```

### 硬钩子设计

- 位置：`pipeline.py` 最后一步
- 触发：任何 render 完成时自动写入
- 不允许用户禁用（"硬"钩子的意思）

### 学术 CV 字段

| 字段名 | 语义 |
|:---|:---|
| `research_interests` | 研究方向 |
| `teaching_experience` | 教学经历 |
| `academic_service` | 学术服务（审稿人 / 组委会） |
| `grants` | 科研资助 |
| `citation_metrics` | 引用指标（H-index / 总引用） |
| `invited_talks` | 邀请报告 |
| `advising` | 指导学生 |
| `professional_memberships` | 专业协会 |

---

## 量化成果与协作面

| 维度 | 成果 |
|:---|:---|
| 支持的用户模式 | 单次生成 → 多版本迭代 → 跨会话档案 |
| 支持的场景 | 校招 / 社招 / 学术 CV |
| 硬钩子覆盖率 | 100% render 路径 |
| 姓名纠正联动 | 自动迁移历史 |

### 协作面

- **司棋**：VFS 存储层协作
- **yitong**：memory 层设计一致性（yitong 的错题本 `memory/error_book_index.py` 与之设计范式一致）

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author="11099826" --pretty=format:"%ad|%s" --date=short | grep -i "素材\|master_profile\|学术\|academic"
```
