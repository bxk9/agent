    {"role": "system", "content": system_prompt_use_reason},
    {"role": "user", "content": content}
]

# 模型会输出带reason的JSON
# {"工具调用类型": {"reason": "...", "label": "single"}, ...}
```

### 6.3 使用4token优化Prompt

```python
from data_process.router_prompt import system_prompt_no_reason_space

# 使用空格分隔的Prompt（用于SGLang早停）
messages = [
    {"role": "system", "content": system_prompt_no_reason_space},
    {"role": "user", "content": content}
]

# 模型会输出：single clear norm ok（空格分隔）
```

## 7. 常见问题

### 7.1 分类不准确
**现象**：模型输出的标签与预期不符

**原因**：
1. Prompt描述不够清晰
2. 示例覆盖不全
3. 规则存在歧义

**解决方案**：
1. 优化分类标准描述
2. 增加更多示例
3. 明确优先级规则

### 7.2 输出格式错误
**现象**：模型输出不符合要求的格式

**原因**：
1. 输出约束不够严格
2. 模型理解偏差

**解决方案**：
1. 加强输出格式约束
2. 添加更多格式示例
3. 使用后处理校验

### 7.3 推理过程不一致
**现象**：带推理的输出中reason与label不匹配

**原因**：
1. 推理引导不够明确
2. 字段顺序约束不严格

**解决方案**：
1. 强化推理引导
2. 明确字段顺序约束
3. 添加推理示例

## 8. 最佳实践

1. **定期审查**：定期审查分类标准，确保覆盖新场景
2. **示例更新**：根据实际case更新示例库
3. **A/B测试**：新Prompt上线前进行A/B测试
4. **效果监控**：监控分类准确率，及时发现问题
5. **版本管理**：Prompt版本化管理，便于回滚
6. **文档同步**：Prompt修改时同步更新文档
