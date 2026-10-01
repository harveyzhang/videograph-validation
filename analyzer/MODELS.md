# analyzer/MODELS.md — 模型选型与商用许可（SONG-01）

> 规则：默认链路只放许可清楚、可商用的模型；“待核实”条目在读到权重仓库 LICENSE 原文并存档链接之前，
> **不算可商用**。NC 或许可不明模型只能由用户显式开启，并在工程 provenance 与导出清单中记录。
> 模型许可不覆盖用户输入的歌曲；界面必须提示用户只处理自己有权使用的音频。

| 用途 | 默认（可商用） | 备选 | 排除出默认（原因） |
|---|---|---|---|
| 节拍/下拍 | `beat_this` 1.1.0：代码与权重 MIT（README 声明）；部分训练数据有版权限制，作者提示自行判断 | librosa `beat_track`（ISC，纯算法无权重） | madmom 预训练（CC BY-NC-SA 4.0）；all-in-one（权重许可未写明） |
| 段落 | 自研：librosa 自相似矩阵 + 新颖度曲线，吸附小节线（ISC）；标签 v1 为 unknown，由人在 SONG-02 修正 | — | all-in-one（同上） |
| 鼓点 | librosa HPSS + 频段 onset（ISC） | 开启分轨后用 drums stem | — |
| 人声分离（可选 T2） | 默认不分轨；显式开启时 Spleeter 2.4.2（代码 MIT；权重未单独声明，已被商业软件采用，按相对低风险；需 TF + py3.8–3.11 独立环境） | Demucs htdemucs：代码 MIT，但权重训练用 MUSDB18（仅学术），issue #327 无官方答复 → 灰色，只能显式开启并记录 | 默认关闭 |
| 歌词识别 | `Qwen/Qwen3-ASR-1.7B`（0.6B 降级备选）：仓库 Apache-2.0，权重卡**待核实**；52 语言含中英 | faster-whisper 1.2.1（MIT）+ Whisper large-v3（MIT，**待核实**） | — |
| 强制对齐 | `Qwen/Qwen3-ForcedAligner-0.6B`：模型卡 Apache-2.0（**待核实 LICENSE 原文**）；11 语言含中英粤日韩；单次 ≤5 分钟；官方只声明“语音”，对演唱效果需 pdoom 基准实测 | Montreal Forced Aligner english/mandarin_mfa（CC BY 4.0，需署名）；stable-ts（MIT）细化词时间 | MMS_FA（CC-BY-NC，pdoom 原管线所用，不复用）；whisperX 默认 wav2vec2（部分 NC） |

## 待核实清单（SONG-01 实施时逐项完成）

- [ ] Qwen3-ForcedAligner-0.6B 权重 LICENSE 原文（链接存档于此）
- [ ] Qwen3-ASR-1.7B / 0.6B 权重卡许可原文
- [ ] Whisper large-v3 权重许可原文（仅当启用备选）
- [ ] beat_this 训练数据限制的作者说明原文

## 验证顺序（每次下载前征得用户同意）

1. T1：仅需 pip 依赖 + beat_this 小权重（合成 click track F≥0.98、bpm 误差 ≤0.5，pdoom 基准记录）。
2. Qwen3-ForcedAligner（~1.2GB）：pdoom 歌词文本对齐 vs 参考词时间，中位误差 ≤50ms 才定为默认。
3. Qwen3-ASR-1.7B（~3.5GB）：8GB 卡实测显存；失败自动降级 0.6B 并记录 provenance。
4. 备选（MFA / stable-ts）只在默认链路不达标时启用。
