import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationWillFinishLaunching(_ notification: Notification) {
        initApp()
        super.applicationWillFinishLaunching(notification)
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        restoreMainWindow()
        return true
    }

    @IBAction func showMainWindow(_ sender: Any?) {
        restoreMainWindow()
    }

    private func restoreMainWindow() {
        guard let window = mainFlutterWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0 is MainFlutterWindow }) else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(self)
        }
        window.makeKeyAndOrderFront(self)
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

}
