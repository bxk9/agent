# 02 · ASR 与音频链路接入

## 一句话概括

陈乾在 06-09 单日完成 **ASR 工具首建 + Agent 层音频 URL 解析**，并在 07-15 前后通过 mime 白名单、后缀兜底、超时治理，将音频链路稳定率从"半可用"提升到"可交付"。

---

## 时间线

| 日期 | Commit |
|:---:|:---|
| 06-09 | 新增 asr 工具 接入面试复盘链路 |
| 06-09 | feat(agent): 解析 message.metadata.audioUrl，拼入 query 供面试复盘使用 |
| 06-09 | ASR 超时时间设为 600s |
| 06-12 | feat(executor): 自动从音频后缀文件 part 提取 audio_url |
| 06-12 | fix(executor): 文件名为空时回退为'未命名文件' |
| 06-15 | feat(executor): 从 text 兜底提取 claw:// 音频链接 + 签发前去重 |
| 07-10 | feat(audio): 本地路径拦截与转写失败兜底，引导下游上传云端链接 |
| 07-13 | docs(skill): 录音转写失败时透传上传引导 |
| 07-15 | fix: 音频识别改为 mime 白名单+后缀兜底，支持 mpeg/mpga |
| 07-16 | feat: 不支持的音频格式给出明确提示引导用户转码 |

---

## 三层解析链

陈乾在 executor 层构建了**三层音频 URL 提取**：

```
1. message.metadata.audioUrl  ← 前端显式传入（06-09）
2. file part with audio 后缀   ← 用户直接上传附件（06-12）
3. text 中 claw:// 兜底提取    ← 模型输出/用户粘贴（06-15）
```

**签发前去重**：同一 URL 多路径命中时只签发一次，避免多次调用 ASR。

---

## MIME 白名单方案（07-15）

### 问题

初期用后缀判断 → mp3 变体（mpeg/mpga）被拒识 → 用户困惑

### 方案

```python
# 优先 MIME 白名单
if content_type in {"audio/mpeg", "audio/mpga", "audio/wav", ...}:
    accept()
# MIME 缺失时后缀兜底
elif suffix in {".mp3", ".wav", ".m4a", ".mpeg", ".mpga"}:
    accept()
else:
    guide_user_to_transcode()  # 07-16 明确提示
```

---

## 失败兜底策略（07-10 / 07-13）

不是所有音频都能转写成功。陈乾设计了**"失败但不断流"**策略：

| 失败原因 | 处理 |
|:---|:---|
| 本地路径（file://） | 直接拦截，引导上传云端 |
| 转写超时 | 返回 download_url，跳过 HTML 交付 |
| 转写内部错误 | 收紧失败判断口径，透传上传引导 |

**关键设计**：即使 ASR 失败，用户也拿到 download_url，不会"啥也没有"。

---

## 与团队协作

- **司棋**：VFS 签发接口（`claw://` 短链）
- **11197109**：ASR 与 VLM 并列的多模态工具体系
- **yitong**：语音链路上游对接（mock 面试产出的音频文件直接进入 ASR）

---

## 量化成果

| 指标 | 值 |
|:---|:---|
| 支持音频格式 | mp3/wav/m4a/mpeg/mpga（5+ 变体） |
| ASR 超时上限 | 600s（长录音支持） |
| URL 提取通路 | 3 层（metadata / file part / text 兜底） |
| 失败兜底 | 全场景（不断流） |

---

## 版本历史

| 版本 | 日期 | 变更 |
|:---:|:---:|:---|
| v1.0 | 2026-08-10 | 首次建立 |

## 取数命令

```bash
git log --author=陈乾 --grep="asr\|audio\|音频\|转写" --pretty=format:"%ad %s" --date=short
```
