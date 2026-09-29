# Android 广播自动化开发计划

状态：P0–P4 已实现并通过本地验收；其他 Android 版本、厂商设备和未安装的自动化工具仍需单独验证。
核对日期：2026-09-29。需求来源：[Issue #205](https://github.com/OneXray/OneXray/issues/205)。
源码基线：`dev-26.10.1-1`，`c466c56a5a3ff63360be9834b446474a73fbe18d`。

本计划记录本轮执行范围、验收门槛和实际结果。当前行为以
[Android 外部自动化合同](../docs/android-automation.md)为准；本地通过不等于已经提交、发布或完成其他设备验收。

## 1. 目标与首版范围

让 Android 用户通过 Tasker、MacroDroid、Automate 等工具发送带 Token 的广播，
在不打开 OneXray 窗口、不创建 Flutter 引擎的情况下启动或停止 VPN。

首版范围固定为：

- Android 专属、默认关闭的外部自动化入口。
- START 和 STOP 两个独立动作；两者都需要同一个设备专属 Token。
- START 复用最近生成的完整 `run/start.json`，沿用 Widget/Tile 的原生启动能力。
- STOP 复用现有原生停止流程，包括启动中取消；不要求配置文件或启动权限仍然存在。
- 独立设置详情页：启用开关、复制 Token、重置 Token、广播参数与使用说明。
- 配置或权限不满足时告知具体原因，由用户点击通知打开 App 处理；不强制拉起窗口。

不纳入首版：

- 按节点、订阅、位置或 Raw ID 选择配置；TOGGLE、RESTART、订阅更新等额外命令。
- 后台读取数据库并重新编译配置、测速、自动下载 Geodata 或启动失败恢复旧连接。
- HTTP API 移植到 Android、CLI、Tasker 专用插件、OAuth、远程控制服务。
- 广播查询状态、公共状态推送、回调 PendingIntent、持久命令队列或定时轮询。
- iOS、桌面端的新自动化功能，以及 libXray、VCore 改动。

## 2. 必须明确的行为合同

### 2.1 外部 Interface

以下字段在实现、测试、设置页和文档站中保持一致：

| 字段 | 目标值 |
| --- | --- |
| Target | Broadcast Receiver |
| Package | `net.yuandev.onexray` |
| Class | `net.yuandev.onexray.automation.VpnAutomationReceiver` |
| 启动 Action | `net.yuandev.onexray.action.START_VPN` |
| 停止 Action | `net.yuandev.onexray.action.STOP_VPN` |
| 必填 Extra | `token`，类型为 String |

所有使用示例都指定 Package 和 Class。首版不读取调用者提供的配置路径、JSON、
服务器 ID 或回调对象，不把调用者自报的包名作为身份认证。未知 Action 不执行。
这两个广播是本机跨 App 命令，不是 HTTP 请求；Token 放在 Extra 中，不使用 HTTP Header。

### 2.2 启动配置的准确语义

`run/start.json` 表示最近生成的完整原生启动请求，不保证是最近一次成功连接，
也不保证反映用户后来在数据库中修改的选择。修改选择后，应通过 App 正常连接一次，
使后续自动化使用新生成的请求。设置页和文档必须说明这一限制。

鉴权成功后，START 依次执行：

1. 检查是否处于禁止后台启动的清理/恢复阶段。
2. 读取现有文件并验证启动请求外层结构，不另建 Xray JSON 校验器。
3. 检查现有 VPN/局域网权限。`VpnService.prepare()` 可能改变准备状态，
   必须放在鉴权和文件结构检查之后；无效请求不得影响另一款 VPN。
4. 交给现有原生前台服务启动路径，实际资源与状态仍由 `OneVpnService` 管理。

首版不在 Receiver 中运行完整内核构造、下载或等待连接完成。外层结构通过不等于内核启动成功；
本地文件缺失、内核错误与系统拒绝继续通过现有后台启动失败路径反馈。

### 2.3 幂等、并发与结果

- 重复 START 不创建第二个 Core，也不让已连接 VPN 无故重连；重复 STOP 不报虚假失败。
- STOP 不调用 `VpnService.prepare()`，不检查启动文件，不被启动权限拒绝阻塞。
- 启动中收到 STOP，最终应停止并释放 TUN、Core、前台通知与采样。
- 停止中收到 START，不新增等待重启队列；按现有资源状态拒绝/忽略，用户稍后重试。
- 不承诺不同发送进程间的全局广播顺序；以本机实际接收和原生处理顺序为准。
- 已接受命令不等于已连接/已断开。首版不增加异步回执协议，实际结果通过现有 App、
  Widget、Tile、VPN 通知和原生日志核对；工具显示“已发送”不能计为 VPN 验收通过。
- 鉴权失败、功能关闭、未知动作静默拒绝，不触发窗口、Toast 或通知轰炸。
  合法请求的配置、权限、系统或内核失败提供具体原因，不统一降为“启动失败”。
- 需要用户处理时只提供通知点击入口；通知被拒绝时仍不自动打开 App，保留可诊断原因。
  点击后由正常 App 流程处理，不自动重放先前失败的广播。

### 2.4 Token 与持久化

- 第一次启用时生成 `ox_` 前缀加 32 字节安全随机数的 URL-safe 文本；不让用户手写短密码。
- Token 在普通重启、连接、设置调整和 App 升级后保持不变；关闭功能保留 Token，
  重新开启仍可复用。主动重置后，后续鉴权不再接受旧 Token。
- 关闭、重置不停止当前 VPN，也不撤销已通过鉴权并交付执行的命令。
- Token 独立于桌面 HTTP API，不进入数据库、连接配置、App 备份、日志、错误详情或文档示例。
- 使用 Android 私有 `noBackupFilesDir` 下的一份小型设备设置。不存在或损坏时按关闭处理；
  不因读取失败自动生成一个已启用配置。卸载/系统清除数据后重新授权。
- 设置写入集中在主 App 的 Native 桥，串行写入；同目录写入后原子替换正式文件。
  Receiver 每次读取正式文件，不通过 Flutter 单例或跨进程 SharedPreferences 缓存决定授权。
  写入失败不展示成功，也不得发布半份 Token。
- Token 只作为 String 精确比较，不自动转数字、不 trim 纠正错误凭据；错误类型安全拒绝。
  不打印整个 Intent/Bundle，不提供查询 Token 的外部广播。
- 分享自动化模板前移除真实 Token；普通工具变量只是复用方式，不宣称它们是安全密码库。

### 2.5 数据清理和备份恢复

新增 Native 入口不能绕过已有清理/恢复互斥。只在这两个破坏性操作的临界区增加
轻量、跨进程可见的 START 阻断；不恢复通用 DataMaintenance，不扩展到测速或普通保存。

- 在停止 VPN 和替换数据前完成 START 阻断；不能建立阻断时，不进入破坏性操作。
- 阻断期间仍允许已授权的 STOP；正在启动的请求交由现有停止机制取消。
- 清理全部用户数据时，关闭并删除自动化授权；不能仅删除 Dart Preferences。
- 备份和恢复不携带、不修改设备 Token/启用偏好；恢复期间阻断 START，完成后按现有合同恢复受理。
  恢复本身不生成新的 `start.json`，不能把恢复数据等同于更新了自动化启动配置。
- 中途进程异常退出时保持保守阻断，由下次正常 App 数据准备完成后解除。
  该标记只保护破坏性写入，不缓存 VPN 状态，不引入自动恢复连接。
- Native 设置页、数据清理和 Receiver 的读写约束在一个 Module 内实现，不让页面各自操作文件。

## 3. 界面与实现组织

### 3.1 界面

在“高级 → VPN 隧道 → Android 系统 VPN”增加“外部自动化”详情入口，
以 `pushScoped` 留在当前根 Tab。非 Android 不显示入口，也不注册可访问的详情路由。

详情页复用共享主题、`PageAppBar`、设置行和局部 loading：

- “允许外部自动化”默认关闭；变更立即保存，失败恢复原显示并展示具体原因。
- 开启后提供复制 Token、重置 Token；重置前确认会使旧自动化任务失效。
- 展示并支持复制公开的包名、接收器和两个 Action，Token 不默认明文展开。
- 提示“使用最近生成的连接配置”“首次授权需在 App 内完成”，并链接三款工具的设置说明。
- 不复用 VPN 策略草稿，不要求点“保存并重新连接”；授权修改不重连、不影响按应用分流草稿。
- 保存/复制等异步动作只有对应控件 loading；沿用成功 Toast，不全局锁定交互。
- 新文案补齐现有五种语言；Token、Action、包名按 LTR 显示，覆盖波斯语和大字号。

### 3.2 Module 与复用点

按 codebase-design 的小 Interface 原则，只新增 Android 自动化 Module；
广播 Receiver 是 Adapter，调用已有原生启停 Implementation，不建设第二套连接协调器。

| 位置 | 职责与改动范围 |
| --- | --- |
| `android/.../automation/`（新增） | 授权设置、广播解析/鉴权、有限的清理/恢复阻断及命令交付 |
| [AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) | 新增 exported Receiver，放入已有 `:native` 进程；保留 VPN service、Widget、Tile 的原有保护 |
| [VpnController.kt](../android/app/src/main/kotlin/net/yuandev/onexray/vpn/VpnController.kt) | 复用启停；调整 saved-start 的文件/权限顺序与必要失败原因，保留 Widget/Tile 原有点击回退 |
| [SavedVpnConfig.kt](../android/app/src/main/kotlin/net/yuandev/onexray/vpn/SavedVpnConfig.kt) | 继续解析现有启动请求，只做必要外层检查 |
| [OneVpnService.kt](../android/app/src/main/kotlin/net/yuandev/onexray/vpn/OneVpnService.kt) | 保持唯一运行所有者；只修复本功能验收确证的启停/反馈缺口 |
| [Pigeon 源文件](../pigeon/message.dart)、[MainActivity.kt](../android/app/src/main/kotlin/net/yuandev/onexray/MainActivity.kt) | 增加 Android 专属的最小设置桥；生成 Dart/Kotlin/Swift，不手改生成文件 |
| `lib/service/advanced/tunnel/android/automation/`（新增） | Dart 的设置访问与操作结果，不管理 VPN 状态或另存 Token |
| `lib/pages/advanced/tunnel/android/automation/`（新增） | `PageCubit`、详情页和局部 loading |
| [导航注册](../lib/pages/main/navigation.dart)、[页面构建](../lib/pages/main/url.dart)、[Android VPN 页](../lib/pages/advanced/tunnel/android/page.dart) | 当前 Tab 内入口与平台限制 |
| [数据清理](../lib/service/settings/data_cleanup.dart)及正常服务初始化 | 在既有清理/恢复临界区对接 Native 阻断、授权删除及崩溃后解除 |

不需要新第三方依赖、数据库列/迁移、Xray 配置字段或常驻 Flutter 后台引擎。
若实现暴露上述前提不成立，先停下说明，不自行扩大到其他仓库或新后台架构。

## 4. 开发阶段与验收门槛

| 顺序 | 阶段 | 交付物 | 进入下一阶段的条件 |
| --- | --- | --- | --- |
| P0 | 基线与验收准备 | 当前源码/设备记录、隔离测试数据、场景清单 | 设备和数据隔离方式可用；无冲突改动；合同无未决核心问题 |
| P1 | Native 自动化 Module | Token 设置、Receiver、原生启停接入、针对性测试 | 未授权无副作用；正确命令可交付；原生测试和 Android 检查通过 |
| P2 | App 设置与清理/恢复接入 | 设置桥、Android UI、语言、数据操作联动 | 页面及跨进程授权测试通过；不重连、不跨 Tab、非 Android 无入口 |
| P3 | Android 真正后台验收 | API 37 模拟器证据、独立发送端和工具联调 | 下列核心设备验收全部通过，不能用 shell 发送成功替代 |
| P4 | 回归与使用文档 | 现行合同、网站操作说明、完整验证记录 | 自动检查通过；已测/未测范围明确；所有核心失败已修复或停止交付 |

### P0：基线与准备

1. 复核当前分支、未提交改动、现行代码和本计划。不因基线改变覆盖其他任务的改动。
2. 确认 Flutter/Dart 没有并发命令；需停止他人 Debug/daemon 时先获得许可。
3. 在当前模拟器记录 API、安装版本、通知/VPN 权限及已有连接状态，不擅自清空或卸载 App。
4. 准备隔离测试配置和必要资源；测试数据、合法官方工具包、最小发送端及证据统一放在
   工作空间 `references/android-intent-automation/`，不使用系统临时目录或开发者主数据库。
5. 正向测试需要一个已在 App 内正常连接的测试配置；无外网节点时，可用隔离的最小配置验证
   TUN/生命周期，但必须把真实代理联网列为未通过，不能冒充完整验收。

验收：具备可复现的准备/恢复步骤，测试凭据不提交、不出现在截图或可分享日志中。
实际使用 `emulator-5554` 的独立用户 10；保留用户 0 的数据库与原安装 APK，测试凭据只存于本地 references。

### P1：原生实现

1. 先实现小型授权设置存储和请求解析，覆盖默认关闭、生成、保存失败、重置、类型错误等测试。
2. 新增只包含两个 Action 的 Receiver；先鉴权再调用生命周期，不导出内部 Widget/STOP 通道。
3. 在既有 saved-start 中按“文件外层检查 → 权限 → 原生交付”组织逻辑，保留系统/内核实际错误。
4. 接入短时 Receiver 工作，不阻塞等待 VPN 连接；确需异步时正确结束 `goAsync()`，
   不新增 WorkManager、后台轮询或 Activity 跳板。
5. 补充 Native 测试：使用正式 Module 的 Interface，注入必要的平台调用替身；
   不另写一套测试专用 Receiver 行为。
6. 跑 JVM/Robolectric、Debug 构建和 Release Manifest/Lint，验证合并后的 exported/process/permission。

验收：

- [x] 未启用、缺失/错误/非字符串 Token、未知 Action、损坏设置均不调用 prepare/start/stop，不改文件。
- [x] Token 关闭/重置后，已有 `:native` 进程的下一次请求立即按最新正式文件鉴权。
- [x] 已授权但缺少/损坏启动请求时，先报配置问题；文件先于权限的调用顺序由 Native 测试与设备失败场景核对，未另装第二款 VPN。
- [x] STOP 在启动文件缺失、VPN/LAN 权限不满足时仍走停止路径。
- [x] 重复 START/STOP 和启动中 STOP 不产生第二个 Core 或遗留 TUN；仅覆盖本轮观察窗口，不声明长期资源无泄漏。
- [x] 普通 App、Widget、Tile、通知停止入口的保护和既有行为不退化。

### P2：设置与 App 集成

1. 增加最小 Android 设置桥及 Dart 访问，不借用桌面 HTTP Token、数据库或 VPN 策略对象。
2. 实现详情页和当前 Tab 内导航；复制/重置/开关操作共享一份已保存状态。
3. 在既有清理/恢复的狭窄临界区接入跨进程 START 阻断；清理删除设备授权，恢复不携带授权。
4. 正常 App 就绪时处理异常遗留的阻断；不放进 Setup，也不自动重连。
5. 补齐 ARB 与 Native 用户可见提示，重新生成代码；补页面、路由、桥和清理/恢复测试。

验收：

- [x] 首次关闭；开启、返回、重开页面与进程重启后状态正确，不生成额外 Token。
- [x] 复制值可用于正向广播；重置确认后旧值失效；保存失败不显示成功。
- [x] 开关/重置不改变当前 VPN、运行配置、按应用分流草稿或其他设置。
- [x] 清理/恢复入口的先阻断后停机顺序及失败释放通过测试；设备阻断时 START 拒绝、STOP 可用，正常冷启动解除异常遗留标记。
- [x] 实际恢复后授权文件哈希不变；实际清除数据后授权文件删除，旧 Token 无效。
- [x] Android 导航、五语言、RTL、深浅色和大字号 Widget 测试通过；非 Android 无入口或可用详情路由。设备截图核对简体中文页面。

### P3：模拟器与自动化工具

使用当前 API 37 模拟器。开发阶段实际启动 VPN，并验证经过代理的 HTTPS 请求。
优先用 Flutter Debug 观察 UI 和 Native 日志，必要时使用 Android 截图；所有 Flutter/Dart 命令串行。

建立一个最小独立 Android 发送 APK：不同 UID、普通权限，只填写目标、动作、Token 和单次延迟发送。
使用按钮安排延迟后返回桌面，再由进程发送；避免让 OneXray 的 instrumentation 或 `adb shell am broadcast`
成为唯一发送者。它只验证广播身份/后台条件，不建设生产自动化框架；实际工具后台触发另外验收。

| 必测场景 | 操作 | 通过标准 |
| --- | --- | --- |
| 真正后台启动 | OneXray 不在前台，第三方进程后台发送合法 START | 不出现 OneXray Activity；TUN/前台服务与通知实际建立；测试代理请求成功 |
| Flutter 未运行 | 使用非 force-stop 的方式结束无活动 VPN 的 App 进程后发送 START | 仅 Native 路径完成连接；不拉起 Flutter/UI；冷进程场景与强行停止明确区分 |
| 后台停止 | 已连接时发送合法 STOP | Core/TUN/采样关闭，前台通知结束，App/Widget/Tile 恢复断开状态 |
| 重复与取消 | 重复 START、重复 STOP、START 后立即 STOP | 无重复运行；最后已受理的 STOP 能停止启动；不自动恢复旧连接 |
| 授权更新 | Native 存活时关闭、重新开启、重置 Token | 后续请求服从新状态；旧 Token 被拒；当前连接不被重置操作停止 |
| 未授权请求 | 错误/缺失/错误类型 Token、未知动作、设置损坏 | 无窗口、权限框、通知、准备状态或 VPN 改变；不输出 Token |
| 无可用文件 | 删除/损坏隔离启动请求后发送 START | 不启动，不下载兜底；通知明确提示先在 App 配置/连接 |
| 启动权限缺失 | 分别撤销测试 VPN、API 37 LAN 授权 | 不强制弹框/打开 App；通知点击能进入正常处理；STOP 不受限制 |
| 通知权限拒绝 | 合法请求失败但通知不可见 | 不崩溃、不拉起 Activity，不把发送请求当连接成功；可通过 App/日志诊断 |
| 内核/资源失败 | 测试端口冲突、必要本地资源缺失等 | 原生实际失败，不遗留 VPN 状态或通知，不偷偷下载/重试旧配置 |
| 清理与恢复 | 测试数据操作期间发送 START/STOP | START 不与替换文件竞争，STOP 可执行；授权清理/保留符合 P2 |
| 既有入口 | 手动连接、Widget、Tile、快捷项、通知停止 | 原有入口仍可用，自动化关闭时也不影响它们 |

工具联调要求：

1. 至少完成 MacroDroid 或 Automate 一款真实工具的后台触发、START/STOP、错误 Token 与重置复测，
   再加独立发送端验证，才能把首版核心后台能力标为通过。
2. 尽量分别验证 Tasker、MacroDroid、Automate 的真实填写方式；每款记录版本、字段、触发方式、
   结果与证据。Token 用可替换变量配置时，再验证变量替换和更新。
3. 只使用合法官方来源；需要付费、登录或缺少可用包时记录未测，不绕过授权，也不把其他工具
   成功当作该工具已通过。对外只声明实际验证过的工具，其余注明文档支持、待实测。
4. 强行停止、重启后首次解锁前、Doze/OEM 省电和另一款 always-on/lockdown VPN 单列边界，
   不承诺绕过系统限制。至少验证可复现的拒绝/恢复行为；其他 API/OEM 进入后续真机矩阵。
5. 结束后恢复模拟器原有连接状态，移除本轮测试接收/发送设置；不删除用户服务器数据。

### P4：回归与文档收口

1. 按改动范围运行 Flutter 与 Native 回归、Android Debug 构建和 Release Lint；
   检查代码生成、平台隔离、依赖分层与差异。只运行本地构建，不执行上传商店的脚本。
2. 更新 [导航](../docs/app-navigation.md)、[启动](../docs/app-startup.md)、
   [验证](../docs/refactor-validation.md)等受影响合同：将“移动端不接入系统自动化”准确收敛为
   Android 的上述有限例外，iOS 行为不变。授权不进入备份的约束同步到备份合同。
3. 在 onexray.com 的 Android VPN/快捷入口说明中提供三款工具的广播参数、Token 操作、
   配置版本语义、权限/后台限制与排障，不新增另一套互相冲突的 HTTP/CLI 指南。
   网站内容按现有语言与校验流程维护；实测范围与能力依据分开。
4. 逐项填写下面的验收记录；阻断项未通过不得写“全部完成”。
   核心项通过但旧 Android/OEM 未测时明确保留后续矩阵，不以 API 37 模拟器代表所有设备。

验证入口（按实际改动选择，Flutter/Dart 全局串行）：

```shell
dart run pigeon --input pigeon/message.dart
flutter gen-l10n
dart run tool/check_native_model_contract.dart
dart run tool/check_layer_dependencies.dart
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test <本阶段相关测试目录>
flutter build apk --debug
# 在 android/ 中运行：
./gradlew :app:testDebugUnitTest :app:lintVitalRelease
git diff --check
```

是否需要其他平台本地构建按桥接变化判断；macOS 不启动 VPN、不截图，
Windows/Linux 不在当前主机强行编译。跨平台生成检查不等于各系统运行验收。

## 5. 执行、停止与验收记录

- 本轮已按 P0 → P1 → P2 → P3 → P4 执行，前一阶段门槛通过再进入下一阶段。
- 每阶段记录改动、命令、结果、设备证据与未测项。后续如授权按阶段 commit，
  只提交本阶段实际修改的仓库，不为 libXray/VCore 创建空提交。
  本次实施未执行 commit、push、PR、商店操作或 Issue 回复。
- 不能靠打开 OneXray 主界面、shell 权限或新 Flutter 引擎才启动成功时，核心目标未达到，
  停止并说明；不要悄悄把“后台启动”降级为“打开 App”。
- 构建/核心测试失败、API 37 后台限制阻止方案、需要新增生产依赖/平台权限或扩展范围时，
  先报告问题；不得跳过失败去标记后续阶段完成。
- 全部证据只覆盖当时的提交、工具版本和设备；凭据和真实配置不写入 Git。

| 项目 | 当前状态 | 验收证据 |
| --- | --- | --- |
| 设备准备 / P0 | 通过 | API 37 arm64；独立用户 10；原用户 0 数据未读取或清理；原 APK 留存用于还原 |
| P1 | 通过 | Native 全量 45 项测试；Debug APK、Release Manifest 和 Lint；广播鉴权与文件/权限顺序 |
| P2 | 通过 | Android 详情页、作用域路由、五语言/RTL/深浅色/320px/1.5 倍字号；复制、重置、写入失败、清理/恢复测试 |
| P3 | 通过本轮核心门槛 | 独立普通 UID 发送端 + Automate 1.53.2；后台 START/STOP、无 Flutter 冷进程、HTTPS 204、授权撤销、失败场景与既有入口 |
| P4 | 通过 | Flutter 全量 1,368 项通过 / 6 项按既有条件跳过；analyze、生成合同、分层检查、Android 构建/Lint；Hugo 及文档/SEO检查 |
| 其他 Android API/OEM | 未验证 | 按实际设备单独记录，不算模拟器已覆盖 |

验收后已停止测试 VPN、删除本轮创建的用户 10 和独立发送端，并切回用户 0。
原 APK 已还原且校验一致；原用户数据库未读取或清理，用户安装的 Automate 保留。

本地详细证据：[validation.md](../../references/android-intent-automation/validation.md)。
其中日志、截图、最小独立发送 APK 和私有测试配置不进入 App Git 仓库。

### 实测结果与边界

- Automate 1.53.2 使用 Flow beginning → Delay（10 秒）→ Broadcast send，返回桌面后发送。
  Action 使用带引号的表达式，Extras 使用 `{"token":"YOUR_TOKEN"}` 字典；明确填写 Package/Class。
  后台启停、错误 Token、重置后旧 Token 拒绝以及更新 Token 后恢复均通过。
- 独立发送 APK 与 OneXray 使用不同 UID、只有普通 INTERNET 权限；延迟发送时桌面处于前台。
  使用 `am kill` 结束空闲 App 进程后，仅 `:native` 完成连接；实际 HTTPS 返回 204。
- 重复命令、启动中停止、缺失/损坏启动文件、撤销 VPN/LAN/通知权限、非法内核协议、损坏授权均已测试。
  合法失败不自动启动 Activity；未授权请求无用户反馈或生命周期副作用。
- 自动化关闭时实际 App、Widget、Tile、桌面图标快捷项和通知停止仍可工作。
  恢复和清除数据由实际 App 页面触发；阻断期间命令和交付顺序另外通过设备标记测试及单元测试覆盖，
  不宣称已穷举破坏性操作的所有并发时序。
- 当前 API 37 设备在 force-stop 后仍可接收显式第三方广播并启动；这是一条设备观测，
  不是“所有强行停止都可恢复”或“所有系统都拒绝”的承诺。
- Tasker/MacroDroid 未实际安装验证；网站为其提供参数填写说明，但不列为设备通过。
  其他 Android API/OEM、Doze、重启未解锁和另一个 always-on/lockdown VPN 均留待真机矩阵。
- 没有修改 libXray/VCore、数据库结构、桌面 HTTP API 或其他平台运行入口，也未新增生产依赖。

## 6. 调研依据

- [Android 实现可行性与当前源码入口](../../references/issue-205-android-intent-automation.md)。
- [Token 与自动化工具兼容性](../../references/issue-205-token-client-compatibility.md)。
- [Android 广播与安全](https://developer.android.com/develop/background-work/background-tasks/broadcasts)。
- [后台启动 Activity 限制](https://developer.android.com/guide/components/activities/secure-bal)。
- [Tasker Send Intent](https://tasker.joaoapps.com/userguide/en/intents.html)。
- [Automate Broadcast send](https://llamalab.com/automate/doc/block/broadcast_send.html)。
- [MacroDroid Send Intent](https://macrodroidforum.com/wiki/index.php?title=Action:_Send_Intent)。
- [AdGuard 带密码的自动化先例](https://adguard.com/kb/adguard-for-android/solving-problems/tasker/)。

调研证实参数传递和既有 Android 机制，不代替本计划要求的真实后台启动验收。
