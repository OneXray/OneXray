import os

from app.builder import Builder
from app.command_line import (
    dart_command,
    is_amd64,
    is_arm64,
    run_command,
)


class WindowsBuilder(Builder):
    def __init__(
        self,
        project: str,
        system: str,
        build_scripts_dir: str,
    ):
        super().__init__(project, system, build_scripts_dir)
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

    def before_build(self):
        super().before_build()
        self.build_core()

    def build_app(self):
        self.package_msix()

    def package_msix(self):
        run_command(
            [
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
            ],
            cwd=self.root_dir,
        )

    def msix_version(self) -> str:
        marketing_parts = self.read_version().split("+", maxsplit=1)[0].split(".")
        if len(marketing_parts) != 3:
            raise ValueError("MSIX version must contain major, minor, and patch")
        try:
            values = [int(component) for component in (*marketing_parts, "0")]
        except ValueError as error:
            raise ValueError("MSIX version components must be numeric") from error
        if any(value < 0 or value > 65535 for value in values):
            raise ValueError("MSIX version components must be between 0 and 65535")
        if values[0] == 0:
            raise ValueError("MSIX major version must be greater than 0")
        return ".".join(str(value) for value in values)
