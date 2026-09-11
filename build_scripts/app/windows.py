import hashlib
import json
import os
import re
import shutil
import struct
import zipfile
from pathlib import Path

from app.builder import Builder
from app.command_line import (
    dart_command,
    download_file,
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
_VCORE_IDENTITY = (
    "VCore;engine=rust;coreVersion=0.1.0;invokeApiVersion=5;configVersion=13"
)
_WINTUN_VERSION = "0.14.1"
_WINTUN_SHA256 = "07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51"
_RUNTIME_FILES = ("libXray.dll", "OneXrayCore.exe", "wintun.dll", *_VCORE_ARTIFACTS)


class WindowsBuilder(Builder):
    def __init__(
        self,
        project: str,
        system: str,
        build_scripts_dir: str,
        *,
        mode: str = "exe",
    ):
        if mode not in ("exe", "msix"):
            raise ValueError(f"Unsupported Windows mode: {mode}")
        super().__init__(project, system, build_scripts_dir)
        self.mode = mode
        self.target_architecture = self._target_architecture()
        package_architecture = "amd64" if self.target_architecture == "x64" else "arm64"
        self.package_suffix = f"windows-{package_architecture}"

    @staticmethod
    def _target_architecture() -> str:
        configured = os.environ.get("ONEXRAY_WINDOWS_ARCH")
        if configured in ("x64", "arm64"):
            return configured
        if configured:
            raise ValueError("ONEXRAY_WINDOWS_ARCH must be x64 or arm64")
        if is_amd64():
            return "x64"
        if is_arm64():
            return "arm64"
        raise ValueError("Windows builds only support x64 and arm64")

    def before_build(self):
        super().before_build()
        self.build_core()
        self.build_vcore()
        self.install_wintun()

    def install_wintun(self):
        cache = Path(self.workspace_dir) / "references" / "windows-build"
        cache.mkdir(parents=True, exist_ok=True)
        archive = cache / f"wintun-{_WINTUN_VERSION}.zip"
        if not archive.is_file():
            download_file(f"https://www.wintun.net/builds/{archive.name}", str(archive))
        if hashlib.sha256(archive.read_bytes()).hexdigest() != _WINTUN_SHA256:
            raise ValueError(f"Wintun archive hash mismatch; replace {archive}")
        architecture = "amd64" if self.target_architecture == "x64" else "arm64"
        destination = Path(self.project_dir) / "app" / "wintun.dll"
        destination.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as package:
            # Only the official DLL is bundled; attribution lives on the docs site.
            destination.write_bytes(package.read(f"wintun/bin/{architecture}/wintun.dll"))
        if _pe_machine(str(destination)) != self._machine():
            raise ValueError("Wintun DLL has the wrong architecture")

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
            ],
            cwd=vcore_dir,
        )

        source = os.path.join(vcore_dir, "dist", "windows", self.target_architecture)
        _copy_vcore_artifacts(
            source,
            os.path.join(self.project_dir, "app"),
            self.target_architecture,
        )

    def _vcore_dir(self) -> str:
        configured = os.environ.get("VCORE_DIR")
        candidates = [configured, os.path.join(self.workspace_dir, "VCore")]
        for candidate in candidates:
            if candidate and os.path.isfile(os.path.join(candidate, "Cargo.toml")):
                return os.path.abspath(candidate)
        raise FileNotFoundError("VCore checkout not found; set VCORE_DIR")

    def build_app(self):
        if self.mode == "msix":
            self.package_msix()
        else:
            self.package_exe_and_zip()

    def _machine(self) -> int:
        return 0x8664 if self.target_architecture == "x64" else 0xAA64

    def _required_crt_files(self) -> tuple[str, ...]:
        runtime_files = ("msvcp140.dll", "vcruntime140.dll")
        if self.target_architecture == "x64":
            runtime_files += ("vcruntime140_1.dll",)
        return runtime_files

    def _release_bundle(self) -> Path:
        source = (Path(self.root_dir) / "build" / "windows" /
                  self.target_architecture / "runner" / "Release")
        for name in (
            f"{self.project}.exe", "flutter_windows.dll", *_RUNTIME_FILES,
            *self._required_crt_files(),
        ):
            artifact = source / name
            if not artifact.is_file():
                raise FileNotFoundError(f"Windows release runtime missing: {artifact}")
            if _pe_machine(str(artifact)) != self._machine():
                raise ValueError(f"Windows release runtime has the wrong architecture: {artifact}")
        for name in ("data/icudtl.dat", "data/app.so", "data/flutter_assets/AssetManifest.bin"):
            if not (source / name).is_file():
                raise FileNotFoundError(f"Windows release data missing: {source / name}")
        return source

    def package_exe_and_zip(self):
        config_path = Path(self.project_dir) / "packaging/exe/make_config.yaml"
        original_config = config_path.read_bytes()
        pubspec_path = Path(self.root_dir) / "pubspec.yaml"
        original_pubspec = pubspec_path.read_bytes()
        marketing_version, _, build_number = self.read_version().partition("+")
        config = original_config.decode("utf-8")
        architecture = "x64os" if self.target_architecture == "x64" else "arm64"
        for key in ("architectures_allowed", "architectures_install_in_64bit_mode"):
            config, count = re.subn(
                rf"(?m)^{key}:.*$", f"{key}: {architecture}", config, count=1,
            )
            if count != 1:
                raise ValueError(f"Fastforge EXE configuration is missing {key}")

        try:
            config_path.write_bytes(config.encode("utf-8"))
            # Inno Setup needs a numeric version; keep Flutter's build number
            # explicitly, while Fastforge builds once for both package targets.
            self.write_version(marketing_version)
            self.fastforge_build(
                "exe,zip",
                arguments=(
                    "--build-dart-define", "ONEXRAY_WINDOWS_MODE=exe",
                    "--flutter-build-args", f"build-number={build_number or self.build_number}",
                    "--artifact-name", f"{self.project}-{self.package_suffix}." + "{{ext}}",
                ),
                # Fastforge resolves the bundle directory from this variable.
                env={"PROCESSOR_ARCHITECTURE": "AMD64" if architecture == "x64os" else "ARM64"},
            )
        finally:
            config_path.write_bytes(original_config)
            pubspec_path.write_bytes(original_pubspec)

        self._release_bundle()
        packages = [
            Path(self.root_dir) / "dist" / marketing_version /
            f"{self.project}-{self.package_suffix}.{extension}"
            for extension in ("exe", "zip")
        ]
        for package in packages:
            if not package.is_file():
                raise FileNotFoundError(f"Fastforge package missing: {package}")
        for package in packages:
            shutil.copy2(package, self.output_dir)

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
            certificate_thumbprint=os.environ.get("ONEXRAY_DEV_CERT_THUMBPRINT"),
            certificate_path=os.environ.get("ONEXRAY_DEV_CERT_PATH"),
            certificate_password=os.environ.get("ONEXRAY_DEV_CERT_PASSWORD"),
            development_publisher=os.environ.get("ONEXRAY_DEV_PUBLISHER"),
        )

    def _prepare_msix_bundle(self):
        source = self._release_bundle()
        # ponytail: msix 3.18 resolves the architecture twice; remove this
        # extra directory level when upstream stops doing that.
        destination = os.path.join(
            self.root_dir,
            "build",
            "windows",
            self.target_architecture,
            self.target_architecture,
            "runner",
            "Release",
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


def _copy_vcore_artifacts(source: str, destination: str, architecture: str) -> None:
    manifest_path = os.path.join(source, "vcore-windows-artifacts.json")
    try:
        with open(manifest_path, encoding="utf-8") as manifest_file:
            manifest = json.load(manifest_file)
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError("invalid VCore Windows artifact manifest") from error

    if (
        not isinstance(manifest, dict)
        or manifest.get("formatVersion") != 1
        or manifest.get("windowsPackageIntegrationRevision") != 3
        or manifest.get("architecture") != architecture
        or manifest.get("buildIdentity") != _VCORE_IDENTITY
        or not isinstance(manifest.get("artifacts"), dict)
        or set(manifest["artifacts"]) != set(_VCORE_ARTIFACTS)
    ):
        raise ValueError("incompatible VCore Windows artifact manifest")

    expected_machine = 0x8664 if architecture == "x64" else 0xAA64
    for name in _VCORE_ARTIFACTS:
        artifact = os.path.join(source, name)
        try:
            with open(artifact, "rb") as contents:
                digest = hashlib.file_digest(contents, "sha256").hexdigest()
        except OSError as error:
            raise ValueError(f"missing VCore artifact: {name}") from error
        if digest != manifest["artifacts"][name]:
            raise ValueError(f"VCore artifact hash mismatch: {name}")
        if _pe_machine(artifact) != expected_machine:
            raise ValueError(f"VCore artifact has the wrong architecture: {artifact}")

    os.makedirs(destination, exist_ok=True)
    for name in _VCORE_ARTIFACTS:
        shutil.copy2(os.path.join(source, name), destination)


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
