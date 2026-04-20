import app_links
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
            for window in NSApp.windows {
                if !window.isVisible {
                    window.setIsVisible(true)
                }
                window.orderFront(self)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        return true
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    override func application(_ application: NSApplication,
                              continue userActivity: NSUserActivity,
                              restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool
    {
        guard let url = AppLinks.shared.getUniversalLink(userActivity) else {
            return false
        }

        AppLinks.shared.handleLink(link: url.absoluteString)

        return false // Returning true will stop the propagation to other packages
    }
}
