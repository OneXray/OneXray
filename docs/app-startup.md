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
3. `LaunchBootstrapService` 只检查隐私确认和首次初始化标记；任一未完成都进入同一个 Setup 流程，否则进入 Connect。它不打开数据库、不发布 Geodata，也不初始化连接服务。
4. 首次初始化通过 `SetupService` 复用存储、Geodata、平台前置条件和权限能力。首次初始化必须完成 VPN 授权及适用的 Android 局域网授权；iOS 模拟器由 Swift 返回 VPN 授权“不需要”，Dart 不按 Debug 构建跳过检查。Windows/Linux 还必须明确选择出口网卡。国家/区域和添加服务器可由用户主动跳过，已有服务器时仍显示添加步骤。Setup 不启动 VPN。
5. 进入正常主界面时，主 Shell 先以 `ServiceManager` 作为唯一就绪门，依次完成 `StoragePreparation`、Geodata 发布校验和平台运行前置条件检查；初始化成功前不构建四个业务页面，失败停留在主 Shell 的重试界面。`ConnectionCoordinator` 随后用同一次原生状态读取完成 VPN、Android 局域网及 System Extension 权限只读查询与连接状态初始化。正常启动不依赖 Setup 曾执行这些步骤。托盘在普通服务初始化阶段创建；所有服务准备完成后刷新托盘状态。连接页只管理自身数据与页面可见期间的实时流量读取。
6. 若允许自动连接，调用连接协调器完成资源和节点准备，再启动已保存的普通或 Raw 配置。已有服务器或有效 Raw 时，首页可直接连接。
7. 关键启动准备失败、就绪后的托盘刷新失败或自动连接失败时显示主窗口，让用户可以处理错误；“启动时隐藏”不能遮蔽失败和重试入口。辅助服务初始化独立捕获并记录错误，不一概阻断主界面。

隐私协议与首次初始化会抑制本次进程的自动连接，并要求显示主窗口。该抑制不改写保存的偏好。
隐私正文使用 HTTPS 页面，不在 App 内托管。

Geodata 在进程内首次准备时通过文件访问队列安装与恢复；Setup 进入主界面及打开 Geodata 页时，
已准备完成的数据只做完整性读取检查，不等待或中断导入后的后台测速。目录或发布数据完整
丢失时仍通过文件访问队列重建，部分损坏保持报错。Geodata 不关闭全局维护门；只有
清空数据会阻止新任务并等待在途任务结束，具体访问协调见 [数据管理](data-management.md)。

首次初始化的“添加服务器”步骤直接执行所选方式，不再打开通用的方式选择弹窗：
文件进入系统选择器，扫码进入扫描页，粘贴、订阅和手动添加进入对应表单。取消后返回
当前初始化步骤；文件解析、预览、校验与提交复用普通导入流程，失败仍提供反馈。
初始化导入成功不显示 Toast；正常服务器页的成功提示保持不变。
导入完成以节点成功入库为准，不要求已有延迟或位置，也不等待测速结果。Setup 期间不启动
自动测速，只展示导入/下载进度；成功后立即允许手动“进入首页”。正常服务初始化及原生
状态检查完成后，再从数据库读取未检测节点并提交现有后台测速队列，不阻塞首页就绪。

Setup 内不自动跳过或前进：隐私仍需主动同意；系统准备、适用的授权和网卡选择完成后，
点击“继续”进入地区步骤。地区识别只预选候选地区，不能把默认 CN 当成识别结果；
区域选择直接复用智能路由的直连地区页面，使用同一份已安装 Geodata 列表、搜索、单选和
“完成”操作；完成后只更新 Setup 草稿，返回或取消不改选择。点击“继续”才保存直连地区
并前进，或点击“跳过”保留原配置；主动清空后完成并继续会保存空的直连地区列表，不等同于跳过。
网卡列表仍选中即返回当前步骤。已有或新导入服务器仅更新就绪状态，仍需点击“进入首页”
完成初始化；没有服务器时保留“稍后添加”。失败停留在对应步骤，也不启动 VPN。
已完成首次初始化的用户正常启动时仍直接进入主界面；未完成的流程保留已保存步骤。

## 平台前置条件与权限

正常启动每次都检查当前平台事实，不能以 Setup 已完成作为授权或运行环境仍然有效的证明：

- 原生桥初始化必须返回非空的绝对数据根目录；Apple App Group 容器不可用等错误在任何数据库或 Geodata 访问前直接失败，不能退化为相对目录。
- Android 与 Apple 平台查询系统 VPN 授权；Android 17 及以上还检查 `ACCESS_LOCAL_NETWORK`，macOS System Extension 还查询扩展授权状态。
- Windows 检查包身份、VCore 和 `OneXrayCore.exe`；Linux 检查 Core 可执行权限、`/dev/net/tun` 以及 `cap_net_admin` / `cap_net_raw`。
- Windows/Linux 每次实际连接前按已保存名称检查 Xray 出口网卡：未设置或当前列表中不存在时，在触碰现有 VPN 与原生启动命令前失败并提示重新选择。连接建立后不持续监测网卡状态。
- 正常启动及回到前台只查询，不主动弹出系统授权界面。缺少 VPN、Android 局域网或 System Extension 授权时，连接首页保持可用并提供继续授权入口；只有用户触发后才请求授权。
- Android 通知权限仍由 `NotificationService` 在服务初始化时管理。扫码相机权限属于扫描动作，在进入扫码功能时请求，不属于启动前置条件。

除 iOS 模拟器外，首次初始化仍必须取得 VPN 授权才能完成；这项产品要求不改变正常启动的只读检查语义。
Swift 使用 `targetEnvironment(simulator)` 判断模拟器，权限查询和申请均返回“不需要”，
VPN 安装检查视为通过，不调用不可用的 NetworkExtension VPN preferences IPC。
Setup、正常启动与恢复前台统一消费原生结果；iOS 真机的 Debug 和正式构建均执行正常授权检查。
Android 17 及以上在同一授权动作中依次请求 VPN 和局域网权限，两者就绪后才能完成系统准备。
局域网权限被拒绝时保留授权入口；被永久拒绝时，再次点击入口打开系统 App 设置，返回后重新检查。
局域网授权状态直接读取系统，不写入初始化完成标记；旧版 Android 不检查或申请这项权限。

## 存储冷启动恢复

`ServiceManager` 在启用外部命令和自动连接之前处理数据库或整个 `dat` 目录丢失，使用
内置资源重建默认路由数据，不依赖网络或 Setup。部分损坏或未登记文件不能被当作完整
存储丢失而静默清理；具体恢复边界见 [数据管理](data-management.md#冷启动重建)。

## 各平台登录项

### macOS

原生层使用 `SMAppService.mainApp`。状态可能是已启用、已关闭、需要用户批准、不可用或错误；需要批准时，界面可以打开系统的登录项设置。Dart 侧通过 Pigeon 调用原生实现。

### Windows

Microsoft Store MSIX 注册默认关闭的 package `StartupTask`，TaskId 为 `VCoreStartup`。Dart 通过 `vcore.dll` 的 `VCoreWindowsVpnInvoke` 查询、申请启用和关闭任务；用户或策略阻止启用时，设置页引导打开 `ms-settings:startupapps`。

该功能要求 package identity，未打包的 `flutter run windows` 中不可用。Windows 实现不读取或迁移 Startup Folder 快捷方式、注册表登录项及旧版偏好。StartupTask 只负责登录后启动 App；是否隐藏窗口和是否连接 VPN 仍分别由对应偏好决定。

### Linux

App 在 XDG autostart 目录管理 `net.yuandev.onexray.desktop`。优先使用 `XDG_CONFIG_HOME`，否则使用 `$HOME/.config`；无法确定目录时报告不可用。现有条目的 `Exec`、`TryExec` 或可执行文件无效时视为失效。

## 清理与失败边界

- 清理 App 数据且准备删除用户偏好时，必须先取消当前平台登录项；取消失败时停止破坏性清理。Windows 只操作当前 MSIX 的 StartupTask。
- 清理成功后由清理流程重新发布内置 Geodata 与数据库元数据，再直接返回连接首页；不重置隐私和首次初始化标记，也不借助 Setup 或重启恢复运行不变量。
- 登录项注册状态由操作系统事实决定，不能只依据 Preferences 显示。
- 自动连接只执行一次。重复的服务就绪事件不得重复启动 Core。
- 自动与手动连接使用同一协调器；配置准备、原生启停、失败状态与运行输入遵循
  [连接生命周期](xray-configuration.md#运行协调与统计)。
- 连接页直接操作失败由页面反馈；通过移动端快捷方式或桌面托盘启动失败时额外发送系统通知，确保 App 不在前台时仍能看到结果。Apple 通知权限在发送此类通知时按需申请。

## 主要实现入口

- 启动编排：`lib/service/launch/app_startup.dart`
- 平台分发：`lib/core/desktop_startup/`
- 隐私与首次初始化路由：`lib/service/launch/bootstrap.dart`、`lib/pages/launch/`
- 正常服务初始化：`lib/service/manager.dart`
- 偏好：`lib/core/constants/preferences.dart`
- 存储准备：`lib/service/launch/storage_preparation.dart`
- 首次初始化：`lib/service/launch/setup.dart`
- 平台前置条件与权限：`lib/service/connect/platform_requirements.dart`
- 连接协调：`lib/service/connect/coordinator.dart`
- 系统 GeoData：`lib/service/advanced/xray/geodata/service.dart`
