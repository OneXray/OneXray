import os
import platform
import shutil
import subprocess
from pathlib import Path

import requests


def is_linux() -> bool:
    name = platform.system().lower()
    return name == "linux"


def is_macos() -> bool:
    name = platform.system().lower()
    return name == "darwin"


def is_windows() -> bool:
    name = platform.system().lower()
    return name == "windows"


def is_amd64() -> bool:
    machine = platform.machine().lower()
    return machine == "x86_64" or machine == "amd64"


def is_arm64() -> bool:
    machine = platform.machine().lower()
    return machine == "aarch64" or machine == "arm64"


def get_env() -> dict[str, str]:
    my_env = os.environ.copy()
    env_path = my_env["PATH"]
    home_dir = str(Path.home())
    flutter_home = os.path.join(home_dir, "lib", "flutter", "bin")
    go_home = os.path.join(home_dir, "go", "bin")
    env_path = f"{flutter_home}:{go_home}:{env_path}"
    if is_macos():
        env_path = f"/opt/homebrew/bin:{env_path}"
    if is_linux():
        pub_cache = os.path.join(home_dir, ".pub-cache", "bin")
        go_lib = os.path.join(home_dir, "lib", "go", "bin")
        env_path = f"{pub_cache}:{go_lib}:{env_path}"
    my_env["PATH"] = env_path
    return my_env


def check_and_create_dir(work_dir: str):
    if not os.path.exists(work_dir):
        os.makedirs(work_dir)


def check_and_delete_dir(work_dir: str):
    if os.path.exists(work_dir):
        shutil.rmtree(work_dir)


def check_and_delete_file(file_path: str):
    if os.path.exists(file_path):
        os.remove(file_path)


def python_command() -> str:
    if is_windows():
        return "python"
    else:
        return "python3"


def flutter_command() -> str:
    if is_windows():
        return "flutter.bat"
    else:
        return "flutter"


def dart_command() -> str:
    if is_windows():
        return "dart.bat"
    else:
        return "dart"


def fastforge_command() -> str:
    if is_windows():
        return "fastforge.bat"
    else:
        return "fastforge"


def run_command(cmd: list[str]):
    print(cmd)
    p = subprocess.run(cmd, env=get_env())
    if p.returncode != 0:
        raise Exception(f"run {cmd} failed")


def cp_dir_files(src_dir: str, dst_dir: str):
    for entry in os.listdir(src_dir):
        full_path = os.path.join(src_dir, entry)
        if os.path.isdir(full_path):
            cp_dir_files(full_path, dst_dir)
        else:
            shutil.copy2(full_path, dst_dir)


def download_file(file_url: str, save_path: str):
    r = requests.get(file_url, stream=True)
    with open(save_path, "wb") as fd:
        for chunk in r.iter_content(chunk_size=128):
            fd.write(chunk)
