# clicktrack_test.py — SONG-01 T1 验收：合成 click track（已知 BPM/拍号）验证节拍与下拍。
# 通过线：beat F-measure ≥0.98，bpm 误差 ≤0.5。下拍相位也记录。
import json
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).parent))
import analysis_lib as lib  # noqa: E402


def make_click_track(bpm=132.0, meter=4, bars=32, sr=lib.SR):
    rng = np.random.default_rng(7)
    total = int(bars * meter * 60.0 / bpm * sr)
    y = np.zeros(total)
    period = 60.0 / bpm * sr
    ground_beats, ground_downbeats = [], []
    for beat_index in range(bars * meter):
        start = int(beat_index * period)
        is_down = beat_index % meter == 0
        length = int(0.06 * sr)
        t = np.arange(length) / sr
        # 真实底鼓 = 低频尾 + 宽带攻击瞬态（纯音会被 HPSS 归入谐波层，检测不到）
        click = np.sin(2 * np.pi * (55 if is_down else 110) * t) * np.exp(-t * 60) * (1.0 if is_down else 0.55)
        click += rng.normal(0, (0.5 if is_down else 0.3), length) * np.exp(-t * 400)
        if beat_index % meter in (1, 3):  # snare 噪声给相位信息
            click += rng.normal(0, 0.25, length) * np.exp(-t * 45)
        y[start:start + length] += click
        ground_beats.append(start / sr)
        if is_down:
            ground_downbeats.append(start / sr)
    y += rng.normal(0, 0.002, total)
    peak = np.abs(y).max()
    return (y / peak * 0.9).astype(np.float32), ground_beats, ground_downbeats, bpm


def main():
    y, ground_beats, ground_downbeats, bpm_true = make_click_track()
    with tempfile.TemporaryDirectory() as tmp:
        wav = str(Path(tmp) / "click.wav")
        sf.write(wav, y, lib.SR)
        beats, downbeats, bpm, method, confidence = lib.estimate_beats(y, audio_path=wav)
    f_measure = lib.beat_f_measure(beats, ground_beats)
    bpm_error = abs(bpm - bpm_true)
    phase_hits = sum(1 for d in downbeats if any(abs(d - g) <= 0.07 for g in ground_downbeats))
    report = {
        "method": method,
        "confidence": confidence,
        "bpm": round(bpm, 3),
        "bpmTrue": bpm_true,
        "bpmError": round(bpm_error, 3),
        "beatFMeasure": round(f_measure, 4),
        "beatCount": len(beats),
        "groundBeatCount": len(ground_beats),
        "downbeatPhaseHits": f"{phase_hits}/{len(ground_downbeats)}",
        "pass": bool(f_measure >= 0.98 and bpm_error <= 0.5),
        "thresholds": {"beatFMeasure": 0.98, "bpmError": 0.5},
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    sys.exit(0 if report["pass"] else 1)


if __name__ == "__main__":
    main()
