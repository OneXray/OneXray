# OneXray

[简体中文](./readme/README.zh_CN.md)

## App Introduction

Follow us on Telegram: [OneXray](https://t.me/OneXrayApp)

[Documentation](https://onexray.com)

## Download

| Operating System | Version                                                    | CPU Architecture     | Installation Package Format | Download Link                                                                                                              |
| ---------------- | ---------------------------------------------------------- | -------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Windows          | Windows 10, Windows 11                                     | x86_64               | exe                         | [OneXray-windows-amd64.exe](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.exe)         |
| Windows          | Windows 10, Windows 11                                     | x86_64               | zip                         | [OneXray-windows-amd64.zip](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.zip)         |
| Android          | Android 8.0 and above                                      | arm32, arm64, x86_64 | aab                         | [Google Play Store](https://play.google.com/store/apps/details?id=net.yuandev.onexray)                                     |
| Android          | Android 8.0 and above                                      | arm32, arm64, x86_64 | apk                         | [OneXray-android-universal.apk](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-android-universal.apk) |
| iOS              | iOS 15.0 and above                                         | arm64                | ipa                         | [App Store](https://apps.apple.com/us/app/onexray/id6745748773)                                                            |
| iOS              | iOS 15.0 and above                                         | arm64                | ipa                         | [OneXray-ios.ipa](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-ios.ipa)                             |
| macOS            | macOS 12.0 and above                                       | Apple silicon, Intel | pkg                         | [Mac App Store](https://apps.apple.com/us/app/onexray/id6745748773)                                                        |
| Linux            | Ubuntu 24.04 and above, Debian 12 and above, GLIBC >= 2.36 | x86_64               | deb                         | [OneXray-linux-x86_64.deb](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.deb)           |
| Linux            | Ubuntu 24.04 and above, Debian 12 and above, GLIBC >= 2.36 | x86_64               | zip                         | [OneXray-linux-x86_64.zip](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip)           |
| Linux            | Ubuntu 24.04 and above, Debian 12 and above, GLIBC >= 2.36 | arm64                | deb                         | [OneXray-linux-aarch64.deb](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.deb)         |
| Linux            | Ubuntu 24.04 and above, Debian 12 and above, GLIBC >= 2.36 | arm64                | zip                         | [OneXray-linux-aarch64.zip](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.zip)         |

## Notes

### iOS

If you don't have an Apple ID, or your Apple ID cannot download OneXray, you can download **OneXray-ios.ipa** and then use [AltStore](https://altstore.io/) or other third-party tools to install it.

### Linux

If you use the zip package, you need to make the following settings to use OneXray normally.

Please confirm the directory before executing the command.

```shell
sudo apt install -y procps libcap2-bin libayatana-appindicator3-1
sudo setcap cap_net_admin+epi OneXray/bin/OneXrayCore
sudo setcap cap_net_admin+epi OneXray/bin/OneXrayTun
```

If you use the deb package, you can use the following commands to install and uninstall.

```shell
sudo apt install ./OneXray-linux-x86_64.deb
sudo apt remove onexray
```

If your device is arm64 and is used in a Chinese environment, please install the Noto font.

```shell
sudo apt install fonts-noto-cjk fonts-noto-cjk-extra
```

If your desktop environment is gnome, please install the [AppIndicator](https://github.com/ubuntu/gnome-shell-extension-appindicator) extension.

### Kernel Upgrade

On Linux and Windows platforms, you can upgrade or replace Xray-core yourself. You can compile it using the build script according to the instructions in [libXray](https://github.com/XTLS/libXray).

#### Linux

Replace `OneXray/lib/libXray.so` with the compiled product of libXray `linux_so/libXray.so`.

Replace `OneXray/bin/OneXrayCore` with the compiled product of libXray `bin/xray`.

#### Windows

Replace `OneXray/libXray.dll` with the compiled product of libXray `windows_dll/libXray.dll`.

Replace `OneXray/bin/OneXrayCore.exe` with the compiled product of libXray `bin/xray.exe`.

## Questions and Answers

### Why is there no self-installable pkg or dmg package?

When distributing packages outside the Mac App Store, you need to use the **Developer ID Installer** and **Developer ID Application** certificates. Unfortunately, these two certificates do not support signing Network Extension plugins.

## Contribution

If this project is helpful to you, you can consider contributing to this project in the following ways.

1. Give this project a star.
2. Translate the app's UI text [l10n](https://github.com/OneXray/l10n) .
3. Translate the app's documentation [onexray.com](https://github.com/OneXray/onexray.com) .
4. Share your routing settings [Routing](https://github.com/OneXray/Routing) .
