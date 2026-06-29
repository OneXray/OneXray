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

On Linux and Windows platforms, you can upgrade or replace Xray-core yourself. Build libXray for the dynamic library, and build the Xray-core CLI separately for `OneXrayCore`.

#### Linux

Replace `OneXray/lib/libXray.so` with the compiled product of libXray `linux_so/libXray.so`.

Replace `OneXray/bin/OneXrayCore` with the compiled Xray-core CLI.

#### Windows

Replace `OneXray/libXray.dll` with the compiled product of libXray `windows_dll/libXray.dll`.

Replace `OneXray/bin/OneXrayCore.exe` with the compiled Xray-core CLI.

## Contribution

If this project is helpful to you, you can consider contributing to this project in the following ways.

1. Give this project a star.
2. Translate the app's documentation [onexray.com](https://github.com/OneXray/onexray.com) .
3. Share your routing settings [Routing](https://github.com/OneXray/Routing) .
