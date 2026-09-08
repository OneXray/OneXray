#!/usr/bin/env python3

import argparse
import os

from app.config import PROJECT_CONFIG
from app.flutter import FlutterBuilder

SYSTEMS = ("ios", "macos", "macos_se", "android", "windows", "linux")


def build_scripts_dir() -> str:
    return os.path.abspath(os.path.dirname(__file__))


def main():
    parser = argparse.ArgumentParser(description="Build and package OneXray")
    parser.add_argument("project", choices=PROJECT_CONFIG)
    parser.add_argument("system", choices=SYSTEMS)
    parser.add_argument("--windows-mode", choices=("exe", "msix"),
                        help="Windows runtime/package mode (default: exe)")
    args = parser.parse_args()
    if args.windows_mode is not None and args.system != "windows":
        parser.error("--windows-mode is only valid for Windows")
    FlutterBuilder(args.project, args.system, build_scripts_dir(),
                   windows_mode=args.windows_mode or "exe").build()


if __name__ == "__main__":
    main()
