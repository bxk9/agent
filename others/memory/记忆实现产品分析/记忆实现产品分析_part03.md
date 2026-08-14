> **原生全模态统一架构**：2.4 万亿个参数基于统一自回归骨架构建的大规模基础模型，以统一自回归框架从零开始同时训练文本、图像、视频、音频，实现跨模态理解与生成。
> 
> **一目标：**将所有模态映射到共享的标记空间，并使用统一的下一组标记预测进行端到端优化。
> 
> **全模态能力**：通过有效消除模态障碍，该模型实现了无缝的多模态理解和生成。

### **技术路线与系统架构**

ERNIE 5.0采用纯自回归统一架构：在预训练阶段将各类多模态数据按统一方式输入，使模型底层即能协同感知和生成不同媒体格式。采用超大规模MoE结构，只有<3%参数激活，使用弹性训练（Once-For-All）预训练流程。所有模态被映射到共享Token空间，通过统一的下一组Token预测目标优化。训练语料包含海量文本和多模态数据，通过分阶段扩展上下文长度至128K。

该架构下，ERNIE 5.0 采用完全统一的方法。

  - **文本建模**：采用标准**下一词预测 (NTP) ，并通过多词预测 (MTP)**加速，以提高推理吞吐量。
  - **视觉建模**：采用**下一帧尺度预测（NFSP）**。图像被视为单帧视频，使模型能够同时学习空间（多尺度）和时间（多帧）表示。
  - **音频建模**：采用深度自回归设计实现**下一编解码器预测 (NCP) ，从语义内容到细粒度的声学细节，对音频进行分层建模。**

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/kozutFEqNZewCDWDZUeDjhgpWM7jI0ZI43QkLvne1yMMKlSsKvK899k-P_rq3dLP "image.png")

#### 关键架构创新：超稀疏 MoE 与统一自回归

  - **模态无关专家路由 (Modality-Agnostic Routing):** 模型内部的“专家”（例如，“视觉专家”与“文本专家”）并不预先指定负责哪种模态。路由机制根据 Token 的语义表示自动分发任务（标记特征驱动）。
  - **超稀疏混合专家架构 (Ultra-Sparse MoE):** 尽管拥有 2.4 万亿总参数，但通过先进的稀疏激活机制，模型在推理时仅需激活**不到 3%** 的参数。这种设计在保证极高性能上限的同时，大幅降低了计算成本和响应延迟（计算成本控制在与规模小得多的密集模型相当的水平）。
  - **统一自回归框架 (Unified Autoregressive Framework):** 模型将所有模态的信息（文本 Token、视觉 Patch、音频 Codec 等）映射到一个**共享的符号空间（Shared Token Space）**。通过统一的“下一组 Token 预测”（Next-Group-of-Tokens Prediction）任务进行训练，实现了模态间的无缝交互。
  - **自发专业化：** 训练后发现，专家们会自发形成分工，有些专攻逻辑，有些专攻视觉特征，还有些成为跨模态对齐的“通才”。

#### 全模态处理技术细节

  - **文本：** 采用标准的 Next-Token Prediction (NTP) 并辅以 Multi-Token Prediction (MTP) 增强生成效率和逻辑性。
  - **视觉（图像与视频）：** 使用 Next-Frame-and-Scale Prediction (NFSP)，使模型不仅能理解静态画面，还能捕捉视频中的动作衔接、情感氛围和叙事意图。
  - **音频：** 采用 Next-Codec Prediction (NCP)，在音频理解（如语音识别）和生成（文本转语音）上均达到业界领先水平。

#### 弹性训练与部署 (Elastic Training)[一次性]

为了满足多样化的商业化部署需求，ERNIE 5.0 提出了**弹性训练策略**。通过一次训练即可优化出一个“超网络”，可以根据需求动态裁剪：

  - **弹性深度：**训练过程中随机跳过网络层。
  - **弹性宽度：** 动态限制参与计算的专家池。
  - **弹性稀疏度：** 灵活调节推理时的激活专家数（自适应 Top-k 路由）。 这使得模型无需重新微调，即可衍生出不同尺寸的子模型，直接继承全量模型的能力。

#### 训练方法

  **数据：**

  预训练语料库包含**数万亿个词元**，采用**UTF-16BE**编码以实现卓越的多语言支持。利用配对数据（图像-文本、视频-文本）和交错序列的组合，以实现稳健的跨模态上下文学习。

  **基模：**

  **ERNIE 5.0 基于**[**PaddlePaddle**](https://github.com/PaddlePaddle/Paddle)构建，采用定制的混合并行策略来大规模管理超稀疏 MoE 架构。训练过程经过严格的分阶段进行**——**将上下文长度从 8K 扩展到 128K——并融合了先进的稳定性技术，以防止任何单一模态主导梯度更新。

  **post-training（****RL****）：**

    - **U-RB（无偏重放缓冲区）**：在不引入采样偏差的情况下解决长尾响应效率低下问题。
    - **稳定性机制（MISC 和 WPSM）**：缓解熵崩溃并专注于优化具有挑战性的样品的技术。
    - **AHRL（基于自适应提示的强化学习）**：一种提供逐渐消失的“思维骨架”（提示）的支架式方法，以促进稀疏奖励、困难推理任务的学习。

### **记忆实现方法**

截至目前，文心5.0未公开特定的持久记忆方案。文心5.0自身没有额外记忆模块，仅通过输入扩展来处理长上下文（最长可达128K Token）。对话交互中，系统仅使用当前对话历史（短期记忆）。若需要跨会话记忆，可能依托百度云服务层面的记忆数据库（例如千帆平台未来可能提供类似Polar Agent Memory的服务），但官方未明说。

### **评估方法与基准**

百度声称ERNIE 5.0在多模态任务上突破SOTA。在超过 40 项基准评测中，ERNIE 5.0 展现出“六边形战士”的特质：

  - **深度推理：** 在 MATH 等复杂推理任务中表现卓越。
  - **精细理解：** 能够识别视频中选手的细微表情（如起跳时的紧张皱眉），并结合常识进行逻辑推断（如通过角色性格判断视频中人的真实身份）。
  - **智能体能力：** 模型在任务规划、工具调用（Function Calling）方面有显著提升，能自主搜索并整合信息完成长程任务。
  - **数字人驱动：** 基于其全模态能力，可实现声音 Token 实时驱动数字人的表情与口型，输出低延迟、高表现力的视频流。

#### 语言能力

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/ZcUjthhouadKW7DWUgtvlR-0JSwaHcQupyo7quNr4tNX-62pPa7TNk7PQl4EKE3Y "image.png")

_（表1：训练前对比）_

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/hQ3DHWJA33Dz6VAAcPjsga4Ys-OXmwtqPovaws-mN8HA1chmLJhZQCmlQOySS0Wi "image.png")

_（表2：训练后对比）_

#### 多模态理解

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/msxUgt0HGousNkNQkTZrePrckJ4UF0scELMvWe46VgZ2OEr6_YR9WJEmiBP0m3xn "image.png")

#### 代际能力

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/HPUUuQdhnlQETyJSqg7wBRBtH2N6UGLjdmMdMu0Fe0DwIpIWZ1S6xphE7bZVG4uK "image.png")

_（表5：图像生成）_

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/dbYAm1gj6PMBpxHdvi6xIjpWgjbTtsldcGdyoAQFE04gCNbUy_1z0rDiceywpGbu "image.png")

_（表 6：视频生成）_

#### 音频功能

**在音频理解方面**取得了一流的成绩（例如，TUT2017），并且**在文本转语音**性能方面具有竞争力。

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/fex2MPeFnMVrFTUqgWBvr8PudfjfeY89V-9l-eLd44GhUNZ1NVmkvIoAel1gYAND "image.png")

_（表 7：音频理解）_

![image.png](http://veditor.vivo.xyz/api/v1/attachment/file/q8ooJ1XZ8aDPF3ko-9mW6YdvJ4K2vEevSaaykHEIVbuI1Bflp1ya1f3kNPENmv5M "image.png")

_（表 8：文本转语音）_

### **实验设置与结果**

参数量远超前代，但推理仅激活小部分参数。实际延迟和吞吐尚无公开数据。其他数据结果如上。

### **典型问题示例**

暂无公开的专门对话示例。模型设计定位通用任务，包括问答、写作、图像生成等，多轮对话需要依赖上下文处理能力。

### **应用场景与演示**

文心5.0面向中外文本及多模态应用，现开放给个人和企业，通过百度App和千帆平台可体验。其记忆功能暂无说明。主要作为百度AI开放平台的基座，支撑文心App、文心一问等产品。对手机助手而言，它可用作云端大模型引擎，为智能搜索或语音助手提供多模态感知能力，但本身不具备专门的对话记忆功能。

### **技术贡献与影响**

ERNIE 5.0代表了百度在多模态统一训练方面的探索，对模型融合架构有启示意义。虽暂不聚焦记忆，但为多模态交互的智能助理打下基础。通过成功地将理解和生成整合到一个单一、弹性且可扩展的自回归框架中，为构建不仅能够处理数据，还能像人类认知一样流畅地感知和创造的系统奠定了基础。**模态无关路由**和**弹性训练**方面的创新为在从云超级集群到边缘设备等各种环境中部署大规模智能开辟了新的可能性，且不会影响其性能。

### **开源资料与链接**

模型本身非开源，只在百度平台提供API/服务。相关论文发布（[https://arxiv.org/abs/2602.04705](https://arxiv.org/abs/2602.04705)）

# 阿里巴巴

> 2026年Q1通义千问发布了面向对话场景的Qwen 3.5系列模型（35B、27B、122B、Flash等），采用混合稀疏专家（MoE）与创新注意力架构实现高效多模态能力。预训练使用了超大规模多语言多模态语料（官方宣称36T tokens），并通过混合精度FP8流水线与并行策略提升训练效率。微调阶段引入了指令调教与强化学习（包括P-GenRM个性化奖励模型），对齐用户偏好并支持代码解释器、网络搜索等工具调用。

对于移动场景，团队同时发布了量化版（如Qwen3-VL-2B 4-bit）并设计端云混合部署架构。评估方面，Qwen3-Max-Thinking在多项国际基准刷新了纪录；常见评测采用困惑度、BLEU/ROUGE、USR等指标，并结合用户研究和A/B测试评估对话体验。
