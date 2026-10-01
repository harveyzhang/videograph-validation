# analyzer/environment.md — 本地分析器运行环境（SONG-01）

> 建环境与下载模型前必须征得用户同意（ROADMAP SONG-01）。本机基线：Windows、RTX 5070 Laptop 8GB（sm_120）、
> conda 25.5.1 位于 `D:\Users\Martis\anaconda3`、ffmpeg 9 在 PATH、模型缓存统一 `F:\aicg\.models`
> （`HF_HOME`/`TORCH_HOME` 指向此处，不进仓库）。

## 方案 A（默认，2026-10-02 用户已批准）：克隆现有 pytorch 环境

```sh
conda create -n videograph-analyzer --clone pytorch -y     # 复用 torch 2.8.0+cu128，免下 3GB
"D:/Users/Martis/anaconda3/envs/videograph-analyzer/python.exe" -m pip install -r analyzer/requirements-analyzer.txt
```

- 克隆约占 D 盘 9GB（D 剩 29GB）。Python 3.9：依赖版本全部选仍支持 3.9 的（见 requirements）。
- qwen-asr 固定 `transformers==4.57.6`（与源环境一致）；`accelerate==1.12.0` 在克隆环境内升级。
- runner 通过环境变量 `VIDEOGRAPH_ANALYZER_PYTHON` 指定解释器绝对路径，不从 PATH 猜。

## 方案 B（A 出现依赖冲突时）：新建 Python 3.12 环境

```sh
conda create -n videograph-analyzer python=3.12 -y
conda run -n videograph-analyzer python -m pip install torch --index-url https://download.pytorch.org/whl/cu128   # ~3GB
conda run -n videograph-analyzer python -m pip install -r analyzer/requirements-analyzer.txt
```

B 下可升级 librosa 1.0 / demucs 4.1；版本变更必须同步 requirements 与 MODELS.md。

## 模型下载（逐项列出体积，用户同意后执行）

| 模型 | 体积（约） | 用途 | 许可状态 |
|---|---|---|---|
| beat_this 1.1.0 权重 | ~0.1GB | T1 节拍/下拍 | 代码与权重 MIT（README 声明）；训练数据部分受限，作者提示使用者自行判断 |
| Qwen/Qwen3-ForcedAligner-0.6B | ~1.2GB | T3 有歌词文本时强制对齐（中文字级/英文词级） | 模型卡标注 Apache-2.0；**实施时读权重仓库 LICENSE 原文存档后才算可商用** |
| Qwen/Qwen3-ASR-1.7B | ~3.5GB | T3 无文本时歌词草稿（fp16 推理约 4–5GB 显存，8GB 卡需实测） | 仓库 Apache-2.0；权重卡许可**待核实** |
| faster-whisper + large-v3 | 备选，默认不装 | ASR 兜底 | MIT（权重许可待核实） |

NC 或许可不明的（madmom、MMS_FA、whisperX 默认对齐模型、Demucs htdemucs 权重）不进默认链路；
Demucs 分轨（T2）只能由用户显式开启并记录在导出清单。

## 自检

```sh
"…/videograph-analyzer/python.exe" analyzer/doctor.py          # JSON 报告
"…/videograph-analyzer/python.exe" analyzer/clicktrack_test.py # T1 验收：F≥0.98，bpm 误差 ≤0.5
```
