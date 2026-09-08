import hashlib
import json
import os
import re
import shutil
import tempfile
import unittest
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch

from app.windows import (
    WindowsBuilder,
    _copy_vcore_artifacts,
    _VCORE_ARTIFACTS,
    _VCORE_IDENTITY,
    _RUNTIME_FILES,
    _WINTUN_VERSION,
)
from app.windows_msix import augment_manifest, package_with_vcore


class WindowsPackagingTest(unittest.TestCase):
    def setUp(self):
        fixtures = Path(__file__).resolve().parents[3] / "references" / "windows-build" / "tests"
        fixtures.mkdir(parents=True, exist_ok=True)
        self.temp_dir = tempfile.TemporaryDirectory(dir=fixtures)
        self.addCleanup(self.temp_dir.cleanup)

        self.project_dir = os.path.join(self.temp_dir.name, "windows")
        os.makedirs(self.project_dir)
        self.pubspec_path = os.path.join(self.temp_dir.name, "pubspec.yaml")
        with open(self.pubspec_path, mode="wb") as f:
            f.write(b"name: OneXray\ndescription: Test fixture\nversion: 26.7.3+412\n")

        self.builder = WindowsBuilder.__new__(WindowsBuilder)
        self.builder.project = "OneXray"
        self.builder.root_dir = self.temp_dir.name
        self.builder.project_dir = self.project_dir
        self.builder.workspace_dir = self.temp_dir.name
        self.builder.mode = "msix"
        self.builder.output_dir = os.path.join(self.temp_dir.name, "output")
        self.builder.package_suffix = "windows-amd64"
        self.builder.target_architecture = "x64"
        self.builder._prepare_msix_bundle = lambda: None
        os.makedirs(self.builder.output_dir)
        self.config_path = Path(self.project_dir) / "packaging/exe/make_config.yaml"
        self.config_path.parent.mkdir(parents=True)
        shutil.copy2(
            Path(__file__).resolve().parents[2] / "windows/packaging/exe/make_config.yaml",
            self.config_path,
        )

    def test_build_app_packages_only_msix(self):
        calls = []
        self.builder.package_msix = lambda: calls.append("msix")
        self.builder.fastforge_build = self.fail

        self.builder.build_app()

        self.assertEqual(calls, ["msix"])

    def test_exe_mode_packages_installer_and_zip_without_msix(self):
        self.builder.mode = "exe"
        calls = []
        self.builder.package_msix = self.fail
        self.builder.package_exe_and_zip = lambda: calls.append("exe,zip")
        self.builder.build_app()
        self.assertEqual(calls, ["exe,zip"])

    def _bundle(self):
        source = (Path(self.builder.root_dir) / "build/windows" /
                  self.builder.target_architecture / "runner/Release")
        source.mkdir(parents=True, exist_ok=True)
        for name in ("OneXray.exe", "flutter_windows.dll", *_RUNTIME_FILES):
            (source / name).write_bytes(_pe(self.builder._machine()))
        for name in ("data/icudtl.dat", "data/app.so", "data/flutter_assets/AssetManifest.bin",
                     "data/flutter_assets/assets/dat/geoip.dat", "plugin.dll"):
            file = source / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(b"fixture")
        return source

    def test_fastforge_builds_both_formats_with_explicit_mode_and_architecture(self):
        original_config = self.config_path.read_bytes()
        pubspec = Path(self.pubspec_path).read_bytes()
        for target, package_arch, inno_arch, processor_arch in (
            ("x64", "amd64", "x64os", "AMD64"),
            ("arm64", "arm64", "arm64", "ARM64"),
        ):
            with self.subTest(architecture=target):
                self.builder.target_architecture = target
                self.builder.package_suffix = f"windows-{package_arch}"

                def package(*args, **kwargs):
                    config = self.config_path.read_text()
                    self.assertIn(f"architectures_allowed: {inno_arch}\n", config)
                    self.assertIn(f"architectures_install_in_64bit_mode: {inno_arch}\n", config)
                    self.assertEqual(self.builder.read_version(), "26.7.3")
                    self._bundle()
                    dist = Path(self.builder.root_dir) / "dist" / self.builder.read_version()
                    dist.mkdir(parents=True, exist_ok=True)
                    for extension in ("exe", "zip"):
                        (dist / f"OneXray-windows-{package_arch}.{extension}").write_bytes(
                            f"Fastforge {target} {extension}".encode()
                        )
                    (dist / "unrelated.msix").write_bytes(b"not an EXE-mode artifact")

                with patch.object(self.builder, "fastforge_build", side_effect=package) as fastforge:
                    self.builder.package_exe_and_zip()
                fastforge.assert_called_once_with(
                    "exe,zip",
                    arguments=(
                        "--build-dart-define", "ONEXRAY_WINDOWS_MODE=exe",
                        "--flutter-build-args", "build-number=412",
                        "--artifact-name", f"OneXray-windows-{package_arch}." + "{{ext}}",
                    ),
                    env={"PROCESSOR_ARCHITECTURE": processor_arch},
                )
                for extension in ("exe", "zip"):
                    self.assertEqual(
                        (Path(self.builder.output_dir) / f"OneXray-windows-{package_arch}.{extension}").read_bytes(),
                        f"Fastforge {target} {extension}".encode(),
                    )
                self.assertFalse((Path(self.builder.output_dir) / "unrelated.msix").exists())
                self.assertEqual(self.config_path.read_bytes(), original_config)
                self.assertEqual(Path(self.pubspec_path).read_bytes(), pubspec)

    def test_fastforge_failure_restores_configuration_without_collecting_packages(self):
        self.builder.target_architecture = "arm64"
        original_config = self.config_path.read_bytes()
        original_pubspec = Path(self.pubspec_path).read_bytes()
        with patch.object(self.builder, "fastforge_build", side_effect=RuntimeError("packaging failed")):
            with self.assertRaisesRegex(RuntimeError, "packaging failed"):
                self.builder.package_exe_and_zip()
        self.assertEqual(self.config_path.read_bytes(), original_config)
        self.assertEqual(Path(self.pubspec_path).read_bytes(), original_pubspec)
        self.assertEqual(list(Path(self.builder.output_dir).iterdir()), [])

    def test_fastforge_requires_both_outputs_for_the_current_version(self):
        self._bundle()
        dist = Path(self.builder.root_dir) / "dist"
        for version, extensions in (("old-version", ("exe", "zip")), ("26.7.3", ("exe",))):
            directory = dist / version
            directory.mkdir(parents=True)
            for extension in extensions:
                (directory / f"OneXray-windows-amd64.{extension}").write_bytes(b"fixture")
        with patch.object(self.builder, "fastforge_build"), self.assertRaisesRegex(FileNotFoundError, "Fastforge package missing"):
            self.builder.package_exe_and_zip()
        self.assertEqual(list(Path(self.builder.output_dir).iterdir()), [])

    def test_bundle_rejects_missing_dependencies_and_wrong_architecture(self):
        source = self._bundle()
        for name in (*_RUNTIME_FILES, "data/app.so", "data/flutter_assets/AssetManifest.bin"):
            with self.subTest(missing=name):
                original = (source / name).read_bytes()
                (source / name).unlink()
                with self.assertRaises(FileNotFoundError):
                    self.builder._release_bundle()
                (source / name).write_bytes(original)
        (source / "wintun.dll").write_bytes(_pe(0xAA64))
        with self.assertRaisesRegex(ValueError, "wrong architecture"):
            self.builder._release_bundle()

    def test_wintun_copies_only_the_verified_architecture_dll(self):
        archive = Path(self.builder.workspace_dir) / "references/windows-build" / f"wintun-{_WINTUN_VERSION}.zip"
        archive.parent.mkdir(parents=True)
        with zipfile.ZipFile(archive, "w") as package:
            package.writestr("wintun/bin/amd64/wintun.dll", _pe(0x8664))
            package.writestr("wintun/bin/arm64/wintun.dll", _pe(0xAA64))
            package.writestr("wintun/LICENSE.txt", "upstream license")
        for architecture, machine in (("x64", 0x8664), ("arm64", 0xAA64)):
            self.builder.target_architecture = architecture
            with patch("app.windows._WINTUN_SHA256", hashlib.sha256(archive.read_bytes()).hexdigest()):
                self.builder.install_wintun()
            app = Path(self.project_dir) / "app"
            self.assertEqual([file.name for file in app.iterdir()], ["wintun.dll"])
            self.assertEqual((app / "wintun.dll").read_bytes(), _pe(machine))
        with patch("app.windows._WINTUN_SHA256", "0" * 64), self.assertRaisesRegex(ValueError, "hash mismatch"):
            self.builder.install_wintun()

    def test_installer_preserves_released_identity_and_scopes_cleanup(self):
        root = Path(__file__).resolve().parents[2]
        installer = (root / "windows/packaging/exe/inno_setup.iss").read_text()
        config = (root / "windows/packaging/exe/make_config.yaml").read_text()
        self.assertIn("app_id: 835d7bbd-85bb-4c73-97f8-ce0740f151a7", config)
        self.assertIn("executable_name: OneXray.exe", config)
        self.assertIn("privileges_required: lowest", config)
        self.assertIn("AppId={{APP_ID}}", installer)
        self.assertIn("PrivilegesRequired={{PRIVILEGES_REQUIRED}}", installer)
        self.assertIn("AppVersion={{APP_VERSION}}", installer)
        self.assertIn("StartupShortcutTargetsCurrentInstall(ShortcutPath, ExpectedTarget)", installer)
        self.assertIn("CompareText(CurrentCommand", installer)
        self.assertNotIn("uninsdeletekey", installer)
        self.assertNotIn("LicenseFile", installer)
        cmake = (root / "windows/app.cmake").read_text()
        for name in _RUNTIME_FILES:
            self.assertIn(name, cmake)
        self.assertNotIn("if(EXISTS", cmake)

    def test_exe_workflow_installs_fastforge_and_configures_inno_setup(self):
        workflow = (Path(__file__).resolve().parents[2] / ".github/workflows/build.yml").read_text()
        windows = workflow.split("\n  windows:", 1)[1].split("\n  linux:", 1)[0]
        self.assertIn("name: Install Fastforge\n        if: matrix.mode == 'exe'", windows)
        self.assertIn("dart pub global activate fastforge", windows)
        self.assertIn('"INNO_SETUP_PATH=$installDir" >> $env:GITHUB_ENV', windows)
        self.assertNotIn('"ISCC=$compiler"', windows)

    def test_winget_workflow_publishes_stable_exe_installers_only(self):
        workflow = (Path(__file__).resolve().parents[2] / ".github/workflows/update-winget.yml").read_text()
        self.assertIn("release:\n    types:\n      - released", workflow)
        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn('git check-ref-format "refs/tags/$tag"', workflow)
        self.assertIn("identifier: YuanDevLLC.OneXray", workflow)
        self.assertIn("uses: vedantmgoyal9/winget-releaser@v2", workflow)
        self.assertIn("max-versions-to-keep: 0", workflow)
        self.assertIn("contents: read", workflow)
        self.assertIn("secrets.PACKAGE_MANAGER_GITHUB_TOKEN", workflow)
        self.assertEqual(workflow.count("if: steps.verify.outputs.should_update == 'true'"), 2)
        pattern = re.search(r"installers-regex: '([^']+)'", workflow).group(1)
        for name in ("OneXray-windows-amd64.exe", "OneXray-windows-arm64.exe"):
            self.assertRegex(name, pattern)
            self.assertIn(name, workflow)
        for name in ("OneXray-windows-amd64.zip", "OneXray-windows-arm64.msix",
                     "OneXrayCore.exe", "OneXray-windows-amd64.exe.sig"):
            self.assertNotRegex(name, pattern)

    def test_msix_uses_store_version_without_rebuilding_windows(self):
        with (
            patch("app.windows.dart_command", return_value="dart"),
            patch("app.windows.run_command") as run_command,
            patch("app.windows.package_with_vcore") as package_with_vcore,
        ):
            self.builder.package_msix()

        run_command.assert_called_once_with(
            [
                "dart",
                "run",
                "msix:create",
                "--build-windows",
                "false",
                "--store",
                "--architecture",
                "x64",
                "--version",
                "26.7.3.0",
                "--output-path",
                self.builder.output_dir,
                "--output-name",
                "OneXray-windows-amd64",
            ],
            cwd=self.builder.root_dir,
        )
        package_with_vcore.assert_called_once_with(
            os.path.join(
                self.builder.output_dir,
                "OneXray-windows-amd64.msix",
            ),
            local_development=False,
            certificate_thumbprint=None,
            certificate_path=None,
            certificate_password=None,
            development_publisher=None,
        )

    def test_arm64_msix_uses_arm64_architecture(self):
        self.builder.target_architecture = "arm64"
        self.builder.package_suffix = "windows-arm64"

        with (
            patch("app.windows.dart_command", return_value="dart"),
            patch("app.windows.run_command") as run_command,
            patch("app.windows.package_with_vcore"),
        ):
            self.builder.package_msix()

        command = run_command.call_args.args[0]
        self.assertEqual(command[command.index("--architecture") + 1], "arm64")
        self.assertEqual(command[-1], "OneXray-windows-arm64")

    def test_vcore_build_lets_vcore_detect_native_architecture(self):
        vcore_dir = os.path.join(self.temp_dir.name, "VCore")
        with (
            patch.object(self.builder, "_vcore_dir", return_value=vcore_dir),
            patch("app.windows.run_command") as run_command,
            patch("app.windows._copy_vcore_artifacts") as copy_vcore_artifacts,
        ):
            self.builder.build_vcore()

        self.assertEqual(
            run_command.call_args_list[1].args[0],
            [
                "uv",
                "run",
                "--project",
                os.path.join(vcore_dir, "scripts"),
                "--locked",
                "vcore-scripts",
                "build",
                "windows",
            ],
        )
        copy_vcore_artifacts.assert_called_once_with(
            os.path.join(vcore_dir, "dist", "windows", "x64"),
            os.path.join(self.project_dir, "app"),
            "x64",
        )

    def test_prepare_msix_bundle_stages_path_resolved_by_msix_3_18(self):
        self.builder.target_architecture = "arm64"
        source = os.path.join(
            self.temp_dir.name,
            "build",
            "windows",
            "arm64",
            "runner",
            "Release",
        )
        self._bundle()

        WindowsBuilder._prepare_msix_bundle(self.builder)

        self.assertTrue(
            os.path.isfile(
                os.path.join(
                    self.temp_dir.name,
                    "build",
                    "windows",
                    "arm64",
                    "arm64",
                    "runner",
                    "Release",
                    "OneXray.exe",
                )
            )
        )

    def test_msix_rejects_versions_the_store_cannot_accept(self):
        versions = ("26.8", "dev.8.5", "26.70000.5", "0.8.5")
        for version in versions:
            with self.subTest(version=version):
                with patch.object(self.builder, "read_version", return_value=version):
                    with self.assertRaises(ValueError):
                        self.builder.msix_version()

    def test_target_architecture_prefers_workflow_setting(self):
        with patch.dict(os.environ, {"ONEXRAY_WINDOWS_ARCH": "arm64"}):
            self.assertEqual(WindowsBuilder._target_architecture(), "arm64")

    def test_windows_jobs_resolve_vcore_main_once_and_record_sha(self):
        workflow = (
            Path(__file__).resolve().parents[2] / ".github/workflows/build.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("VCORE_REF: main", workflow)
        self.assertIn(
            'echo "$vcore_sha" > release-metadata/vcore-sha.txt',
            workflow,
        )
        self.assertEqual(workflow.count("ref: ${{ env.VCORE_REF }}"), 1)
        self.assertIn("ref: ${{ needs.release_metadata.outputs.vcore_sha }}", workflow)

    def test_local_signing_requires_certificate_and_publisher(self):
        with self.assertRaises(ValueError):
            package_with_vcore(
                "missing.msix",
                local_development=True,
                certificate_path="missing.pfx",
                certificate_password="test",
                development_publisher="CN=OneXray Development",
            )
        with self.assertRaisesRegex(ValueError, "40 hexadecimal"):
            package_with_vcore(
                "missing.msix",
                local_development=True,
                certificate_thumbprint="invalid",
                development_publisher="CN=OneXray Development",
            )

    def test_vcore_artifact_manifest_is_verified_before_copying(self):
        source = os.path.join(self.temp_dir.name, "vcore")
        destination = os.path.join(self.project_dir, "app")
        _write_vcore_set(source)

        _copy_vcore_artifacts(source, destination, "x64")

        for name in _VCORE_ARTIFACTS:
            self.assertTrue(os.path.isfile(os.path.join(destination, name)))

    def test_vcore_artifact_manifest_rejects_incompatible_sets(self):
        mutations = {
            "revision": lambda manifest: manifest.update(
                windowsPackageIntegrationRevision=1
            ),
            "previous revision": lambda manifest: manifest.update(
                windowsPackageIntegrationRevision=2
            ),
            "architecture": lambda manifest: manifest.update(architecture="arm64"),
            "identity": lambda manifest: manifest.update(buildIdentity="old"),
            "file set": lambda manifest: manifest["artifacts"].pop(
                "vcore-windows-session-host.exe"
            ),
            "hash": lambda manifest: manifest["artifacts"].update(
                {"vcore.dll": "0" * 64}
            ),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                source = os.path.join(self.temp_dir.name, name.replace(" ", "-"))
                manifest = _write_vcore_set(source)
                mutate(manifest)
                _write_manifest(source, manifest)
                with self.assertRaises(ValueError):
                    _copy_vcore_artifacts(
                        source,
                        os.path.join(self.project_dir, "app"),
                        "x64",
                    )

    def test_store_and_local_manifests_have_one_application_contract(self):
        for local_development in (False, True):
            with self.subTest(local_development=local_development):
                manifest = os.path.join(
                    self.temp_dir.name,
                    f"AppxManifest-{local_development}.xml",
                )
                with open(manifest, "w", encoding="utf-8") as output:
                    output.write(_MANIFEST_FIXTURE)

                augment_manifest(
                    manifest,
                    local_development=local_development,
                    development_publisher="CN=OneXray Development",
                )

                root = ET.parse(manifest).getroot()
                ns = {
                    "f": _FOUNDATION,
                    "uap": _UAP,
                    "uap10": _UAP10,
                    "desktop": _DESKTOP,
                }
                identity = root.find("f:Identity", ns)
                self.assertEqual(
                    identity.attrib["Name"],
                    "OneXray.Dev" if local_development else "YuanDevLLC.OneXray",
                )
                self.assertEqual(
                    identity.attrib["Publisher"],
                    "CN=OneXray Development" if local_development else "CN=Store",
                )
                ignorable = root.attrib["IgnorableNamespaces"].split()
                self.assertIn("uap10", ignorable)
                self.assertNotIn("uap3", ignorable)

                applications = root.findall("f:Applications/f:Application", ns)
                self.assertEqual(len(applications), 1)
                application = applications[0]
                self.assertEqual(application.attrib["Id"], "OneXray")
                self.assertEqual(application.attrib["Executable"], "OneXray.exe")
                self.assertFalse(
                    any("AppListEntry" in element.attrib for element in root.iter())
                )

                session = application.find(
                    "f:Extensions/desktop:Extension"
                    "[@Category='windows.fullTrustProcess']",
                    ns,
                )
                self.assertEqual(
                    session.attrib["Executable"],
                    "vcore-windows-session-host.exe",
                )
                self.assertIsNotNone(session.find("desktop:FullTrustProcess", ns))

                provider = application.find(
                    "f:Extensions/f:Extension[@Category='windows.backgroundTasks']",
                    ns,
                )
                self.assertEqual(
                    provider.attrib["Executable"],
                    "vcore-windows-vpn-host.exe",
                )
                self.assertEqual(
                    provider.attrib["EntryPoint"],
                    "VCore.VpnBackgroundTask",
                )
                self.assertEqual(
                    provider.attrib[f"{{{_UAP10}}}RuntimeBehavior"],
                    "windowsApp",
                )
                self.assertEqual(
                    provider.attrib[f"{{{_UAP10}}}TrustLevel"],
                    "appContainer",
                )
                self.assertIsNotNone(
                    provider.find("f:BackgroundTasks/uap:Task[@Type='vpnClient']", ns)
                )
                self.assertIsNotNone(
                    application.find(
                        "f:Extensions/uap:Extension[@Category='windows.protocol']"
                        "/uap:Protocol[@Name='onexray']",
                        ns,
                    )
                )
                startup = application.find(
                    "f:Extensions/desktop:Extension[@Category='windows.startupTask']"
                    "/desktop:StartupTask",
                    ns,
                )
                self.assertEqual(startup.attrib["TaskId"], "VCoreStartup")
                self.assertEqual(startup.attrib["Enabled"], "false")
                self.assertEqual(
                    root.find(".//f:InProcessServer/f:Path", ns).text,
                    "vcore.dll",
                )

    def test_manifest_rejects_duplicate_vcore_extensions(self):
        manifest = os.path.join(self.temp_dir.name, "AppxManifest.xml")
        with open(manifest, "w", encoding="utf-8") as output:
            output.write(_MANIFEST_FIXTURE)
        augment_manifest(manifest)

        with self.assertRaises(ValueError):
            augment_manifest(manifest)


def _write_vcore_set(path):
    os.makedirs(path)
    hashes = {}
    for name in _VCORE_ARTIFACTS:
        artifact = os.path.join(path, name)
        contents = _pe(0x8664)
        with open(artifact, "wb") as output:
            output.write(contents)
        hashes[name] = hashlib.sha256(contents).hexdigest()
    manifest = {
        "formatVersion": 1,
        "windowsPackageIntegrationRevision": 3,
        "architecture": "x64",
        "buildIdentity": _VCORE_IDENTITY,
        "artifacts": hashes,
    }
    _write_manifest(path, manifest)
    return manifest


def _pe(machine):
    contents = bytearray(0x86)
    contents[:2] = b"MZ"
    contents[0x3C:0x40] = (0x80).to_bytes(4, "little")
    contents[0x80:0x84] = b"PE\0\0"
    contents[0x84:0x86] = machine.to_bytes(2, "little")
    return contents


def _write_manifest(path, manifest):
    with open(
        os.path.join(path, "vcore-windows-artifacts.json"),
        "w",
        encoding="utf-8",
    ) as output:
        json.dump(manifest, output)


_FOUNDATION = "http://schemas.microsoft.com/appx/manifest/foundation/windows10"
_UAP = "http://schemas.microsoft.com/appx/manifest/uap/windows10"
_UAP10 = "http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
_DESKTOP = "http://schemas.microsoft.com/appx/manifest/desktop/windows10"
_MANIFEST_FIXTURE = f'''<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="{_FOUNDATION}"
 xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
 xmlns:uap3="http://schemas.microsoft.com/appx/manifest/uap/windows10/3"
 xmlns:desktop="{_DESKTOP}"
 xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
 IgnorableNamespaces="uap uap3 desktop rescap">
 <Identity Name="YuanDevLLC.OneXray" Publisher="CN=Store" Version="1.0.0.0" ProcessorArchitecture="x64" />
 <Capabilities>
  <Capability Name="internetClientServer" />
  <Capability Name="privateNetworkClientServer" />
  <rescap:Capability Name="runFullTrust" />
  <rescap:Capability Name="networkingVpnProvider" />
 </Capabilities>
 <Applications>
  <Application Id="OneXray" Executable="OneXray.exe" EntryPoint="Windows.FullTrustApplication">
   <Extensions>
    <uap:Extension Category="windows.protocol">
     <uap:Protocol Name="onexray" />
    </uap:Extension>
    <desktop:Extension Category="windows.startupTask" Executable="OneXray.exe" EntryPoint="Windows.FullTrustApplication">
     <desktop:StartupTask TaskId="VCoreStartup" Enabled="false" DisplayName="OneXray" />
    </desktop:Extension>
   </Extensions>
  </Application>
 </Applications>
</Package>
'''


if __name__ == "__main__":
    unittest.main()
