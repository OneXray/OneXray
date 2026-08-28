# Debug Environment Setup

This guide is for OneXray developers. It describes the minimum setup for the **local debug environment** and does not cover release, store submission, signing, or fastlane publishing.

## 1. Initialize the project

This repository uses the latest stable Flutter SDK. After cloning the repository, install Flutter first:

```shell
# macOS / Linux
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$HOME/flutter/stable"
export PATH="$HOME/flutter/stable/bin:$PATH"

# Windows
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "%USERPROFILE%\\flutter\\stable"
setx PATH "%USERPROFILE%\\flutter\\stable\\bin;%PATH%"
```

Then run in the repository root:

```shell
flutter pub get
```

## 2. Prepare libXray artifacts

Local OneXray debugging depends on artifacts built from the sibling `libXray` repository. The main outputs are:

- Apple: `LibXray.xcframework`
- Android: `libXray.aar`, `libXray-sources.jar`
- Linux: `linux_so/libXray.so` and `bin/xray`, copied as `OneXrayCore`
- Windows: `windows_dll/libXray.dll` and `bin/xray.exe`, copied as `OneXrayCore.exe`

Build the required targets in `libXray` first. These commands use the standard
build and resolve Xray-core from libXray's Go module dependencies:

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

`linux/app.cmake` links `libXray.so` from `linux/app/` and installs
`OneXrayCore` into the final bundle. Copy both libXray outputs using the names
expected by OneXray:

```shell
mkdir -p linux/app
cp ../libXray/linux_so/libXray.so linux/app/
cp ../libXray/bin/xray linux/app/OneXrayCore
```

### Windows

`windows/app.cmake` installs `libXray.dll` and `OneXrayCore.exe` from
`windows/app/`. Copy both libXray outputs using the names expected by OneXray:

```shell
mkdir -p windows/app
cp ../libXray/windows_dll/libXray.dll windows/app/
cp ../libXray/bin/xray.exe windows/app/OneXrayCore.exe
```

## 3. Start debugging

Run the target platform with:

```shell
flutter run -d android
flutter run -d macos
```

Before debugging Linux, install the local build dependencies:

```shell
sudo apt-get update
sudo apt-get install -y \
  ninja-build clang cmake pkg-config \
  libgtk-3-dev liblzma-dev libblkid-dev libsecret-1-dev \
  libayatana-appindicator3-dev \
  file
flutter run -d linux
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

The repository provides the remaining non-secret defaults required for local debugging.

## 7. Minimal setup summary

For local development and breakpoint debugging, the minimum setup is:

1. Install the latest stable Flutter SDK and run `flutter pub get`.
2. Build `libXray` and copy its artifacts into the corresponding OneXray directories.
3. Install platform-specific dependencies when needed, such as `pod install` on Apple platforms and `libayatana-appindicator3-dev` on Linux.
4. Start the app with `flutter run -d <device>`.

Files such as `playservice.json`, `android/keystore/`, and the platform `AuthKey.p8` files are part of the release workflow, not the debug environment bootstrap.
