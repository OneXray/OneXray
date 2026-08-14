import os
import tempfile
import unittest
from unittest.mock import patch

import yaml

from app.windows import WindowsBuilder


class WindowsPackagingTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)

        self.project_dir = os.path.join(self.temp_dir.name, "windows")
        os.makedirs(self.project_dir)
        self.exe_config_path = os.path.join(
            self.project_dir, "packaging", "exe", "make_config.yaml"
        )
        os.makedirs(os.path.dirname(self.exe_config_path))
        self.exe_config_content = b"display_name: OneXray\n"
        with open(self.exe_config_path, mode="wb") as f:
            f.write(self.exe_config_content)

        self.pubspec_path = os.path.join(self.temp_dir.name, "pubspec.yaml")
        self.original_content = (
            b"name: OneXray\n"
            b"description: Test fixture\n"
            b"version: 26.7.3+412\n"
        )
        with open(self.pubspec_path, mode="wb") as f:
            f.write(self.original_content)

        self.builder = WindowsBuilder.__new__(WindowsBuilder)
        self.builder.project = "OneXray"
        self.builder.project_dir = self.project_dir
        self.builder.output_dir = os.path.join(self.temp_dir.name, "output")
        self.builder.package_suffix = "windows-amd64"
        self.builder.target_architecture = "x64"
        os.makedirs(self.builder.output_dir)

    def test_exe_uses_marketing_version_and_restores_pubspec(self):
        calls = []

        def record_version(target):
            calls.append((target, self.builder.read_version()))

        self.builder.fastforge_build = record_version

        self.builder.build_app()

        self.assertEqual(
            calls,
            [
                ("zip", "26.7.3+412"),
                ("exe", "26.7.3"),
            ],
        )
        with open(self.pubspec_path, mode="rb") as f:
            self.assertEqual(f.read(), self.original_content)
        with open(self.exe_config_path, mode="rb") as f:
            self.assertEqual(f.read(), self.exe_config_content)

    def test_pubspec_is_restored_when_exe_packaging_fails(self):
        def fail_on_exe(target):
            if target == "exe":
                self.assertEqual(self.builder.read_version(), "26.7.3")
                raise RuntimeError("packaging failed")

        self.builder.fastforge_build = fail_on_exe

        with self.assertRaisesRegex(RuntimeError, "packaging failed"):
            self.builder.build_app()

        with open(self.pubspec_path, mode="rb") as f:
            self.assertEqual(f.read(), self.original_content)
        with open(self.exe_config_path, mode="rb") as f:
            self.assertEqual(f.read(), self.exe_config_content)

    def test_arm64_exe_uses_arm64_installer_and_restores_config(self):
        self.builder.target_architecture = "arm64"
        observed_config = {}

        def inspect_config(target):
            self.assertEqual(target, "exe")
            with open(self.exe_config_path, mode="r", encoding="utf-8") as f:
                observed_config.update(yaml.load(f, Loader=yaml.CLoader))

        self.builder.fastforge_build = inspect_config
        self.builder.package_exe()

        self.assertEqual(observed_config["architectures_allowed"], "arm64")
        self.assertEqual(
            observed_config["architectures_install_in_64bit_mode"], "arm64"
        )
        with open(self.exe_config_path, mode="rb") as f:
            self.assertEqual(f.read(), self.exe_config_content)

    def test_target_architecture_prefers_workflow_setting(self):
        with patch.dict(os.environ, {"ONEXRAY_WINDOWS_ARCH": "arm64"}):
            self.assertEqual(WindowsBuilder._target_architecture(), "arm64")

    def test_arm64_uses_arm64_wintun(self):
        self.builder.target_architecture = "arm64"
        self.assertEqual(self.builder._wintun_architecture(), "arm64")

    def test_installer_leaves_startup_shortcut_creation_to_the_app(self):
        template_path = os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "..",
                "..",
                "windows",
                "packaging",
                "exe",
                "inno_setup.iss",
            )
        )
        with open(template_path, mode="r", encoding="utf-8") as f:
            template = f.read()

        self.assertNotIn("launchAtStartup", template)
        self.assertNotIn("[UninstallDelete]", template)
        self.assertIn(
            "StartupShortcutTargetsCurrentInstall",
            template,
        )
        self.assertNotIn("CurrentVersion\\Run", template)
        self.assertNotIn("LegacyRun", template)
        self.assertNotIn("RegDeleteValue", template)


if __name__ == "__main__":
    unittest.main()
