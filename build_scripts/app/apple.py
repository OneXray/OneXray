from app.builder import Builder
from app.command_line import run_command


class AppleBuilder(Builder):
    def before_build(self):
        super().before_build()
        self.build_core()
        self.update_build_number()
        self.update_pod()

    def update_build_number(self):
        run_command(
            ["xcrun", "agvtool", "new-version", "-all", str(self.build_number)],
            cwd=self.project_dir,
        )

    def update_pod(self):
        run_command(["pod", "repo", "update"], cwd=self.project_dir)

    def build_app(self):
        run_command(["fastlane", self.fastlane, "--verbose"], cwd=self.project_dir)
