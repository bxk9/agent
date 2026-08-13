# 专题 10｜提交时间线（按周）

> 生成方式：`git log --author=yitong --format="%ai|%s" | sort` 后按日期聚合
> 版本：v1.0

---

## 一、月度分布

| 月份 | 提交数 | 主线 |
|------|-------|------|
| 2026-06 | 26 | 项目预研、语音面试初版、错题本 v1、Skill 化改造 |
| 2026-07 | 179 | **攻坚高峰**：语音链路、Prompt 工程、错题本 v2、耗时优化 |
| 2026-08 | 34 | 稳定性收敛、埋点闭环、话术微调 |

---

## 二、按周精粹

### W1（06-04 ~ 06-08）：项目起步
- `feat: 前端错题本展示优化`
- `html替换成办公网域名`

### W2（06-09 ~ 06-15）：语音面试骨架
- `新增语音模拟面试功能`
- `模拟面试改为先搜后问，根据用户需求灵活搜索`
- `refactor(voice): 后端按 context_id 自取历史/简历，统一走 build_interview_context`

### W3（06-16 ~ 06-22）：跨模块联动
- `feat(voice): 语音对话结束回写主聊天 MemorySaver + 错题本日期工具`
- `在最终 artifact 注入原样复述指令，约束主网关勿二次总结`

### W4（06-23 ~ 06-30）：Skill 开关 + 场景扩展
- `feat: 语音面试可逆下线，通过 ENABLE_VOICE_INTERVIEW 切换 skill`
- `feat(mock_interview): 支持转正/述职/晋升答辩场景`

### W5（07-01 ~ 07-07）：错题本 v2
- `feat(error_book): 错题本规范全量迁入 save_error_book docstring`
- `错题本：单题JSON+索引+Jinja2 HTML 两层架构`
- `refactor(error_book): 错题本持久化切到 output/<user_id>/error_book/ 本地 JSON`
- `feat(error_book): v2 全量入册 + is_correct 对错区分 + Markdown 渲染`

### W6（07-08 ~ 07-14）：错题本状态管理
- `feat(error_book): 错题本增删改查/掌握/恢复状态管理 + update 工具`
- `feat(error_book): 自动入册规则接入 system_prompt`
- `feat(error_book): 同 query 重答自动覆盖答案（保留复习进度）`
- `feat(error_book_template): 筛选栏改为上下布局 + pill + popover`

### W7（07-15 ~ 07-21）：session 化 + LLM Judge
- `feat(voice-session): 主 Agent session_id 透传 + context 双维度查询 + 复盘链路修复`
- `feat(voice-session): add-dialogue 后台 LLM judge 自动入册错题本`
- `feat: 语音模拟面试上下文与对话持久化到 VFS`
- `文字模拟面试增加判断用户是否中断逻辑`

### W8（07-22 ~ 07-28）：deeplink + Prompt 单一源
- `deeplink增加sync_to_main_bot参数`
- `deeplink增加&onceClick=true限制单次点击`
- `deeplink增加filename和mediatype`
- `voice: 单一 prompt 源 + 流式 LLM + FALLBACK 兜底 + 面经正文透传`
- `refactor(voice-session): 语音上下文预加载链路重构`
- `feat(voice): 让语音面试 system prompt 从 LangGraph 对话中提炼简历摘要`
- `refactor(voice): split resume summary and interviewer profile generation`
- `更新面试设置清单，删减难度和风格，改成题目风格`
- `追问、反馈、点评话术要求同步至语音prompt`

### W9（07-29 ~ 08-04）：12 条硬约束 + 埋点闭环
- `fix usage_tokens埋点bug` × 5
- `1. 语音面试点评策略调整...（12 条硬约束单提交）`
- `语音prompt明确题目数量要求，不能无限追问`
- `增加批量删除和恢复错题本功能`
- `每次只出一题，点评话术约束`
- `点评风格约束`
- `增加兜底v4 pro模型`
- `blueclaw_chat增加裁剪和日志`
- `语音上下文裁剪`
- `增加断开时长`
- `blueclaw infra增加header`

### W10（08-05 ~ 08-10）：稳定性 & 产品调优
- `强化语音内部不能点评，文字逐题出`
- `deeplink task id改成用主agent的taskid`（+ 回滚 + 恢复）
- `优化语音输出150分钟的问题；解决模型未遵循json的问题`
- `语音错题本识别增加重试机制`
- `出题策略默认改为深度追问`（最新）

---

## 三、提交节奏分析

| 指标 | 数值 |
|------|------|
| 时间跨度 | 68 天 |
| 有效提交日 | 约 47 天 |
| 日均提交（活跃日） | ~5.1 次 |
| 单日最高（07-30） | ~12 次 |
| 最长连续提交日 | 07-24 → 07-31（8 天） |

---

## 四、可复现的取数命令

```bash
# 按日聚合
git log --author=yitong --format="%ai|%s" | sort | \
  awk -F"|" '{d=substr($1,1,10); if(d!=cur){print ""; print "### "d; cur=d} print "- "$2}'

# 月度分布
git log --author=yitong --format="%ai" | awk '{print substr($1,1,7)}' | sort | uniq -c

# 增删统计
git log --author=yitong --shortstat --format="" | \
  awk '/files? changed/ {f+=$1; i+=$4; d+=$6} END {printf "files=%d ins=%d del=%d\n",f,i,d}'
```

---

## 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|---------|
| v1.0 | 2026-08-10 | 初版 |
