# Debug Environment Setup

This guide is for OneXray developers. It describes the minimum setup for the **local debug environment** and does not cover release, store submission, signing, or fastlane publishing.

## 1. Initialize the project

After cloning the repository, prepare the local config files needed for debugging:

```shell
cp .env.example .env
cp firebase.json.example firebase.json
cp lib/firebase_options.dart.example lib/firebase_options.dart
cp android/app/google-services.json.example android/app/google-services.json
cp swift/AppStore/GoogleService-Info.plist.example swift/AppStore/GoogleService-Info.plist
cp swift/macOSSE/GoogleService-Info.plist.example swift/macOSSE/GoogleService-Info.plist
flutter pub get
```

The `.example` files are enough for local development. Replace them with your own config later if you need to test real Firebase or AdMob behavior.

## 2. Prepare libXray artifacts

Local OneXray debugging depends on artifacts built from the sibling `libXray` repository. The main outputs from `libXray/build` are:

- Apple: `LibXray.xcframework`
- Android: `libXray.aar`, `libXray-sources.jar`
- Linux: `linux_so/libXray.so`, `bin/xray`
- Windows: `windows_dll/libXray.dll`, `bin/xray.exe`

Build the required targets in `libXray` first:

```shell
cd ../libXray
python3 build/main.py apple go
python3 build/main.py android
python3 build/main.py linux
python3 build/main.py windows
```

Then copy the artifacts into the corresponding OneXray directories.

### iOS / macOS

Apple platforms share `LibXray.xcframework`. Copy it into `swift/All/`:

```shell
cp -R ../libXray/LibXray.xcframework swift/All/
```

`swift/All/` already contains Swift integration files such as `BridgeHeader.h`; in practice you mainly update `LibXray.xcframework` here.

### Android

Android uses the `aar` and the sources jar. Copy them into `android/app/libs/`:

```shell
mkdir -p android/app/libs
cp ../libXray/libXray.aar android/app/libs/
cp ../libXray/libXray-sources.jar android/app/libs/
```

### Linux

`linux/app.cmake` links `libXray.so` from `linux/app/` and installs `OneXrayCore` into the final bundle. Copy the Linux artifacts into `linux/app/`, and rename `bin/xray` to match OneXray's expected name:

```shell
mkdir -p linux/app
cp ../libXray/linux_so/libXray.so linux/app/
cp ../libXray/bin/xray linux/app/OneXrayCore
```

### Windows

`windows/app.cmake` installs `libXray.dll` and `OneXrayCore.exe` from `windows/app/`. Copy the Windows artifacts into `windows/app/`, and rename `bin/xray.exe` to match OneXray's expected name:

```shell
mkdir -p windows/app
cp ../libXray/windows_dll/libXray.dll windows/app/
cp ../libXray/bin/xray.exe windows/app/OneXrayCore.exe
```

> `windows/app.cmake` also packages `wintun.dll`. That file does not come from `libXray` and must be prepared separately in the Windows development environment.

## 3. Start debugging

Run the target platform with:

```shell
flutter run -d android
flutter run -d macos
```

Before debugging iOS, install CocoaPods dependencies:

```shell
cd ios
pod install
cd ..
flutter run -d ios
```

## 4. `.env` notes

For local debugging, `.env` can usually stay empty:

- If `ADMOB_APP_ID_ANDROID` or `ADMOB_APP_ID_IOS` is empty, OneXray falls back to Google's official test App ID.
- If `ADMOB_AD_UNIT_ID_ANDROID` or `ADMOB_AD_UNIT_ID_IOS` is empty, no real ad unit IDs are injected.
- `FASTLANE_*` variables are only for release flows and are not required for debugging.

You only need to `source .env` and set `BUILD_NUMBER` when running the repository's packaging scripts.

## 5. Related `.gitignore` files

The following paths are ignored by `.gitignore`. In the **debug environment**, they should be understood like this:

| Path | Role in debug setup | Notes |
| ---- | ------------------- | ----- |
| `android/fastlane/playservice.json` | Not used | Only used for Play Store publishing. |
| `android/keystore/` | Not used | Only used for Android release signing; local debug uses the debug keystore. |
| `ios/fastlane/AuthKey.p8` | Not used | Only used for iOS release. |
| `macos/fastlane/AuthKey.p8` | Not used | Only used for Mac App Store release. |
| `macos_se/fastlane/AuthKey.p8` | Not used | Only used for macOS SE release / notarization. |
| `ios/Flutter/AdMob.xcconfig` | Optional | If missing, iOS uses the default test App ID; release scripts can also generate it automatically. |
| `swift/AppStore/GoogleService-Info.plist` | Provide when needed | Used when debugging iOS / macOS with Firebase enabled. |
| `swift/macOSSE/GoogleService-Info.plist` | Provide when needed | Used when debugging macOS SE with Firebase enabled. |

## 6. Files commonly used in debug

These are the files you will usually touch more often in local development:

| Path | Purpose |
| ---- | ------- |
| `swift/All/LibXray.xcframework` | Apple libXray artifact used by iOS / macOS. |
| `android/app/libs/libXray.aar` | Android libXray package. |
| `android/app/libs/libXray-sources.jar` | Matching sources jar for Android. |
| `linux/app/libXray.so` | Shared library linked by the Linux desktop app. |
| `linux/app/OneXrayCore` | Core binary used by the Linux desktop app. |
| `windows/app/libXray.dll` | Dynamic library loaded by the Windows desktop app. |
| `windows/app/OneXrayCore.exe` | Core binary used by the Windows desktop app. |
| `lib/firebase_options.dart` | Flutter-side Firebase initialization config. |
| `android/app/google-services.json` | Android Firebase config. |
| `swift/AppStore/GoogleService-Info.plist` | Firebase plist for the iOS / macOS App Store targets. |
| `swift/macOSSE/GoogleService-Info.plist` | Firebase plist for the macOS SE target. |

The repository already provides matching `.example` files. For the first debug setup, copying those files is enough.

## 7. Minimal setup summary

For local development and breakpoint debugging, the minimum setup is:

1. Copy the `.example` config files.
2. Build `libXray` and copy its artifacts into the corresponding OneXray directories.
3. Run `flutter pub get`.
4. Run `pod install` when working on Apple platforms.
5. Start the app with `flutter run -d <device>`.

Files such as `playservice.json`, `android/keystore/`, and the platform `AuthKey.p8` files are part of the release workflow, not the debug environment bootstrap.
