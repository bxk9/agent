2. **情感感知**：主动感知用户的情绪变化，并适当回应。
   如果用户今天的情绪与之前不同，温和地关心，不要审问。
3. **连续性**：记住上次对话中未完成的话题和待办事项，适时跟进。
   例如："上次你说要去看牙医，后来怎么样了？"
4. **边界感**：虽然你了解用户很多信息，但不要在不相关的上下文中突兀地
   提起敏感信息。让信息的引用服务于当前对话。

# 用户画像（L3 长期记忆）
{user_profile_json}

# 当前话题上下文（L2 情景记忆）
## 话题：{current_topic_name}
## 历史摘要：
{accumulated_context}

## 上次对话的关键信息：
- 日期：{last_session_date}
- 摘要：{last_session_summary}
- 当时的情感状态：{last_emotional_state}
- 待跟进事项：{unresolved_items}

# 近期重要事件（时间线）
{recent_events_timeline}

# 对话历史压缩摘要（L1 工作记忆 - 早期部分）
{compressed_early_conversation}

# 情感指导
- 用户当前的情感基线：{emotional_baseline}
- 上次交流的情感状态：{last_emotional_state}
- 如果检测到以下信号，请优先进行情感回应：
  * 用户使用了情绪词（烦、累、开心、难过等）
  * 用户主动分享个人经历
  * 用户语气与平时不同（更短促/更沉默/更兴奋）
  
- 情感回应优先级：
  1. 先共情（"听起来你今天挺累的"）
  2. 再询问（"想聊聊吗？"）
  3. 最后才建议（只在用户明确寻求建议时给出）

# 记忆更新指令
在每次回复后，你需要在回复末尾以特殊格式标注需要更新的记忆信息：
（注意：这部分会被系统截取，用户不会看到）

<!-- MEMORY_UPDATE
{
    "new_facts": [],
    "emotional_state": "",
    "decisions": [],
    "follow_up_items": []
}
-->
```

### 情感追踪子系统

**情感标签体系**：

```plaintext
一级情感：正面 | 负面 | 中性
二级情感：
  正面 → 开心 | 兴奋 | 满足 | 感激 | 期待
  负面 → 沮丧 | 焦虑 | 愤怒 | 委屈 | 孤独 | 疲惫
  中性 → 平静 | 思考 | 犹豫 | 好奇
```

**情感检测 prompt（预处理阶段使用）**：

```plaintext
请分析以下用户消息的情感状态。

用户消息："{user_message}"

用户近期情感轨迹：{recent_emotion_history}

请输出：
1. 当前情感标签（从给定体系中选择）
2. 情感强度（1-5）
3. 与上次情感的变化方向（提升/下降/不变）
4. 是否需要优先进行情感关怀（是/否）
5. 判断依据
```

### 动态上下文组装算法

这是整个方案中最关键的工程部分——如何在有限的 token 预算内，组装出最有效的 prompt：

```python
def assemble_context(user_message, token_budget=120000):
    """
    动态组装上下文的核心算法（伪代码）
    """
    
    # 1. 固定部分：角色定义 + 行为准则（约 1000 tokens）
    context = ROLE_DEFINITION  # 固定不变
    remaining_budget = token_budget - count_tokens(context)
    
    # 2. L3 长期记忆：用户画像（约 500-2000 tokens）
    user_profile = load_user_profile()
    context += format_user_profile(user_profile)
    remaining_budget -= count_tokens(user_profile)
    
    # 3. 话题识别与 L2 记忆检索
    current_topic = identify_topic(user_message, existing_topics)
    
    if current_topic:
        # 3a. 匹配到已有话题：注入该话题的情景记忆
        topic_memory = load_topic_memory(current_topic.topic_id)
        
        # 优先注入：最近一次该话题的对话摘要
        context += format_last_session(topic_memory.sessions[-1])
        # 其次：累积上下文
        context += topic_memory.accumulated_context
        # 最后：更早的会话摘要（按时间倒序，在预算内尽量多装）
        for session in reversed(topic_memory.sessions[:-1]):
            session_text = format_session_summary(session)
            if remaining_budget > count_tokens(session_text) + 30000:
                # 保留至少 30000 tokens 给 L1 工作记忆
                context += session_text
                remaining_budget -= count_tokens(session_text)
            else:
                break
    
    # 4. L1 工作记忆：当前对话历史
    conversation_history = get_current_conversation()
    
    if count_tokens(conversation_history) <= remaining_budget:
        # 全量装入
        context += conversation_history
    else:
        # 需要压缩
        # 4a. 最近 30 轮始终保留原文
        recent_30 = conversation_history[-30:]
        context += recent_30
        remaining_budget -= count_tokens(recent_30)
        
        # 4b. 更早的部分进行分段压缩
        older_history = conversation_history[:-30]
        chunks = split_into_chunks(older_history, chunk_size=10)
        
        compressed_chunks = []
        for chunk in chunks:
            summary = llm_summarize(chunk, COMPRESSION_PROMPT)
            compressed_chunks.append(summary)
        
        # 4c. 压缩后如果还是超预算，进一步合并压缩
        while count_tokens(compressed_chunks) > remaining_budget:
            # 合并最旧的两段压缩
            merged = llm_summarize(
                compressed_chunks[0] + compressed_chunks[1], 
                MERGE_PROMPT
            )
            compressed_chunks = [merged] + compressed_chunks[2:]
        
        context = insert_before_recent(context, compressed_chunks, recent_30)
    
    # 5. 情感指导（约 500 tokens）
    emotion_state = detect_emotion(user_message)
    emotion_guidance = format_emotion_guidance(
        emotion_state, 
        user_profile.emotional_baseline
    )
    context += emotion_guidance
    
    return context
```

### 记忆更新流程（后处理）

每次模型回复后，执行以下后处理流程：

```python
def post_process(assistant_response, user_message, conversation):
    """
    后处理：提取并更新记忆
    """
    
    # 1. 从模型回复中解析 MEMORY_UPDATE 标记（如果有）
    memory_update = parse_memory_update(assistant_response)
    
    # 2. 清理回复（移除 MEMORY_UPDATE 标记后返回给用户）
    clean_response = remove_memory_tags(assistant_response)
    
    # 3. 使用额外 LLM 调用提取记忆（双保险）
    extracted = llm_extract_memory(
        user_message, 
        clean_response,
        MEMORY_EXTRACTION_PROMPT
    )
    
    # 4. 合并记忆更新
    merged_update = merge_memory_updates(memory_update, extracted)
    
    # 5. 更新 L3（如果有新的画像信息）
    if merged_update.new_facts:
        update_user_profile(merged_update.new_facts)
    
    # 6. 更新 L2（当前话题的情景记忆）
    if current_topic:
        append_to_topic_memory(
            current_topic.topic_id, 
            merged_update
        )
    
    # 7. 更新情感轨迹
    update_emotion_history(merged_update.emotional_state)
    
    # 8. 检查是否需要触发 L1 压缩
    if get_conversation_length() > COMPRESSION_THRESHOLD:
        trigger_compression()
    
    return clean_response
```

### 关键实现细节

#### 记忆冲突处理

当新信息与旧记忆矛盾时（例如用户之前说在北京，现在说搬到了上海）：

```plaintext
你是一个记忆管理助手。以下新信息可能与已有记忆存在冲突，请进行判断。

已有记忆：
{existing_memory_item}

新信息：
{new_information}

请判断：
1. 是否存在真正的冲突（而非补充/细化）？
2. 如果冲突，应该保留哪个版本？（通常以最新信息为准）
3. 旧信息是否应该归档而非删除？（例如"用户之前住在北京，2025年4月搬到了上海"）

输出更新后的记忆条目。
```

#### 记忆遗忘机制

为了避免记忆无限膨胀：

```python
def memory_decay():
    """
    记忆衰减：定期清理不再相关的记忆
    """
    for memory_item in all_memories:
        # 衰减因子 = 时间衰减 × 访问频率
        days_since_last_access = (now - memory_item.last_accessed).days
        access_count = memory_item.access_count
        
        decay_score = access_count / (1 + days_since_last_access * 0.1)
        
        if decay_score < FORGET_THRESHOLD:
            # 不直接删除，而是降级
            if memory_item.level == 'active':
                memory_item.level = 'archived'
            elif memory_item.level == 'archived' and days_since_last_access > 90:
                memory_item.level = 'deleted'
```

#### 记忆检索优化

对于场景二，跨对话记忆检索需要精准高效：

```python
def retrieve_relevant_memories(user_message, top_k=10):
    """
    混合检索策略
    """
    # 1. 向量相似度检索（语义匹配）
    semantic_results = vector_search(
        embed(user_message), 
        memory_store, 
        top_k=top_k * 2
    )
    
    # 2. 关键词检索（精确匹配人名、地名等实体）
    entities = extract_entities(user_message)
    keyword_results = keyword_search(entities, memory_store)
    
    # 3. 时间衰减加权
    for result in semantic_results + keyword_results:
        recency_boost = 1.0 / (1 + days_ago(result.timestamp) * 0.05)
        result.final_score = result.relevance_score * 0.7 + recency_boost * 0.3
    
    # 4. 合并去重，取 top_k
    merged = merge_and_deduplicate(semantic_results, keyword_results)
    return sorted(merged, key=lambda x: x.final_score, reverse=True)[:top_k]
```

### 用户体验保障

确保记忆功能不降低用户体验的关键原则：

**1. 自然引用，不刻意展示记忆**

```plaintext
❌ 错误方式：
"根据我的记忆数据库记录，你在2025年3月15日曾经表示对产品经理工作不满意。"

✅ 正确方式：
"上次你提到在考虑转型的事情，最近有什么新想法吗？"
```

**2. 记忆引用的 prompt 指导**：

```plaintext
## 记忆引用规范
- 像朋友一样自然地提起共同记忆，而非像数据库查询一样引用
- 使用模糊时间词："上次"、"之前"、"你前段时间说的"，而非精确日期