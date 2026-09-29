# Android 外部自动化

Android 提供默认关闭的广播入口，供 Tasker、MacroDroid、Automate 等本机工具启动或停止 VPN。
设置位于高级 → VPN 隧道 → Android 系统 VPN → 外部自动化；详情页留在当前 Tab。
开关立即保存，重置 Token 需确认；这两项都不重连、不改变应用分流草稿。
非 Android 不注册入口或详情路由；桌面 HTTP API 的 Token 和接口与此独立。

## 广播合同

| 参数 | 值 |
| --- | --- |
| 类型 | Broadcast Receiver |
| Package | `net.yuandev.onexray` |
| Class | `net.yuandev.onexray.automation.VpnAutomationReceiver` |
| START Action | `net.yuandev.onexray.action.START_VPN` |
| STOP Action | `net.yuandev.onexray.action.STOP_VPN` |
| Extra | `token`，精确的 String 值 |

接收器只处理两个动作，不接受配置路径、节点选择、回调地址或调用者声明的身份。
未知动作、关闭状态、凭据缺失/类型错误/不匹配均静默拒绝；鉴权前不检查 VPN 权限或修改运行状态。
Token 不是 HTTP Header，也不提供公开的 Token 查询或状态广播。

## 原生运行边界

接收器运行在已有 `:native` 进程，是现有 `VpnController` / `OneVpnService` 的适配层。
不创建 Flutter 引擎，不启动 Activity，不新增 Core、配置编译器、后台队列或轮询器。

- START 使用最近生成的完整 `run/start.json`。它不保证是最后一次成功连接，也不会追随后来
  在数据库中修改的选择；修改配置后，先从 App 正常连接一次。
- 顺序为鉴权 → 清理/恢复阻断 → 启动请求外层读取 → VPN/LAN 权限查询 → 原生启动。
  文件外层检查在 `VpnService.prepare()` 前完成；实际配置和资源错误仍交给内核。
- 缺少配置、权限或资源时只报告具体原因，保留通知点击入口；不自动打开 App、下载文件、
  重试或回退旧连接。通知权限被拒绝时仍不拉起 App，原生日志保留原因。
- STOP 不读取启动文件、不检查启动权限，也不受 START 阻断限制。重复 START 不重复启动
  Core，重复 STOP 可接受；启动中 STOP 复用现有停止标记与释放流程。
- 已交付不等于已完成。工具显示“已发送”不是连接成功证明；实际状态由原生运行资源及现有
  App、Widget、Tile、VPN 通知体现。不同发送进程间不承诺全局顺序。

系统强制停止、重启后未解锁、Doze、OEM 省电和其他 always-on/lockdown VPN 属于系统边界；
本功能不绕过这些限制。Widget/Tile 保留缺配置时打开 App 的原行为，广播不使用该回退。

## 设备授权与数据操作

`AutomationStore` 在私有 `noBackupFilesDir` 管理一份授权。主 App 的 Android 专属 Pigeon 桥
是唯一写入入口；同目录临时写入、同步后原子替换。接收器每次重新读取正式文件，不使用跨进程缓存。
不存在、损坏、超限或未完成发布的设置按关闭处理。

首次开启生成 `ox_` 加 32 字节安全随机数的 URL-safe Token。关闭保留 Token，再开启复用；
只有显式重置才更换。关闭或重置只影响后续鉴权，不撤销已交付命令，也不停止当前连接。
Token 不进入数据库、连接配置、日志、错误详情、剪贴板参数示例或 App 备份。
用户主动复制时才写入剪贴板；分享自动化任务前应删除实际 Token。

清理和恢复沿用 `AppDataCleanupService` 的狭窄临界区：

1. 停止 VPN 和替换数据前，先建立跨进程 START 阻断；建立失败则不进入破坏性操作。
2. 阻断期间仍接收已授权 STOP，设置桥不允许同时启用或重置授权。
3. 清理全部数据删除授权；备份恢复保留目标设备授权，不从备份携带授权。
4. 正常退出临界区解除阻断。异常退出遗留标记时，下次 `ServiceManager` 完成存储与协调器
   准备后解除；不依赖 Setup，不自动恢复连接。

`OneVpnService` 在接收外部启动命令时再次检查阻断，覆盖广播已交付但服务尚未处理的窗口。
此标记只控制破坏性操作期间的启动准入，不保存 VPN 状态，也不扩展到测速或普通保存。

## 验证与使用说明

设置/路由/清理测试覆盖 Android 隔离、五语言、RTL、大小字体、授权保存失败与恢复保留。
Native 测试覆盖授权、广播拒绝、桥接、文件/权限顺序及服务保护。设备验收必须包含普通第三方
UID 的真正后台启停，以及至少一款真实自动化工具；shell 广播或单元测试不能替代。

设备与工具结果见[开发计划](../plans/android-intent-automation.md#5-执行停止与验收记录)；
用户参数、三款工具填写方式和排障见[文档站](https://onexray.com/zh/docs/advanced/android/#automation)。
