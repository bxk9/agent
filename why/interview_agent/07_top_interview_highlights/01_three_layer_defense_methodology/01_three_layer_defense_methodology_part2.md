问题：正则把 "每天工作8小时" 中的 "8小时" 当成时间区间切分
修复：小时/时长类匹配不与日期区间正则共用，独立处理

问题（commit 13fff83 "优化时间提取"）：
"2020.03-至今" 被切成 ["2020", "03-至今"]
修复：区间分隔符检测（_detect_separator）先于切分执行
```

### 4.3 第 3 层：归一化防御

**实现位置**：`app/tools/resume_sidebar/normalize.py`（4008 行，30+ 个归一化函数）

**键名翻译**（修复 `7291bf3` LLM 自创英文键名）：

```python
def _sanitize_extra_fields(data:dict, language: str = "zh") -> dict:
    def _translate_key(k: str) -> str:
        """LLM 自创键名 → 标准键名
        self_assessment → 自我评价
        awards → 获奖情况
        未知键名 → 保留原文进入 extra_sections，绝不丢弃
        """
```

**嵌套容错**（commit `fb29509`"basicInfo 嵌套容错"）：

```python
def _pre_normalize_raw_data(raw_data: dict, language: str = "zh") -> dict:
    """入口预归一化：
    - LLM 有时输出 {"basicInfo": {...}}，有时输出 {"basic": {...}}
    - 有时多包一层嵌套，有时不包
    - 统一展平为标准形态，两种都兼容
    """
```

**跨字段去重**（真实函数群）：

```python
_dedup_job_intent_with_work_title(data)   # 求职意向与工作标题去重
_dedup_city_with_work_location(data)      # 城市与工作地去重
_dedup_cert_from_skills(certs, skills)    # 证书从技能列表去重
_dedup_education(entries)                 # 教育经历去重
_dedup_work_experience(entries)           # 工作经历去重（含 AI 标记保护）
```

**AI 标记保护的去重**（commit `5f3a3e0`"简历中已有内容不做红色AI标记"相关）：

```python
def _dedup_work_experience(entries: list) -> list:
    def _has_ai_mark(text: str) -> bool:
        """带 AI 标记的内容在去重时优先保留"""
    def _time_overlap(t1_start, t1_end, t2_start, t2_end) -> bool:
        """时间区间重叠才判定为重复条目"""
    def _merge_bullets(b1: list, b2: list) -> list:
        """合并重复条目的 bullet，而不是粗暴丢弃"""
```

**Markdown 残留清洗**：

```python
def _strip_markdown_markers(text: str) -> str:
    """清除 LLM 输出中残留的 **加粗**、- 列表符等标记
    （LLM 经常把训练语料的 Markdown 习惯带进结构化输出）"""
```

### 4.4 完整处理流程

```python
def _normalize_for_sidebar(data: dict, date_format=..., preserve_order=False,
                           language="zh", preserve_format=False) -> dict:
    """侧边栏入口的完整归一化流水线（真实签名）"""
    # 1. 预归一化：嵌套展平、键名翻译
    data = _pre_normalize_raw_data(data, language)
    # 2. Markdown 清洗
    data = _strip_markdown_in_data(data)
    # 3. 字段级消毒（生日合法性、作品集、求职意向）
    data = _sanitize_portfolio_value(data)
    data["basic"]["birth_date"] = ... if _is_valid_birth_date(...) else None
    # 4. 语义归类（校园 vs 工作）
    grad_year = _extract_grad_year(data.get("education", []))
    # 5. 跨字段去重
    data = _dedup_job_intent_with_work_title(data)
    data = _dedup_city_with_work_location(data)
    # 6. 日期格式化
    # 7. extra_sections 整理（_sanitize_extra_fields）
    return data
```

### 4.5 降级策略：拒绝渲染 → 降级全量渲染

**关键决策**（commit `fb29509` 原文："拒绝渲染改为降级全量渲染"）：

```
旧策略：三层防御判定数据异常 → 拒绝渲染
问题:   用户拿不到任何产物，体验比"渲染不精准"更差

新策略：
异常等级 1（字段缺失）→ 补默认值，正常渲染
异常等级 2（局部格式错）→ 跳过该字段，其余正常渲染
异常等级 3（整体不可用）→ 降级全量渲染（原文直出），绝不拒绝交付
```

### 4.6 边界 case 处理

**Case 1：LLM 自创键名**
```
输入: {"self_assessment": "认真负责"}
处理: _translate_key 翻译为标准键名；翻译不了的保留原文进 extra_sections
结果: 内容绝不丢失（commit 7291bf3 的根治）
```

**Case 2：嵌套形态不一**
```
输入A: {"basicInfo": {"name": "张三"}}
输入B: {"basic": {"name": "张三"}}
处理: _pre_normalize_raw_data 两种形态都展平为标准形
结果: 渲染层只见到一种形态（commit fb29509）
```

**Case 3：歧义经历归类**
```
输入: "学生会外联部部长"（歧义词）
处理: _is_campus_activity 结合毕业年份判断
      公司白名单（美团等）强制判为工作
结果: 归类错误收敛（commits ba6d575、0141ea9、ec8d913"优化学习部长的提取效果"）
```

**Case 4：重复条目合并**
```
输入: 两段工作经历时间区间重叠
处理: _time_overlap 判定 + _merge_bullets 合并，带 AI 标记的优先保留
结果: 不粗暴丢弃用户内容
```

---

## 5. 效果评估与优化

### 5.1 bug 密度对比（git 统计）

| 阶段 | 时间窗 | 字段类 bug 数 | 模式 |
|:---|:---|:---:|:---|
| 体系化前 | 08-02 ~ 08-04（3 天） | 4 起 | 单点打补丁，修一个冒一个 |
| 体系化落地 | 08-04（`555285d`） | — | 三层防御对齐 |
| 体系化后 | 08-05 ~ 08-11（7 天） | 3 起，且全部是**策略级修复** | 降级策略、入口迁移、字段增强 |

**关键变化**：体系化后的修复不再是"某字段又丢了"，而是"防御策略本身的升级"（`fb29509` 降级、`9b1066c` 入口迁移、`b636f11` extra_sections 增强）——bug 从"数据层"上升为"策略层"，说明基础防御已生效。

### 5.2 可扩展性验证

```
b2384eb（08-10）一次性新增 8 个学术 CV 字段：
  research_interests / teaching_experience / academic_service / grants
  citation_metrics / invited_talks / advising / professional_memberships

无三层体系时：8 字段 × 15 模板 × 3 格式 = 360 个改动点
有三层体系时：Schema 补字段 + 归一化适配 + 学术模板渲染，不动其余模板
```

---

## 6. 技术亮点总结

### 6.1 创新性

1. **三层失败模式正交划分**：Schema/正则/归一化各挡一类失败，交集为空，这是体系能收敛的根本
2. **双入口全覆盖**：防御逻辑在所有消费路径生效，杜绝"薛定谔的 bug"
3. **降级而非拒绝**：异常分级处置，交付永远有产物

### 6.2 技术深度

1. **4008 行归一化代码**：30+ 个专职函数，覆盖键名翻译、嵌套容错、语义归类、跨字段去重、日期归一
2. **配套测试体系**：`test/normalize/` 6 个测试文件 + `test/ai_marks/test_normalize_marks.py`
3. **设计文档沉淀**：`docs/design/sidebar模板统一管理方案.md`、`docs/bug_reports/20260726_render_sidebar_resume_scope主防护输入源修复方案.md`

### 6.3 业务价值

1. **字段丢失事故收敛**：从每周多发到体系化拦截
2. **交付可靠性**：降级策略保证用户永远拿得到产物
3. **可扩展性**：新增 8 个学术 CV 字段（`b2384eb`）只需改 Schema + 归一化，不动 15+ 模板

### 6.4 方法论抽象与迁移（原文档保留部分）

**抽象出的通用方法论——"失败模式正交分解"**：

1. **先枚举失败模式，再设计防御层**：不要先想"用什么技术"，先收集真实 bug，按根因聚类
2. **按正交性分层**：每层挡一类失败，层间交集为空——否则会出现"两层都管但都没管住"的灰色地带
3. **所有消费入口过防御层**：防御逻辑的价值取决于覆盖面，漏一个入口等于没防
4. **异常分级降级**：永远给用户产物，错误分级处置而非一刀切拒绝

**可迁移场景**：

| 场景 | 迁移点 |
|:---|:---|
| AI 填表 / 智能工单 | 同样的三类失败模式（缺失/格式/键名） |
| 文档智能抽取（发票/合同） | Schema 补全 + 正则切分 + 键名归一 |
| 数据仓库 ETL | 源数据脏的三层治理同构 |
| 多前端复用同一后端 | 契约层 + 全入口覆盖 |

**反例警示**：
- **反例 1**：只防一个入口 → 预览正常导出丢字段，排查成本极高
- **反例 2**：逻辑放错层（`9b1066c` scope 在 agent_executor 层注入无效）→ 防御形同虚设
- **反例 3**：拒绝交付（旧策略）→ 用户拿不到产物，比"不精准"更糟

---

## 7. 面试问答准备

### Q1: 为什么是三层，不是两层或四层？

**A**：
1. 三层对应 LLM 输出的三类正交失败模式：没输出（Schema）、输出了但格式错（正则）、输出了但键名/形态错（归一化）
2. 两层会漏：比如把正则并入归一化，会导致"格式切分"和"键名翻译"的职责混淆，bug 定位困难
3. 四层没必要：三层失败模式交集已为空，加层只增加维护成本
4. 实证：git 中 6 起字段类 bug 恰好均匀分布在三层，每起都只能被对应层拦截

### Q2: 如何保证防御逻辑不在某个入口失效？

**A**：
1. **双入口显式调用**：customize_for_sidebar 和 _normalize_jinja2_data 都调用归一化（commit `555285d` 明确要求）
2. **教训反例**：`9b1066c`（scope 检测逻辑在 agent_executor 层注入无效，迁移到工具层才生效）证明逻辑放错层就会在某个入口失效
3. **验证手段**：预览与导出产物对比测试（test/normalize/test_sidebar_render.py）

### Q3: 三层都拦不住的数据怎么办？

**A**：
1. **分级降级**（commit `fb29509`）：字段缺失补默认值、局部错误跳过该字段、整体异常降级全量渲染
2. **绝不拒绝交付**：简历生成是核心转化路径，"宁可粗糙不可没有"
3. **留痕**：异常进日志，供后续补充防御规则

### Q4: 为什么不用 function calling / structured output？

**A**：
1. 简历字段高度可变（论文/竞赛/作品集因人而异），刚性 schema 会拒掉合法内容
2. 统一 LLM 网关下并非所有模型都支持严格 JSON 模式
3. 三层防御是"软约束 + 多层兜底"，对自由格式输入的鲁棒性更强
4. 团队共识佐证：`4cbdbb4` 对不稳定能力选择砍掉而非硬上

### Q5: 这个方法论能迁移到什么场景？

**A**：