5f3a3e0 | 2026-08-06 | 11099826 | 解决教育背景中获奖情况提取问题 简历中已有内容不做红色AI标记
b636f11 | 2026-08-11 | 11099826 | fix: extra_sections字段提取增强 + bullet缩进修正 + 语音URL修复
```

### 4.2 相关代码文件

- `app/tools/resume_sidebar/normalize.py`：归一化核心（4008 行）
  - `_pre_normalize_raw_data`（第 1942 行）：嵌套容错入口
  - `_sanitize_extra_fields` / `_translate_key`（第 1050/1073 行）：键名翻译
  - `_is_campus_activity` / `_extract_grad_year`（第 426/404 行）：语义归类
  - `_dedup_work_experience` / `_has_ai_mark`（第 733/751 行）：AI 标记保护去重
  - `_detect_date_format` / `_detect_separator`（第 1790/1824 行）：日期归一
- `app/tools/resume_sidebar_constants.py`：`_CAMPUS_KEYWORDS`（第 28 行）、`_AMBIGUOUS_CAMPUS_KEYWORDS`（第 59 行）
- `test/normalize/`：6 个回归测试文件
- `docs/design/sidebar模板统一管理方案.md`：设计文档

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-13 | 首次建立，基于 git 证据链还原三层防御的真实成因 |
| v2.0 | 2026-08-14 | 参照 SGLang 原因说明示例改写：来源+原文+详细解释+场景示例结构，补充真实代码行号引用 |
| v2.1 | 2026-08-14 | 按用户要求合并原文档：原简略分析（除证据等级表）作为第一部分完整保留 |
