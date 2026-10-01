# download_models.py — SONG-01 模型预下载（用户批准后由 install 流程执行）。
# 缓存统一 HF_HOME/TORCH_HOME=F:\aicg\.models；逐项打印体积再下载，NC 模型绝不出现。
import argparse
import json
import os
import sys

MODELS = [
    {"name": "beat_this", "repo": "cpjku/beast_this__beat_this_final0", "alternates": ["cpjku/beat_this_final0"], "type": "hf"},
    {"name": "qwen3-forced-aligner-0.6b", "repo": "Qwen/Qwen3-ForcedAligner-0.6B", "type": "hf"},
    {"name": "qwen3-asr-1.7b", "repo": "Qwen/Qwen3-ASR-1.7B", "type": "hf"},
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default=None, help="逗号分隔的模型名；缺省全部")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    wanted = args.only.split(",") if args.only else [m["name"] for m in MODELS]
    plan = [m for m in MODELS if m["name"] in wanted]
    print(json.dumps({"plan": [m["name"] for m in plan], "cacheRoot": os.environ.get("HF_HOME"), "dryRun": args.dry_run}, ensure_ascii=False))
    if args.dry_run:
        return
    from huggingface_hub import snapshot_download
    for model in plan:
        repos = [model["repo"]] + model.get("alternates", [])
        last_error = None
        for repo in repos:
            try:
                print(json.dumps({"download": model["name"], "repo": repo}, ensure_ascii=False), flush=True)
                path = snapshot_download(repo)
                print(json.dumps({"downloaded": model["name"], "path": path}, ensure_ascii=False), flush=True)
                break
            except Exception as error:  # 仓库名以实测为准，失败逐个尝试备选
                last_error = error
        else:
            print(json.dumps({"error": model["name"], "detail": str(last_error)[:300]}, ensure_ascii=False), flush=True)
            sys.exitCode = 1
    print(json.dumps({"done": True}, ensure_ascii=False))


if __name__ == "__main__":
    main()
