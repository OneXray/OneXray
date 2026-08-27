import os
import platform
import shutil
import subprocess
from pathlib import Path
from urllib.request import urlopen


def is_linux() -> bool:
    return platform.system().lower() == "linux"


def is_macos() -> bool:
    return platform.system().lower() == "darwin"


def is_windows() -> bool:
    return platform.system().lower() == "windows"


def is_amd64() -> bool:
    return platform.machine().lower() in ("x86_64", "amd64")


def is_arm64() -> bool:
    return platform.machine().lower() in ("aarch64", "arm64")


def get_env(overrides: dict[str, str] | None = None) -> dict[str, str]:
    env = os.environ.copy()
    home_dir = str(Path.home())
    path_entries = []
    if flutter_root := env.get("FLUTTER_ROOT"):
        path_entries.append(os.path.join(flutter_root, "bin"))
    path_entries.extend(
        [
            os.path.join(home_dir, "lib", "flutter", "bin"),
            os.path.join(home_dir, "go", "bin"),
        ]
    )
    if is_macos():
        path_entries.insert(0, "/opt/homebrew/bin")
    if is_linux():
        path_entries.extend(
            [
                os.path.join(home_dir, ".pub-cache", "bin"),
                os.path.join(home_dir, "lib", "go", "bin"),
            ]
        )
    if is_windows():
        pub_cache_root = env.get(
            "PUB_CACHE",
            os.path.join(
                env.get("LOCALAPPDATA", os.path.join(home_dir, "AppData", "Local")),
                "Pub",
                "Cache",
            ),
        )
        path_entries.append(os.path.join(pub_cache_root, "bin"))
    env["PATH"] = os.pathsep.join([*path_entries, env.get("PATH", "")])
    if overrides:
        env.update(overrides)
    return env


def check_and_create_dir(work_dir: str):
    os.makedirs(work_dir, exist_ok=True)


def check_and_delete_dir(work_dir: str):
    if os.path.exists(work_dir):
        shutil.rmtree(work_dir)


def flutter_command() -> str:
    return "flutter.bat" if is_windows() else "flutter"


def dart_command() -> str:
    return "dart.bat" if is_windows() else "dart"


def fastforge_command() -> str:
    return "fastforge.bat" if is_windows() else "fastforge"


def run_command(
    cmd: list[str],
    *,
    cwd: str | None = None,
    env: dict[str, str] | None = None,
    redact: bool = False,
):
    print("[redacted command]" if redact else cmd, flush=True)
    subprocess.run(cmd, cwd=cwd, env=get_env(env), check=True)


def cp_dir_files(src_dir: str, dst_dir: str):
    for entry in os.listdir(src_dir):
        full_path = os.path.join(src_dir, entry)
        if os.path.isdir(full_path):
            cp_dir_files(full_path, dst_dir)
        else:
            shutil.copy2(full_path, dst_dir)


def download_file(file_url: str, save_path: str):
    with urlopen(file_url, timeout=60) as response, open(save_path, "wb") as output:
        shutil.copyfileobj(response, output)
