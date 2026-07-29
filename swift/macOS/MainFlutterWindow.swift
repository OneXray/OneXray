import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        MainActor.assumeIsolated {
            let flutterViewController = FlutterViewController()
            let windowFrame = frame
            contentViewController = flutterViewController
            setFrame(windowFrame, display: true)

            let binaryMessenger = flutterViewController.engine.binaryMessenger
            let flutterApi = AppFlutterApi(binaryMessenger: binaryMessenger)
            BridgeHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: AppHostApi(flutterApi: flutterApi))

            RegisterGeneratedPlugins(registry: flutterViewController)

            super.awakeFromNib()
            DockIconService.restoreIcon()
        }
    }

    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}
