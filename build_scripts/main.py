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
    args = parser.parse_args()
    FlutterBuilder(args.project, args.system, build_scripts_dir()).build()


if __name__ == "__main__":
    main()
