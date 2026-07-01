import os

from app.builder import Builder
from app.command_line import run_command

FIREBASE_ANALYTICS_WITHOUT_ADID = "FIREBASE_ANALYTICS_WITHOUT_ADID"


class AppleBuilder(Builder):
    def __init__(self, project: str, system: str, build_scripts_dir: str):
        super().__init__(project, system, build_scripts_dir)
        self.package_suffix = "ios"

    def build(self):
        self.before_build()

        self.build_app()

        self.after_build()

    def before_build(self):
        super().before_build()

        self.build_core()

        self.update_build_number()

        self.update_pod()

    def update_build_number(self):
        os.chdir(self.project_dir)
        run_command(["xcrun", "agvtool", "new-version", "-all", str(self.build_number)])

    def update_pod(self):
        run_command(["pod", "repo", "update"])

    def build_app(self):
        os.chdir(self.project_dir)
        os.environ[FIREBASE_ANALYTICS_WITHOUT_ADID] = "true"
        run_command(["fastlane", self.fastlane, "--verbose"])
