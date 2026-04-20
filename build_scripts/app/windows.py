import os
import shutil

import yaml

from app.builder import Builder
from app.command_line import (
    check_and_create_dir,
    download_file,
    run_command,
    dart_command,
)


class WindowsBuilder(Builder):
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

        self.download_win_tun()

    def download_win_tun(self):
        app_path = os.path.join(
            self.project_dir, self.project_config["core.lib.dst.dir.windows"]
        )
        check_and_create_dir(app_path)

        zip_path = os.path.join(self.output_dir, "wintun.zip")
        win_tun_url = "https://www.wintun.net/builds/wintun-0.14.1.zip"
        download_file(win_tun_url, zip_path)
        shutil.unpack_archive(zip_path, self.output_dir)

        win_tun_src_path = os.path.join(
            self.output_dir, "wintun", "bin", "amd64", "wintun.dll"
        )
        shutil.move(win_tun_src_path, app_path)

    def build_app(self):
        self.fastforge_build("zip")
        self.fastforge_build("exe")
