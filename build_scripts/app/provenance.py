"""Small, stdlib-only build receipts; no credentials or full environment dump."""

import hashlib
import json
import os
import platform
import re
import subprocess
import sys
from pathlib import Path

from app.command_line import dart_command, flutter_command, get_env

_SHA = re.compile(r"[0-9a-f]{40}")
_PACKAGE_SUFFIXES = {".ipa", ".pkg", ".zip", ".deb", ".msix", ".apk", ".aab"}


def sha256(path: Path) -> str:
    with path.open("rb") as contents:
        return hashlib.file_digest(contents, "sha256").hexdigest()


def _output(command: list[str], cwd: Path) -> str:
    return subprocess.run(
        command, cwd=cwd, env=get_env(), check=True, capture_output=True,
        text=True, timeout=60,
    ).stdout.strip()


def source_revision(path: Path, expected: str | None = None) -> str:
    revision = _output(["git", "rev-parse", "HEAD"], path)
    if not _SHA.fullmatch(revision) or (expected and revision != expected):
        raise ValueError(f"Unexpected checkout revision: {path.name}")
    return revision


def begin_build(builder, target: str) -> dict:
    root = Path(builder.root_dir)
    workspace = Path(builder.workspace_dir)
    sources = {
        "app": source_revision(root, os.environ.get("GITHUB_SHA")),
        "libXray": source_revision(
            workspace / builder.project_config["core.dir"],
            os.environ.get("ONEXRAY_LIBXRAY_SHA"),
        ),
    }
    source_paths = {
        "app": root,
        "libXray": workspace / builder.project_config["core.dir"],
    }
    if target == "windows":
        source_paths["VCore"] = Path(builder.builder._vcore_dir())
        sources["VCore"] = source_revision(
            source_paths["VCore"], os.environ.get("ONEXRAY_VCORE_SHA"),
        )
    return {
        "formatVersion": 1,
        "target": target,
        "architecture": getattr(
            builder.builder, "target_architecture", platform.machine().lower(),
        ),
        "targetArchitectures": {
            "ios": ["arm64"], "macos": ["arm64", "x86_64"],
            "macos_se": ["arm64", "x86_64"], "android": ["arm64", "x86_64"],
        }.get(target, [getattr(
            builder.builder, "target_architecture", platform.machine().lower(),
        )]),
        "runId": os.environ.get("GITHUB_RUN_ID"),
        "runAttempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "repository": os.environ.get("GITHUB_REPOSITORY"),
        "sources": sources,
        # Capture before version rewriting, macOS SE preparation, or core builds.
        # Only booleans leave this process, never source paths or diff contents.
        "sourceDirty": {
            name: bool(_output(["git", "status", "--porcelain", "--untracked-files=normal"], path))
            for name, path in source_paths.items()
        },
        "sourceVersion": builder.read_version(),
    }


def _tool(command: list[str], root: Path) -> dict:
    try:
        result = subprocess.run(
            command, cwd=root, env=get_env(), capture_output=True, text=True,
            timeout=60,
        )
        return {"exitCode": result.returncode,
                "version": (result.stdout + result.stderr).strip()[:8192]}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"unavailable": type(error).__name__}


def finish_build(builder, receipt: dict) -> Path:
    root = Path(builder.root_dir)
    output = Path(builder.output_dir)
    target = receipt["target"]
    tools = {
        "python": {"version": sys.version},
        "flutter": _tool([flutter_command(), "--version", "--machine"], root),
        "dart": _tool([dart_command(), "--version"], root),
        "go": _tool(["go", "version"], root),
        "uv": _tool(["uv", "--version"], root),
    }
    commands = {
        "ios": (("xcodebuild", "-version"), ("pod", "--version"),
                ("fastlane", "--version"), ("ruby", "--version")),
        "macos": (("xcodebuild", "-version"), ("pod", "--version"),
                  ("fastlane", "--version"), ("ruby", "--version")),
        "macos_se": (("xcodebuild", "-version"), ("pod", "--version"),
                     ("fastlane", "--version"), ("ruby", "--version")),
        "android": (("java", "-version"), ("fastlane", "--version")),
        "windows": (("rustc", "-Vv"), ("cargo", "--version"),
                    ("cmake", "--version"), ("gcc", "--version")),
        "linux": (("clang", "--version"), ("cmake", "--version"),
                  ("fastforge", "--version")),
    }
    for command in commands[target]:
        tools[command[0]] = _tool(list(command), root)
    if target == "android":
        tools["gradle"] = _tool(["./gradlew", "--version"], root / "android")

    lock_files = [root / name for name in (
        "pubspec.lock", "build_scripts/uv.lock", "android/settings.gradle.kts",
        "android/gradle/wrapper/gradle-wrapper.properties",
    )]
    lock_files.extend(root.glob("*/Podfile.lock"))
    if target == "windows":
        vcore = Path(builder.builder._vcore_dir())
        lock_files.extend((vcore / "Cargo.lock", vcore / "scripts/uv.lock"))
    files = {}
    for path in lock_files:
        if path.is_file():
            name = (f"OneXray/{path.relative_to(root).as_posix()}" if path.is_relative_to(root)
                    else f"VCore/{path.relative_to(vcore).as_posix()}")
            files[name] = sha256(path)

    native_paths = [root / "assets/dat", root / "assets/geodata"]
    lib_destination = Path(builder.project_dir) / builder.project_config[
        f"core.lib.dst.dir.{builder.system}"]
    for name in builder.project_config[f"core.lib.src.files.{builder.system}"]:
        native_paths.append(lib_destination / Path(name).name)
    if builder.system in ("windows", "linux"):
        native_paths.append(Path(builder.project_dir) / "app")
    for path in native_paths:
        for file in path.rglob("*") if path.is_dir() else [path]:
            if file.is_file():
                files[f"OneXray/{file.resolve().relative_to(root.resolve()).as_posix()}"] = sha256(file)

    patterns = {
        "ios": ("OneXray-ios*.ipa",),
        "macos": ("*.pkg",),
        "macos_se": ("OneXray-macos-universal*.zip",),
        "android": ("OneXray-android-universal*.apk", "app-release.aab"),
        "windows": (f"OneXray-{builder.builder.package_suffix}.msix",),
        "linux": (f"OneXray-{builder.builder.package_suffix}.zip",
                  f"OneXray-{builder.builder.package_suffix}.deb"),
    }
    packages = {path.name: sha256(path) for pattern in patterns[target]
                for path in output.glob(pattern) if path.is_file()}
    if not packages:
        raise ValueError("No packages available for build provenance")
    receipt.update({
        "version": builder.read_version(),
        "buildNumber": builder.build_number,
        "host": platform.platform(),
        "runnerImage": {key: os.environ.get(key) for key in ("ImageOS", "ImageVersion")},
        "windowsToolchain": {key: os.environ.get(key) for key in (
            "VCToolsVersion", "WindowsSDKVersion", "ONEXRAY_LLVM_MINGW_RELEASE",
            "ONEXRAY_LLVM_MINGW_SHA256",
        )} if target == "windows" else None,
        "tools": tools,
        "fileSha256": files,
        "packages": packages,
    })
    ndk = os.environ.get("ANDROID_NDK_HOME") or os.environ.get("ANDROID_NDK_ROOT")
    if ndk and (Path(ndk) / "source.properties").is_file():
        receipt["androidNdk"] = (Path(ndk) / "source.properties").read_text()
    if target == "windows":
        receipt["msixVersion"] = builder.builder.msix_version()
        receipt["vcoreArtifacts"] = json.loads((vcore / "dist/windows" /
            receipt["architecture"] / "vcore-windows-artifacts.json").read_text())
    destination = output / f"provenance-{target}-{receipt['architecture']}.json"
    destination.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return destination


def verify_release(artifacts: Path, run: dict, *, tag: str | None = None,
                   tag_sha: str | None = None, windows_only: bool = False) -> None:
    """Fail closed before any release mutation, including manual build runs."""
    metadata = artifacts / "release-metadata"
    def value(name: str) -> str:
        result = (metadata / f"{name}.txt").read_text(encoding="utf-8").strip()
        if not result:
            raise ValueError(f"Empty release metadata: {name}")
        return result

    expected = {key: value(name) for key, name in (
        ("app", "sha"), ("libXray", "libxray-sha"), ("VCore", "vcore-sha"),
    )}
    if any(not _SHA.fullmatch(revision) for revision in expected.values()):
        raise ValueError("Release revisions must be full commit SHAs")
    if (run.get("path") != ".github/workflows/build.yml"
            or run.get("conclusion") != "success"
            or str(run.get("id")) != value("run-id")
            or str(run.get("run_attempt")) != value("run-attempt")
            or run.get("head_sha") != expected["app"]
            or run.get("repository", {}).get("full_name") != value("repository")):
        raise ValueError("Release metadata does not match the successful Build run")
    if tag and (not tag.startswith("v") or tag_sha != expected["app"]):
        raise ValueError("Release tag does not point to the built App commit")
    if (metadata / "tag.txt").exists():
        recorded_tag = value("tag")
        if not recorded_tag.startswith("v") or (tag and tag != recorded_tag):
            raise ValueError("Release tag does not match build metadata")

    manifests = sorted(artifacts.rglob("provenance-*.json"))
    if not manifests:
        raise ValueError("Missing per-platform build provenance")
    package_hashes = {}
    windows_arches = set()
    for manifest in manifests:
        receipt = json.loads(manifest.read_text(encoding="utf-8"))
        sources = receipt.get("sources", {})
        if (receipt.get("formatVersion") != 1 or not receipt.get("tools")
                or not receipt.get("fileSha256") or not receipt.get("packages")
                or receipt.get("runId") != value("run-id")
                or receipt.get("runAttempt") != value("run-attempt")
                or receipt.get("repository") != value("repository")
                or sources.get("app") != expected["app"]
                or sources.get("libXray") != expected["libXray"]):
            raise ValueError(f"Invalid build provenance: {manifest.name}")
        target = receipt.get("target")
        required_sources = ("app", "libXray", "VCore") if target == "windows" else ("app", "libXray")
        dirty = receipt.get("sourceDirty")
        if not isinstance(dirty, dict) or any(dirty.get(name) is not False for name in required_sources):
            raise ValueError("Release sources must be recorded and clean before building")
        if receipt.get("target") == "windows":
            if sources.get("VCore") != expected["VCore"]:
                raise ValueError("VCore checkout does not match build metadata")
            windows_arches.add(receipt.get("architecture"))
        for name, digest in receipt["packages"].items():
            if name in package_hashes and package_hashes[name] != digest:
                raise ValueError(f"Conflicting package provenance: {name}")
            package_hashes[name] = digest
    if windows_only and windows_arches != {"x64", "arm64"}:
        raise ValueError("Both Windows architectures need build provenance")
    packages = [path for path in artifacts.rglob("*")
                if path.is_file() and path.suffix in _PACKAGE_SUFFIXES]
    if windows_only:
        packages = [path for path in packages if path.suffix == ".msix"]
        if {path.name for path in packages} != {
            "OneXray-windows-amd64.msix", "OneXray-windows-arm64.msix",
        } or len(packages) != 2:
            raise ValueError("Expected exactly two Windows Store packages")
    if not packages:
        raise ValueError("No release packages found")
    for path in packages:
        if package_hashes.get(path.name) != sha256(path):
            raise ValueError(f"Package hash mismatch or missing provenance: {path.name}")
