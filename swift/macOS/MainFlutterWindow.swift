import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        let engine = flutterViewController.engine
        let flutterApi = AppFlutterApi(binaryMessenger: engine.binaryMessenger)
        BridgeHostApiSetup.setUp(binaryMessenger: engine.binaryMessenger, api: AppHostApi(flutterApi: flutterApi))

        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()
    }
}
