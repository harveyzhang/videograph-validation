# analysis_lib.py — SONG-01 共享分析库：包络/鼓点/节拍/段落。
# 方法论对齐 pdoom 参考分析（100fps、46ms RMS 窗、单极平滑、99 分位归一化、HPSS 频段攻击点），
# 但不复制其手调常量；所有参数显式写出并进入 provenance。
import bisect
import numpy as np

SR = 44100
ENV_FPS = 100
HOP = int(SR * 0.01)          # 10ms 帧移
WIN = int(SR * 0.046)         # 46ms RMS 窗（≈pdoom）
SMOOTH_ATTACK = 0.010         # s
SMOOTH_RELEASE = 0.090        # s
BAND_LOW = 150.0              # Hz（low/mid 分界）
BAND_HIGH = 4000.0            # Hz（mid/high 分界）
KICK_MAX = 120.0
SNARE_LO, SNARE_HI = 1500.0, 5000.0
HAT_MIN = 7000.0


def load_mono(path, sr=SR):
    import librosa
    y, _ = librosa.load(path, sr=sr, mono=True)
    return y


def _one_pole(values, attack_s, release_s):
    a = float(np.exp(-1.0 / (attack_s * ENV_FPS)))
    r = float(np.exp(-1.0 / (release_s * ENV_FPS)))
    out = np.empty_like(values)
    acc = values[0]
    for i, v in enumerate(values):
        acc = a * acc + (1 - a) * v if v > acc else r * acc + (1 - r) * v
        out[i] = acc
    return out


def _normalize(values):
    peak = float(np.percentile(values, 99))
    if peak <= 1e-9:
        return np.zeros_like(values)
    return np.clip(values / peak, 0.0, 1.0)


def compute_envelopes(y, sr=SR, fps=ENV_FPS):
    """rms/low/mid/high 包络：STFT 频段能量 + 单极平滑 + 99 分位归一化（0..1）。"""
    import librosa
    hop = int(sr * 0.01)
    n_fft = 4096
    stft = np.abs(librosa.stft(y, n_fft=n_fft, hop_length=hop))
    freqs = librosa.fft_frequencies(sr=sr, n_fft=n_fft)
    band = lambda lo, hi: np.sum(stft[(freqs >= lo) & (freqs < hi)] ** 2, axis=0)
    energy = {
        "low": band(0, BAND_LOW),
        "mid": band(BAND_LOW, BAND_HIGH),
        "high": band(BAND_HIGH, sr / 2 + 1),
    }
    rms = librosa.feature.rms(y=y, frame_length=WIN, hop_length=hop)[0] ** 2
    frames = min(len(rms), min(len(v) for v in energy.values()))
    out = {}
    for key, values in [("low", energy["low"]), ("mid", energy["mid"]), ("high", energy["high"])]:
        smoothed = _one_pole(values[:frames], SMOOTH_ATTACK, SMOOTH_RELEASE)
        out[key] = _normalize(smoothed).astype(float).tolist()
    rms_smooth = _one_pole(rms[:frames], SMOOTH_ATTACK, SMOOTH_RELEASE)
    out["rms"] = _normalize(rms_smooth).astype(float).tolist()
    return out, fps, hop / sr


def _band_attacks(y, sr, lo, hi):
    import librosa
    S = np.abs(librosa.stft(y, n_fft=4096, hop_length=int(sr * 0.01)))
    freqs = librosa.fft_frequencies(sr=sr, n_fft=4096)
    mask = (freqs >= lo) & (freqs < hi)
    flux = np.maximum(0.0, np.diff(S[mask], axis=1)).sum(axis=0)
    peaks = librosa.util.peak_pick(flux, pre_max=8, post_max=8, pre_avg=16, post_avg=16, delta=flux.max() * 0.05, wait=10)
    times = librosa.frames_to_time(peaks, sr=sr, hop_length=int(sr * 0.01))
    peak_values = flux[peaks] if len(peaks) else np.array([])
    top = peak_values.max() if len(peak_values) else 1.0
    strengths = (peak_values / top * 0.9 + 0.05) if len(peak_values) else np.array([])
    return [(float(t), float(s)) for t, s in zip(times, strengths)]


def _near(t, events, window):
    return any(abs(t - other) <= window for other, _ in events)


def percussion_onsets(y, sr=SR):
    """kick/snare/hat 攻击点（[time, strength]）：HPSS 打击成分 + 频段 flux 峰。
    vocal onset 无分轨时用「全混音中低频 onset − 已归入鼓组的事件」近似（provenance 标 hpss+band-flux）。"""
    import librosa
    percussive, _ = librosa.effects.hpss(y)
    kick = _band_attacks(percussive, sr, 20, KICK_MAX)
    snare = _band_attacks(percussive, sr, SNARE_LO, SNARE_HI)
    hat = _band_attacks(percussive, sr, HAT_MIN, sr / 2)
    hat = [(t, s) for t, s in hat if not _near(t, snare, 0.04) and not _near(t, kick, 0.03)]
    harmonic, _ = librosa.effects.hpss(y)
    melodic = [(t, s) for t, s in _band_attacks(harmonic, sr, 150, HAT_MIN)
               if not _near(t, kick, 0.03) and not _near(t, snare, 0.04) and not _near(t, hat, 0.03)]
    return {"kick": kick, "snare": snare, "hat": hat, "vocal": melodic}


def estimate_beats(y, sr=SR, meter=4, audio_path=None, device=None):
    """节拍/下拍：优先 beat_this（GPU 可用更快），失败回退 librosa beat_track + 相位推算（低置信）。"""
    import librosa
    try:
        beats, downbeats, method, confidence = _beats_via_beat_this(audio_path, device)
        if beats is not None and len(beats) > 4:
            # BPM 取拍位置线性拟合斜率：网格局部吸附有抖动，长程速率才是真实 BPM
            fit_bpm = 60.0 / float(np.polyfit(np.arange(len(beats)), np.asarray(beats, dtype=float), 1)[0])
            return list(map(float, beats)), list(map(float, downbeats)), fit_bpm, method, confidence
    except Exception as beat_this_error:  # 模型缺失/显存不足都回退，provenance 记录真实方法
        import sys as _sys
        print(f'WARNING beat_this fallback: {beat_this_error}', file=_sys.stderr)
    tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr, units="time", trim=False)
    tempo_value = float(np.atleast_1d(tempo)[0])
    # 八度校正：对 t/2、t、2t 候选按「匹配到的 kick/snare 事件强度均值」评分——
    # 2× 网格在真实音乐里一半落在 hat/空档（强度≈0），均值减半即被淘汰；错拍半速时 2× 网格仍全踩强拍。
    onsets = percussion_onsets(y, sr)
    strong = sorted([(t, s) for key in ("kick", "snare") for t, s in onsets[key]])
    strong_times = [t for t, _ in strong]

    def grid_score(grid):
        total = 0.0
        for t in grid:
            best = 0.0
            index = bisect.bisect_left(strong_times, t - 0.06)
            while index < len(strong_times) and strong_times[index] <= t + 0.06:
                best = max(best, strong[index][1])
                index += 1
            total += best
        return total / max(1, len(grid))

    scored = []
    for candidate in (tempo_value / 2, tempo_value, tempo_value * 2):
        if not (20 <= candidate <= 400):
            continue
        _, grid = librosa.beat.beat_track(y=y, sr=sr, bpm=float(candidate), units="time", trim=False)
        if len(grid) < 4:
            continue
        scored.append((float(candidate), grid_score(np.asarray(grid, dtype=float)), np.asarray(grid, dtype=float)))
    if not scored:
        return [], [], tempo_value, "librosa.beat_track", 0.3
    best_score = max(score for _, score, _ in scored)
    qualified = [entry for entry in scored if entry[1] >= max(0.7 * best_score, 0.4)]
    bpm_value, score, beats = max(qualified, key=lambda entry: entry[0])
    strength_at = lambda t: max((s for events in onsets.values() for other, s in events if abs(other - t) < 0.05), default=0.0)
    best_offset, best_score = 0, -1.0
    for offset in range(meter):
        score = sum(strength_at(t) for i, t in enumerate(beats) if (i - offset) % meter == 0)
        if score > best_score:
            best_offset, best_score = offset, score
    downbeats = [float(t) for i, t in enumerate(beats) if (i - best_offset) % meter == 0]
    # BPM 取拍位置的线性拟合斜率：网格局部有抖动，长程速率才是真实 BPM
    fit_bpm = 60.0 / float(np.polyfit(np.arange(len(beats)), np.asarray(beats), 1)[0])
    return beats.tolist(), downbeats, fit_bpm, "librosa.beat_track+phase+octave", 0.5


def _beats_via_beat_this(audio_path, device):
    import torch
    if device is None:
        device = "cuda" if torch.cuda.is_available() else "cpu"
    try:
        from beat_this.inference import File2Beats  # type: ignore
    except ImportError:
        from beat_this.inference.file2beats import File2Beats  # type: ignore
    f2b = File2Beats(checkpoint_path="final0", device=device)
    beats, downbeats = f2b(audio_path)
    return np.asarray(beats), np.asarray(downbeats), "beat_this(final0,%s)" % device, 0.9


def estimate_sections(y, sr=SR, downbeats=None, fps_hint=1.0):
    """段落：色度+MFCC 自相似矩阵 → 棋盘核新颖度曲线 → 峰值切分，吸附最近下拍。标签 v1=unknown。"""
    import librosa
    hop = int(sr * 1.0)  # 1s 分辨率足够段落级
    chroma = librosa.feature.chroma_stft(y=y, sr=sr, hop_length=hop)
    mfcc = librosa.feature.mfcc(y=y, sr=sr, hop_length=hop, n_mfcc=12)
    features = np.vstack([chroma, mfcc / (np.abs(mfcc).max() + 1e-9)])
    S = librosa.segment.recurrence_matrix(features, width=8, mode="affinity", metric="cosine", sym=True)
    # 新颖度：沿主对角线的亲和度差分（棋盘核的稳定近似，无额外依赖）
    diag = np.array([S[i, i + 8] if i + 8 < S.shape[0] else 0.0 for i in range(S.shape[0] - 8)])
    novelty = np.abs(np.diff(diag, n=1))
    if len(novelty) < 4:
        return [{"start": 0.0, "end": len(y) / sr, "label": "unknown", "confidence": 0.3}]
    peaks = librosa.util.peak_pick(novelty, pre_max=12, post_max=12, pre_avg=24, post_avg=24, delta=novelty.max() * 0.2, wait=20)
    bounds = sorted({0.0} | {float(p) for p in peaks} | {len(y) / sr})
    if downbeats:
        snapped = []
        for b in bounds:
            if b in (0.0, len(y) / sr):
                snapped.append(b)
                continue
            nearest = min(downbeats, key=lambda d: abs(d - b))
            snapped.append(float(nearest) if abs(nearest - b) <= 4.0 else b)
        bounds = sorted(set(snapped))
    sections = []
    for start, end in zip(bounds, bounds[1:]):
        if end - start >= 5.0:
            sections.append({"start": start, "end": end, "label": "unknown", "confidence": 0.4})
    if not sections:
        sections = [{"start": 0.0, "end": len(y) / sr, "label": "unknown", "confidence": 0.3}]
    return sections


def beat_f_measure(predicted, reference, tolerance=0.07):
    """拍点 F 值（±tolerance 秒匹配）。"""
    if not predicted or not reference:
        return 0.0
    matched, used = 0, set()
    for t in predicted:
        for i, r in enumerate(reference):
            if i not in used and abs(t - r) <= tolerance:
                matched += 1
                used.add(i)
                break
    precision, recall = matched / len(predicted), matched / len(reference)
    return 2 * precision * recall / (precision + recall) if precision + recall else 0.0
