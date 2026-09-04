# App 启动行为

本文区分三个容易混淆的设置：登录时启动 App、桌面端隐藏主窗口、App 启动后自动连接。三者彼此独立，默认都关闭。

## 设置范围

| 设置 | 平台 | 作用 |
| --- | --- | --- |
| 登录时启动 | macOS、Windows、Linux | 向操作系统注册或取消 OneXray 登录项 |
| 启动时隐藏 | macOS、Windows、Linux | 桌面窗口准备完成后保持隐藏，托盘仍可使用 |
| App 启动时连接 | 全平台 | 服务准备完成后连接默认配置 |

隐藏启动不是命令行参数，也不要求登录时启动已开启。用户手动打开 App 时，该设置同样决定初始窗口是否可见。

## 启动顺序

1. 启动早期读取“App 启动时连接”和“启动时隐藏”；读取失败按关闭处理。登录项状态不来自启动偏好，由设置页向操作系统查询。
2. 桌面窗口准备完成后，根据“启动时隐藏”显示或隐藏窗口。
3. 托盘在普通服务初始化阶段创建；所有服务准备完成后刷新托盘状态。
4. 若允许自动连接，调用新连接协调器完成资源、节点和平台准备，再启动已保存的普通或 Raw 配置。
5. 托盘初始化或自动连接失败时显示主窗口，让用户可以处理错误。

初始化使用统一流程完成隐私确认、平台 VPN 授权及必要配置。Windows/Linux 必须明确选择
出口网卡；国家/区域和添加服务器步骤可跳过，已有服务器时跳过添加。授权不启动 VPN。
进入首页前完成运行前置条件；已有服务器或有效 Raw 时可以直接连接。

隐私协议与首次初始化会抑制本次进程的自动连接，并要求显示主窗口。该抑制不改写保存的偏好。
隐私正文使用 HTTPS 页面，不在 App 内托管。

## 各平台登录项

### macOS

原生层使用 `SMAppService.mainApp`。状态可能是已启用、已关闭、需要用户批准、不可用或错误；需要批准时，界面可以打开系统的登录项设置。Dart 侧通过 Pigeon 调用原生实现。

### Windows

Microsoft Store MSIX 注册默认关闭的 package `StartupTask`，TaskId 为 `VCoreStartup`。Dart 通过 `vcore.dll` 的 `VCoreWindowsVpnInvoke` 查询、申请启用和关闭任务；用户或策略阻止启用时，设置页引导打开 `ms-settings:startupapps`。

该功能要求 package identity，未打包的 `flutter run windows` 中不可用。Windows 实现不读取或迁移 Startup Folder 快捷方式、注册表登录项及旧版偏好。StartupTask 只负责登录后启动 App；是否隐藏窗口和是否连接 VPN 仍分别由对应偏好决定。

### Linux

App 在 XDG autostart 目录管理 `net.yuandev.onexray.desktop`。优先使用 `XDG_CONFIG_HOME`，否则使用 `$HOME/.config`；无法确定目录时报告不可用。现有条目的 `Exec`、`TryExec` 或可执行文件无效时视为失效。

## 清理与失败边界

- 清理 App 数据且准备删除用户偏好时，必须先取消当前平台登录项；取消失败时停止破坏性清理。Windows 只操作当前 MSIX 的 StartupTask。恢复备份会保留登录项状态。
- 登录项注册状态由操作系统事实决定，不能只依据 Preferences 显示。
- 自动连接只执行一次。重复的服务就绪事件不得重复启动 Core。
- 自动与手动连接使用同一协调器，不回到旧 Profile 路径。配置在内存中完成解析、选择和
  校验，`run/start.json` 是交给原生宿主并供 App 重开识别当前运行的唯一描述；不创建
  `ConnectionPlan`、`run/plans/<id>` 或运行历史。
- 准备失败且尚未触碰原生宿主时，当前连接保持不变。一旦开始停止或启动原生 VPN，后续
  任一步骤失败都尽力停止本次运行并进入 `failed`，不重新启动旧连接，也不恢复旧运行输入。
- Windows 和 Linux 在旧运行停止后、每次实际启动桌面 Core 前清理整个 `run/core-inputs`，
  再生成唯一的 `core-inputs/input-*` 输入目录；输入目录不复用，也不保留历史。
- 启动过程不复制 Geodata，运行环境直接使用平铺的 `VpnConstants.datDir`；macOS System
  Extension 仅可通过既有 Swift 跨容器传输实现这一平台边界。

## 主要实现入口

- 启动编排：`lib/service/app_startup/service.dart`
- 平台分发：`lib/core/desktop_startup/`
- 首次运行与隐私流程：`lib/pages/launch/`
- 偏好：`lib/core/constants/preferences.dart`
- 初始化：`lib/service/launch/setup.dart`
- 连接协调：`lib/service/connection/coordinator.dart`
- 系统 GeoData：`lib/service/geo_data/service.dart`
