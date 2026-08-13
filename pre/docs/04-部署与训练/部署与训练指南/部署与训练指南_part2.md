| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `tensor-parallel-size` | 张量并行 GPU 数量 | 2（必须双卡） |
| `max-model-len` | 最大序列长度 | 32768 |
| `gpu-memory-utilization` | GPU 显存利用率 | 0.8-0.9 |
| `host` | 监听地址 | 0.0.0.0 |
| `port` | 监听端口 | 8080 |
| `served-model-name` | 模型名称 | qwen3.5-35b-router |

#### 4.2.2 高级配置

```bash
vllm serve /path/to/output \
    --tensor-parallel-size 2 \
    --max-model-len 32768 \
    --gpu-memory-utilization 0.8 \
    --host 0.0.0.0 \
    --port 8080 \
    --served-model-name qwen3.5-35b-router \
    --max-num-batched-tokens 65536 \
    --max-num-seqs 256 \
    --enable-prefix-caching \
    --disable-log-requests
```

**高级参数说明**：

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `max-num-batched-tokens` | 最大批处理 token 数 | 65536 |
| `max-num-seqs` | 最大并发序列数 | 256 |
| `enable-prefix-caching` | 启用前缀缓存 | 推荐开启 |
| `disable-log-requests` | 禁用请求日志 | 生产环境开启 |

#### 4.2.3 服务测试

**简单测试**：

```bash
curl http://localhost:8080/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "qwen3.5-35b-router",
        "messages": [
            {"role": "system", "content": "你是一个智能路由分类器"},
            {"role": "user", "content": "帮我定一个明天早上8点的闹钟"}
        ],
        "max_tokens": 50,
        "temperature": 0
    }'
```

**预期响应**：

```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "qwen3.5-35b-router",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "single,clear,norm,ok"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 123,
    "completion_tokens": 4,
    "total_tokens": 127
  }
}
```

**性能测试**：

```python
import requests
import time

url = "http://localhost:8080/v1/chat/completions"
payload = {
    "model": "qwen3.5-35b-router",
    "messages": [
        {"role": "system", "content": "你是一个智能路由分类器"},
        {"role": "user", "content": "帮我定一个明天早上8点的闹钟"}
    ],
    "max_tokens": 50,
    "temperature": 0
}

# 单次请求测试
start = time.time()
response = requests.post(url, json=payload)
latency = time.time() - start

print(f"Latency: {latency * 1000:.2f} ms")
print(f"Response: {response.json()['choices'][0]['message']['content']}")

# 并发测试
import concurrent.futures

def send_request(i):
    start = time.time()
    response = requests.post(url, json=payload)
    latency = time.time() - start
    return latency

with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
    futures = [executor.submit(send_request, i) for i in range(100)]
    latencies = [f.result() for f in futures]

print(f"Average latency: {sum(latencies) / len(latencies) * 1000:.2f} ms")
print(f"P50 latency: {sorted(latencies)[50] * 1000:.2f} ms")
print(f"P99 latency: {sorted(latencies)[99] * 1000:.2f} ms")
```

### 4.3 SGLang 部署（支持早停）

#### 4.3.1 启动 SGLang 服务

```bash
# 激活 conda 环境
conda activate qwen35

# 启动 SGLang 服务
python -m sglang.launch_server \
    --model-path /path/to/output \
    --tp 2 \
    --host 0.0.0.0 \
    --port 8080 \
    --mem-fraction-static 0.8 \
    --max-running-requests 256
```

**SGLang vs vLLM 对比**：

| 特性 | vLLM | SGLang |
|------|------|--------|
| OpenAI 兼容 | ✅ | ✅ |
| 早停支持 | ❌ | ✅ (stop_token_ids) |
| 性能 | 高 | 更高（早停场景） |
| 稳定性 | 成熟 | 较新 |
| 推荐场景 | 通用部署 | 需要早停优化 |

#### 4.3.2 测试早停功能

```python
import requests

url = "http://localhost:8080/generate"
payload = {
    "text": "<|im_start|>system\n你是一个智能路由分类器<|im_end|>\n<|im_start|>user\n帮我定一个明天早上8点的闹钟<|im_end|>\n<|im_start|>assistant\n",
    "sampling_params": {
        "temperature": 0,
        "max_new_tokens": 50,
        "stop_token_ids": [25429, 9398, 3613, 14992]  # multi, chat, pend, qa
    }
}

response = requests.post(url, json=payload)
result = response.json()

print(f"Output: {result['text']}")
print(f"Matched token: {result.get('matched_token_id')}")
print(f"Completion tokens: {result['meta_info']['completion_tokens']}")
```

## 5. 服务集成

### 5.1 更新路由服务配置

#### 5.1.1 修改模型地址

编辑 `config/config.py`：

```python
ROUTER_MODEL_URL = {
    "dev": "http://your-new-model-server:8080",
    "pre": "http://your-new-model-server:8080",
    "prd": "http://your-new-model-server:8080",
    "test": "http://your-new-model-server:8080",
}
```

#### 5.1.2 更新模型名称

如果使用 vLLM，确保 `served-model-name` 与代码中的模型名称一致：

```python
# utils/request_llm_v2.py
async def call_sglang_generate(
    tools_content, 
    content,
    trace_id,
    *,
    base_url: str,
    model: str = "qwen3.5-35b-router",  # 更新为实际模型名称
    # ...
):
```

### 5.2 启动路由服务

```bash
# 设置环境变量
export APP_ENV=dev
export APP_NAME=intent-tool-retrieval

# 启动服务
python main.py
```

或使用 uvicorn：

```bash
uvicorn main:app --host 0.0.0.0 --port 19777 --reload
```

### 5.3 端到端测试

```python
import requests

# 测试路由服务
url = "http://localhost:19777/router"
payload = {
    "query": "帮我定一个明天早上8点的闹钟",
    "tools": [
        {
            "key": "create_alarm",
            "function_name": ["timeAndSchedule.createAlarmClock"]
        }
    ],
    "chat_history": [],
    "trace_id": "test-001",
    "need_dispatch": True,
    "copilot_env": "v1"
}

response = requests.post(url, json=payload)
result = response.json()

print("路由结果：")
print(f"  task_type: {result['task_type']}")
print(f"  is_use_tool: {result['is_use_tool']}")
print(f"  is_intent_specific: {result['is_intent_specific']}")
print(f"  is_special_instruction: {result['is_special_instruction']}")
print(f"  is_exe_success: {result['is_exe_success']}")
print(f"  post_type: {result['post_type']}")
```

## 6. 模型评测

### 6.1 评测脚本

使用 `train_deploy_eval/eval/eval.py` 进行模型评测：

```bash
cd train_deploy_eval/eval

# 运行评测
python eval.py \
    --model_path /path/to/output \
    --test_data atom_intents_router.xlsx \
    --output_path eval_results.xlsx
```

### 6.2 评测指标

**主要指标**：
- **准确率 (Accuracy)**：整体分类准确率
- **精确率 (Precision)**：每个类别的精确率
- **召回率 (Recall)**：每个类别的召回率
- **F1 Score**：精确率和召回率的调和平均

**分维度指标**：
- 工具调用类型准确率
- 意图明确度准确率
- 指令类型准确率
- 执行反馈状态准确率

### 6.3 评测结果分析

```python
import pandas as pd

# 加载评测结果
df = pd.read_excel("eval_results.xlsx", sheet_name="准确率汇总")

print("各维度准确率：")
for _, row in df.iterrows():
    print(f"  {row['维度']}: {row['准确率']}")

# 加载详细结果
df_detail = pd.read_excel("eval_results.xlsx", sheet_name="详细数据")

# 分析错误案例
errors = df_detail[df_detail['task_type_diff'] == 0]
print(f"\n错误案例数：{len(errors)}")

# 查看常见错误模式
print("\n常见错误模式：")
print(errors[['query', 'is_use_tool', 'is_use_tool_true']].head(10))
```

## 7. 常见问题与解决方案

### 7.1 训练问题

#### 7.1.1 OOM (Out of Memory)

**问题**：训练时 GPU 显存不足

**解决方案**：
1. 减小 `per_device_train_batch_size`
2. 增加 `gradient_accumulation_steps`
3. 减小 `max_seq_length`
4. 使用 LoRA 替代全量微调
5. 启用梯度检查点：`gradient_checkpointing=True`

#### 7.1.2 训练不收敛

**问题**：Loss 不下降或震荡

**解决方案**：
1. 降低学习率（减半）
2. 增加 warmup 比例
3. 检查数据质量（标签是否正确）
4. 增加训练数据量
5. 调整 LoRA rank（增大或减小）

#### 7.1.3 训练速度慢

**问题**：训练耗时过长

**解决方案**：
1. 增加 GPU 数量
2. 增大 batch size（如果显存允许）
3. 使用 LoRA 替代全量微调
4. 启用 Flash Attention：`use_flash_attention=True`
5. 减少 `max_seq_length`

### 7.2 部署问题

#### 7.2.1 vLLM 启动失败

**问题**：vLLM 服务启动时报错

**常见错误及解决方案**：

**错误 1**：`CUDA out of memory`
- 解决方案：减小 `gpu-memory-utilization` 或增加 GPU 数量

**错误 2**：`Model architecture not supported`
- 解决方案：检查模型格式，确保是 HF 格式

**错误 3**：`Tokenizer not found`
- 解决方案：确保 tokenizer 文件完整

#### 7.2.2 推理延迟高

**问题**：推理延迟超过预期

**解决方案**：
1. 启用前缀缓存：`--enable-prefix-caching`
2. 调整 `max-num-batched-tokens`
3. 使用 SGLang 替代 vLLM（支持早停）
4. 优化 Prompt 长度
5. 增加 GPU 数量

#### 7.2.3 并发性能差

**问题**：高并发时性能下降

**解决方案**：
1. 增加 `max-num-seqs`
2. 调整 `max-num-batched-tokens`
3. 启用连续批处理：`--enable-chunked-prefill`
4. 增加 GPU 数量
5. 使用负载均衡（多实例部署）

### 7.3 集成问题

#### 7.3.1 模型输出格式错误

**问题**：模型输出不符合预期格式

**解决方案**：
1. 检查 Prompt 是否正确
2. 验证模型是否正确加载
3. 检查温度参数（应为 0）
4. 查看模型训练数据格式

#### 7.3.2 路由结果不准确

**问题**：路由分类准确率下降

**解决方案**：
1. 检查模型版本是否正确
2. 验证工具定义是否更新
3. 检查 Prompt 版本
4. 重新评测模型
5. 回滚到上一个稳定版本

## 8. 最佳实践

### 8.1 训练最佳实践

1. **数据质量优先**：
   - 确保标签准确
   - 覆盖各种场景
   - 平衡各类别样本

2. **渐进式训练**：
   - 先用小数据集快速验证
   - 确认效果后再用全量数据
   - 定期保存 checkpoint

3. **超参调优**：
   - 使用网格搜索或贝叶斯优化