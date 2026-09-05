import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from app.builder import Builder
from app.command_line import download_file, run_command


class BuilderTest(unittest.TestCase):
    def setUp(self):
        fixtures = (Path(__file__).resolve().parents[3] / "references" /
                    "onexray-refactor-validation" / "build-scripts")
        fixtures.mkdir(parents=True, exist_ok=True)
        self.temp_dir = tempfile.TemporaryDirectory(dir=fixtures, prefix="builder-")
        self.addCleanup(self.temp_dir.cleanup)
        self.root_dir = Path(self.temp_dir.name)
        self.builder = Builder.__new__(Builder)
        self.builder.root_dir = str(self.root_dir)

    def test_version_update_preserves_pubspec(self):
        pubspec = self.root_dir / "pubspec.yaml"
        pubspec.write_bytes(
            b'name: onexray\r\nversion: "26.8.5+1" # build\r\ndependencies:\r\n'
        )

        self.assertEqual(self.builder.read_version(), "26.8.5+1")
        self.builder.write_version("26.8.5+401")

        self.assertEqual(
            pubspec.read_bytes(),
            b'name: onexray\r\nversion: "26.8.5+401" # build\r\n'
            b"dependencies:\r\n",
        )

    def test_core_binary_is_copied_from_libxray(self):
        workspace = self.root_dir / "workspace"
        source = workspace / "libXray" / "bin" / "xray.exe"
        source.parent.mkdir(parents=True)
        source.write_bytes(b"libXray Core")

        self.builder.workspace_dir = str(workspace)
        self.builder.project_dir = str(workspace / "OneXray" / "windows")
        self.builder.system = "windows"
        self.builder.project_config = {
            "core.dir": "libXray",
            "core.bin.src.file.windows": "bin/xray.exe",
            "core.bin.dst.file.windows": "app/OneXrayCore.exe",
        }

        self.builder.build_core_binary()

        destination = workspace / "OneXray" / "windows" / "app" / "OneXrayCore.exe"
        self.assertEqual(destination.read_bytes(), b"libXray Core")

    def test_core_build_copies_artifacts_without_metadata(self):
        for system, command in (
            ("linux", [sys.executable, "build/main.py", "linux"]),
            ("macos", [sys.executable, "build/main.py", "apple", "go"]),
        ):
            with self.subTest(system=system):
                workspace = self.root_dir / system
                lib_dir = workspace / "libXray"
                library_name = "LibXray.xcframework" if system == "macos" else "libXray.so"
                library_file = f"{library_name}/libXray.a" if system == "macos" else library_name
                library = lib_dir / library_file
                library.parent.mkdir(parents=True)
                library.write_bytes(b"fixture library")
                geodata = lib_dir / "dat" / "geoip.dat"
                geodata.parent.mkdir()
                geodata.write_bytes(b"fixture geodata")
                self.builder.workspace_dir = str(workspace)
                self.builder.system = system
                self.builder.project_dir = str(workspace / "OneXray" / system)
                self.builder.project_config = {
                    "core.dir": "libXray",
                    f"core.lib.dst.dir.{system}": "app",
                    f"core.lib.src.files.{system}": [library_name],
                    "core.dat.dst.dir": "assets/dat",
                }
                with mock.patch("app.builder.run_command") as run:
                    self.builder.build_core()

                run.assert_called_once_with(command, cwd=str(lib_dir))
                destination = Path(self.builder.project_dir)
                self.assertEqual((destination / "app" / library_file).read_bytes(), b"fixture library")
                self.assertEqual((destination / "assets/dat/geoip.dat").read_bytes(), b"fixture geodata")
                self.assertFalse((lib_dir / "build").exists())

    def test_core_build_failure_propagates_before_copying_artifacts(self):
        self.builder.workspace_dir = str(self.root_dir)
        self.builder.system = "linux"
        self.builder.project_config = {"core.dir": "libXray"}
        failure = subprocess.CalledProcessError(1, ["core-build"])
        with (
            mock.patch("app.builder.run_command", side_effect=failure),
            mock.patch("app.builder.check_and_create_dir") as prepare_destination,
            self.assertRaises(subprocess.CalledProcessError) as raised,
        ):
            self.builder.build_core()
        self.assertIs(raised.exception, failure)
        prepare_destination.assert_not_called()

    def test_download_file_uses_standard_url_handler(self):
        source = self.root_dir / "source.bin"
        destination = self.root_dir / "destination.bin"
        source.write_bytes(b"OneXray")

        download_file(source.as_uri(), str(destination))

        self.assertEqual(destination.read_bytes(), b"OneXray")

    def test_run_command_applies_working_directory_and_environment(self):
        result = self.root_dir / "result.txt"
        run_command(
            [
                sys.executable,
                "-c",
                "import os; from pathlib import Path; "
                "Path(os.environ['RESULT']).write_text(os.getcwd())",
            ],
            cwd=str(self.root_dir),
            env={"RESULT": str(result)},
        )

        self.assertEqual(Path(result.read_text()).resolve(), self.root_dir.resolve())


if __name__ == "__main__":
    unittest.main()
