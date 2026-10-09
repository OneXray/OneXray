import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from verify_release import verify_release

PUBLIC_PACKAGES = {
    "ios": ["ios/OneXray-ios.ipa"],
    "macos": ["macos_se/OneXray-macos-universal.zip"],
    "android": ["android-universal/OneXray-android-universal.apk"],
    "linux": [
        "linux-x64/OneXray-linux-x86_64.zip",
        "linux-x64/OneXray-linux-x86_64.deb",
        "linux-arm64/OneXray-linux-aarch64.zip",
        "linux-arm64/OneXray-linux-aarch64.deb",
    ],
    "windows": [
        "windows-x64/OneXray-windows-amd64.exe",
        "windows-x64/OneXray-windows-amd64.zip",
        "windows-arm64/OneXray-windows-arm64.exe",
        "windows-arm64/OneXray-windows-arm64.zip",
    ],
}
STORE_PACKAGES = [
    "windows-store-x64/OneXray-windows-amd64.msix",
    "windows-store-arm64/OneXray-windows-arm64.msix",
]


class ReleaseTest(unittest.TestCase):
    def setUp(self):
        fixtures = Path(__file__).resolve().parents[3] / "references/onexray-tests/release-files"
        fixtures.mkdir(parents=True, exist_ok=True)
        directory = tempfile.TemporaryDirectory(dir=fixtures)
        self.addCleanup(directory.cleanup)
        self.artifacts = Path(directory.name)
        self.metadata = self.artifacts / "release-metadata"
        self.metadata.mkdir()
        for name, value in {
            "sha": "a" * 40,
            "run-id": "123",
            "run-attempt": "1",
            "repository": "YuanDevTeam/OneXray",
            "target": "all",
        }.items():
            (self.metadata / f"{name}.txt").write_text(value)
        self.run = {
            "path": ".github/workflows/build.yml",
            "conclusion": "success",
            "id": 123,
            "run_attempt": 1,
            "head_sha": "a" * 40,
            "repository": {"full_name": "YuanDevTeam/OneXray"},
        }
        for name in [name for group in PUBLIC_PACKAGES.values() for name in group] + STORE_PACKAGES:
            path = self.artifacts / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"package fixture")

    def test_selects_only_the_requested_channel_and_platform(self):
        all_public = [name for group in PUBLIC_PACKAGES.values() for name in group]
        for target, names in {**PUBLIC_PACKAGES, "all": all_public}.items():
            with self.subTest(target=target):
                (self.metadata / "target.txt").write_text(target)
                self.assertEqual(
                    verify_release(self.artifacts, self.run),
                    [self.artifacts / name for name in names],
                )
        for target in ("all", "windows"):
            (self.metadata / "target.txt").write_text(target)
            self.assertEqual(
                verify_release(self.artifacts, self.run, windows_only=True),
                [self.artifacts / name for name in STORE_PACKAGES],
            )
        (self.metadata / "target.txt").write_text("ios")
        with self.assertRaises(ValueError):
            verify_release(self.artifacts, self.run, windows_only=True)

    def test_missing_required_package_stops_release_selection(self):
        for name, windows_only in (
            (PUBLIC_PACKAGES["linux"][-1], False),
            (STORE_PACKAGES[1], True),
        ):
            path = self.artifacts / name
            path.unlink()
            with self.subTest(package=name), self.assertRaises(FileNotFoundError):
                verify_release(self.artifacts, self.run, windows_only=windows_only)
            path.write_bytes(b"package fixture")

    def test_requires_the_selected_successful_build_run(self):
        for field, value in (
            ("path", ".github/workflows/other.yml"),
            ("conclusion", "failure"),
            ("id", 456),
            ("run_attempt", 2),
            ("head_sha", "b" * 40),
            ("repository", {"full_name": "Other/Repository"}),
        ):
            with self.subTest(field=field), self.assertRaises(ValueError):
                verify_release(self.artifacts, {**self.run, field: value})

    def test_release_tag_must_match_the_built_commit_and_recorded_tag(self):
        verify_release(self.artifacts, self.run, tag="v26.9.1", tag_sha="a" * 40)
        for tag, revision in (("26.9.1", "a" * 40), ("v26.9.1", "b" * 40)):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                verify_release(self.artifacts, self.run, tag=tag, tag_sha=revision)
        (self.metadata / "tag.txt").write_text("v26.9.2")
        with self.assertRaises(ValueError):
            verify_release(self.artifacts, self.run, tag="v26.9.1", tag_sha="a" * 40)

    def test_cli_emits_the_complete_list_or_nothing_on_failure(self):
        (self.metadata / "target.txt").write_text("ios")
        run_json = self.artifacts / "build-run.json"
        run_json.write_text(json.dumps(self.run))
        command = [
            sys.executable,
            str(Path(__file__).resolve().parents[1] / "verify_release.py"),
            str(self.artifacts),
            str(run_json),
        ]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(), [str(self.artifacts / PUBLIC_PACKAGES["ios"][0])]
        )
        (self.artifacts / PUBLIC_PACKAGES["ios"][0]).unlink()
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
