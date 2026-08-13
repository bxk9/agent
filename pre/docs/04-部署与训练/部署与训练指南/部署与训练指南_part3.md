   - 记录每次实验的参数和结果
   - 建立超参知识库

4. **版本管理**：
   - 使用 Git 管理代码
   - 使用 DVC 或 MLflow 管理模型
   - 记录每次训练的配置和结果

### 8.2 部署最佳实践

1. **灰度发布**：
   - 新模型先在测试环境验证
   - 小流量灰度（1% → 10% → 100%）
   - 监控关键指标（准确率、延迟、错误率）

2. **监控告警**：
   - 监控 GPU 使用率、显存使用率
   - 监控推理延迟（P50、P99）
   - 监控错误率和异常请求
   - 设置告警阈值

3. **容灾备份**：
   - 保留上一个稳定版本
   - 准备快速回滚方案
   - 定期备份模型文件

4. **性能优化**：
   - 启用前缀缓存
   - 使用 SGLang 早停优化
   - 优化 Prompt 长度
   - 调整批处理参数

### 8.3 运维最佳实践

1. **日志管理**：
   - 集中收集日志
   - 设置日志级别（INFO/WARNING/ERROR）
   - 定期清理旧日志

2. **资源监控**：
   - 监控 CPU、内存、GPU 使用率
   - 监控网络带宽和延迟
   - 监控磁盘空间

3. **自动化运维**：
   - 使用 Kubernetes 管理容器
   - 配置自动扩缩容
   - 设置健康检查和自动重启

4. **文档维护**：
   - 及时更新部署文档
   - 记录问题和解决方案
   - 建立知识库

## 9. 附录

### 9.1 完整训练脚本示例

```bash
#!/bin/bash
# start_training.sh

# 设置环境变量
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=0
export NCCL_NET_GDR_LEVEL=2

# 训练参数
BASE_MODEL="/path/to/Qwen3.5-35B-A3B"
OUTPUT_DIR="/path/to/output/qwen35_router_v1"
DATA_PATH="/path/to/train_data.json"
LOG_DIR="/path/to/logs"

# 创建输出目录
mkdir -p $OUTPUT_DIR
mkdir -p $LOG_DIR

# 启动训练
torchrun \
    --nproc_per_node=8 \
    --nnodes=4 \
    --node_rank=$NODE_RANK \
    --master_addr=$MASTER_ADDR \
    --master_port=$MASTER_PORT \
    train.py \
    --model_name_or_path $BASE_MODEL \
    --data_path $DATA_PATH \
    --output_dir $OUTPUT_DIR \
    --num_train_epochs 3 \
    --per_device_train_batch_size 4 \
    --gradient_accumulation_steps 8 \
    --learning_rate 2e-4 \
    --weight_decay 0.01 \
    --warmup_ratio 0.03 \
    --lr_scheduler_type cosine \
    --logging_steps 10 \
    --save_steps 500 \
    --save_total_limit 3 \
    --eval_steps 500 \
    --bf16 True \
    --tf32 True \
    --gradient_checkpointing True \
    --use_lora True \
    --lora_rank 64 \
    --lora_alpha 128 \
    --lora_dropout 0.05 \
    --max_seq_length 4096 \
    2>&1 | tee $LOG_DIR/training.log

echo "Training completed. Model saved to $OUTPUT_DIR"
```

### 9.2 完整部署脚本示例

```bash
#!/bin/bash
# start_vllm.sh

# 设置环境变量
export CUDA_VISIBLE_DEVICES=0,1
export VLLM_NO_USAGE_STATS=1

# 模型路径
MODEL_PATH="/path/to/qwen35_router_v1"

# 启动 vLLM 服务
vllm serve $MODEL_PATH \
    --tensor-parallel-size 2 \
    --max-model-len 32768 \
    --gpu-memory-utilization 0.8 \
    --host 0.0.0.0 \
    --port 8080 \
    --served-model-name qwen3.5-35b-router \
    --max-num-batched-tokens 65536 \
    --max-num-seqs 256 \
    --enable-prefix-caching \
    --disable-log-requests \
    2>&1 | tee vllm.log

echo "vLLM server started on port 8080"
```

### 9.3 监控脚本示例

```python
#!/usr/bin/env python3
# monitor.py

import requests
import time
import psutil
import pynvml

# 初始化 NVML
pynvml.nvmlInit()

def get_gpu_stats():
    """获取 GPU 使用率"""
    device_count = pynvml.nvmlDeviceGetCount()
    stats = []
    for i in range(device_count):
        handle = pynvml.nvmlDeviceGetHandleByIndex(i)
        util = pynvml.nvmlDeviceGetUtilizationRates(handle)
        memory = pynvml.nvmlDeviceGetMemoryInfo(handle)
        stats.append({
            "gpu": i,
            "utilization": util.gpu,
            "memory_used": memory.used / 1024**3,
            "memory_total": memory.total / 1024**3,
            "memory_percent": memory.used / memory.total * 100
        })
    return stats

def check_vllm_health(url="http://localhost:8080/health"):
    """检查 vLLM 服务健康状态"""
    try:
        response = requests.get(url, timeout=5)
        return response.status_code == 200
    except:
        return False

def monitor():
    """监控循环"""
    while True:
        # GPU 状态
        gpu_stats = get_gpu_stats()
        for stat in gpu_stats:
            print(f"GPU {stat['gpu']}: {stat['utilization']}% | "
                  f"Memory: {stat['memory_used']:.1f}/{stat['memory_total']:.1f} GB "
                  f"({stat['memory_percent']:.1f}%)")
        
        # vLLM 健康状态
        healthy = check_vllm_health()
        print(f"vLLM Health: {'✓' if healthy else '✗'}")
        
        # CPU 和内存
        cpu_percent = psutil.cpu_percent()
        memory = psutil.virtual_memory()
        print(f"CPU: {cpu_percent}% | Memory: {memory.percent}%")
        
        print("-" * 50)
        time.sleep(5)

if __name__ == "__main__":
    monitor()
```

## 10. 总结

本文档详细介绍了 Dynamic Router 项目的模型训练和部署流程，包括：

1. **环境准备**：训练和部署的硬件配置和软件依赖
2. **模型训练**：LoRA 微调和全量微调的完整流程
3. **模型部署**：使用 vLLM 和 SGLang 部署 OpenAI 兼容服务
4. **服务集成**：将训练好的模型集成到路由服务
5. **模型评测**：评测指标和结果分析
6. **常见问题**：训练、部署、集成中的问题和解决方案
7. **最佳实践**：训练、部署、运维的最佳实践

通过遵循本文档，您可以顺利完成模型的训练、部署和集成工作。如有问题，请参考常见问题部分或联系技术支持。
