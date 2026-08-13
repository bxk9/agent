    domains = [DOMAIN_Z2E.get(k.get('domain', ''), 'normal') for k in tools]
    
    match_domain = 'normal'
    match_template = ''
    template_matched = False
    
    for domain_key in domains:
        templates = regex_templates.get(domain_key, [])
        for pattern in templates:
            if re.search(pattern, query):
                match_domain = domain_key
                match_template = pattern
                template_matched = True
                break
        if template_matched:
            break
    
    return {
        "template": {
            "matched": template_matched,
            "match_domain": match_domain,
            "match_template": match_template,
        },
        "entropy": {"matched": False},
    }
```

**匹配策略**：
1. 提取工具所属领域
2. 遍历领域对应的正则模板
3. 第一个匹配的模板即为结果
4. 返回匹配结果和匹配的模板

## 6. 结果融合逻辑

```python
# 向量搜索结果容错
if isinstance(results[0], Exception):
    logger.warning(f"向量搜索失败，降级使用路由模型结果: {results[0]}")
    q_q_result, is_high_score = [], False
else:
    (q_q_result, is_high_score) = results[0]

# 路由模型结果容错
if isinstance(results[1], Exception):
    logger.error(f"路由模型调用失败: {results[1]}")
    return _make_result_dict(task_type="complex", fill="err")
result_dict = results[1]

# 模板命中优先返回
if need_dispatch:
    matched = results[2]
    if matched["template"]["matched"]:
        return _make_result_dict(task_type="easy", fill="template")

# 高分向量命中直接返回
if is_high_score:
    logger.info(f"命中向量库大于指定阈值的向量，直接返回结果: {q_q_result[0]}")
    task = 'easy' if q_q_result[0] == '简单任务' else 'complex'
    result_dict['post_type'] = 'hit_vector'
    result_dict['task_type'] = task

return result_dict
```

**融合优先级**：
1. **模板匹配**：正则模板命中 → 返回 easy
2. **向量高分**：向量相似度 > 0.95 → 直接返回
3. **模型结果**：使用模型推理结果

## 7. 性能优化策略

### 7.1 并发执行
```python
coroutines = [
    self._vector_search_task(...),
    self._get_router_result(...),
]
results = await asyncio.gather(*coroutines)
```

**优势**：
- 向量搜索和模型推理并行执行
- 总耗时取两者最大值而非累加
- 充分利用系统资源

### 7.2 早停优化
- 使用 SGLang 的 `stop_token_ids` 参数
- 模型生成到特定token时立即停止
- 显著降低生成延迟

### 7.3 超时降级
```python
query_results = await asyncio.wait_for(
    asyncio.to_thread(gen_llm_vsearch_res, ...),
    timeout=timeout,
)
```

**降级策略**：
- 向量搜索超时2秒 → 返回空结果
- 不阻塞模型推理主流程
- 保证服务可用性

### 7.4 历史记录截断
- 保留最近6轮对话
- 逐级截断assistant和user内容
- 总长度控制在2048字符内

## 8. 错误处理

### 8.1 异常捕获
```python
try:
    # 主流程
    ...
except Exception as e:
    logger.error(f"query:{query} 出错；原因：{e}")
    traceback.print_exc()
    return _make_result_dict(task_type="complex", fill="err")
```

### 8.2 降级策略
- 向量搜索失败 → 使用模型结果
- 模型推理失败 → 返回错误结果
- 字段校验失败 → 返回错误结果

### 8.3 统一错误格式
```python
def _make_result_dict(task_type="complex", fill="err"):
    """生成统一的结果字典模板"""
    return {
        "task_type": task_type,
        "is_intent_specific": fill,
        "is_use_tool": fill,
        "is_special_instruction": fill,
        "is_exe_success": fill,
        "post_type": '',
    }
```

## 9. 设计理念总结

### 9.1 并发优先
- 最大化利用异步IO
- 向量搜索和模型推理并行
- 减少总响应时间

### 9.2 降级容错
- 向量搜索超时降级
- 模型推理失败降级
- 保证服务高可用

### 9.3 短路优化
- 基于SGLang早停机制
- 减少不必要的token生成
- 显著降低延迟

### 9.4 多维度融合
- 向量检索辅助
- 正则模板快速匹配
- 模型推理精确分类
- 多路结果智能融合

### 9.5 灵活扩展
- 支持工具融合规则
- 支持正则模板扩展
- 支持Prompt版本切换

## 10. 使用示例

### 10.1 基本调用
```python
router = Router()

result = await router.search(
    trace_id="trace-123",
    query="帮我定一个明天早上8点的闹钟",
    tools=[{"key": "create_alarm", "function_name": ["timeAndSchedule.createAlarmClock"]}],
    tools_history=[],
    chat_history=[],
    need_dispatch=True,
    copilot_env="v1"
)

print(result)
# {
#     "task_type": "easy",
#     "is_intent_specific": "clear",
#     "is_use_tool": "single",
#     "is_special_instruction": "norm",
#     "is_exe_success": "ok",
#     "post_type": ""
# }
```

### 10.2 带历史对话
```python
result = await router.search(
    trace_id="trace-456",
    query="改成9点",
    tools=[...],
    tools_history=[],
    chat_history=[
        {"role": "user", "content": "帮我定一个明天早上8点的闹钟"},
        {"role": "assistant", "content": "好的，已为您设置明天早上8点的闹钟"}
    ],
    need_dispatch=False
)
```

## 11. 常见问题

### 11.1 模型返回格式错误
**现象**：日志显示 "llm返回格式错误"

**原因**：
1. 模型生成了超过4个字段
2. 模型生成了非法标签

**排查方法**：
```python
# 查看原始返回
logger.info(f"llm原始返回: {llm_raw_result}")

# 检查Prompt是否正确
logger.info(f"工具选择：{tools_content}")
```

### 11.2 向量搜索超时
**现象**：日志显示 "向量库搜索超时"

**原因**：
1. VSearch服务响应慢
2. 网络延迟高

**解决方案**：
1. 增加超时时间（不推荐）
2. 优化VSearch服务性能
3. 接受降级，使用模型结果

### 11.3 早停未生效
**现象**：模型生成了完整的4个字段，没有早停

**原因**：
1. 模型未生成早停标签
2. `stop_token_ids` 配置错误

**排查方法**：
```python
# 检查命中标签
logger.info(f"matched_label={matched_label}")

# 检查output_ids
logger.info(f"output_ids={output_ids}")
```

## 12. 最佳实践

1. **合理设置超时**：向量搜索超时2秒，平衡性能和可用性
2. **监控早停命中率**：统计早停触发比例，评估优化效果
3. **定期更新工具定义**：保持Excel工具定义与业务同步
4. **日志追踪**：使用trace_id关联完整请求链路
5. **性能监控**：记录各环节耗时，识别性能瓶颈
