import os
import tempfile
import unittest
import xml.etree.ElementTree as ET
from unittest.mock import patch

from app.windows import WindowsBuilder
from app.windows_msix import augment_manifest, package_with_vcore


class WindowsPackagingTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)

        self.project_dir = os.path.join(self.temp_dir.name, "windows")
        os.makedirs(self.project_dir)
        self.pubspec_path = os.path.join(self.temp_dir.name, "pubspec.yaml")
        with open(self.pubspec_path, mode="wb") as f:
            f.write(
                b"name: OneXray\n"
                b"description: Test fixture\n"
                b"version: 26.7.3+412\n"
            )

        self.builder = WindowsBuilder.__new__(WindowsBuilder)
        self.builder.project = "OneXray"
        self.builder.root_dir = self.temp_dir.name
        self.builder.project_dir = self.project_dir
        self.builder.output_dir = os.path.join(self.temp_dir.name, "output")
        self.builder.package_suffix = "windows-amd64"
        self.builder.target_architecture = "x64"
        self.builder._prepare_msix_bundle = lambda: None
        os.makedirs(self.builder.output_dir)

    def test_build_app_packages_only_msix(self):
        calls = []
        self.builder.package_msix = lambda: calls.append("msix")
        self.builder.fastforge_build = self.fail

        self.builder.build_app()

        self.assertEqual(calls, ["msix"])

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
            patch("app.windows._pe_machine", return_value=0x8664),
            patch("app.windows.shutil.copy2"),
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

    def test_local_signing_requires_certificate_and_publisher(self):
        with self.assertRaises(ValueError):
            package_with_vcore(
                "missing.msix",
                local_development=True,
                certificate_path="missing.pfx",
                certificate_password="test",
                development_publisher="CN=OneXray Development",
            )

    def test_manifest_adds_vcore_hosts_and_activation(self):
        manifest = os.path.join(self.temp_dir.name, "AppxManifest.xml")
        with open(manifest, "w", encoding="utf-8") as output:
            output.write(_MANIFEST_FIXTURE)

        augment_manifest(
            manifest,
            local_development=True,
            development_publisher="CN=OneXray Development",
        )

        root = ET.parse(manifest).getroot()
        ns = {"f": _FOUNDATION}
        identity = root.find("f:Identity", ns)
        self.assertEqual(identity.attrib["Name"], "OneXray.Dev")
        self.assertEqual(identity.attrib["Publisher"], "CN=OneXray Development")
        self.assertIsNotNone(root.find(".//f:Application[@Id='SessionHost']", ns))
        self.assertIsNotNone(root.find(".//f:Application[@Id='VpnProvider']", ns))
        self.assertEqual(
            root.find(".//f:InProcessServer/f:Path", ns).text,
            "vcore.dll",
        )


_FOUNDATION = "http://schemas.microsoft.com/appx/manifest/foundation/windows10"
_DESKTOP = "http://schemas.microsoft.com/appx/manifest/desktop/windows10"
_MANIFEST_FIXTURE = f'''<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="{_FOUNDATION}"
 xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
 xmlns:desktop="{_DESKTOP}"
 xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
 IgnorableNamespaces="uap desktop rescap">
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
