import hashlib
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest import mock
import zipfile

from build_cli import TARGETS, app_version, build


class CLIBuildTest(unittest.TestCase):
    def setUp(self):
        fixtures = Path(__file__).resolve().parents[3] / "references" / "cli-build-tests"
        fixtures.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=fixtures)
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "OneXray"
        (self.root / "cli").mkdir(parents=True)
        (self.root / "pubspec.yaml").write_text("name: onexray\nversion: 26.9.5+1\n")
        (self.root / "LICENSE").write_text("App license\n")
        (self.root / "cli" / "README.md").write_text("CLI help\n")
        (self.root / "cli" / "THIRD_PARTY_NOTICES.md").write_text("Dependency licenses\n")

    def test_version_and_all_six_targets(self):
        self.assertEqual(app_version(self.root), "26.9.5")
        self.assertEqual(set(TARGETS), {f"{system}-{arch}" for system in
                                      ("darwin", "linux", "windows") for arch in ("amd64", "arm64")})

    def test_packaging_uses_pure_go_and_preserves_sources(self):
        calls = []

        def fake_go(command, *, cwd, env, check):
            calls.append((command, cwd, env, check))
            executable = Path(command[command.index("-o") + 1])
            executable.write_bytes(b"mock executable")
            executable.chmod(0o755)

        before = (self.root / "pubspec.yaml").read_bytes()
        with mock.patch("build_cli.subprocess.run", side_effect=fake_go):
            products = build(self.root, self.root.parent / "output", list(TARGETS))
        self.assertEqual(len(products), 7)
        self.assertEqual((self.root / "pubspec.yaml").read_bytes(), before)
        for command, cwd, environment, check in calls:
            self.assertEqual(command[1], "build")
            self.assertEqual(environment["CGO_ENABLED"], "0")
            self.assertIn(f"{environment['GOOS']}-{environment['GOARCH']}", TARGETS)
            self.assertEqual(cwd, self.root / "cli")
            self.assertIn("-s -w -X main.version=26.9.5", command)
            self.assertTrue(check)
        for product in products[:-1]:
            if product.suffix == ".zip":
                with zipfile.ZipFile(product) as archive:
                    self.assertEqual(set(archive.namelist()), {"onexray-cli.exe", "README.md", "LICENSE", "THIRD_PARTY_NOTICES.md"})
            else:
                with tarfile.open(product) as archive:
                    self.assertEqual(set(archive.getnames()), {"onexray-cli", "README.md", "LICENSE", "THIRD_PARTY_NOTICES.md"})
                    self.assertTrue(archive.getmember("onexray-cli").mode & 0o111)
            self.assertIn(hashlib.sha256(product.read_bytes()).hexdigest(), products[-1].read_text())

    def test_invalid_target_fails_before_build_or_output(self):
        destination = self.root.parent / "output"
        with self.assertRaises(ValueError), mock.patch("build_cli.subprocess.run") as run:
            build(self.root, destination, ["windows-x86"])
        self.assertFalse(destination.exists())
        run.assert_not_called()

    def test_cli_workflow_is_separate_from_store_release(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / ".github" / "workflows" / "cli.yml").read_text()
        for target in TARGETS:
            self.assertIn(target, workflow)
        self.assertIn("build_scripts/build_cli.py", workflow)
        self.assertIn("actions/upload-artifact", workflow)
        self.assertNotIn("contents: write", workflow)
        self.assertNotIn("gh release", workflow)
        self.assertNotIn("flutter", workflow)


if __name__ == "__main__":
    unittest.main()
