# Local development setup

[English](./FIRST_RUN.md) · [简体中文](./FIRST_RUN.zh_CN.md) · [Русский](./FIRST_RUN.ru.md)

Prepare one target platform and run OneXray in Flutter Debug mode. This guide is not a release or store-publishing workflow.

## 1. Prepare the tools

Install [Flutter stable](https://docs.flutter.dev/install) with a Dart SDK that satisfies [pubspec.yaml](../pubspec.yaml), Git, Python 3.12+, Go matching libXray's `go.mod`, and LLVM/libclang for [FFI generation](https://pub.dev/packages/ffigen#requirements).

| Target | Build host and additional tools |
| --- | --- |
| iOS / macOS | macOS with full Xcode and the required platform SDKs; install an iOS Simulator runtime for simulator debugging. |
| Android | Android SDK, JDK (CI uses 21), and the SDK/NDK versions in [android/app/build.gradle.kts](../android/app/build.gradle.kts). Set `ANDROID_HOME` and `ANDROID_NDK_HOME` to the installed SDK and NDK directories. |
| Linux | Linux with GCC/G++, Clang/libclang, CMake, Ninja, pkg-config, and the GTK/plugin dependencies below. |
| Windows | Windows with Visual Studio C++ tools, Windows SDK, LLVM/libclang, a matching-architecture MinGW-compatible `gcc.exe` / `g++.exe`, Rust, and `uv`. See [Windows builds](../docs/windows-build.md) (Chinese). |

Add Flutter and Go tools to `PATH`. Android builds install `gomobile` automatically; its installation directory (`GOBIN`, or `GOPATH/bin` when unset) must also be on `PATH`.

Check the environment before building:

```shell
flutter doctor -v
go version
```

Run all Flutter/Dart commands serially, including across terminals. Stop an active `flutter run` before starting generation, analysis, or tests.

## 2. Check out the repositories

From your chosen workspace directory:

```shell
git clone https://github.com/OneXray/OneXray.git
git clone https://github.com/XTLS/libXray.git
cd OneXray
```

**All remaining commands start in the OneXray App repository root**, beside `pubspec.yaml`. Skip cloning repositories you already have.

```text
workspace/
├── OneXray/    # Flutter App; current directory
├── libXray/    # native libraries and GeoData
└── VCore/      # Windows only
```

Use dependency revisions compatible with your App checkout; the [Build workflow](../.github/workflows/build.yml) defines the CI references. Do not mix old native binaries with a new App API. A separate Xray-core checkout is not needed for the standard libXray build.

## 3. Prepare native libraries and GeoData

Run only the section for your target. These libXray commands resolve Go dependencies and prepare `../libXray/dat/`; they do not build or publish the App.

### iOS / macOS

```shell
python3 ../libXray/build/main.py apple go
rsync -a --delete ../libXray/LibXray.xcframework/ swift/All/LibXray.xcframework/
```

Both platforms use this framework, including its simulator slices. The sync replaces only the generated framework; keep the other files in `swift/All/`.

The Xcode projects use [Swift Package Manager](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers). There are no checked-in Podfiles: do not run `pod install` or add a Podfile as a setup step. Flutter prepares the generated plugin package during the Apple build. If you previously disabled SwiftPM globally, enable it with `flutter config --enable-swift-package-manager`.

### Android

```shell
python3 ../libXray/build/main.py android
mkdir -p android/app/libs
cp ../libXray/libXray.aar ../libXray/libXray-sources.jar android/app/libs/
```

The commands above use a macOS/Linux shell; on Windows, use Python and PowerShell equivalents for the build and copies. The App supports arm64-v8a and x86_64, not 32-bit ARM. Local Debug builds use the debug keystore; no Play service account or upload keystore is needed.

### Linux

On Debian/Ubuntu, install the build and runtime dependencies:

```shell
sudo apt-get update
sudo apt-get install -y build-essential clang libclang-dev cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libblkid-dev libsecret-1-dev libayatana-appindicator3-dev libcap2-bin procps file
python3 ../libXray/build/main.py linux
mkdir -p linux/app
cp ../libXray/linux_so/libXray.so linux/app/
cp ../libXray/bin/xray linux/app/OneXrayCore
chmod +x linux/app/OneXrayCore
```

Build for the same architecture as the Flutter App.

### Windows

From the App root, clone VCore if needed:

```powershell
git clone https://github.com/OneXray/VCore.git ../VCore
```

Windows needs `libXray.dll`, `OneXrayCore.exe`, and all three VCore files: `vcore.dll`, `vcore-windows-vpn-host.exe`, and `vcore-windows-session-host.exe`. Copying only libXray is not enough.

For an executable development setup, follow the [local signing instructions](../docs/windows-build.md#本地签名包) (Chinese) and the [Windows packaging workflow](../build_scripts/README.md#english). The App build script builds both dependencies, validates and copies matching VCore artifacts, copies GeoData, and creates the MSIX. Do not use bare `dart run msix:create`: it omits the App's VCore manifest integration.

VPN and startup checks require an installed package identity. An unpackaged `flutter run -d windows` is not a complete VPN test environment. `VCORE_DIR` may point to an existing VCore checkout outside this workspace.

### Copy GeoData — required for manual builds

After the selected libXray build, copy the **whole** data directory, including the JSON indexes and timestamp, not just the two `.dat` files:

```shell
mkdir -p assets/dat
cp -R ../libXray/dat/. assets/dat/
```

PowerShell equivalent:

```powershell
New-Item -ItemType Directory -Force assets/dat | Out-Null
Copy-Item ../libXray/dat/* assets/dat/ -Force
```

`assets/dat/` is ignored by Git. A fresh clone cannot initialize its default routing data without these files. The Windows App packaging script already performs this copy.

## 4. Generate local Dart files

After native libraries and GeoData are ready:

```shell
flutter pub get
flutter gen-l10n
dart run ffigen
```

Localizations and `lib/core/ffi/generated_bindings.dart` are not tracked. Generate them even for Apple/Android builds, since shared Dart imports reference the FFI bindings. FFI configuration and header paths are already in `pubspec.yaml`; if libclang cannot be found, check your LLVM installation and the configured `llvm-path`.

The checked-in model, database, asset, and Pigeon outputs do not need regeneration just to start the App. See the next section when their sources change.

## 5. Start debugging

For Android or the iOS Simulator, start the device, list devices, and replace `DEVICE_ID` with its actual ID:

```shell
flutter devices
flutter run -d DEVICE_ID
```

For macOS:

```shell
flutter run -d macos
```

- **iOS Simulator:** Swift automatically uses a local SOCKS inbound and bypasses unavailable VPN authorization. There is no App-level proxy switch, and this does not verify a real system VPN.
- **Apple signing:** for your own development team, align the Runner/tunnel bundle IDs, App Group entitlements, and [Swift group identifiers](../swift/All/Constants.swift). Real devices require valid development signing and Network Extension capabilities; do not assume the repository owner's signing settings work for your account.
- **Linux:** build the Debug bundle, grant capabilities to its actual Core binary, then launch. For x64:
  ```shell
  flutter build linux --debug
  sudo setcap cap_net_admin,cap_net_raw+eip build/linux/x64/debug/bundle/OneXrayCore
  flutter run -d linux
  ```
  Use `arm64` instead of `x64` on ARM64. Reapply capabilities if rebuilding replaces the Core binary.
- **Windows:** launch the installed development MSIX from the Windows setup above.

Complete the App's initial setup and import your own test servers when needed. See the repository's [validation boundaries](../docs/refactor-validation.md#平台边界) (Chinese) for platform-specific verification requirements.

## 6. After source changes

| Changed source | Run from the App root |
| --- | --- |
| ARB translations | `flutter gen-l10n` |
| JSON/Drift models or declared assets | `dart run build_runner build --delete-conflicting-outputs` |
| `pigeon/message.dart` | `dart run pigeon --input pigeon/message.dart` |
| FFI headers or configuration | `dart run ffigen` |
| libXray / native libraries | Rebuild and replace the matching native artifacts, then stop and relaunch the App; hot reload does not replace native libraries. |

Choose checks appropriate to your changes: `flutter analyze`, focused `flutter test`, and `git diff --check`. Keep temporary demos and test fixtures in workspace `references/`, and do not use the developer's main database.

## Debug is not deployment

Ordinary `flutter run` does not need `.env`, `BUILD_NUMBER`, Fastlane credentials, App Store Connect keys, or a Play upload account. Apple development signing and Windows development-package signing are separate requirements.

Do not use `build_scripts/main.py` as a generic debug shortcut: Apple/Android targets may upload to stores, and `macos_se` replaces the local `macos/` tree. Read the [build documentation](../build_scripts/README.md) before packaging; do not run `build_scripts/setup_flutter.sh` against an SDK you want to preserve.

[Back to README](../README.md)
