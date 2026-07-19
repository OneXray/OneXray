import os
import shutil

import yaml

from app.builder import Builder
from app.command_line import (
    check_and_create_dir,
    download_file,
    run_command,
    dart_command,
    is_amd64,
    is_arm64,
)


class WindowsBuilder(Builder):
    def __init__(
        self,
        project: str,
        system: str,
        build_scripts_dir: str,
    ):
        super().__init__(project, system, build_scripts_dir)
        self.version = ""
        self.target_architecture = self._target_architecture()
        package_architecture = (
            "amd64" if self.target_architecture == "x64" else "arm64"
        )
        self.package_suffix = f"windows-{package_architecture}"

    @staticmethod
    def _target_architecture() -> str:
        configured = os.environ.get("ONEXRAY_WINDOWS_ARCH")
        if configured in ("x64", "arm64"):
            return configured
        if is_amd64():
            return "x64"
        if is_arm64():
            return "arm64"
        raise ValueError("Windows builds only support x64 and arm64")

    def _wintun_architecture(self) -> str:
        return "amd64" if self.target_architecture == "x64" else "arm64"

    def build(self):
        self.before_build()

        self.build_app()

        self.after_build()

    def before_build(self):
        super().before_build()
        self.build_core()

        self.download_win_tun()

    def download_win_tun(self):
        app_path = os.path.join(
            self.project_dir, self.project_config["core.lib.dst.dir.windows"]
        )
        check_and_create_dir(app_path)

        zip_path = os.path.join(self.output_dir, "wintun.zip")
        win_tun_url = "https://www.wintun.net/builds/wintun-0.14.1.zip"
        download_file(win_tun_url, zip_path)
        shutil.unpack_archive(zip_path, self.output_dir)

        win_tun_src_path = os.path.join(
            self.output_dir,
            "wintun",
            "bin",
            self._wintun_architecture(),
            "wintun.dll",
        )
        shutil.move(win_tun_src_path, app_path)

    def build_app(self):
        self.fastforge_build("zip")
        self.package_exe()
        self.package_msix()

    def package_exe(self):
        config_path = os.path.join(
            self.project_dir, "packaging", "exe", "make_config.yaml"
        )
        with open(config_path, mode="rb") as f:
            original_content = f.read()

        config = yaml.load(original_content, Loader=yaml.CLoader)
        architecture = (
            "x64compatible" if self.target_architecture == "x64" else "arm64"
        )
        config["architectures_allowed"] = architecture
        config["architectures_install_in_64bit_mode"] = architecture

        try:
            with open(config_path, mode="w", encoding="utf-8", newline="\n") as f:
                yaml.dump(
                    config,
                    f,
                    Dumper=yaml.CDumper,
                    allow_unicode=True,
                    sort_keys=False,
                )
            self.package_with_marketing_version("exe")
        finally:
            with open(config_path, mode="wb") as f:
                f.write(original_content)

    def package_msix(self):
        cmd = [
            dart_command(),
            "run",
            "msix:create",
            "--build-windows",
            "false",
            "--store",
            "--architecture",
            self.target_architecture,
            "--version",
            self.msix_version(),
            "--output-path",
            self.output_dir,
            "--output-name",
            f"{self.project}-{self.package_suffix}",
        ]
        run_command(cmd)

    def msix_version(self) -> str:
        marketing_parts = self.read_version().split("+", maxsplit=1)[0].split(".")
        if len(marketing_parts) != 3:
            raise ValueError("MSIX version must contain major, minor, and patch")
        components = [*marketing_parts, "0"]
        try:
            values = [int(component) for component in components]
        except ValueError as error:
            raise ValueError("MSIX version components must be numeric") from error
        if any(value < 0 or value > 65535 for value in values):
            raise ValueError("MSIX version components must be between 0 and 65535")
        if values[0] == 0:
            raise ValueError("MSIX major version must be greater than 0")
        return ".".join(str(value) for value in values)

    def after_build(self):
        super().after_build()

        for file_type in (".zip", ".exe"):
            file_name = self.find_file(file_type)
            if file_name:
                self.rename_file(file_name, file_type)
