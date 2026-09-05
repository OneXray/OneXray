import os
import shutil

from app.android import AndroidBuilder
from app.apple import AppleBuilder
from app.builder import Builder
from app.command_line import cp_dir_files, dart_command, flutter_command, run_command
from app.linux import LinuxBuilder
from app.provenance import begin_build, finish_build
from app.windows import WindowsBuilder


class FlutterBuilder(Builder):
    def __init__(
        self,
        project: str,
        system: str,
        build_scripts_dir: str,
    ):
        self.requested_system = system
        new_system = "macos" if system == "macos_se" else system
        super().__init__(project, new_system, build_scripts_dir)
        builder_types = {
            "ios": AppleBuilder,
            "macos": AppleBuilder,
            "android": AndroidBuilder,
            "linux": LinuxBuilder,
            "windows": WindowsBuilder,
        }
        if new_system not in builder_types:
            raise ValueError(f"unsupported system: {system}")
        self.builder = builder_types[new_system](project, new_system, build_scripts_dir)
        self.build_type = {
            "android": "appbundle",
            "ios": "ipa",
            "macos": "macos",
            "linux": "linux",
            "windows": "windows",
        }

    @staticmethod
    def prepare_macos_se(system: str, build_scripts_dir: str) -> str:
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
        receipt = begin_build(self, self.requested_system)
        self.before_build()
        self.build_app()
        self.after_build()
        finish_build(self, receipt)

    def before_build(self):
        self.prepare_macos_se(self.requested_system, os.path.join(self.root_dir, "build_scripts"))
        super().before_build()
        self.update_build_number()
        self.pub_get()
        self.run_ffi_gen()
        self.builder.before_build()

    def update_build_number(self):
        marketing_version = self.read_version().split("+", maxsplit=1)[0]
        self.write_version(f"{marketing_version}+{self.build_number}")

    def pub_get(self):
        run_command([flutter_command(), "pub", "get"], cwd=self.root_dir)

    def run_ffi_gen(self):
        run_command([dart_command(), "run", "ffigen"], cwd=self.root_dir)

    def build_app(self):
        if self.system in ("ios", "macos"):
            self.builder.build_app()
            return

        cmd = [flutter_command(), "build", self.build_type[self.system]]
        if self.system == "android":
            cmd.extend(["--target-platform", "android-arm64,android-x64"])
        run_command(cmd, cwd=self.root_dir)
        self.builder.build_app()

    def after_build(self):
        super().after_build()
        app_key = f"app.release.dir.{self.system}"
        if app_key in self.project_config:
            app_src_dir = os.path.join(self.project_dir, self.project_config[app_key])
            cp_dir_files(app_src_dir, self.output_dir)
        self.builder.after_build()
