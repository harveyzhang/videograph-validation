# doctor.py — SONG-01 环境自检：JSON 报告，不修改任何状态。
import json
import platform
import shutil
import sys
from importlib.metadata import version as pkg_version, PackageNotFoundError
from pathlib import Path

PACKAGES = ["librosa", "soundfile", "demucs", "beat_this", "faster_whisper", "qwen_asr", "transformers", "accelerate", "torch", "numpy", "scipy"]
MODELS = {
    "beat_this": ["beat_this"],
    "qwen3-forced-aligner-0.6b": ["Qwen3-ForcedAligner-0.6B", "Qwen--Qwen3-ForcedAligner-0.6B", "models--Qwen--Qwen3-ForcedAligner-0.6B"],
    "qwen3-asr-1.7b": ["Qwen3-ASR-1.7B", "Qwen--Qwen3-ASR-1.7B", "models--Qwen--Qwen3-ASR-1.7B"],
}


def model_cached(names, cache_root):
    if not cache_root:
        return False
    root = Path(cache_root)
    return any(root.rglob(f"*{name}*") for name in names for _ in [0]) and any(True for _ in root.rglob(f"*{names[0]}*"))


def main():
    report = {
        "python": platform.python_version(),
        "executable": sys.executable,
        "platform": platform.platform(),
        "packages": {},
        "cuda": {"available": False},
        "ffmpeg": None,
        "models": {},
        "cacheRoot": None,
        "disk": {},
    }
    for package in PACKAGES:
        try:
            report["packages"][package] = pkg_version(package.replace("_", "-") if package in ("beat_this", "qwen_asr", "faster_whisper") else package)
        except PackageNotFoundError:
            report["packages"][package] = None
    try:
        import torch
        report["cuda"]["available"] = torch.cuda.is_available()
        if torch.cuda.is_available():
            free, total = torch.cuda.mem_get_info(0)
            report["cuda"].update({
                "device": torch.cuda.get_device_name(0),
                "capability": ".".join(map(str, torch.cuda.get_device_capability(0))),
                "vramFreeGB": round(free / 2**30, 2),
                "vramTotalGB": round(total / 2**30, 2),
                "sm120": torch.cuda.get_device_capability(0) >= (1, 20),
            })
    except Exception as error:
        report["cuda"]["error"] = str(error)
    ffmpeg = shutil.which("ffmpeg")
    report["ffmpeg"] = ffmpeg
    import os
    cache_root = os.environ.get("HF_HOME") or os.environ.get("TORCH_HOME")
    report["cacheRoot"] = cache_root
    if cache_root and Path(cache_root).exists():
        for model, names in MODELS.items():
            hits = any(any(Path(cache_root).rglob(f"*{name}*")) for name in names)
            report["models"][model] = hits
    else:
        for model in MODELS:
            report["models"][model] = False
    for drive in ("C:\\", "D:\\", "F:\\"):
        try:
            usage = shutil.disk_usage(drive)
            report["disk"][drive] = {"freeGB": round(usage.free / 2**30, 1), "totalGB": round(usage.total / 2**30, 1)}
        except OSError:
            pass
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
