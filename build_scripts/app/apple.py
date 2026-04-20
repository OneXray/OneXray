import os

from app.builder import Builder
from app.command_line import run_command


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

        self.write_ios_admob_xcconfig()

    def update_build_number(self):
        os.chdir(self.project_dir)
        run_command(["xcrun", "agvtool", "new-version", "-all", str(self.build_number)])

    def update_pod(self):
        run_command(["pod", "repo", "update"])

    # Info.plist references $(ADMOB_APP_ID_IOS); Debug/Release.xcconfig set a
    # test-ad default and #include? "AdMob.xcconfig" so this file can override
    # without being tracked. Only written when the env var is set — otherwise
    # the build falls back to Google's public test App ID.
    def write_ios_admob_xcconfig(self):
        if self.system != "ios":
            return
        value = os.environ.get("ADMOB_APP_ID_IOS")
        if not value:
            return
        path = os.path.join(self.project_dir, "Flutter", "AdMob.xcconfig")
        with open(path, "w") as f:
            f.write(f"ADMOB_APP_ID_IOS = {value}\n")

    def build_app(self):
        os.chdir(self.project_dir)
        run_command(["fastlane", self.fastlane, "--verbose"])
