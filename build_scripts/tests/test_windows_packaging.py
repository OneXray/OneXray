import os
import tempfile
import unittest

from app.windows import WindowsBuilder


class WindowsPackagingTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)

        self.project_dir = os.path.join(self.temp_dir.name, "windows")
        os.makedirs(self.project_dir)
        self.pubspec_path = os.path.join(self.temp_dir.name, "pubspec.yaml")
        self.original_content = (
            b"name: OneXray\n"
            b"description: Test fixture\n"
            b"version: 26.7.3+412\n"
        )
        with open(self.pubspec_path, mode="wb") as f:
            f.write(self.original_content)

        self.builder = WindowsBuilder.__new__(WindowsBuilder)
        self.builder.project_dir = self.project_dir

    def test_exe_uses_marketing_version_and_restores_pubspec(self):
        calls = []

        def record_version(target):
            calls.append((target, self.builder.read_version()))

        self.builder.fastforge_build = record_version

        self.builder.build_app()

        self.assertEqual(
            calls,
            [("zip", "26.7.3+412"), ("exe", "26.7.3")],
        )
        with open(self.pubspec_path, mode="rb") as f:
            self.assertEqual(f.read(), self.original_content)

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


if __name__ == "__main__":
    unittest.main()
