import AppKit

@MainActor
enum DockIconService {
    private static let defaultsKey = "dockIconName"
    private static let assetNames = [
        "IconBlack": "black",
        "IconGreen": "green",
        "IconOrange": "orange",
        "IconPurple": "purple",
        "IconRed": "red",
    ]

    static var currentIconName: String {
        guard let iconName = UserDefaults.standard.string(forKey: defaultsKey),
              assetNames[iconName] != nil else {
            return ""
        }
        return iconName
    }

    static func setIcon(_ iconName: String) -> Bool {
        if iconName.isEmpty || iconName == "IconBlue" {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            NSApplication.shared.applicationIconImage = nil
            return true
        }

        guard let image = loadImage(for: iconName) else {
            return false
        }

        UserDefaults.standard.set(iconName, forKey: defaultsKey)
        NSApplication.shared.applicationIconImage = image
        return true
    }

    static func restoreIcon() {
        let iconName = currentIconName
        guard !iconName.isEmpty else {
            return
        }
        if !setIcon(iconName) {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            NSApplication.shared.applicationIconImage = nil
        }
    }

    private static func loadImage(for iconName: String) -> NSImage? {
        guard let assetName = assetNames[iconName],
              let frameworksURL = Bundle.main.privateFrameworksURL,
              let appBundle = Bundle(
                url: frameworksURL.appendingPathComponent("App.framework")
              ),
              let imageURL = appBundle.url(
                forResource: assetName,
                withExtension: "png",
                subdirectory: "flutter_assets/assets/macos_icon"
              ) else {
            return nil
        }
        return NSImage(contentsOf: imageURL)
    }
}
