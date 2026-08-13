# 04 · HTML 转 Word（LibreOffice 方案）

## 一句话概括

11197109 在 08-07 采用 **LibreOffice 库方案实现 HTML → Word 转换**——避开纯 Python 库（python-docx / mammoth）的样式还原度不足，选择更工业级的方案。

---

## 时间线

| 日期 | Commit |
|:---:|:---|
| 08-07 | html 转 word 使用 LibreOffice 库方案 |

---

## 方案对比

| 方案 | 优点 | 缺点 |
|:---|:---|:---|
| python-docx | 纯 Python、无外部依赖 | 从 HTML 转换需要自己写映射，样式还原差 |
| mammoth | HTML → docx 支持 | 反向能力弱、复杂样式丢失 |
| **LibreOffice CLI** | **样式还原度高、稳定** | 需要系统安装 LibreOffice |
| Aspose 等商业库 | 效果好 | 收费 |

**选择 LibreOffice 的原因**：
- 简历样式复杂（多模板、图标、表格、多列）
- python-docx 系列方案还原度不足
- 服务端可预装 LibreOffice
- 命令行调用 `libreoffice --headless --convert-to docx input.html`

---

## 与 11099826 简历模块协作

**11099826 的 03 号文档** `03_resume_docx_rendering.md` 主要处理"直接用 python-docx 生成 docx"的路径。

**11197109 的本方案**互补：
- 11099826 路径：结构化数据 → python-docx → docx（快速、可控）
- 11197109 路径：HTML → LibreOffice → docx（样式高保真）

**使用场景**：
- 简历首次生成：走 11099826 路径
- 复盘报告等富格式内容转 Word：走 11197109 路径

---

## 部署要点

- Docker 镜像需预装 LibreOffice
- headless 模式避免 GUI 依赖
- 转换超时保护（避免大文件卡死）

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author=11197109 --grep="word\|LibreOffice\|docx" --pretty=format:"%ad %s" --date=short
```
