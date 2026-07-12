import os
import re
from pathlib import Path

from app.builder import Builder


class LinuxBuilder(Builder):
    def __init__(
        self,
        project: str,
        system: str,
        build_scripts_dir: str,
    ):
        super().__init__(project, system, build_scripts_dir)
        self.version = ""

    def build(self):
        self.before_build()

        self.build_app()

        self.after_build()

    def before_build(self):
        super().before_build()
        self.build_core()

    def build_app(self):
        self.fastforge_build("zip")
        self._build_deb()

    def _build_deb(self):
        config_path = Path(self.project_dir) / "packaging" / "deb" / "make_config.yaml"
        original_config = config_path.read_text(encoding="utf-8")
        installed_size = self._installed_size_kib()
        updated_config, replacements = re.subn(
            r"(?m)^installed_size:\s*\d+\s*$",
            f"installed_size: {installed_size}",
            original_config,
            count=1,
        )
        if replacements != 1:
            raise Exception("Linux package installed_size is missing")

        config_path.write_text(updated_config, encoding="utf-8")
        try:
            self.fastforge_build("deb")
        finally:
            config_path.write_text(original_config, encoding="utf-8")

    def _installed_size_kib(self) -> int:
        build_root = Path(self.project_dir).parent / "build" / "linux"
        bundles = list(build_root.glob("*/release/bundle"))
        if not bundles:
            raise Exception("Linux release bundle is missing")
        bundle = max(bundles, key=lambda path: path.stat().st_mtime_ns)
        total_bytes = sum(
            path.stat().st_size for path in bundle.rglob("*") if path.is_file()
        )
        return max(1, (total_bytes + 1023) // 1024)

    def after_build(self):
        super().after_build()

        for file_type in (".zip", ".deb"):
            file_name = self.find_file(file_type)
            if file_name:
                self.rename_file(file_name, file_type)
