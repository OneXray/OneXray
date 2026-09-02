import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from app.provenance import begin_build, finish_build, source_revision, sha256, validate_lib_inputs, verify_release


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
        }.items():
            (self.metadata / f"{name}.txt").write_text(value)
        self.run = {
            "path": ".github/workflows/build.yml", "conclusion": "success",
            "id": 123, "run_attempt": 1, "head_sha": "a" * 40,
            "repository": {"full_name": "OneXray/OneXray"},
        }

    def receipt(self, architecture):
        suffix = "amd64" if architecture == "x64" else "arm64"
        package = self.artifacts / f"windows-store-{architecture}" / (
            f"OneXray-windows-{suffix}.msix")
        package.parent.mkdir()
        package.write_bytes(architecture.encode())
        receipt = {
            "formatVersion": 1, "target": "windows", "architecture": architecture,
            "runId": "123", "runAttempt": "1", "repository": "OneXray/OneXray",
            "sources": {"app": "a" * 40, "libXray": "b" * 40, "VCore": "c" * 40},
            "sourceDirty": {"app": False, "libXray": False, "VCore": False},
            "tools": {"python": {"version": "fixture"}},
            "fileSha256": {"pubspec.lock": "d" * 64},
            "packages": {package.name: sha256(package)},
            "libXrayInputs": {
                "schemaVersion": 1, "evidence": "build-inputs-only", "builder": "windows",
                "libXrayCommit": "b" * 40, "errors": [], "recordedAt": "fixture",
                "goVersion": "fixture", "modules": "fixture", "goModSha256": "a" * 64,
                "goSumSha256": "b" * 64,
            },
        }
        destination = self.artifacts / f"provenance-windows-{architecture}.json"
        destination.write_text(json.dumps(receipt))
        return destination, package

    def test_release_requires_exact_run_sources_tag_and_package_hashes(self):
        manifest, package = self.receipt("x64")
        self.receipt("arm64")
        verify_release(self.artifacts, self.run, windows_only=True)
        # Manual builds may publish only to a tag pointing to the exact built commit.
        verify_release(self.artifacts, self.run, tag="v26.9.1", tag_sha="a" * 40)
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

    def test_core_receipt_is_complete_and_identifies_the_builder_not_build_success(self):
        receipt = {
            "schemaVersion": 1, "evidence": "build-inputs-only", "builder": "apple-go",
            "libXrayCommit": "b" * 40, "errors": [], "recordedAt": "fixture",
            "goVersion": "go version fixture", "modules": "github.com/xtls/xray-core fixture",
            "goModSha256": "a" * 64, "goSumSha256": "b" * 64,
            "libXrayDirty": True,
        }
        self.assertEqual(validate_lib_inputs(json.dumps(receipt), "apple-go", "b" * 40), receipt)
        for key, value in (("builder", "android"), ("errors", ["go failed"]),
                           ("modules", None), ("libXrayCommit", "c" * 40)):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_lib_inputs(json.dumps({**receipt, key: value}), "apple-go", "b" * 40)

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
        lib_inputs = {
            "schemaVersion": 1, "evidence": "build-inputs-only", "builder": "linux",
            "libXrayCommit": "b" * 40, "errors": [], "recordedAt": "fixture",
            "goVersion": "fixture Go", "modules": "fixture Xray", "goModSha256": "a" * 64,
            "goSumSha256": "b" * 64,
        }
        builder = SimpleNamespace(
            root_dir=str(root), output_dir=str(output), workspace_dir=str(self.artifacts),
            project_dir=str(root / "linux"), system="linux", build_number=401,
            builder=SimpleNamespace(package_suffix="linux-x86_64",
                                    core_build_metadata=json.dumps(lib_inputs)),
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
        self.assertEqual(receipt["libXrayInputs"], lib_inputs)
        self.assertEqual(receipt["version"], "26.9.1+401")


if __name__ == "__main__":
    unittest.main()
