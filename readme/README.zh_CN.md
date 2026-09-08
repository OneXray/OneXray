<p align="center">
  <img src="../assets/logo.png" width="112" alt="OneXray 图标">
</p>

<h1 align="center">OneXray</h1>

<p align="center">
  自己的服务器，自己的路由，跨设备使用。
</p>

<p align="center">
  <a href="https://github.com/OneXray/OneXray/releases/latest"><img src="https://img.shields.io/github/v/release/OneXray/OneXray?display_name=tag&sort=semver" alt="最新版本"></a>
  <a href="../LICENSE"><img src="https://img.shields.io/github/license/OneXray/OneXray" alt="许可证"></a>
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20Android%20%7C%20Windows%20%7C%20Linux-0A84FF" alt="支持平台">
</p>

<p align="center">
  <a href="https://onexray.com">文档站</a> ·
  <a href="https://github.com/OneXray/OneXray/releases">版本发布</a> ·
  <a href="https://t.me/OneXrayApp">Telegram</a>
</p>

<p align="center">
  <a href="../README.md">English</a> · 简体中文 · <a href="./README.ru.md">Русский</a>
</p>

OneXray 是适用于手机、平板和桌面的开源 Xray-core 客户端。导入自己的服务器或订阅，选择流量的路由方式，通过设备的系统 VPN 连接。

**需要自行提供服务器。** OneXray 不提供 VPN 服务、代理服务器或订阅。使用前，请准备来自可信来源的兼容配置或订阅。

## 下载

| 平台 | 系统要求 | 下载 |
| --- | --- | --- |
| iPhone / iPad | iOS / iPadOS 15+ | [App Store](https://apps.apple.com/us/app/onexray/id6745748773) · [IPA](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-ios.ipa) |
| macOS | macOS 13+，Apple silicon 或 Intel | [Mac App Store](https://apps.apple.com/us/app/onexray/id6745748773) |
| macOS — OneXraySE | macOS 13+，Apple silicon 或 Intel | [Homebrew](https://formulae.brew.sh/cask/onexrayse) · [Universal ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-macos-universal.zip) |
| Android 手机 / 平板 | Android 10+，arm64-v8a 或 x86_64 | [Google Play](https://play.google.com/store/apps/details?id=net.yuandev.onexray) · [通用 APK](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-android-universal.apk) |
| Windows x64 | Windows 10 20H2+ | `winget install --id YuanDevLLC.OneXray -e` · [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.zip) · Microsoft Store |
| Windows ARM64 | Windows 11 | `winget install --id YuanDevLLC.OneXray -e` · [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-arm64.zip) · Microsoft Store |
| Linux x86_64 | glibc 2.39+ | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.deb) · [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip) |
| Linux arm64 | glibc 2.39+ | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.deb) · [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.zip) |

本文描述当前代码中的功能，商店和已发布版本可能有所不同。各平台的安装要求见[安装说明](#安装说明)。

## 主要功能

- **灵活连接**：使用自动选择、订阅、节点位置或指定服务器。查看连接状态、实时上下行速率和本次连接的流量。
- **管理服务器**：按订阅或节点位置浏览，比较延迟和协议标签，编辑、分享和删除节点与订阅。支持从文本或文件导入分享链接、Xray JSON 节点及受支持的 Clash/Mihomo YAML 节点；iOS 和 Android 还支持扫描二维码。
- **智能路由**：选择直连地区，让局域网与指定服务保持直连，并可选拦截常见广告域名。自动选择支持 1–3 个接入节点及负载均衡，也可指定最终出口实现链式代理。
- **自定义规则**：按顺序配置域名、IP、端口和网络条件，选择直连、VPN 或阻断。域名和 IP 输入支持 GeoData 自动补全；路由可以独立于所选服务器导入、导出和分享。
- **完整 JSON 配置**：专家模式将常规服务器选择区域替换为 Raw JSON 配置选择与编辑。隧道、日志、metrics 等运行设置仍由 OneXray 管理，具体边界见 [Xray 配置合同](../docs/xray-configuration.md)。
- **维护与诊断**：手动或定期更新订阅和 GeoData，配置测速 URL 与超时，查看实际生成的 Xray 配置。除 macOS System Extension 版本外，可查看本地访问日志和错误日志。

订阅支持 **age 加密**：填写已有密钥对，或在本地生成 X25519 / Hybrid（`ML-KEM-768 + X25519`）密钥。仅向订阅源发送公钥，私钥保存在设备上；订阅仍要求 HTTPS。参阅 [Age 加密订阅](../docs/age-encrypted-subscriptions.md)。

## 运行截图

以下为 iOS、Android、macOS 和 Windows 的真实运行截图，点击图片可查看原图。

<table>
  <tr>
    <th width="50%">iOS · 连接</th>
    <th width="50%">Android · 服务器</th>
  </tr>
  <tr>
    <td align="center"><a href="./images/connect-ios.png"><img src="./images/connect-ios.png" width="320" alt="iOS 连接页面，展示服务器选择与本次连接流量"></a></td>
    <td align="center"><a href="./images/servers-android.png"><img src="./images/servers-android.png" width="320" alt="Android 服务器页面，按订阅分组并展示延迟"></a></td>
  </tr>
</table>

### macOS · 智能路由

![macOS 智能路由页面，展示直连选项和路由结果预览](./images/smart-routing-macos.png)

### Windows · 自定义路由

![Windows 自定义路由页面，展示导入、分享、接入节点数量与有序规则](./images/custom-routing-windows.png)

## 首次连接

1. 完成首次初始化，并授予所需的系统权限。Windows 和 Linux 还需要明确选择 Xray 出口网卡。
2. 选择国家或地区，用于智能路由的“直连地区”，然后导入服务器或订阅。这两步均可跳过，稍后再设置。
3. 在“连接”页选择服务器和流量方式，然后启动 VPN。可先使用智能路由；“所有流量经过 VPN”将流量交给所选服务器，“自定义路由”则使用自己编写的规则。

普通服务器导入只提取节点，不导入来源文件中的路由或 DNS 配置。完整配置应通过自定义路由或 Raw JSON 导入。

## 平台专属功能

| 平台 | 系统集成 |
| --- | --- |
| iOS / macOS | 始终开启与按需 VPN；连接指定 Wi-Fi 时自动连接或断开；独立设置蜂窝网络（iOS）或 Ethernet（macOS）的行为。 |
| Android | 按应用分流：全部应用、仅所选应用、除所选应用外的所有应用；包含与排除列表分别保存。 |
| Windows / Linux | 明确指定 Xray 出口网卡。 |
| 桌面端 | 托盘控制、登录时启动、启动时隐藏，以及可选的 App 启动时连接。 |

浅色 / 深色主题和界面语言默认跟随系统。支持英语、简体中文、繁体中文、俄语和波斯语，波斯语使用从右向左的布局。

## 安装说明

<details>
<summary>macOS：Mac App Store 或 OneXraySE</summary>

Mac App Store 版本使用 Packet Tunnel 扩展；独立分发的 **OneXraySE** 使用 System Extension，可通过 [Homebrew](https://formulae.brew.sh/cask/onexrayse) 安装：

```shell
brew install --cask onexrayse
```

使用 ZIP 时，解压后先将 `OneXraySE.app` 移至 `/Applications`，再打开 App。完成首次初始化，并批准 VPN 和网络扩展请求。根据 macOS 版本，授权入口可能位于“系统设置 → 通用 → 登录项与扩展”或“隐私与安全性”；如系统要求重启，请按提示操作。参阅 [Apple System Extension 安装指南](https://developer.apple.com/documentation/systemextensions/installing-system-extensions-and-drivers)。

更新 ZIP 版本时，先退出 OneXraySE，替换 `/Applications` 中的 App，再重新打开。如有扩展更新授权提示，请予以批准。

</details>

<details>
<summary>iOS：安装 IPA</summary>

通过 App Store 安装最简单。自行安装 IPA 时，必须为主 App 和 Packet Tunnel 扩展重新签名，并使用允许 Network Extension 能力的描述文件。免费的 Personal Team 不提供所需能力，需要付费 Apple Developer Program 会员。App 能正常打开，不代表 VPN 扩展已获得授权。参阅 [Apple 支持的能力](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)。

</details>

<details>
<summary>Windows：EXE / ZIP 与 Microsoft Store</summary>

EXE 和 ZIP 使用独立 Core 与原生 TUN，启动 VPN 时通过 UAC 请求管理员授权。ZIP 必须完整解压后运行，不自动注册协议链接或创建快捷方式。

Microsoft Store 使用包含系统 VPN Provider 的 MSIX 包，负责架构选择和更新。EXE / ZIP 与 MSIX 的数据目录独立，不能跨渠道覆盖升级。开发构建和模式选择见 [Windows 构建说明](../docs/windows-build.md)。

</details>

<details>
<summary>Linux：安装包与权限</summary>

Debian / Ubuntu 用户安装对应架构的 DEB 即可；安装包会处理运行依赖、注册 OneXray 链接并授予所需网络能力：

```shell
sudo apt install ./OneXray-linux-x86_64.deb
```

arm64 使用 `OneXray-linux-aarch64.deb`。在 Debian / Ubuntu 上使用 ZIP 时，请在包含已解压 `OneXray` 文件夹的目录中执行：

```shell
sudo apt install -y procps libcap2-bin libayatana-appindicator3-1
sudo setcap cap_net_admin,cap_net_raw+eip OneXray/OneXrayCore
```

ZIP 不会自动注册 `onexray://` 链接。GNOME 用户可能需要安装 [AppIndicator 扩展](https://github.com/ubuntu/gnome-shell-extension-appindicator)以使用托盘控制。

</details>

## 隐私

无需账户，不含广告、分析、跟踪、遥测或崩溃上报服务。OneXray 不收集您的流量、浏览记录、配置或连接日志。网络请求发往哪些服务器与服务，由您的配置决定；订阅源、DNS 和其他第三方服务各自适用其隐私政策。参阅[隐私政策](https://onexray.com/docs/privacy/)。

分享的配置、订阅 URL 和导出的日志可能包含凭据等敏感信息，请在分享前检查内容。

## 文档与贡献

- [使用文档](https://onexray.com)与 [Telegram 社区](https://t.me/OneXrayApp)。
- 本地调试参阅[开发环境配置](./FIRST_RUN.zh_CN.md)，打包参阅[构建脚本](../build_scripts/README.md)。
- [App 当前行为与工程约定](../docs/README.md)，包括[导入与 OneXray 链接](../docs/subscriptions-and-sharing.md)。
- [反馈问题或建议](https://github.com/OneXray/OneXray/issues)：请附上平台、App / Xray-core 版本和复现步骤，不要公开私密凭据。

欢迎贡献代码、翻译和[文档改进](https://github.com/OneXray/onexray.com)。

## 许可证

[GNU General Public License v3.0](../LICENSE)。
