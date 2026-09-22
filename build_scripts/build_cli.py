#!/usr/bin/env python3
"""Build/package the pure-Go CLI; never build the App, start VPN or deploy."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import zipfile


TARGETS = tuple(f"{system}-{arch}" for system in ("darwin", "linux", "windows")
                for arch in ("amd64", "arm64"))
ROOT = Path(__file__).resolve().parents[1]


def app_version(root: Path) -> str:
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+(?:-[\w.-]+)?)(?:\+[\w.-]+)?\s*$",
                      (root / "pubspec.yaml").read_text(encoding="utf-8"), re.MULTILINE)
    if not match:
        raise ValueError("pubspec.yaml must contain a valid version")
    return match.group(1)


def package(directory: Path, destination: Path, system: str) -> None:
    files = sorted(directory.iterdir())
    if system == "windows":
        with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for path in files:
                archive.write(path, path.name)
    else:
        with tarfile.open(destination, "w:gz") as archive:
            for path in files:
                archive.add(path, path.name, recursive=False)


def build(root: Path, output: Path, targets: list[str], go: str = "go") -> list[Path]:
    if not targets or any(target not in TARGETS for target in targets):
        raise ValueError("Unsupported CLI target")
    version = app_version(root)
    output.mkdir(parents=True, exist_ok=True)
    staging = root.parent / "references" / "client-improvements" / "cli-build"
    staging.mkdir(parents=True, exist_ok=True)
    products = []
    for target in dict.fromkeys(targets):
        system, architecture = target.split("-")
        extension = "zip" if system == "windows" else "tar.gz"
        destination = output / f"OneXrayCLI-{version}-{target}.{extension}"
        with tempfile.TemporaryDirectory(prefix=f"{target}-", dir=staging) as temporary:
            directory = Path(temporary)
            executable = directory / ("onexray-cli.exe" if system == "windows" else "onexray-cli")
            environment = {**os.environ, "CGO_ENABLED": "0", "GOOS": system,
                           "GOARCH": architecture, "GOWORK": "off"}
            subprocess.run([go, "build", "-trimpath", "-mod=readonly", "-buildvcs=false",
                            "-ldflags", f"-s -w -X main.version={version}",
                            "-o", str(executable), "."],
                           cwd=root / "cli", env=environment, check=True)
            for name, source in (("README.md", root / "cli" / "README.md"),
                                 ("LICENSE", root / "LICENSE"),
                                 ("THIRD_PARTY_NOTICES.md", root / "cli" / "THIRD_PARTY_NOTICES.md")):
                (directory / name).write_bytes(source.read_bytes())
            package(directory, destination, system)
        products.append(destination)
    checksums = output / "SHA256SUMS"
    checksums.write_text("".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n" for path in products
    ), encoding="utf-8")
    return [*products, checksums]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=("all", *TARGETS), default="all",
                        help="pure-Go cross-compilation target (default: all six targets)")
    parser.add_argument("--output", type=Path, default=ROOT.parent / "output" / "cli")
    parser.add_argument("--go", default="go", help="Go executable")
    args = parser.parse_args()
    targets = list(TARGETS) if args.target == "all" else [args.target]
    for product in build(ROOT, args.output.resolve(), targets, args.go):
        print(product)


if __name__ == "__main__":
    main()
