#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

from app.provenance import verify_release


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Verify downloaded Build artifacts")
    parser.add_argument("artifacts", type=Path)
    parser.add_argument("run_json", type=Path)
    parser.add_argument("--tag")
    parser.add_argument("--tag-sha")
    parser.add_argument("--windows-only", action="store_true")
    args = parser.parse_args()
    files = verify_release(args.artifacts, json.loads(args.run_json.read_text()),
                           tag=args.tag, tag_sha=args.tag_sha, windows_only=args.windows_only)
    print("\n".join(str(path) for path in files))
