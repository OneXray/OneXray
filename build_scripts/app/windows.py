import os
import shutil
import struct

from app.builder import Builder
from app.command_line import (
    dart_command,
    is_amd64,
    is_arm64,
    run_command,
)
from app.windows_msix import package_with_vcore

_VCORE_ARTIFACTS = (
    "vcore.dll",
    "vcore-windows-vpn-host.exe",
    "vcore-windows-session-host.exe",
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
        self.build_vcore()

    def build_vcore(self):
        vcore_dir = self._vcore_dir()
        scripts = os.path.join(vcore_dir, "scripts")
        run_command(
            [
                "uv",
                "run",
                "--project",
                scripts,
                "--locked",
                "vcore-scripts",
                "check",
                "tls-dependencies",
            ],
            cwd=vcore_dir,
        )
        run_command(
            [
                "uv",
                "run",
                "--project",
                scripts,
                "--locked",
                "vcore-scripts",
                "build",
                "windows",
                "--architecture",
                self.target_architecture,
            ],
            cwd=vcore_dir,
        )

        source = os.path.join(
            vcore_dir, "dist", "windows", self.target_architecture
        )
        destination = os.path.join(self.project_dir, "app")
        os.makedirs(destination, exist_ok=True)
        expected_machine = 0x8664 if self.target_architecture == "x64" else 0xAA64
        for name in _VCORE_ARTIFACTS:
            artifact = os.path.join(source, name)
            if _pe_machine(artifact) != expected_machine:
                raise ValueError(
                    f"VCore artifact has the wrong architecture: {artifact}"
                )
            shutil.copy2(artifact, destination)

    def _vcore_dir(self) -> str:
        configured = os.environ.get("VCORE_DIR")
        candidates = [configured, os.path.join(self.workspace_dir, "VCore")]
        for candidate in candidates:
            if candidate and os.path.isfile(os.path.join(candidate, "Cargo.toml")):
                return os.path.abspath(candidate)
        raise FileNotFoundError("VCore checkout not found; set VCORE_DIR")

    def build_app(self):
        self.package_msix()

    def package_msix(self):
        self._prepare_msix_bundle()
        output_name = f"{self.project}-{self.package_suffix}"
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
                output_name,
            ],
            cwd=self.root_dir,
        )
        local_development = os.environ.get("ONEXRAY_DEV_SIGN") == "1"
        package_with_vcore(
            os.path.join(self.output_dir, f"{output_name}.msix"),
            local_development=local_development,
            certificate_path=os.environ.get("ONEXRAY_DEV_CERT_PATH"),
            certificate_password=os.environ.get("ONEXRAY_DEV_CERT_PASSWORD"),
            development_publisher=os.environ.get("ONEXRAY_DEV_PUBLISHER"),
        )

    def _prepare_msix_bundle(self):
        source = os.path.join(
            self.root_dir,
            "build",
            "windows",
            self.target_architecture,
            "runner",
            "Release",
        )
        if not os.path.isfile(os.path.join(source, f"{self.project}.exe")):
            raise FileNotFoundError(
                f"Windows {self.target_architecture} release bundle not found: {source}"
            )
        destination = os.path.join(
            self.root_dir, "build", "windows", "runner", "Release"
        )
        shutil.rmtree(destination, ignore_errors=True)
        shutil.copytree(source, destination)

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


def _pe_machine(path: str) -> int:
    with open(path, "rb") as artifact:
        if artifact.read(2) != b"MZ":
            raise ValueError(f"not a PE artifact: {path}")
        artifact.seek(0x3C)
        pe_offset_data = artifact.read(4)
        if len(pe_offset_data) != 4:
            raise ValueError(f"invalid PE artifact: {path}")
        artifact.seek(struct.unpack("<I", pe_offset_data)[0])
        if artifact.read(4) != b"PE\0\0":
            raise ValueError(f"invalid PE artifact: {path}")
        machine = artifact.read(2)
        if len(machine) != 2:
            raise ValueError(f"invalid PE artifact: {path}")
        return struct.unpack("<H", machine)[0]
