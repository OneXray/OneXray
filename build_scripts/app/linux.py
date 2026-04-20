import os

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
        self.fastforge_build("deb")
