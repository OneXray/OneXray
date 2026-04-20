import os

from app.builder import Builder
from app.command_line import run_command


class AndroidBuilder(Builder):
    def __init__(self, project: str, system: str, build_scripts_dir: str):
        super().__init__(project, system, build_scripts_dir)
        self.package_suffix = "android-universal"

    def before_build(self):
        super().before_build()
        self.build_core()
        self.fix_fastlane_version_code()

    def fix_fastlane_version_code(self):
        file_path = os.path.join(self.project_dir, "fastlane", "Fastfile")
        with open(file_path, mode="r") as f:
            text = f.read()
            text = text.replace("##version_code##", f"{self.build_number}")

        with open(file_path, mode="w") as f:
            f.write(text)

    def build(self):
        self.before_build()

        self.build_app()

        self.after_build()

    def build_app(self):
        os.chdir(self.project_dir)
        run_command(["fastlane", self.fastlane, "--verbose"])
