# OneXray

[English](../README.md) | [Русский](./README.ru.md)

## 应用介绍

关注我们的 Telegram 频道：[OneXray](https://t.me/OneXrayApp)

[文档站](https://onexray.com)

[First Run 指南](./FIRST_RUN.zh_CN.md)

## 下载

| 平台 | 要求 | 下载 |
| --- | --- | --- |
| iOS | iOS 15.0 及以上，arm64 | [App Store](https://apps.apple.com/us/app/onexray/id6745748773)、[IPA](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-ios.ipa) |
| macOS | macOS 12.0 及以上，Apple silicon 或 Intel | [Mac App Store](https://apps.apple.com/us/app/onexray/id6745748773)、[Universal ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-macos-universal.zip) |
| Android | Android 10.0 及以上，arm32、arm64 或 x86_64 | [Google Play](https://play.google.com/store/apps/details?id=net.yuandev.onexray)、[Universal APK](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-android-universal.apk) |
| Windows | Windows 10 或 Windows 11，x86_64 | [EXE](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.exe)、[ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.zip) |
| Linux x86_64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.deb)、[ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip) |
| Linux arm64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.deb)、[ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.zip) |

## 桌面端 CLI

桌面端安装包包含 `onexray` CLI。CLI 通过本地 Automation API 连接正在运行的 App，因此使用 CLI 命令前必须先打开 OneXray。

```shell
onexray health
onexray status
onexray import --file /path/to/import.txt
onexray import --text 'vless://...'
cat import.txt | onexray import --file -
onexray debug session
onexray vpn start
onexray vpn start --id 123
onexray vpn stop
```

`onexray import` 支持 OneXray URL Scheme、HTTPS 订阅 URL、Xray 分享链接、多行分享文本、Clash.Meta YAML，以及内置 libXray API 可识别的 Xray JSON 文本。`--file` 读取文本文件；二维码图片导入请在 App UI 中使用。

完整命令参数、导入 payload、session 路径和 Automation API 细节见 [开发](https://onexray.com/zh/docs/develop/) 和 [AI 参考](https://onexray.com/zh/docs/reference/)。

## 使用注意

### iOS

若您没有 Apple ID ，或您的 Apple ID 无法下载 OneXray ，您可以下载 **OneXray-ios.ipa** ，然后使用 [AltStore](https://altstore.io/) 或
其他第三方工具进行安装。

### Linux

若您使用 zip 包，您需要进行如下设置才可正常使用 OneXray。

执行指令前请确认目录。

```shell
sudo apt install -y procps libcap2-bin libayatana-appindicator3-1
sudo setcap cap_net_admin,cap_net_raw+eip OneXray/bin/OneXrayCore
```

若您使用 deb 包，您可使用如下指令进行安装和卸载。

```shell
sudo apt install ./OneXray-linux-x86_64.deb
sudo apt remove onexray
```

若您的桌面环境为 gnome，请安装 [AppIndicator](https://github.com/ubuntu/gnome-shell-extension-appindicator) 扩展。

若您的机器 CPU 架构为 Arm64，当您将语言切换为 CJK（中文，日文，韩文）时，OneXray 会将界面语言修正为英文。

### 内核升级

在 Linux 和 Windows 平台，您可自行升级或替换 Xray-core 。您可按照 [libXray](https://github.com/XTLS/libXray) 中的指引，使用 build 脚本进行编译。

#### Linux

将 `OneXray/lib/libXray.so` 替换为 libXray 的编译产物 `linux_so/libXray.so` 。

将 `OneXray/bin/OneXrayCore` 替换为 libXray 的编译产物 `bin/xray` 。

#### Windows

将 `OneXray/libXray.dll` 替换为 libXray 的编译产物 `windows_dll/libXray.dll` 。

将 `OneXray/bin/OneXrayCore.exe` 替换为 libXray 的编译产物 `bin/xray.exe` 。

## 贡献

若本项目对您有所帮助，您可考虑通过以下方式对本项目进行贡献。

1. 给本项目一个 star 。
2. 翻译 App 的文档 [onexray.com](https://github.com/OneXray/onexray.com) 。
3. 分享您的路由设置 [Routing](https://github.com/OneXray/Routing) 。
