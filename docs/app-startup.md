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
3. `LaunchBootstrapService` 只根据隐私确认和首次初始化状态选择 Privacy、Setup 或 Connect；它不打开数据库、不发布 Geodata，也不初始化连接服务。
4. 首次初始化通过 `SetupService` 复用存储、Geodata、平台前置条件和权限能力。首次初始化必须完成 VPN 授权；Windows/Linux 还必须明确选择出口网卡。国家/区域和添加服务器可跳过，已有服务器时跳过添加。Setup 不启动 VPN。
5. 进入正常主界面时，主 Shell 先以 `ServiceManager` 作为唯一就绪门，依次完成 `StoragePreparation`、Geodata 发布校验和平台运行前置条件检查；初始化成功前不构建四个业务页面，失败停留在主 Shell 的重试界面。`ConnectionCoordinator` 随后用同一次原生状态读取完成 VPN / System Extension 权限只读查询与连接状态初始化。正常启动不依赖 Setup 曾执行这些步骤。托盘在普通服务初始化阶段创建；所有服务准备完成后刷新托盘状态。连接页只管理自身数据与页面可见期间的实时流量读取。
6. 若允许自动连接，调用连接协调器完成资源和节点准备，再启动已保存的普通或 Raw 配置。已有服务器或有效 Raw 时，首页可直接连接。
7. 任一正常服务初始化、托盘刷新或自动连接失败时显示主窗口，让用户可以处理错误；“启动时隐藏”不能遮蔽失败和重试入口。

隐私协议与首次初始化会抑制本次进程的自动连接，并要求显示主窗口。该抑制不改写保存的偏好。
隐私正文使用 HTTPS 页面，不在 App 内托管。

## 平台前置条件与权限

正常启动每次都检查当前平台事实，不能以 Setup 已完成作为授权或运行环境仍然有效的证明：

- 原生桥初始化必须返回非空的绝对数据根目录；Apple App Group 容器不可用等错误在任何数据库或 Geodata 访问前直接失败，不能退化为相对目录。
- Android 与 Apple 平台查询系统 VPN 授权；macOS System Extension 还查询扩展授权状态。
- Windows 检查包身份、VCore 和 `OneXrayCore.exe`；Linux 检查 Core 可执行权限、`/dev/net/tun` 以及 `cap_net_admin` / `cap_net_raw`。
- Windows/Linux 每次实际连接前按已保存名称检查 Xray 出口网卡：未设置或当前列表中不存在时，在触碰现有 VPN 与原生启动命令前失败并提示重新选择。连接建立后不持续监测网卡状态。
- 正常启动只查询，不主动弹出系统授权界面。缺少 VPN 或 System Extension 授权时，连接首页保持可用并提供继续授权入口；只有用户触发后才请求授权。
- Android 通知权限仍由 `NotificationService` 在服务初始化时管理。扫码相机权限属于扫描动作，在进入扫码功能时请求，不属于启动前置条件。

首次初始化仍必须取得 VPN 授权才能完成；这项产品要求不改变正常启动的只读检查语义。

## 存储冷启动恢复

恢复发生在 `ServiceManager` 启用外部命令和自动连接之前：

- 数据库文件在冷启动前已丢失时，创建全新的 schema 3。由于原 Geodata manifest 同时丢失，平铺目录里的 orphan 文件不能被推断为已注册数据，全部丢弃并从 App 资源重建默认 `geoip.dat` / `geosite.dat` 组。
- 整个 `dat` 根目录缺失，或目录为空但数据库仍有发布元数据时，文件已经不可恢复；清除对应 Geodata 元数据并重建默认组。
- 只有完整存储单元丢失时执行上述收敛恢复。部分文件损坏、嵌套文件、默认组不完整，以及没有明确“数据库本次冷启动前不存在”信号的 orphan 文件继续视为错误，避免把未知文件静默纳入或删除。

重建默认组只使用随 App 提供的资源，不依赖网络；自定义 Geodata 在数据库或整个数据目录丢失后无法恢复。

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
- 清理成功后由清理流程重新发布内置 Geodata 与数据库元数据，再直接返回连接首页；不重置隐私和首次初始化标记，也不借助 Setup 或重启恢复运行不变量。
- 登录项注册状态由操作系统事实决定，不能只依据 Preferences 显示。
- 自动连接只执行一次。重复的服务就绪事件不得重复启动 Core。
- 自动与手动连接使用同一协调器，不回到旧 Profile 路径。配置在内存中完成解析、选择和
  校验，`run/start.json` 是交给原生宿主并供 App 重开识别当前运行的唯一描述；不创建
  `ConnectionPlan`、`run/plans/<id>` 或运行历史。
- 连接页直接操作失败由页面反馈；通过移动端快捷方式或桌面托盘启动失败时额外发送系统通知，确保 App 不在前台时仍能看到结果。Apple 通知权限只在首次实际发送此类通知时请求。
- 准备失败且尚未触碰原生宿主时，当前连接保持不变。一旦开始停止或启动原生 VPN，后续
  任一步骤失败都尽力停止本次运行并进入 `failed`，不重新启动旧连接，也不恢复旧运行输入。
- Windows 和 Linux 在旧运行停止后、每次实际启动桌面 Core 前清理整个 `run/core-inputs`，
  再生成唯一的 `core-inputs/input-*` 输入目录；输入目录不复用，也不保留历史。
- 启动过程不复制 Geodata，运行环境直接使用平铺的 `VpnConstants.datDir`；macOS System
  Extension 仅可通过既有 Swift 跨容器传输实现这一平台边界。

## 主要实现入口

- 启动编排：`lib/service/app_startup/service.dart`
- 平台分发：`lib/core/desktop_startup/`
- 隐私与首次初始化路由：`lib/service/launch/bootstrap.dart`、`lib/pages/launch/`
- 正常服务初始化：`lib/service/manager.dart`
- 偏好：`lib/core/constants/preferences.dart`
- 存储准备：`lib/service/launch/storage_preparation.dart`
- 首次初始化：`lib/service/launch/setup.dart`
- 平台前置条件与权限：`lib/service/connection/platform_requirements.dart`
- 连接协调：`lib/service/connection/coordinator.dart`
- 系统 GeoData：`lib/service/geo_data/service.dart`
