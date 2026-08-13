# Dynamic Router 部署与训练指南

## 1. 概述

本文档详细介绍 Dynamic Router 项目的模型训练和部署流程，包括：
- **模型训练**：使用 megatron-swift 框架进行全量微调和 LoRA 微调
- **模型部署**：使用 vLLM 框架部署 OpenAI 兼容的 API 服务
- **服务集成**：将训练好的模型集成到路由服务中

### 1.1 支持的模型

| 模型 | 参数量 | 架构 | 训练方式 |
|------|--------|------|----------|
| Qwen3-30B-A3B | 30B (激活3B) | MoE | 全量微调 / LoRA |
| Qwen3.5-35B-A3B | 35B (激活3B) | MoE | 全量微调 / LoRA |

### 1.2 技术栈

- **训练框架**：megatron-swift 4.0.1
- **部署框架**：vLLM 0.17.1
- **基础镜像**：Ubuntu 22.04 + CUDA 12.8.1 + PyTorch 2.10.0
- **硬件要求**：NVIDIA GPU (A100/H100 推荐)

## 2. 环境准备

### 2.1 训练环境

#### 2.1.1 容器镜像

```bash
registry-wl01.vivo.lan/vtraining/images/11165695/modelscope:ubuntu22.04-cuda12.8.1-py311-torch2.10.0-vllm0.17.0-modelscope1.34.0-swift4.0.1
```

#### 2.1.2 硬件配置

**LoRA 微调配置**：
| 参数 | 配置 |
|------|------|
| 实例数 | 4 |
| 总 CPU | 380 核 |
| 总内存 | 3800 GB |
| 总 GPU | 16 卡 |
| RDMA 网络 | ib |

**全量微调配置**：
| 参数 | 配置 |
|------|------|
| 实例数 | 8 |
| 总 CPU | 760 核 |
| 总内存 | 7600 GB |
| 总 GPU | 32 卡 |
| RDMA 网络 | ib |

#### 2.1.3 目录结构

```
train_deploy_eval/train/
├── qwen3_30B_A3B_full_sft/      # Qwen3-30B 全量微调
│   ├── qwen3_30B_A3B.sh         # 训练参数配置
│   ├── run.sh                   # 运行脚本
│   └── start_training.sh        # 启动脚本
├── qwen3_30B_A3B_lora_sft/      # Qwen3-30B LoRA 微调
│   ├── qwen3_30B_A3B.sh
│   ├── run.sh
│   └── start_training.sh
├── qwen35_35B_A3B_full_sft/     # Qwen3.5-35B 全量微调
│   ├── qwen3_5_35B_A3B.sh
│   ├── run.sh
│   └── start_training.sh
└── qwen35_35B_A3B_lora_sft/     # Qwen3.5-35B LoRA 微调
    ├── qwen3_5_35B_A3B.sh
    ├── run.sh
    └── start_training.sh
```

### 2.2 部署环境

#### 2.2.1 容器镜像

```bash
registry-wl01.vivo.lan/vtraining/images/11165329/11169265:swift_2.6.1_deploy_qwen35python3.11vllm0.17.1transformers5.3.0_piby11165329at20260312191303__piby11165329at20260318121423
```

#### 2.2.2 硬件配置

| 参数 | 配置 |
|------|------|
| 实例数 | 1 |
| 总 CPU | 64 核 |
| 总内存 | 512 GB |
| 总 GPU | 2 卡 (必须双卡，否则 OOM) |

#### 2.2.3 依赖安装

```bash
# 激活 conda 环境
conda activate qwen35

# 验证 vLLM 安装
python -c "import vllm; print(vllm.__version__)"
```

## 3. 模型训练

### 3.1 训练数据准备

#### 3.1.1 数据格式

训练数据应为 JSON 格式，包含以下字段：

```json
{
  "query": "帮我定一个明天早上8点的闹钟",
  "history": [],
  "tools": [
    {
      "key": "create_alarm",
      "function_name": ["timeAndSchedule.createAlarmClock"]
    }
  ],
  "label": "single,clear,norm,ok"
}
```

**字段说明**：
- `query`: 用户当前输入的 query
- `history`: 历史对话列表，格式为 `[{"role": "user", "content": "..."}, ...]`
- `tools`: 候选工具列表
- `label`: 目标标签，格式为 `工具类型,意图明确度,指令类型,执行状态`

#### 3.1.2 数据生成

使用 `data_process/run_router_data.py` 生成训练数据：

```python
from data_process.run_router_data import generate_training_data

# 从 Excel 生成训练数据
generate_training_data(
    excel_path="config/atom_intents_router.xlsx",
    output_path="data/train_data.json"
)
```

#### 3.1.3 数据质量检查

```python
import json

# 加载数据
with open("data/train_data.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# 检查数据分布
label_counts = {}
for item in data:
    label = item["label"]
    label_counts[label] = label_counts.get(label, 0) + 1

print("标签分布：")
for label, count in sorted(label_counts.items(), key=lambda x: x[1], reverse=True):
    print(f"  {label}: {count}")
```

### 3.2 LoRA 微调

#### 3.2.1 配置参数

编辑 `qwen35_35B_A3B_lora_sft/qwen3_5_35B_A3B.sh`：

```bash
# 基础配置
MODEL_NAME="Qwen3.5-35B-A3B"
BASE_MODEL_PATH="/path/to/base/model"
OUTPUT_DIR="/path/to/output"
LOG_DIR="/path/to/logs"
DATA_PATH="/path/to/train_data.json"

# LoRA 参数
LORA_RANK=64                    # LoRA 秩大小
LORA_ALPHA=128                  # LoRA 缩放因子（通常为 rank 的 1-2 倍）
LORA_DROPOUT=0.05               # LoRA dropout

# 训练参数
NUM_TRAIN_EPOCHS=3              # 训练轮数
PER_DEVICE_TRAIN_BATCH_SIZE=4   # 每设备 batch size
GRADIENT_ACCUMULATION_STEPS=8   # 梯度累积步数
LEARNING_RATE=2e-4              # 初始学习率
MIN_LR=2e-5                     # 最小学习率
WARMUP_RATIO=0.03               # 预热比例
WEIGHT_DECAY=0.01               # 权重衰减

# MoE 参数
MOE_AUX_LOSS_COEFF=0.01         # MoE 辅助损失系数
MOE_EXPERT_CAPACITY_FACTOR=1.0  # MoE 专家容量因子

# 其他参数
MAX_SEQ_LENGTH=4096             # 最大序列长度
LOGGING_STEPS=10                # 日志记录步数
SAVE_STEPS=500                  # 模型保存步数
EVAL_STEPS=500                  # 评估步数
```

**关键参数说明**：

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `lora_rank` | LoRA 秩大小，决定可训练参数量 | 32-128 |
| `lora_alpha` | 缩放因子，通常为 rank 的 1-2 倍 | 64-256 |
| `lr` | 初始学习率，影响收敛速度 | 1e-4 ~ 5e-4 |
| `min_lr` | 最小学习率，训练后期稳定模型 | lr 的 1/10 |
| `num_train_epochs` | 训练轮数 | 2-5 |
| `moe_aux_loss_coeff` | MoE 辅助损失系数，平衡专家负载 | 0.01-0.1 |
| `moe_expert_capacity_factor` | 专家容量因子，控制 token 丢弃率 | 1.0-2.0 |

#### 3.2.2 启动训练

```bash
cd train_deploy_eval/train/qwen35_35B_A3B_lora_sft

# 启动训练（自动进行 A/B Adapter 权重 merge）
bash start_training.sh
```

**训练流程**：
1. 加载基础模型
2. 初始化 LoRA 适配器
3. 分布式训练（多卡并行）
4. 定期保存 checkpoint
5. 自动 merge A/B Adapter 权重
6. 输出 HF 格式模型

#### 3.2.3 监控训练

```bash
# 查看训练日志
tail -f logs/training.log

# 查看 GPU 使用情况
watch -n 1 nvidia-smi

# 查看集群所有 GPU 状态
mpirun --allow-run-as-root --hostfile tmp_hostfile -npernode 1 nvidia-smi
```

#### 3.2.4 停止训练

```bash
# 停止当前节点的训练
pkill -f python

# 停止集群所有训练进程
pkill -f mpirun
mpirun --allow-run-as-root --hostfile tmp_hostfile -npernode 1 pkill -9 -f python
```

### 3.3 全量微调

#### 3.3.1 配置参数

编辑 `qwen35_35B_A3B_full_sft/qwen3_5_35B_A3B.sh`：

```bash
# 基础配置
MODEL_NAME="Qwen3.5-35B-A3B"
BASE_MODEL_PATH="/path/to/base/model"
OUTPUT_DIR="/path/to/output"
LOG_DIR="/path/to/logs"
DATA_PATH="/path/to/train_data.json"

# 训练参数（全量微调无需 LoRA 参数）
NUM_TRAIN_EPOCHS=3
PER_DEVICE_TRAIN_BATCH_SIZE=2   # 全量微调 batch size 通常更小
GRADIENT_ACCUMULATION_STEPS=16
LEARNING_RATE=5e-5              # 全量微调学习率通常更小
MIN_LR=5e-6
WARMUP_RATIO=0.03
WEIGHT_DECAY=0.01

# MoE 参数
MOE_AUX_LOSS_COEFF=0.01
MOE_EXPERT_CAPACITY_FACTOR=1.0

# 其他参数
MAX_SEQ_LENGTH=4096
LOGGING_STEPS=10
SAVE_STEPS=500
EVAL_STEPS=500
```

**全量微调 vs LoRA 微调对比**：

| 维度 | 全量微调 | LoRA 微调 |
|------|----------|-----------|
| 可训练参数 | 全部参数 | 仅 LoRA 参数（~1%） |
| 显存占用 | 高 | 低 |
| 训练速度 | 慢 | 快 |
| 效果 | 略好 | 接近全量微调 |
| 适用场景 | 数据量大、效果要求高 | 数据量小、快速迭代 |

#### 3.3.2 启动训练

```bash
cd train_deploy_eval/train/qwen35_35B_A3B_full_sft

# 启动训练
bash start_training.sh
```

### 3.4 训练最佳实践

#### 3.4.1 学习率选择

**LoRA 微调**：
- 推荐范围：1e-4 ~ 5e-4
- 初始值：2e-4
- 如果训练不稳定，降低到 1e-4
- 如果收敛太慢，提高到 3e-4

**全量微调**：
- 推荐范围：2e-5 ~ 1e-4
- 初始值：5e-5
- 如果训练不稳定，降低到 2e-5
- 如果收敛太慢，提高到 8e-5

#### 3.4.2 Batch Size 调整

**LoRA 微调**：
- 单卡 batch size：4-8
- 梯度累积：8-16
- 有效 batch size：32-128

**全量微调**：
- 单卡 batch size：1-4
- 梯度累积：16-32
- 有效 batch size：16-128

#### 3.4.3 训练轮数选择

- **小数据集**（< 10k 样本）：3-5 epochs
- **中等数据集**（10k-100k 样本）：2-3 epochs
- **大数据集**（> 100k 样本）：1-2 epochs

#### 3.4.4 早停策略

监控验证集 loss，当连续 3 个 eval_steps 没有改善时停止训练：

```python
# 在训练脚本中添加早停逻辑
from transformers import EarlyStoppingCallback

trainer = Trainer(
    # ...
    callbacks=[EarlyStoppingCallback(early_stopping_patience=3)]
)
```

## 4. 模型部署

### 4.1 模型准备

#### 4.1.1 检查模型文件

训练完成后，检查输出目录：

```bash
ls -lh /path/to/output/

# 应包含以下文件：
# config.json
# model-00001-of-00008.safetensors
# model-00002-of-00008.safetensors
# ...
# model.safetensors.index.json
# tokenizer.json
# tokenizer_config.json
# special_tokens_map.json
```

#### 4.1.2 验证模型完整性

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model_path = "/path/to/output"

# 加载 tokenizer
tokenizer = AutoTokenizer.from_pretrained(model_path)
print(f"Tokenizer loaded: {len(tokenizer)} tokens")

# 加载模型（仅验证，不加载到 GPU）
model = AutoModelForCausalLM.from_pretrained(
    model_path,
    device_map="cpu",
    torch_dtype="auto"
)
print(f"Model loaded: {model.num_parameters() / 1e9:.2f}B parameters")
```

### 4.2 vLLM 部署

#### 4.2.1 启动服务

```bash
# 激活 conda 环境
conda activate qwen35

# 启动 vLLM 服务
vllm serve /path/to/output \
    --tensor-parallel-size 2 \
    --max-model-len 32768 \
    --gpu-memory-utilization 0.8 \
    --host 0.0.0.0 \
    --port 8080 \
    --served-model-name qwen3.5-35b-router
```

**参数说明**：
