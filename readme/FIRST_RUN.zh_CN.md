# Debug 环境配置

这份文档面向项目开发人员，说明 **OneXray 本地 debug 环境** 的最小配置方式，不覆盖发版、上架、签名或 fastlane 发布流程。

## 1. 初始化项目

首次拉取代码后，先补齐本地调试所需的配置文件：

```shell
cp .env.example .env
cp firebase.json.example firebase.json
cp lib/firebase_options.dart.example lib/firebase_options.dart
cp android/app/google-services.json.example android/app/google-services.json
cp swift/AppStore/GoogleService-Info.plist.example swift/AppStore/GoogleService-Info.plist
cp swift/macOSSE/GoogleService-Info.plist.example swift/macOSSE/GoogleService-Info.plist
flutter pub get
```

这些文件的 `.example` 版本已经足够用于本地开发；如果后续需要联调真实 Firebase / AdMob，再替换成你自己的配置。

## 2. 准备 libXray 产物

OneXray 本地 debug 依赖同级目录下的 `libXray` 仓库产物。`libXray/build` 对应的主要产物如下：

- Apple: `LibXray.xcframework`
- Android: `libXray.aar`、`libXray-sources.jar`
- Linux: `linux_so/libXray.so`、`bin/xray`
- Windows: `windows_dll/libXray.dll`、`bin/xray.exe`

建议先在 `libXray` 仓库完成目标平台构建：

```shell
cd ../libXray
python3 build/main.py apple go
python3 build/main.py android
python3 build/main.py linux
python3 build/main.py windows
```

然后把产物同步到 OneXray 对应目录。

### iOS / macOS

Apple 平台共用 `LibXray.xcframework`。将 `libXray` 产物复制到 `swift/All/`：

```shell
cp -R ../libXray/LibXray.xcframework swift/All/
```

`swift/All/` 目录里已经包含 `BridgeHeader.h` 等 Swift 集成文件；这里主要更新 `LibXray.xcframework`。

### Android

Android 侧依赖 `aar` 和 sources jar。复制到 `android/app/libs/`：

```shell
mkdir -p android/app/libs
cp ../libXray/libXray.aar android/app/libs/
cp ../libXray/libXray-sources.jar android/app/libs/
```

### Linux

`linux/app.cmake` 会从 `linux/app/` 链接 `libXray.so`，并安装 `OneXrayCore` 到最终包内。因此需要把 Linux 产物复制到 `linux/app/`，其中 `bin/xray` 需要按 OneXray 约定重命名：

```shell
mkdir -p linux/app
cp ../libXray/linux_so/libXray.so linux/app/
cp ../libXray/bin/xray linux/app/OneXrayCore
```

### Windows

`windows/app.cmake` 会从 `windows/app/` 安装 `libXray.dll` 和 `OneXrayCore.exe`。因此需要把 Windows 产物复制到 `windows/app/`，其中 `bin/xray.exe` 需要按 OneXray 约定重命名：

```shell
mkdir -p windows/app
cp ../libXray/windows_dll/libXray.dll windows/app/
cp ../libXray/bin/xray.exe windows/app/OneXrayCore.exe
```

> `windows/app.cmake` 还会打包 `wintun.dll`。这个文件不来自 `libXray`，需要按 Windows 开发环境另行准备。

## 3. 启动调试

按目标平台执行：

```shell
flutter run -d android
flutter run -d macos
```

调试 iOS 前先安装 CocoaPods 依赖：

```shell
cd ios
pod install
cd ..
flutter run -d ios
```

## 4. `.env` 说明

本地 debug 场景下，`.env` 可以先保持为空：

- `ADMOB_APP_ID_ANDROID`、`ADMOB_APP_ID_IOS` 留空时，会回退到 Google 官方测试 App ID。
- `ADMOB_AD_UNIT_ID_ANDROID`、`ADMOB_AD_UNIT_ID_IOS` 留空时，不会注入真实广告位。
- `FASTLANE_*` 变量是发布用的，debug 不需要。

只有在运行仓库里的打包脚本时，才需要手动 `source .env` 并设置 `BUILD_NUMBER`。

## 5. `.gitignore` 里的相关文件

下面这些路径会在 `.gitignore` 中被忽略。对 **debug 环境** 来说，可以按下面理解：

| 路径 | debug 环境中的角色 | 说明 |
| ---- | ------------------ | ---- |
| `android/fastlane/playservice.json` | 不参与 | 仅 Android 发布到 Play Store 时使用。 |
| `android/keystore/` | 不参与 | 仅 Android 正式签名时使用，本地调试走 debug keystore。 |
| `ios/fastlane/AuthKey.p8` | 不参与 | 仅 iOS 发布时使用。 |
| `macos/fastlane/AuthKey.p8` | 不参与 | 仅 Mac App Store 发布时使用。 |
| `macos_se/fastlane/AuthKey.p8` | 不参与 | 仅 macOS SE 发布 / notarization 时使用。 |
| `ios/Flutter/AdMob.xcconfig` | 可选 | 不提供时会使用默认测试 App ID；走发布脚本时也会自动生成。 |
| `swift/AppStore/GoogleService-Info.plist` | 按需提供 | 调试 iOS / macOS 且需要 Firebase 时使用。 |
| `swift/macOSSE/GoogleService-Info.plist` | 按需提供 | 调试 macOS SE 且需要 Firebase 时使用。 |

## 6. Debug 更常用的配置文件

本地开发更常接触的是下面这些文件：

| 路径 | 用途 |
| ---- | ---- |
| `swift/All/LibXray.xcframework` | iOS / macOS 使用的 libXray Apple 产物。 |
| `android/app/libs/libXray.aar` | Android 使用的 libXray 动态库封装。 |
| `android/app/libs/libXray-sources.jar` | Android 侧配套 sources jar。 |
| `linux/app/libXray.so` | Linux 桌面端链接的共享库。 |
| `linux/app/OneXrayCore` | Linux 桌面端运行的核心二进制。 |
| `windows/app/libXray.dll` | Windows 桌面端加载的动态库。 |
| `windows/app/OneXrayCore.exe` | Windows 桌面端运行的核心二进制。 |
| `lib/firebase_options.dart` | Flutter 侧 Firebase 初始化配置。 |
| `android/app/google-services.json` | Android 的 Firebase 配置。 |
| `swift/AppStore/GoogleService-Info.plist` | iOS / macOS App Store 目标使用的 Firebase plist。 |
| `swift/macOSSE/GoogleService-Info.plist` | macOS SE 目标使用的 Firebase plist。 |

仓库已经提供对应的 `.example` 文件。首次配置 debug 环境时直接复制即可。

## 7. 最小配置结论

如果目标是本地开发和断点调试，最小步骤如下：

1. 复制 `.example` 配置文件。
2. 构建 `libXray` 并把产物复制到 OneXray 对应目录。
3. 执行 `flutter pub get`。
4. Apple 平台需要时执行 `pod install`。
5. 用 `flutter run -d <device>` 启动。

`playservice.json`、`android/keystore/`、各平台 `AuthKey.p8` 这类发布文件，不属于 debug 环境初始化范围。
