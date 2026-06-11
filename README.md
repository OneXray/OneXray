# OneXray

[简体中文](./readme/README.zh_CN.md) | [Русский](./readme/README.ru.md)

## App Introduction

Follow us on Telegram: [OneXray](https://t.me/OneXrayApp)

[Documentation](https://onexray.com)

[First Run](./readme/FIRST_RUN.md)

## Download

| Platform | Requirements | Download |
| --- | --- | --- |
| iOS | iOS 15.0 and above, arm64 | [App Store](https://apps.apple.com/us/app/onexray/id6745748773), [IPA](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-ios.ipa) |
| macOS | macOS 12.0 and above, Apple silicon or Intel | [Mac App Store](https://apps.apple.com/us/app/onexray/id6745748773), [Universal ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-macos-universal.zip) |
| Android | Android 10.0 and above, arm32, arm64, or x86_64 | [Google Play](https://play.google.com/store/apps/details?id=net.yuandev.onexray), [Universal APK](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-android-universal.apk) |
| Windows | Windows 10 or Windows 11, x86_64 | [EXE](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.exe), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.zip) |
| Linux x86_64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.deb), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip) |
| Linux arm64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.deb), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.zip) |

## Desktop CLI

Desktop packages include the `onexray` CLI. It talks to the running app through the local Automation API, so OneXray must be open before using CLI commands.

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

`onexray import` accepts OneXray URL Scheme links, HTTPS subscription URLs, Xray share links, multi-line share text, Clash.Meta YAML, and Xray JSON text supported by the bundled libXray API. `--file` reads text files; QR image import is available from the app UI.

For exact command options, import payloads, session paths, and Automation API details, see [Develop](https://onexray.com/docs/develop/) and [AI Reference](https://onexray.com/docs/reference/).

## Notes

### iOS

If you don't have an Apple ID, or your Apple ID cannot download OneXray, you can download **OneXray-ios.ipa** and then use [AltStore](https://altstore.io/) or other third-party tools to install it.

### Linux

If you use the zip package, you need to make the following settings to use OneXray normally.

Please confirm the directory before executing the command.

```shell
sudo apt install -y procps libcap2-bin libayatana-appindicator3-1
sudo setcap cap_net_admin,cap_net_raw+eip OneXray/bin/OneXrayCore
```

If you use the deb package, you can use the following commands to install and uninstall.

```shell
sudo apt install ./OneXray-linux-x86_64.deb
sudo apt remove onexray
```

If your desktop environment is gnome, please install the [AppIndicator](https://github.com/ubuntu/gnome-shell-extension-appindicator) extension.

If your machine's CPU architecture is Arm64, switching the language to a CJK language (Chinese, Japanese, or Korean) will cause OneXray to reset the interface language to English.

### Kernel Upgrade

On Linux and Windows platforms, you can upgrade or replace Xray-core yourself. You can compile it using the build script according to the instructions in [libXray](https://github.com/XTLS/libXray).

#### Linux

Replace `OneXray/lib/libXray.so` with the compiled product of libXray `linux_so/libXray.so`.

Replace `OneXray/bin/OneXrayCore` with the compiled product of libXray `bin/xray`.

#### Windows

Replace `OneXray/libXray.dll` with the compiled product of libXray `windows_dll/libXray.dll`.

Replace `OneXray/bin/OneXrayCore.exe` with the compiled product of libXray `bin/xray.exe`.

## Contribution

If this project is helpful to you, you can consider contributing to this project in the following ways.

1. Give this project a star.
2. Translate the app's documentation [onexray.com](https://github.com/OneXray/onexray.com) .
3. Share your routing settings [Routing](https://github.com/OneXray/Routing) .
