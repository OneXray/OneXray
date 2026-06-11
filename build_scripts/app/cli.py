import os
import platform
import shutil
import stat

from app.command_line import check_and_create_dir, run_command


def should_build_cli(system: str) -> bool:
    return system in ("macos", "windows", "linux")


def cli_binary_name(system: str) -> str:
    if system == "windows":
        return "onexray.exe"
    return "onexray"


def build_cli(root_dir: str, system: str) -> str:
    package_dir = os.path.join(root_dir, "cli")
    output_dir = os.path.join(root_dir, "build", "cli", system)
    output_path = os.path.join(output_dir, cli_binary_name(system))

    check_and_create_dir(output_dir)
    os.chdir(package_dir)
    run_command(["go", "mod", "download"])
    if system == "macos":
        arch_paths = []
        for arch in ("arm64", "amd64"):
            arch_path = os.path.join(output_dir, f"onexray_{arch}")
            _go_build("darwin", arch, arch_path)
            arch_paths.append(arch_path)
        run_command(["lipo", "-create", *arch_paths, "-output", output_path])
        _make_executable(output_path)
        return output_path

    target_os = "windows" if system == "windows" else "linux"
    _go_build(target_os, _target_arch(), output_path)
    _make_executable(output_path)
    return output_path


def _go_build(target_os: str, target_arch: str, output_path: str):
    old_goos = os.environ.get("GOOS")
    old_goarch = os.environ.get("GOARCH")
    try:
        os.environ["GOOS"] = target_os
        os.environ["GOARCH"] = target_arch
        run_command(
            [
                "go",
                "build",
                "-trimpath",
                "-ldflags",
                "-s -w",
                "-o",
                output_path,
                "./cmd/onexray",
            ]
        )
    finally:
        _restore_env("GOOS", old_goos)
        _restore_env("GOARCH", old_goarch)


def _restore_env(name: str, value: str | None):
    if value is None:
        os.environ.pop(name, None)
    else:
        os.environ[name] = value


def stage_cli_for_cmake(root_dir: str, system: str, cli_path: str):
    if system not in ("windows", "linux"):
        return

    app_dir = os.path.join(root_dir, system, "app")
    check_and_create_dir(app_dir)
    dst_path = os.path.join(app_dir, cli_binary_name(system))
    shutil.copy2(cli_path, dst_path)
    _make_executable(dst_path)


def _target_arch() -> str:
    machine = platform.machine().lower()
    if machine in ("x86_64", "amd64"):
        return "amd64"
    if machine in ("aarch64", "arm64"):
        return "arm64"
    return machine


def _make_executable(path: str):
    if os.name == "nt":
        return
    mode = os.stat(path).st_mode
    os.chmod(path, mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
