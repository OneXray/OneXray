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
        if !flag {
            restoreMainWindow()
        }
        return true
    }

    @IBAction func showMainWindow(_ sender: Any?) {
        restoreMainWindow()
    }

    private func restoreMainWindow() {
        for window in NSApp.windows {
            if !window.isVisible {
                window.setIsVisible(true)
            }
            if window.isMiniaturized {
                window.deminiaturize(self)
            }
            window.makeKeyAndOrderFront(self)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

}
