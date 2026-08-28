import os

from app.builder import Builder
from app.command_line import run_command


class AndroidBuilder(Builder):
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

    def build_app(self):
        run_command(["fastlane", self.fastlane, "--verbose"], cwd=self.project_dir)
