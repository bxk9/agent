- `test`: 测试环境
- `pre`: 预发布环境
- `prd`: 生产环境

## 6. 扩展性设计

### 6.1 工具融合机制
```python
TOOL_FUSION_RULES = [
    ({"mage_text_translate", "general_image_qa"}, "general_image_qa"),
]
```
支持将多个相关工具融合为单一工具，简化模型决策。

### 6.2 Prompt版本管理
```python
system_prompt_compressed = system_prompt_no_reason
system_prompt_compressed_special = system_prompt_no_reason_special
system_prompt_compressed_space = system_prompt_no_reason_space
```
支持多种Prompt版本，可根据场景灵活切换。

### 6.3 正则模板扩展
```python
regex_templates = {
    'timeAndSchedule': time_schedule.regex_template,
    'weather': weather.regex_template,
    'normal': []
}
```
支持按领域扩展正则模板，实现快速匹配。

## 7. 监控与日志

### 7.1 结构化日志
```python
logger.bind(traceId=trace_id).info(
    f"query: {query}, history: {chat_history}"
)
```

### 7.2 性能监控
- 向量搜索耗时
- 模型推理耗时
- 总路由耗时
- 短路��中率

## 8. 部署架构

### 8.1 服务端口
- 主服务：19777
- 健康检查：`/check.do`

### 8.2 依赖服务
- **模型服务**：SGLang推理服务
- **向量服务**：VSearch向量检索
- **配置中心**：VivoConfigManager

### 8.3 容器化部署
```dockerfile
FROM python:3.10
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "19777"]
```

## 9. 总结

Dynamic Router 项目通过以下核心设计实现了高效的意图路由：

1. **并发执行**：向量搜索与模型推理并行，最大化资源利用
2. **短路优化**：基于SGLang的早停机制，显著降低延迟
3. **多维度分类**：4个正交维度全面刻画用户意图
4. **动态配置**：支持运行时配置热更新
5. **降级策略**：向量搜索超时降级，保证服务可用性
6. **连接池复用**：HTTP客户端和OpenAI客户端连接池化

这些设计使得系统在保证准确性的同时，实现了低延迟和高可用性。
