# OneXray

## 应用介绍

关注我们的 Telegram 频道：[OneXray](https://t.me/OneXrayApp)

[文档站](https://onexray.com)

## 下载

| 操作系统 | 版本                                  | CPU 架构             | 安装包格式 | 下载链接                                                                                                                   |
| -------- | ------------------------------------- | -------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------- |
| Windows  | Windows 10, Windows 11                | x86_64               | exe        | [OneXray-windows-amd64.exe](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.exe)         |
| Windows  | Windows 10, Windows 11                | x86_64               | zip        | [OneXray-windows-amd64.zip](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.zip)         |
| Android  | Android 9.0 及以上                    | arm64, x86_64        | aab        | [Google Play Store](https://play.google.com/store/apps/details?id=net.yuandev.onexray)                                     |
| Android  | Android 9.0 及以上                    | arm64, x86_64        | apk        | [OneXray-android-universal.apk](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-android-universal.apk) |
| iOS      | iOS 15.0 及以上                       | arm64                | ipa        | [App Store](https://apps.apple.com/us/app/onexray/id6745748773)                                                            |
| iOS      | iOS 15.0 及以上                       | arm64                | ipa        | [OneXray-ios.ipa](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-ios.ipa)                             |
| macOS    | macOS 12.0 及以上                     | Apple silicon, Intel | pkg        | [Mac App Store](https://apps.apple.com/us/app/onexray/id6745748773)                                                        |
| Linux    | Ubuntu 24.04 及以上, Debian 12 及以上 | x86_64               | deb        | [OneXray-linux-x86_64.deb](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.deb)           |
| Linux    | Ubuntu 24.04 及以上, Debian 12 及以上 | x86_64               | zip        | [OneXray-linux-x86_64.zip](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip)           |
| Linux    | Ubuntu 24.04 及以上, Debian 12 及以上 | arm64                | deb        | [OneXray-linux-aarch64.deb](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.deb)         |
| Linux    | Ubuntu 24.04 及以上, Debian 12 及以上 | arm64                | zip        | [OneXray-linux-aarch64.zip](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip)          |

## 使用注意

### iOS

若您没有 Apple ID ，或您的 Apple ID 无法下载 OneXray ，您可以下载 **OneXray-ios.ipa** ，然后使用 [AltStore](https://altstore.io/) 或
其他第三方工具进行安装。

### Linux

若您使用 zip 包，您需要进行如下设置才可正常使用 OneXray。

执行指令前请确认目录。

```shell
sudo apt install -y procps libcap2-bin libayatana-appindicator3-1
sudo setcap cap_net_admin+epi OneXray/bin/tun
sudo setcap cap_net_admin+epi OneXray/bin/route
```

若您使用 deb 包，您可使用如下指令进行安装和卸载。

```shell
sudo apt install ./OneXray-linux-x86_64.deb
sudo apt remove onexray
```

### 内核升级

在 Linux 和 Windows 平台，您可自行升级或替换 Xray-core 。您可按照 [libXray](https://github.com/XTLS/libXray) 中的指引，使用 build 脚本进行编译。

#### Linux

将 `OneXray/lib/libXray.so` 替换为 libXray 的编译产物 `linux_so/libXray.so` 。

#### Windows

将 `OneXray/libXray.dll` 替换为 libXray 的编译产物 `windows_dll/libXray.dll` 。

## 问答

### 为何没有可自行安装的 pkg 或 dmg 包？

当在 Mac App Store 之外分发软件包时，需要用到 **Developer ID Installer** 和 **Developer ID Application** 证书，很不幸，这两种
证书不支持对 Network Extension 插件进行签名。

## 贡献

若本项目对您有所帮助，您可考虑通过以下方式对本项目进行贡献。

1. 给本项目一个 star 。
2. 翻译 App 的 UI 文本 [l10n](https://github.com/OneXray/l10n) 。
3. 翻译 App 的文档 [onexray.com](https://github.com/OneXray/onexray.com) 。
4. 分享您的路由设置 [Routing](https://github.com/OneXray/Routing) 。
