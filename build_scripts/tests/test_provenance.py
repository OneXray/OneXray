import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from app.provenance import begin_build, finish_build, source_revision, sha256, verify_release


class ProvenanceTest(unittest.TestCase):
    def setUp(self):
        fixtures = (Path(__file__).resolve().parents[3] / "references" /
                    "onexray-refactor-validation" / "build-provenance")
        fixtures.mkdir(parents=True, exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(dir=fixtures, prefix="receipt-")
        self.addCleanup(self.directory.cleanup)
        self.artifacts = Path(self.directory.name)
        self.metadata = self.artifacts / "release-metadata"
        self.metadata.mkdir()
        for name, value in {
            "sha": "a" * 40, "libxray-sha": "b" * 40, "vcore-sha": "c" * 40,
            "run-id": "123", "run-attempt": "1", "repository": "OneXray/OneXray",
            "target": "windows",
        }.items():
            (self.metadata / f"{name}.txt").write_text(value)
        self.run = {
            "path": ".github/workflows/build.yml", "conclusion": "success",
            "id": 123, "run_attempt": 1, "head_sha": "a" * 40,
            "repository": {"full_name": "OneXray/OneXray"},
        }

    def receipt(self, architecture, *, target="windows", paths=None):
        suffix = "amd64" if architecture == "x64" else "arm64"
        paths = paths or [f"windows-store-{architecture}/OneXray-windows-{suffix}.msix"]
        packages = [self.artifacts / path for path in paths]
        for package in packages:
            package.parent.mkdir(parents=True, exist_ok=True)
            package.write_bytes(package.name.encode())
        receipt = {
            "formatVersion": 1, "target": target, "architecture": architecture,
            "runId": "123", "runAttempt": "1", "repository": "OneXray/OneXray",
            "sources": {"app": "a" * 40, "libXray": "b" * 40, "VCore": "c" * 40},
            "sourceDirty": {"app": False, "libXray": False, "VCore": False},
            "tools": {"python": {"version": "fixture"}},
            "fileSha256": {"pubspec.lock": "d" * 64},
            "packages": {package.name: sha256(package) for package in packages},
        }
        destination = self.artifacts / f"provenance-{target}-{architecture}.json"
        destination.write_text(json.dumps(receipt))
        return destination, packages

    def public_receipts(self, build_target):
        (self.metadata / "target.txt").write_text(build_target)
        manifests, packages = [], []
        for target, architecture, paths in (
            ("ios", "arm64", ["ios/OneXray-ios.ipa"]),
            ("macos_se", "arm64", ["macos_se/OneXray-macos-universal.zip"]),
            ("android", "x86_64", ["android-universal/OneXray-android-universal.apk"]),
            ("linux", "x86_64", ["linux-x64/OneXray-linux-x86_64.zip",
                                 "linux-x64/OneXray-linux-x86_64.deb"]),
            ("linux", "aarch64", ["linux-arm64/OneXray-linux-aarch64.zip",
                                  "linux-arm64/OneXray-linux-aarch64.deb"]),
        ):
            if build_target not in {"all", "macos" if target == "macos_se" else target}:
                continue
            manifest, files = self.receipt(architecture, target=target, paths=paths)
            manifests.append(manifest)
            packages.extend(files)
        return manifests, packages

    def test_single_platform_builds_publish_only_their_complete_package_set(self):
        for target in ("ios", "macos", "android", "linux"):
            manifests, packages = self.public_receipts(target)
            try:
                with self.subTest(target=target):
                    self.assertEqual(verify_release(self.artifacts, self.run), packages)
                    # A single-platform run must not qualify as an all-platform build.
                    (self.metadata / "target.txt").write_text("all")
                    with self.assertRaises(ValueError):
                        verify_release(self.artifacts, self.run)
            finally:
                for path in manifests + packages:
                    path.unlink()

    def test_all_build_requires_every_public_package_and_target_receipt(self):
        manifests, packages = self.public_receipts("all")
        self.assertEqual(len(packages), 7)
        self.assertEqual(verify_release(self.artifacts, self.run), packages)
        for path in manifests + packages:
            original = path.read_bytes()
            path.unlink()
            try:
                with self.subTest(missing=path.name), self.assertRaises(ValueError):
                    verify_release(self.artifacts, self.run)
            finally:
                path.write_bytes(original)

    def test_linux_build_requires_both_architectures_and_both_formats(self):
        manifests, packages = self.public_receipts("linux")
        for path in (manifests[1], *packages):
            original = path.read_bytes()
            path.unlink()
            try:
                with self.subTest(missing=path.name), self.assertRaises(ValueError):
                    verify_release(self.artifacts, self.run)
            finally:
                path.write_bytes(original)

        # Another target cannot vouch for a missing entry in the Linux receipt.
        data = json.loads(manifests[0].read_text())
        misplaced = {packages[1].name: data["packages"].pop(packages[1].name)}
        manifests[0].write_text(json.dumps(data))
        other, _ = self.receipt("arm64", target="ios", paths=["ios/OneXray-ios.ipa"])
        data = json.loads(other.read_text())
        data["packages"].update(misplaced)
        other.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "missing from target provenance"):
            verify_release(self.artifacts, self.run)

    def test_github_release_excludes_store_outputs(self):
        manifests, packages = self.public_receipts("all")
        # Build uploads the MAS receipt but not its already-published PKG.
        _, (pkg,) = self.receipt("arm64", target="macos", paths=["macos/OneXray.pkg"])
        pkg.unlink()
        # The Android receipt also records the AAB, which is not downloaded.
        android = next(path for path in manifests if "android" in path.name)
        data = json.loads(android.read_text())
        data["packages"]["app-release.aab"] = "e" * 64
        android.write_text(json.dumps(data))
        self.receipt("x64")
        self.receipt("arm64")
        self.assertEqual(verify_release(self.artifacts, self.run), packages)

    def test_cli_emits_only_verified_files_and_nothing_on_failure(self):
        _, packages = self.public_receipts("ios")
        run_json = self.artifacts / "build-run.json"
        run_json.write_text(json.dumps(self.run))
        command = [sys.executable, str(Path(__file__).resolve().parents[1] / "verify_release.py"),
                   str(self.artifacts), str(run_json), "--tag", "v26.9.1", "--tag-sha", "a" * 40]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [str(path) for path in packages])
        (self.metadata / "target.txt").write_text("all")
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_release_requires_exact_run_sources_tag_and_package_hashes(self):
        manifest, (package,) = self.receipt("x64")
        self.receipt("arm64")
        for target in ("windows", "all"):
            (self.metadata / "target.txt").write_text(target)
            self.assertEqual(len(verify_release(self.artifacts, self.run, windows_only=True)), 2)
        # Manual builds may publish only to a tag pointing to the exact built commit.
        verify_release(self.artifacts, self.run, tag="v26.9.1", tag_sha="a" * 40, windows_only=True)
        with self.assertRaises(ValueError):
            verify_release(self.artifacts, self.run, tag="v26.9.1", tag_sha="d" * 40)
        for field, value in (("path", "other.yml"), ("conclusion", "failure"),
                             ("head_sha", "d" * 40), ("run_attempt", 2)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                verify_release(self.artifacts, {**self.run, field: value})
        original = package.read_bytes()
        package.write_bytes(b"changed package")
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            verify_release(self.artifacts, self.run)
        package.write_bytes(original)
        data = json.loads(manifest.read_text())
        data["sources"]["libXray"] = "d" * 40
        manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "Invalid build provenance"):
            verify_release(self.artifacts, self.run)

    def test_dirty_or_unrecorded_sources_are_not_publishable(self):
        manifest, _ = self.receipt("x64")
        original = json.loads(manifest.read_text())
        for source in ("app", "libXray", "VCore"):
            for value in (True, None):
                receipt = {**original, "sourceDirty": {**original["sourceDirty"], source: value}}
                manifest.write_text(json.dumps(receipt))
                with self.subTest(source=source, value=value), self.assertRaisesRegex(ValueError, "clean"):
                    verify_release(self.artifacts, self.run)
        manifest.write_text(json.dumps({**original, "sourceDirty": {}}))
        with self.assertRaisesRegex(ValueError, "clean"):
            verify_release(self.artifacts, self.run)

    def test_missing_metadata_or_branch_in_sha_field_is_not_publishable(self):
        self.receipt("x64")
        with self.assertRaisesRegex(ValueError, "Both Windows"):
            verify_release(self.artifacts, self.run, windows_only=True)
        (self.metadata / "libxray-sha.txt").write_text("main")
        with self.assertRaisesRegex(ValueError, "full commit SHAs"):
            verify_release(self.artifacts, self.run)
        (self.metadata / "libxray-sha.txt").unlink()
        with self.assertRaises(FileNotFoundError):
            verify_release(self.artifacts, self.run)

    def test_checked_out_revision_must_match_the_single_workflow_resolution(self):
        with mock.patch("app.provenance._output", return_value="a" * 40):
            self.assertEqual(source_revision(Path("fixture"), "a" * 40), "a" * 40)
            with self.assertRaises(ValueError):
                source_revision(Path("fixture"), "b" * 40)
        builder = SimpleNamespace(
            root_dir=str(self.artifacts / "OneXray"), workspace_dir=str(self.artifacts),
            project_config={"core.dir": "libXray"}, builder=SimpleNamespace(),
            read_version=lambda: "26.9.1+1",
        )
        for app_status in ("", " M local-source.dart\n?? new-source.dart"):
            with (
                self.subTest(dirty=bool(app_status)),
                mock.patch("app.provenance.source_revision", return_value="a" * 40),
                mock.patch("app.provenance._output", side_effect=[app_status, ""]),
            ):
                receipt = begin_build(builder, "linux")
            self.assertEqual(receipt["sourceDirty"], {"app": bool(app_status), "libXray": False})
            self.assertNotIn("local-source.dart", json.dumps(receipt))
            self.assertNotIn("new-source.dart", json.dumps(receipt))

    def test_all_jobs_use_resolved_sha_and_publishers_require_receipts(self):
        workflows = Path(__file__).resolve().parents[2] / ".github/workflows"
        build = (workflows / "build.yml").read_text()
        self.assertEqual(build.count("needs: release_metadata"), 6)
        self.assertEqual(build.count("ref: ${{ env.LIBXRAY_REF }}"), 1)
        self.assertEqual(build.count("ref: ${{ needs.release_metadata.outputs.libxray_sha }}"), 6)
        self.assertEqual(build.count("name: Upload build provenance"), 6)
        for name in ("publish.yml", "publish-microsoft-store.yml"):
            content = (workflows / name).read_text()
            self.assertIn("build_scripts/verify_release.py", content)
            self.assertNotIn("assuming manual rebuild artifacts", content)
        publish = (workflows / "publish.yml").read_text()
        self.assertIn('> release-files.txt', publish)
        self.assertIn('done < release-files.txt', publish)
        self.assertIn('files: ${{ steps.verify.outputs.files }}', publish)
        self.assertIn('fail_on_unmatched_files: true', publish)
        self.assertLess(publish.index('build_scripts/verify_release.py'),
                        publish.index('name: Delete matching existing release assets'))

    def test_receipt_records_actual_files_and_keeps_other_platform_packages_out(self):
        root = self.artifacts / "OneXray"
        output = self.artifacts / "output"
        output.mkdir()
        library = root / "linux/app/libXray.so"
        library.parent.mkdir(parents=True)
        library.write_bytes(b"fixture lib")
        regions = root / "assets/geodata/regions.json"
        regions.parent.mkdir(parents=True)
        regions.write_text('{}')
        (root / "pubspec.lock").write_text("fixture lock")
        package = output / "OneXray-linux-x86_64.zip"
        package.write_bytes(b"fixture package")
        (output / "OneXray-windows-amd64.msix").write_bytes(b"other target")
        builder = SimpleNamespace(
            root_dir=str(root), output_dir=str(output), workspace_dir=str(self.artifacts),
            project_dir=str(root / "linux"), system="linux", build_number=401,
            builder=SimpleNamespace(package_suffix="linux-x86_64"),
            project_config={"core.lib.dst.dir.linux": "app",
                            "core.lib.src.files.linux": ["linux_so/libXray.so"]},
            read_version=lambda: "26.9.1+401",
        )
        with mock.patch("app.provenance._tool", return_value={"version": "fixture"}):
            destination = finish_build(builder, {
                "target": "linux", "architecture": "x86_64",
                "sources": {"libXray": "b" * 40},
            })
        receipt = json.loads(destination.read_text())
        self.assertEqual(receipt["packages"], {package.name: sha256(package)})
        self.assertEqual(receipt["fileSha256"]["OneXray/assets/geodata/regions.json"], sha256(regions))
        self.assertEqual(receipt["fileSha256"]["OneXray/linux/app/libXray.so"], sha256(library))
        self.assertEqual(receipt["version"], "26.9.1+401")


if __name__ == "__main__":
    unittest.main()
