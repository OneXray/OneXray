# OneXray

[简体中文](./readme/README.zh_CN.md)

## App Introduction

Follow us on Telegram: [OneXray](https://t.me/OneXrayApp)

[Documentation](https://onexray.com)

## Download

| Operating System | Version                                      | CPU Architecture     | Installation Package Format | Download Link                                                                                                              |
| ---------------- | -------------------------------------------- | -------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Windows          | Windows 10, Windows 11                       | x86_64               | exe                         | [OneXray-windows-amd64.exe](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.exe)         |
| Windows          | Windows 10, Windows 11                       | x86_64               | zip                         | [OneXray-windows-amd64.zip](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.zip)         |
| Android          | Android 9.0 and above                        | arm64, x86_64        | aab                         | Google Play Store                                                                                                          |
| Android          | Android 9.0 and above                        | arm64, x86_64        | apk                         | [OneXray-android-universal.apk](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-android-universal.apk) |
| iOS              | iOS 15.0 and above                           | arm64                | ipa                         | [App Store](https://apps.apple.com/us/app/onexray/id6745748773)                                                            |
| iOS              | iOS 15.0 and above                           | arm64                | ipa                         | [OneXray-ios.ipa](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-ios.ipa)                             |
| macOS            | macOS 12.0 and above                         | Apple silicon, Intel | pkg                         | [Mac App Store](https://apps.apple.com/us/app/onexray/id6745748773)                                                        |
| Linux            | Ubuntu 20.04 and above, Debian 11  and above | x86_64               | deb                         | [OneXray-linux-x86_64.deb](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.deb)           |
| Linux            | Ubuntu 20.04 and above, Debian 11  and above | x86_64               | zip                         | [OneXray-linux-x86_64.zip](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip)           |
| Linux            | Ubuntu 20.04 and above, Debian 11  and above | arm64                | deb                         | [OneXray-linux-aarch64.deb](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.deb)         |
| Linux            | Ubuntu 20.04 and above, Debian 11  and above | arm64                | zip                         | [OneXray-linux-aarch64.zip](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.zip)         |

## Notes

### iOS

If you don't have an Apple ID, or your Apple ID cannot download OneXray, you can download **OneXray-ios.ipa** and then use [AltStore](https://altstore.io/) or other third-party tools to install it.

### Linux

If you use the zip package, you need to make the following settings to use OneXray normally.

Please confirm the directory before executing the command.

```shell
sudo setcap cap_net_admin+epi onexray/bin/tun
sudo setcap cap_net_admin+epi onexray/bin/route
```

## Kernel Upgrade

On Linux and Windows platforms, you can upgrade or replace Xray-core yourself. You can compile it using the build script according to the instructions in [libXray](https://github.com/XTLS/libXray).

### Linux

Replace `OneXray/libXray.so` with the compiled product of libXray `linux_so/libXray.so`.

### Windows

Replace `OneXray/libXray.dll` with the compiled product of libXray `windows_dll/libXray.dll`.

## Questions and Answers

### Why is there no self-installable pkg or dmg package?

When distributing packages outside the Mac App Store, you need to use the **Developer ID Installer** and **Developer ID Application** certificates. Unfortunately, these two certificates do not support signing Network Extension plugins.
