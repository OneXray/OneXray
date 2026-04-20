import os
import platform
import shutil

import yaml

from app.command_line import (
    check_and_create_dir,
    check_and_delete_dir,
    get_env,
    run_command,
    python_command,
    fastforge_command,
)
from app.config import PROJECT_CONFIG


class Builder(object):
    def __init__(
        self,
        project: str,
        system: str,
        build_scripts_dir: str,
    ):
        self.project = project
        self.system = system
        self.project_dir = os.path.join(build_scripts_dir, "..", system)
        self.output_dir = os.path.join(build_scripts_dir, "..", "..", "output")

        self.fastlane = "deploy"

        self.project_config = PROJECT_CONFIG[project]

        build_number_base = self.project_config["build_number.base"]
        build_number = get_env()["BUILD_NUMBER"]
        self.build_number = build_number_base + int(build_number)

        system = platform.system().lower()
        machine = platform.machine().lower()
        self.package_suffix = f"{system}-{machine}"

    def build(self):
        pass

    def before_build(self):
        check_and_create_dir(self.output_dir)

    def build_core(self):
        dir_name = self.project_config["core.dir"]
        lib_dir = os.path.join(self.output_dir, "..", dir_name)
        os.chdir(lib_dir)

        cmd_system = self.system
        if self.system == "macos" or self.system == "ios":
            cmd_system = "apple"
        cmd = [python_command(), "build/main.py", cmd_system]
        if cmd_system == "apple":
            cmd.append("go")

        run_command(cmd)

        # copy core lib
        lib_dst_path = os.path.join(
            self.project_dir, self.project_config[f"core.lib.dst.dir.{self.system}"]
        )
        check_and_create_dir(lib_dst_path)
        for src in self.project_config[f"core.lib.src.files.{self.system}"]:
            lib_src_path = os.path.join(lib_dir, src)
            if self.system == "ios" or self.system == "macos":
                dst_dir_path = os.path.join(lib_dst_path, src)
                check_and_delete_dir(dst_dir_path)
                shutil.copytree(lib_src_path, dst_dir_path, symlinks=True)
            else:
                shutil.copy(lib_src_path, lib_dst_path)

        bin_src_key = f"core.bin.src.file.{self.system}"
        if bin_src_key in self.project_config:
            bin_src_path = os.path.join(
                lib_dir,
                self.project_config[bin_src_key],
            )
            bin_dst_file_key = f"core.bin.dst.file.{self.system}"
            bin_dst_path = os.path.join(
                self.project_dir,
                self.project_config[bin_dst_file_key],
            )
            shutil.copy(bin_src_path, bin_dst_path)

        dat_src_path = os.path.join(lib_dir, "dat")
        dat_dst_path = os.path.join(
            self.project_dir, self.project_config["core.dat.dst.dir"]
        )
        check_and_delete_dir(dat_dst_path)
        shutil.copytree(dat_src_path, dat_dst_path, symlinks=True)

    def split_file_path(self, root_path: str, file_path: str) -> str:
        path_parts = file_path.split("/")
        return os.path.join(root_path, *path_parts)

    def build_app(self):
        pass

    def after_build(self):
        pass

    def fastforge_build(self, targets: str):
        build_dir = os.path.join(self.project_dir, "..")
        os.chdir(build_dir)
        system = platform.system().lower()
        cmd = [
            fastforge_command(),
            "package",
            "--platform",
            system,
            "--targets",
            targets,
            "--skip-clean",
            "true",
        ]
        run_command(cmd)

    def read_version(self) -> str:
        file_path = os.path.join(self.project_dir, "..", "pubspec.yaml")
        with open(file_path, mode="r") as f:
            pubspec = yaml.load(f, Loader=yaml.CLoader)
            return pubspec["version"]

    def find_file(self, file_type: str) -> str:
        for entry in os.listdir(self.output_dir):
            full_path = os.path.join(self.output_dir, entry)
            if os.path.isfile(full_path):
                if entry.endswith(file_type):
                    return entry
        return ""

    def rename_file(self, file_name: str, file_type: str) -> str:
        new_file_name = f"{self.project}-{self.package_suffix}{file_type}"
        src_path = os.path.join(self.output_dir, file_name)
        dst_path = os.path.join(self.output_dir, new_file_name)
        shutil.move(src_path, dst_path)
        return new_file_name
