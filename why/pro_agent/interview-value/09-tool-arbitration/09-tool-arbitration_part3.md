4. 实证：闹钟/日程选择策略需要 500+ 字详细描述，适合仲裁系统；天气查询续接策略只需 50 字，适合 Patch 系统

### Q6: 这个方法论能迁移到什么场景？

**A**：
1. 任何"需要非技术人员参与策略配置"的场景：推荐系统、风控系统、运营活动
2. 迁移要点：声明式配置 → 结构和内容分离 → 灵活的触发机制 → 安全防护
3. 反例警示：不做安全防护会导致误配置导致的全局污染，不做结构和内容分离会导致配置难以维护

---

## 8. 代码文件索引

- `operations/arbitration/engine.py`：仲裁引擎核心实现（init、_load_rules、collect_arbitration_prompts、reload_rules）
- `operations/arbitration/configs/alarm_schedule.json`：闹钟/日程仲裁规则元数据
- `operations/arbitration/configs/alarm_schedule.md`：闹钟/日程仲裁策略正文
- `operations/arbitration/configs/volume_settings.json`：音量/设置仲裁规则元数据
- `operations/arbitration/configs/volume_settings.md`：音量/设置仲裁策略正文
- `operations/arbitration/configs/alarm_delete_confirm.json`：闹钟删除确认规则元数据
- `operations/arbitration/configs/alarm_modify_confirm.json`：闹钟修改确认规则元数据
- `operations/arbitration/configs/image_mock_qa.json`：图片工具选择规则元数据
- `agent/pro/stage_infer.py`：仲裁注入集成点（613 行）
- `docs/plans/2026-06-18-tool-arbitration.md`：设计文档

---

## 9. 总结

工具共现仲裁系统是一个典型的**LLM 工具选择优化工程案例**，展示了：

1. **问题抽象能力**：从工具选择不确定问题中归纳出"缺乏声明式规则引擎"的根因
2. **体系化设计**：声明式规则引擎 + 双维度触发 + 非法配置检测 + 热更新支持
3. **工程落地能力**：JSON 元数据 + MD 策略正文分离 + 双维度 AND 组合 + 规则加载顺序确定性
4. **方法论沉淀**：可迁移到任何需要非技术人员参与策略配置的场景

**一句话总结**：针对能力重叠工具共现时模型选择不确定的问题，设计声明式规则引擎（JSON 元数据 + MD 策略正文）+ 双维度触发机制（工具共现 + 请求特征），将产品策略从"硬编码"转变为"可配置"，工具选择准确率从 70% 提升到 95%，是 LLM 工具选择优化的完整工程实践。

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-11 | 首次建立 |
| v2.0 | 2026-08-14 | 参照三层防御示例标准全面改写：补充核心概览、失败模式分析、边界 case、面试问答、代码文件索引 |
