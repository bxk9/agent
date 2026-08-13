3. **使用异步调用**：对于批量请求，使用异步或并发调用
4. **启用连接池**：复用 HTTP 连接，减少连接建立开销

### Q5: 如何调试和排查问题？

**A**:
1. **使用 trace_id**：为每个请求设置唯一的 trace_id，便于日志追踪
2. **查看日志**：通过 trace_id 在服务端日志中查找完整调用链路
3. **使用测试接口**：`/router_test` 支持自定义模型地址，便于调试
4. **检查健康状态**：定期调用 `/check.do` 检查服务健康状态

### Q6: 如何处理超时？

**A**:
```python
import requests
from requests.exceptions import Timeout

try:
    response = requests.post(url, json=payload, timeout=2.0)
    result = response.json()
except Timeout:
    print("请求超时，使用降级策略")
    result = {
        "task_type": "complex",
        "is_intent_specific": "err",
        "is_use_tool": "err",
        "is_special_instruction": "err",
        "is_exe_success": "err",
        "post_type": ""
    }
```

### Q7: 如何监控 API 调用？

**A**:
```python
import time
import requests

def call_router_with_metrics(url, payload):
    """带监控的 API 调用"""
    start_time = time.time()
    
    try:
        response = requests.post(url, json=payload, timeout=2.0)
        latency = time.time() - start_time
        
        # 记录指标
        print(f"Latency: {latency * 1000:.2f} ms")
        print(f"Status: {response.status_code}")
        
        result = response.json()
        print(f"Task Type: {result['task_type']}")
        print(f"Post Type: {result['post_type']}")
        
        return result
    except Exception as e:
        latency = time.time() - start_time
        print(f"Error: {e}, Latency: {latency * 1000:.2f} ms")
        raise
```

---

## 附录

### A. 完整工具列表

详见 [Data 模块文档](../02-模块文档/05-data模块.md) 中的工具意图映射表。

### B. 分类标准详解

详见 [Data Process 模块文档](../02-模块文档/06-data_process模块.md) 中的分类标准定义。

### C. 性能基准

| 指标 | 目标值 | 实际值 |
|------|--------|--------|
| P50 延迟 | < 200ms | ~150ms |
| P99 延迟 | < 500ms | ~350ms |
| 准确率 | > 95% | ~96% |
| 可用性 | > 99.9% | ~99.95% |

### D. 版本历史

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| v2.0.0 | 2024-01 | 支持 SGLang 早停优化，新增多维度分类 |
| v1.0.0 | 2023-12 | 首次发布，基础路由功能 |

---

**文档版本**：v2.0.0  
**最后更新**：2024-01-XX  
**维护团队**：Dynamic Router Team

---

<div align="center">

[📚 返回文档首页](../README.md) | [🏗️ 项目架构](../01-项目概览/项目架构文档.md) | [🔄 数据流程](../03-数据流程/数据流程详解.md)

</div>
