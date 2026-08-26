import os
import tempfile
import unittest
from unittest.mock import patch

from app.windows import WindowsBuilder


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
        self.builder.project_dir = self.project_dir
        self.builder.output_dir = os.path.join(self.temp_dir.name, "output")
        self.builder.package_suffix = "windows-amd64"
        self.builder.target_architecture = "x64"
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
            ]
        )

    def test_arm64_msix_uses_arm64_architecture(self):
        self.builder.target_architecture = "arm64"
        self.builder.package_suffix = "windows-arm64"

        with (
            patch("app.windows.dart_command", return_value="dart"),
            patch("app.windows.run_command") as run_command,
        ):
            self.builder.package_msix()

        command = run_command.call_args.args[0]
        self.assertEqual(command[command.index("--architecture") + 1], "arm64")
        self.assertEqual(command[-1], "OneXray-windows-arm64")

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

    def test_arm64_uses_arm64_wintun(self):
        self.builder.target_architecture = "arm64"
        self.assertEqual(self.builder._wintun_architecture(), "arm64")


if __name__ == "__main__":
    unittest.main()
