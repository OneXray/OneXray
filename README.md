<p align="center">
  <img src="./assets/logo.png" width="112" alt="OneXray logo">
</p>

<h1 align="center">OneXray</h1>

<p align="center">
  A private, cross-platform Xray-core client for your own nodes, subscriptions, and configurations.
</p>

<p align="center">
  <a href="https://github.com/OneXray/OneXray/releases/latest"><img src="https://img.shields.io/github/v/release/OneXray/OneXray?display_name=tag&sort=semver" alt="Latest release"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/github/license/OneXray/OneXray" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20Android%20%7C%20Windows%20%7C%20Linux-0A84FF" alt="Supported platforms">
</p>

<p align="center">
  <a href="https://onexray.com">Documentation</a> ·
  <a href="./readme/FIRST_RUN.md">Development Setup</a> ·
  <a href="https://t.me/OneXrayApp">Telegram</a> ·
  <a href="https://github.com/OneXray/OneXray/releases/latest">Releases</a>
</p>

<p align="center">
  English · <a href="./readme/README.zh_CN.md">简体中文</a> · <a href="./readme/README.ru.md">Русский</a>
</p>

OneXray lets you bring your own compatible server configuration or HTTPS subscription, organize nodes, and control traffic with structured Xray Profiles and routing tools.

OneXray is a client-only app. It does not provide VPN or proxy servers, subscriptions, or network access. It requires no account and contains no advertising, analytics, tracking, telemetry, or crash-reporting services.

## Preview

<p align="center">
  <img src="./readme/images/home-ios.png" width="22%" alt="OneXray Home on iOS">
  &nbsp;&nbsp;
  <img src="./readme/images/home-macos.png" width="70%" alt="OneXray Home on macOS">
</p>

## Highlights

- **Cross-platform TUN** — iOS, macOS, Android, Windows, and Linux.
- **Flexible configuration** — Simple Profile, reusable Xray Profiles, Full Config, and Raw JSON.
- **Routing control** — switch between Rule, Global, and Direct behavior from Home.
- **Import and organize** — supported share links and HTTPS subscriptions from QR codes, images, files, or the clipboard.
- **Local tools** — node ping, Xray logs, GeoData and rule-set management, backup, and restore.
- **Platform integration** — Android Per-App VPN, Apple On Demand, desktop tray controls, and outbound-interface selection.

## Age-Encrypted Subscriptions

When adding or editing an HTTPS subscription, open **Encryption** and either
enter an existing age key pair or generate an X25519 or Mihomo-compatible
Hybrid key (`ML-KEM-768 + X25519`). OneXray sends only the saved public
recipient as `X-Age-Public-Key`; the secret key remains local and the pair is
reused for automatic refreshes.

HTTPS is still required. OneXray backups are not encrypted and include the age
key pair so restored subscriptions remain usable; store backup ZIP files
carefully.

## OneXray URL Scheme

OneXray can share and import content through its proprietary `onexray://` URLs:

```text
onexray://onexray.com/config/add?type=outbound|profile|full|raw&data=<percent-encoded-base64-json>#Name
onexray://onexray.com/sub/add?url=<percent-encoded-https-url>[&age=x25519|hybrid]#Name
onexray://onexray.com/dat/add?type=domain|ip&url=<percent-encoded-https-url>#Name
```

When a shared config references custom GeoData stored in OneXray, matching
GeoData links are placed before the config link.

Only the types shown above are supported. Legacy `type=setting`, backups, and
other commands are not accepted. An age subscription link generates a new
local key pair, sends only its public key for the first download, and stores
the pair when the subscription is imported successfully.

Android, iOS, and installed macOS apps register the scheme directly. On
Windows and Linux, use the EXE/winget or DEB package; ZIP packages do not
register the scheme automatically. The Mac App Store app and OneXraySE share
the same scheme, so installing both can make macOS choose either app as the
handler.

## Download

| Platform | Requirements | Download |
| --- | --- | --- |
| iOS | iOS 15.0 and above, arm64 | [App Store](https://apps.apple.com/us/app/onexray/id6745748773), [IPA](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-ios.ipa) |
| macOS (Mac App Store) | macOS 13.0 and above, Apple silicon or Intel | [App Store](https://apps.apple.com/us/app/onexray/id6745748773) |
| macOS (Outside App Store) | macOS 13.0 and above, Apple silicon or Intel | Homebrew: `brew install --cask onexrayse`, [Universal ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-macos-universal.zip) |
| Android | Android 10.0 and above, arm64-v8a or x86_64 | [Google Play](https://play.google.com/store/apps/details?id=net.yuandev.onexray), [Universal APK](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-android-universal.apk) |
| Windows x86_64 | Windows 10 or Windows 11 | winget: `winget install --id YuanDevLLC.OneXray -e`, [EXE](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.exe), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.zip) |
| Windows ARM64 | Windows 11 | winget: `winget install --id YuanDevLLC.OneXray -e`, [EXE](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-arm64.exe), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-arm64.zip) |
| Linux x86_64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.deb), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip) |
| Linux arm64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.deb), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.zip) |

## Installation Notes

### macOS

The Mac App Store build is a separate store package. Homebrew and the Universal ZIP use the same Developer ID `macos_se` package and install `OneXraySE.app`.

```shell
brew install --cask onexrayse
brew uninstall --cask onexrayse
```

#### Universal ZIP

1. Download and extract `OneXray-macos-universal.zip`.
2. Move `OneXraySE.app` to `/Applications`. Do not run it directly from Downloads or another folder; macOS requires an app containing a System Extension to be installed in a system Applications directory.
3. Open OneXraySE from Applications and accept the macOS launch confirmation.

For the first VPN connection:

1. Import a subscription or node, select a node, and click Start.
2. Open **System Settings > General > Login Items & Extensions**.
3. Under **Extensions**, open **Network Extensions**, enable **OneXraySE**, and click **Done**.
4. If **Privacy & Security** also shows an approval request, click **Allow** and restart the Mac if requested.
5. Return to OneXraySE and click Start again.

To update the ZIP build, quit OneXraySE, replace the existing app in `/Applications` with the newly extracted `OneXraySE.app`, and reopen it. Approve the System Extension update if macOS asks.

See [Installing System Extensions and Drivers](https://developer.apple.com/documentation/systemextensions/installing-system-extensions-and-drivers) and [Change Login Items & Extensions settings](https://support.apple.com/guide/mac-help/change-login-items-extension-settings-mtusr003/mac).

### Windows

Winget automatically selects the x86_64 or ARM64 installer for the current device.

```shell
winget install --id YuanDevLLC.OneXray -e
winget uninstall --id YuanDevLLC.OneXray -e
```

### Android

Android builds support `arm64-v8a` and `x86_64`. 32-bit ARM devices are not supported.

### iOS

If the App Store is unavailable for your Apple ID, download `OneXray-ios.ipa` and install it with [AltStore](https://altstore.io/) or another compatible sideloading tool.

Self-installing the IPA requires re-signing both OneXray and its Packet Tunnel extension with a provisioning profile that authorizes the Network Extension capability. Apple does not support this capability for free Personal Team accounts, so a paid Apple Developer Program membership is required. Without it, the app may open and ping nodes, but the VPN cannot start. See [Apple Developer Forums](https://developer.apple.com/forums/thread/128767) and [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/).

### Linux

For a DEB package:

```shell
sudo apt install ./OneXray-linux-x86_64.deb
sudo apt remove onexray
```

For a ZIP package, run these commands from the directory containing `OneXray`:

```shell
sudo apt install -y procps libcap2-bin libayatana-appindicator3-1
sudo setcap cap_net_admin,cap_net_raw+eip OneXray/bin/OneXrayCore
```

GNOME users should install the [AppIndicator](https://github.com/ubuntu/gnome-shell-extension-appindicator) extension. Linux arm64 currently falls back to English for CJK locales.

## Contributing

Contributions are welcome:

1. Star this repository.
2. Improve the [documentation](https://github.com/OneXray/onexray.com).
3. Share routing templates through [OneXray/Routing](https://github.com/OneXray/Routing).

See [Development Setup](./readme/FIRST_RUN.md) before building the app locally.

## License

OneXray is licensed under the [GNU General Public License v3.0](./LICENSE).
