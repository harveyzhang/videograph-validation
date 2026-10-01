# analyze.py — SONG-01 分析 CLI：读 job JSON，跑 T0/T1/T3，产出 videograph-analysis/v2（原子写）。
# 用法：python analyze.py --spec job.json
# spec: {audioPath, outDir, stages?["t0","t1","t3","assemble"], language?, lyricsText?, lrcPath?, gpu?, title?}
# 每个阶段把 partial 写进 outDir（t0.json/t1.json/t3.json），因此 T0/T1 与 T3 可以分属两个解释器
# （T3 依赖 py3.12 的 qwen-asr；见 analyzer/environment.md）。stdout 输出进度 JSON 行。
import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import analysis_lib as lib  # noqa: E402

SCHEMA = "videograph-analysis/v2"
ANALYZER_VERSION = "song01-v1"


def emit(message):
    print(json.dumps(message, ensure_ascii=False), flush=True)


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_partial(out_dir, name):
    path = out_dir / name
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


def write_partial(out_dir, name, data):
    (out_dir / name).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")


def stage_t0(spec, out_dir):
    """解码为 44.1k WAV；decoderOffset 按 ffmpeg gapless 约定为 0（与 pdoom 参考时间轴同一约定）。"""
    existing = read_partial(out_dir, "t0.json")
    if existing and Path(existing["wav"]).exists():
        emit({"stage": "t0", "status": "reused"})
        return existing
    emit({"stage": "t0", "status": "running"})
    wav = out_dir / "t0-decoded.wav"
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", spec["audioPath"], "-ar", str(lib.SR), wav],
                   check=True, capture_output=True)
    import soundfile as sf
    info = sf.info(wav)
    t0 = {"wav": str(wav), "duration": float(info.duration), "sampleRate": int(info.samplerate),
          "channels": int(info.channels), "decoderOffset": 0.0}
    write_partial(out_dir, "t0.json", t0)
    emit({"stage": "t0", "status": "done", "duration": t0["duration"], "sampleRate": t0["sampleRate"], "channels": t0["channels"]})
    return t0


def stage_t1(spec, out_dir):
    t0 = read_partial(out_dir, "t0.json")
    if not t0:
        raise RuntimeError("T1 需要 T0 的解码结果；请先跑 t0 阶段")
    emit({"stage": "t1", "status": "running"})
    started = time.time()
    y = lib.load_mono(t0["wav"])
    envelopes, fps, _ = lib.compute_envelopes(y)
    onsets = lib.percussion_onsets(y)
    device = "cuda" if spec.get("gpu", True) else "cpu"
    beats, downbeats, bpm, method, confidence = lib.estimate_beats(y, audio_path=t0["wav"], device=device)
    sections = lib.estimate_sections(y, downbeats=downbeats)
    t1 = {
        "envelopes": {**envelopes, "frameRate": fps},
        "onsets": onsets,
        "rhythm": {"beats": beats, "downbeats": downbeats, "bpm": bpm, "meter": 4, "method": method, "confidence": confidence},
        "sections": sections,
        "seconds": round(time.time() - started, 1),
    }
    write_partial(out_dir, "t1.json", t1)
    emit({"stage": "t1", "status": "done", "method": method, "bpm": bpm, "beats": len(beats), "sections": len(sections), "seconds": t1["seconds"]})
    return t1


def parse_lrc(text):
    import re
    lines = []
    for raw in text.splitlines():
        match = re.match(r"^\[(\d+):(\d+(?:\.\d+)?)\](.*)$", raw.strip())
        if match:
            minutes, seconds, content = match.groups()
            lines.append({"start": int(minutes) * 60 + float(seconds), "text": content.strip()})
    return lines


def stage_t3(spec, out_dir):
    t0 = read_partial(out_dir, "t0.json")
    if not t0:
        raise RuntimeError("T3 需要 T0 的解码结果；请先跑 t0 阶段")
    emit({"stage": "t3", "status": "running"})
    started = time.time()
    language = spec.get("language") or "zh"
    text_lines, text_source = None, "asr"
    if spec.get("lyricsText"):
        text_source = "user"
        text_lines = [{"start": None, "text": line.strip()} for line in spec["lyricsText"].splitlines() if line.strip()]
    elif spec.get("lrcPath"):
        text_source = "lrc"
        text_lines = parse_lrc(Path(spec["lrcPath"]).read_text(encoding="utf-8"))
        if not text_lines:
            raise RuntimeError("LRC 里没有可解析的时间戳行")
    if text_lines:
        aligned = align_with_qwen(t0["wav"], [line["text"] for line in text_lines], language, spec)
        lines = []
        for index, line in enumerate(text_lines):
            line_words = aligned[index] if index < len(aligned) else []
            start = line_words[0]["start"] if line_words else 0.0
            end = line_words[-1]["end"] if line_words else start + 2.0
            lines.append({"text": line["text"], "start": start, "end": end, "words": line_words})
        result = {"lyrics": {"language": language, "textSource": text_source, "humanConfirmed": True, "lines": lines}, "mode": "align"}
    else:
        result = {"lyrics": transcribe_with_qwen(t0["wav"], language, spec), "mode": "asr-draft", "draft": True,
                  "warnings": ["ASR 歌词是草稿：必须经人确认后才能用于规划"]}
    result["seconds"] = round(time.time() - started, 1)
    write_partial(out_dir, "t3.json", result)
    emit({"stage": "t3", "status": "done", "mode": result["mode"], "seconds": result["seconds"]})
    return result


def _load_qwen_aligner(spec):
    try:
        from qwen_asr import Qwen3ForcedAligner  # type: ignore
    except ImportError as error:
        raise RuntimeError(f"qwen_asr 未安装或 API 变化（{error}）；请核对 qwen-asr 包文档后更新 analyzer/analyze.py 的 align_with_qwen") from error
    return Qwen3ForcedAligner()


def align_with_qwen(wav, texts, language, spec):
    """Qwen3-ForcedAligner：[文本行] → 每行 [{w, start, end, conf}]。
    首次运行如与包 API 不符，会抛出带修正指引的错误；对演唱效果以 pdoom 基准实测为准。"""
    aligner = _load_qwen_aligner(spec)
    results = []
    for text in texts:
        output = aligner.align(wav, text=text, language=language)
        items = output if isinstance(output, list) else getattr(output, "items", output)
        words = []
        for item in items:
            entry = item if isinstance(item, dict) else {"text": getattr(item, "text", str(item)), "start": getattr(item, "start", 0.0), "end": getattr(item, "end", 0.0)}
            words.append({"w": str(entry.get("text") or entry.get("w") or ""), "start": float(entry.get("start", 0.0)), "end": float(entry.get("end", 0.0)), "conf": float(entry.get("confidence", entry.get("conf", 0.5)))})
        results.append([word for word in words if word["w"]])
    return results


def transcribe_with_qwen(wav, language, spec):
    try:
        from qwen_asr import Qwen3ASR  # type: ignore
    except ImportError as error:
        raise RuntimeError(f"qwen_asr 未安装或 API 变化（{error}）；请核对包文档后更新 analyzer/analyze.py 的 transcribe_with_qwen") from error
    model = Qwen3ASR()
    output = model.transcribe(wav, language=language)
    text = output.get("text", "") if isinstance(output, dict) else str(output)
    lines = [{"text": segment.strip(), "start": 0.0, "end": 0.0, "words": []} for segment in text.splitlines() if segment.strip()]
    return {"language": language, "textSource": "asr", "humanConfirmed": False, "lines": lines}


def assemble(spec, out_dir):
    t0, t1, t3 = (read_partial(out_dir, name) for name in ("t0.json", "t1.json", "t3.json"))
    if not t0 or not t1:
        raise RuntimeError("assemble 需要 t0.json 与 t1.json")
    started = spec.get("startedAt") or int(time.time() * 1000)
    rhythm = t1["rhythm"]
    provenance = {
        "audio": {"tool": "videograph-analyzer", "version": ANALYZER_VERSION, "startedAt": started, "confidence": 1.0, "params": {"decoder": "ffmpeg gapless（与 pdoom 参考时间轴同一约定）"}},
        "rhythm": {"tool": "videograph-analyzer", "version": ANALYZER_VERSION, "startedAt": started, "confidence": rhythm["confidence"], "model": rhythm["method"], "params": {"fps": t1["envelopes"]["frameRate"]}},
        "sections": {"tool": "videograph-analyzer", "version": ANALYZER_VERSION, "startedAt": started, "confidence": 0.4, "params": {"method": "ssm-novelty", "labels": "unknown（由人在校正界面命名）"}},
        "envelopes": {"tool": "videograph-analyzer", "version": ANALYZER_VERSION, "startedAt": started, "confidence": 0.9, "params": {"window": lib.WIN / lib.SR, "smooth": [lib.SMOOTH_ATTACK, lib.SMOOTH_RELEASE], "normalize": "p99-clip"}},
        "onsets": {"tool": "videograph-analyzer", "version": ANALYZER_VERSION, "startedAt": started, "confidence": 0.7, "params": {"method": "hpss+band-flux"}},
    }
    analysis = {
        "schema": SCHEMA,
        "title": spec.get("title") or Path(spec["audioPath"]).stem,
        "audio": {"hash": sha256_file(spec["audioPath"]), "duration": t0["duration"], "sampleRate": t0["sampleRate"], "channels": t0["channels"], "decoderOffset": t0["decoderOffset"]},
        "rhythm": {"bpm": rhythm["bpm"], "beats": rhythm["beats"], "downbeats": rhythm["downbeats"], "meter": rhythm["meter"], "confidence": rhythm["confidence"]},
        "sections": t1["sections"],
        "envelopes": t1["envelopes"],
        "onsets": t1["onsets"],
        "overrides": [],
        "provenance": provenance,
    }
    if t3 and "lyrics" in t3:
        analysis["lyrics"] = t3["lyrics"]
        analysis["provenance"]["lyrics"] = {
            "tool": "videograph-analyzer", "version": ANALYZER_VERSION, "startedAt": started, "confidence": 0.6,
            "model": "Qwen3-ForcedAligner-0.6B" if t3.get("mode") == "align" else "Qwen3-ASR-1.7B",
            "params": {"mode": t3.get("mode"), "draft": bool(t3.get("draft"))},
        }
    output = out_dir / "analysis-v2.json"
    temporary = out_dir / f".analysis-v2.{os.getpid()}.tmp"
    temporary.write_text(json.dumps(analysis, ensure_ascii=False), encoding="utf-8")
    os.replace(temporary, output)
    emit({"stage": "all", "status": "done", "file": str(output)})
    return analysis


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", required=True)
    args = parser.parse_args()
    spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
    out_dir = Path(spec["outDir"])
    out_dir.mkdir(parents=True, exist_ok=True)
    stages = spec.get("stages") or ["t0", "t1", "t3", "assemble"]
    wants_t3 = "t3" in stages and (spec.get("lyricsText") or spec.get("lrcPath") or spec.get("asr"))
    if "t0" in stages:
        stage_t0(spec, out_dir)
    if "t1" in stages:
        if not read_partial(out_dir, "t0.json"):
            stage_t0(spec, out_dir)
        stage_t1(spec, out_dir)
    if wants_t3:
        if not read_partial(out_dir, "t0.json"):
            stage_t0(spec, out_dir)
        stage_t3(spec, out_dir)
    if "assemble" in stages:
        assemble(spec, out_dir)
    elif "t0" in stages and "t1" not in stages:
        emit({"stage": "partial", "status": "done", "note": "仅完成部分阶段"})


if __name__ == "__main__":
    main()
