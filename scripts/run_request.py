#!/usr/bin/env python3
"""Run a UTF-8 JSON request file through the portable MoonARPA CLI."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def invoke(request, target="wasm-gc"):
    text = json.dumps(request, ensure_ascii=True, separators=(",", ":"))
    command = ["moon", "run", "cmd/moonarpa", "--target", target, "--", text]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                            encoding="utf-8", errors="replace")
    if result.returncode:
        raise RuntimeError(result.stderr)
    envelope = json.loads(result.stdout.strip())
    if not envelope.get("ok"):
        raise ValueError(envelope.get("error", "invalid CLI response"))
    return envelope["result"]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("request", type=Path)
    parser.add_argument("--target", default="wasm-gc", choices=["wasm-gc","wasm","js","native"])
    args = parser.parse_args()
    request = json.loads(args.request.read_text(encoding="utf-8-sig"))
    print(json.dumps(invoke(request, args.target), ensure_ascii=False, indent=2, allow_nan=False))

if __name__ == "__main__":
    main()
