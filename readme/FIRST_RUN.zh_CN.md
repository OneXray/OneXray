# 本地开发环境

[English](./FIRST_RUN.md) · [简体中文](./FIRST_RUN.zh_CN.md) · [Русский](./FIRST_RUN.ru.md)

只准备需要调试的平台，然后以 Flutter Debug 模式运行 OneXray。本文不作为发版或商店发布流程。

## 1. 准备工具

安装 [Flutter stable](https://docs.flutter.dev/install)，其 Dart SDK 必须满足 [pubspec.yaml](../pubspec.yaml) 的要求；同时准备 Git、Python 3.12+、满足 libXray `go.mod` 要求的 Go，以及用于 [FFI 生成](https://pub.dev/packages/ffigen#requirements)的 LLVM/libclang。

| 目标平台 | 构建系统及额外工具 |
| --- | --- |
| iOS / macOS | macOS、完整 Xcode 和所需平台 SDK；调试模拟器时还需安装 iOS Simulator runtime。 |
| Android | Android SDK、JDK（CI 使用 21），以及 [android/app/build.gradle.kts](../android/app/build.gradle.kts) 中指定的 SDK/NDK 版本。`ANDROID_HOME`、`ANDROID_NDK_HOME` 分别指向已安装的 SDK 和 NDK 目录。 |
| Linux | Linux、GCC/G++、Clang/libclang、CMake、Ninja、pkg-config，以及下文的 GTK/插件依赖。 |
| Windows | Windows、Visual Studio C++ 工具、Windows SDK、LLVM/libclang、架构匹配的 MinGW 兼容 `gcc.exe` / `g++.exe`、Rust 和 `uv`。参阅 [Windows 构建](../docs/windows-build.md)。 |

将 Flutter 和 Go 工具加入 `PATH`。Android 构建会自动安装 `gomobile`，其安装目录（`GOBIN`，未设置时为 `GOPATH/bin`）也必须位于 `PATH` 中。

构建前检查环境：

```shell
flutter doctor -v
go version
```

所有 Flutter/Dart 命令必须串行执行，包括不同终端中的命令。生成代码、分析或测试前，先停止正在运行的 `flutter run`。

## 2. 获取仓库

在选定的工作空间目录中执行：

```shell
git clone https://github.com/OneXray/OneXray.git
git clone https://github.com/XTLS/libXray.git
cd OneXray
```

**后续所有命令均从 OneXray App 仓库根目录执行**，即 `pubspec.yaml` 所在目录。已有仓库不必重复 clone。

```text
workspace/
├── OneXray/    # Flutter App，当前目录
├── libXray/    # 原生库与 GeoData
└── VCore/      # 仅 Windows 需要
```

依赖版本应与当前 App 代码匹配；CI 使用的依赖引用见 [Build workflow](../.github/workflows/build.yml)。不要将旧原生库与新的 App API 混用。标准 libXray 构建不需要另行 clone Xray-core。

## 3. 准备原生库与 GeoData

只执行目标平台对应的小节。以下 libXray 命令会解析 Go 依赖并准备 `../libXray/dat/`，不会构建或发布 App。

### iOS / macOS

```shell
python3 ../libXray/build/main.py apple go
rsync -a --delete ../libXray/LibXray.xcframework/ swift/All/LibXray.xcframework/
```

两个平台共用该 framework，其中包含模拟器架构。同步只替换生成的 framework，保留 `swift/All/` 中的其他文件。

Xcode 工程使用 [Swift Package Manager](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)，仓库不包含 Podfile，不需要执行 `pod install` 或自行添加 Podfile。Flutter 会在 Apple 构建时准备插件包。若曾全局关闭 SwiftPM，使用 `flutter config --enable-swift-package-manager` 重新开启。

### Android

```shell
python3 ../libXray/build/main.py android
mkdir -p android/app/libs
cp ../libXray/libXray.aar ../libXray/libXray-sources.jar android/app/libs/
```

上述命令使用 macOS/Linux shell；Windows 请使用对应的 Python、PowerShell 构建与复制命令。App 支持 arm64-v8a 和 x86_64，不支持 32 位 ARM。本地 Debug 使用 debug keystore，不需要 Play 服务账号或上传密钥。

### Linux

Debian / Ubuntu 先安装构建与运行依赖：

```shell
sudo apt-get update
sudo apt-get install -y build-essential clang libclang-dev cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libblkid-dev libsecret-1-dev libayatana-appindicator3-dev libcap2-bin procps file
python3 ../libXray/build/main.py linux
mkdir -p linux/app
cp ../libXray/linux_so/libXray.so linux/app/
cp ../libXray/bin/xray linux/app/OneXrayCore
chmod +x linux/app/OneXrayCore
```

原生库的架构必须与 Flutter App 一致。

### Windows

若尚未准备 VCore，在 App 根目录执行：

```powershell
git clone https://github.com/OneXray/VCore.git ../VCore
```

Windows 需要 `libXray.dll`、`OneXrayCore.exe`，以及三个 VCore 文件：`vcore.dll`、`vcore-windows-vpn-host.exe`、`vcore-windows-session-host.exe`。仅复制 libXray 不足以运行。

可运行的开发环境需按照[本地签名说明](../docs/windows-build.md#本地签名包)和 [Windows 打包流程](../build_scripts/README.md#简体中文)准备。App 构建脚本会构建两个依赖、校验并复制匹配的 VCore 产物、复制 GeoData，最后生成 MSIX。不要仅运行 `dart run msix:create`，它缺少 App 的 VCore manifest 集成步骤。

VPN 和启动检查需要已安装的包身份；未打包的 `flutter run -d windows` 不是完整的 VPN 调试环境。已有 VCore 不在工作空间内时，可通过 `VCORE_DIR` 指定其位置。

### 复制 GeoData：手动构建必做

完成目标平台的 libXray 构建后，复制**整个**数据目录，包括 JSON 索引与时间戳，而不只是两个 `.dat` 文件：

```shell
mkdir -p assets/dat
cp -R ../libXray/dat/. assets/dat/
```

PowerShell 对应命令：

```powershell
New-Item -ItemType Directory -Force assets/dat | Out-Null
Copy-Item ../libXray/dat/* assets/dat/ -Force
```

`assets/dat/` 被 Git 忽略。首次 clone 后缺少这些文件时，App 无法初始化默认路由数据。Windows App 打包脚本已包含此复制步骤。

## 4. 生成本地 Dart 文件

原生库与 GeoData 准备完成后执行：

```shell
flutter pub get
flutter gen-l10n
dart run ffigen
```

本地化输出与 `lib/core/ffi/generated_bindings.dart` 不由 Git 跟踪；Apple/Android 也需要生成，因为共享 Dart 代码引用了 FFI 绑定。FFI 配置与头文件路径已定义在 `pubspec.yaml` 中；找不到 libclang 时，检查 LLVM 安装位置与 `llvm-path`。

模型、数据库、资源和 Pigeon 的生成结果已经入库，首次启动无需重复生成。修改对应源文件后，按下文更新。

## 5. 启动调试

Android 或 iOS 模拟器先启动设备，再列出设备，将 `DEVICE_ID` 替换为实际 ID：

```shell
flutter devices
flutter run -d DEVICE_ID
```

macOS：

```shell
flutter run -d macos
```

- **iOS 模拟器**：Swift 自动使用本地 SOCKS 入站，并跳过不可用的 VPN 授权；App 内没有 Proxy 开关。这不代表真实系统 VPN 已通过验证。
- **Apple 签名**：使用自己的开发团队时，需要统一 Runner/tunnel 的 Bundle ID、App Group entitlement 和 [Swift 中的分组标识](../swift/All/Constants.swift)。真机需要有效的开发签名与 Network Extension 能力，不能直接假定仓库维护者的签名设置适用于自己的账号。
- **Linux**：先生成 Debug bundle，为其实际 Core 文件授予网络能力，再启动。以 x64 为例：
  ```shell
  flutter build linux --debug
  sudo setcap cap_net_admin,cap_net_raw+eip build/linux/x64/debug/bundle/OneXrayCore
  flutter run -d linux
  ```
  ARM64 将路径中的 `x64` 改为 `arm64`。重新构建替换 Core 文件后，需要重新授予能力。
- **Windows**：从系统启动前文安装的 MSIX 开发包。

完成 App 首次初始化，按需导入自己的测试服务器。平台验证要求见[验证边界](../docs/refactor-validation.md#平台边界)。

## 6. 修改代码后

| 修改内容 | 在 App 根目录执行 |
| --- | --- |
| ARB 翻译 | `flutter gen-l10n` |
| JSON/Drift 模型或声明的资源 | `dart run build_runner build --delete-conflicting-outputs` |
| `pigeon/message.dart` | `dart run pigeon --input pigeon/message.dart` |
| FFI 头文件或配置 | `dart run ffigen` |
| libXray / 原生库 | 重新构建并替换对应产物，停止并重新运行 App；热重载不会替换原生库。 |

按改动选择 `flutter analyze`、针对性的 `flutter test` 和 `git diff --check`。临时 demo 与测试数据统一放在工作空间的 `references/`，不要使用开发者的主数据库。

## 调试不等于发布

普通 `flutter run` 不需要 `.env`、`BUILD_NUMBER`、Fastlane 凭据、App Store Connect 密钥或 Play 上传账号。Apple 开发签名与 Windows 开发包签名是独立要求。

不要把 `build_scripts/main.py` 当作通用调试快捷入口：Apple/Android 目标可能上传商店，`macos_se` 还会替换本地 `macos/` 目录。打包前阅读[构建文档](../build_scripts/README.md)；不要对需要保留的 SDK 执行 `build_scripts/setup_flutter.sh`。

[返回 README](./README.zh_CN.md)
