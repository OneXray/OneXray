import os
import shutil

import yaml

from app.android import AndroidBuilder
from app.apple import AppleBuilder
from app.builder import Builder
from app.cli import build_cli, should_build_cli, stage_cli_for_cmake
from app.command_line import run_command, cp_dir_files, flutter_command, dart_command
from app.linux import LinuxBuilder
from app.windows import WindowsBuilder


class FlutterBuilder(Builder):
    def __init__(
        self,
        project: str,
        system: str,
        build_scripts_dir: str,
    ):
        new_system = self.prepare_macos_se(system, build_scripts_dir)
        super().__init__(project, new_system, build_scripts_dir)
        builders = {
            "ios": AppleBuilder(project, new_system, build_scripts_dir),
            "macos": AppleBuilder(project, new_system, build_scripts_dir),
            "android": AndroidBuilder(project, new_system, build_scripts_dir),
            "linux": LinuxBuilder(project, new_system, build_scripts_dir),
            "windows": WindowsBuilder(project, new_system, build_scripts_dir),
        }
        self.builder = builders[self.system]
        self.cli_path = None

        self.build_type = {
            "android": "appbundle",
            "ios": "ipa",
            "macos": "macos",
            "linux": "linux",
            "windows": "windows",
        }

    def prepare_macos_se(self, system: str, build_scripts_dir: str) -> str:
        if system != "macos_se":
            return system

        project_dir = os.path.abspath(os.path.join(build_scripts_dir, ".."))
        macos_dir = os.path.join(project_dir, "macos")
        macos_se_dir = os.path.join(project_dir, "macos_se")

        if not os.path.isdir(macos_se_dir):
            raise FileNotFoundError(f"macos_se source not found: {macos_se_dir}")

        if os.path.exists(macos_dir):
            shutil.rmtree(macos_dir)
        # symlinks=True is critical: macos_se/Flutter/ephemeral/.symlinks/ holds
        # pub-cache symlinks per Flutter plugin, and frameworks inside Pods/ use
        # symlinks for versioning. Following them would blow up the copy target
        # and break xcframework bundle structure.
        shutil.copytree(macos_se_dir, macos_dir, symlinks=True)

        print(
            f"[prepare_macos_se] replaced {macos_dir} with {macos_se_dir}; "
            "run `git checkout -- macos/` to restore MAS config"
        )
        return "macos"

    def build(self):
        self.before_build()

        self.build_app()

        self.after_build()

    def before_build(self):
        super().before_build()

        self.update_build_number()
        self.pub_get()
        if should_build_cli(self.system):
            root_dir = os.path.join(self.project_dir, "..")
            self.cli_path = build_cli(root_dir, self.system)
            stage_cli_for_cmake(root_dir, self.system, self.cli_path)
        self.run_ffi_gen()

        self.builder.before_build()

    def update_build_number(self):
        file_path = os.path.join(self.project_dir, "..", "pubspec.yaml")
        with open(file_path, mode="r") as f:
            pubspec = yaml.load(f, Loader=yaml.CLoader)
            version = pubspec["version"]
            versions = version.split("+")
            pubspec["version"] = f"{versions[0]}+{self.build_number}"

        with open(file_path, mode="w") as f:
            yaml.dump(pubspec, f, Dumper=yaml.CDumper)

    def pub_get(self):
        root_dir = os.path.join(self.project_dir, "..")
        os.chdir(root_dir)
        run_command([flutter_command(), "pub", "get"])

    def run_ffi_gen(self):
        root_dir = os.path.join(self.project_dir, "..")
        os.chdir(root_dir)
        run_command([dart_command(), "run", "ffigen"])

    def build_app(self):
        if self.system == "ios" or self.system == "macos":
            self.builder.build_app()
            return

        root_dir = os.path.join(self.project_dir, "..")
        os.chdir(root_dir)
        cmd = [
            flutter_command(),
            "build",
            self.build_type[self.system],
        ]
        run_command(cmd)

        self.builder.build_app()

    def after_build(self):
        super().after_build()
        app_key = f"app.release.dir.{self.system}"
        if app_key in self.project_config:
            app_src_dir = os.path.join(self.project_dir, self.project_config[app_key])
            cp_dir_files(str(app_src_dir), self.output_dir)

        self.builder.after_build()
