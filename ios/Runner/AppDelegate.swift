import app_links
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        let binaryMessenger = engineBridge.applicationRegistrar.messenger()
        let flutterApi = AppFlutterApi(binaryMessenger: binaryMessenger)
        BridgeHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: AppHostApi(flutterApi: flutterApi))
        
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        
        // https://github.com/llfbandit/app_links/blob/master/doc/README_ios_7.md
        AppLinks.shared.defaultUrlHandling = .availability
    }
}
