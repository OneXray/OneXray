# App 重构实施记录

2026-09-02。产品与阶段定义位于工作空间
`references/onexray-app-prototype/{PRODUCT-MODEL,DEVELOPMENT,APP-REFACTOR-PLAN}.md`。
最小验证工程与完整结果位于 `references/onexray-refactor-validation/`，不使用系统临时目录。

## P0：基线与风险验证

基线：OneXray `3edb2dd`、libXray `c871d2e`、VCore `fb1b53f`。
实际 Android AAR 与 libXray 锁定核心均为 Xray 26.7.28（`5ca6f4b7d4dc`）。
Flutter 3.47.2 / Dart 3.13.2，Android API 37 模拟器。

| 项目 | 本阶段证据与边界 |
| --- | --- |
| G0 | Windows bridge v3、必填完整 policy、生成模型与纯 Dart 契约测试通过；实际 DLL/安装包留手测 |
| G1 | Android 1/2/3 接入节点及每接入对应一个最终出口副本，TCP/UDP、每条接入实际计数通过；本机 SOCKS 固定样例，不代表所有远端协议 |
| G2 | 锁定核心用户态验证域名未命中后 IP 二次匹配、默认 loopback 均衡、空候选 block；生成器接入和 Android 完整路由验收在 P2 |
| G3 | Android VPN `:native` 与 App 临时核心隔离：并发 testXray 后 TCP 和计数不变；App Invoke 增加串行化。Apple 扩展边界保留、互斥代码编译通过；其他平台及 iOS Debug 同进程限制留运行阶段 |
| G4 | 直接使用核心草稿 Router 验证 ruleTag/动作及默认解释，不发布访问流量；公开 Invoke 待 P2 接入 |
| G5 | Android 空有效允许列表在建立隧道前失败，未报告 connected；排除列表为空正常运行。页面保存/连接提示待 P7 |
| G6 | Android 授权不启动 VPN 通过；Apple 查询不隐式创建、申请准备不启动、保存失败返回失败、重建连接态不伪报断开，macOS Debug 编译通过；Apple 实际系统授权留手测 |
| G7 | 两个 8.8.8.8 逻辑 DNS 的不同路由 tag、direct 非通用 fallback、代理节点域名引导在本地 UDP 捕获验证通过；不冒充外部 Google DNS 可达性 |
| G8 | Android UI PID 被终止后，原 VPN 宿主继续转发；tunIn 上行 6182→6212、下行 15012→15097，重开 UI 收到真实 connected。采样由宿主承担；30 秒保存、会话水位/重置/结算在 P3 交付，不把此实验当作最终累计功能 |
| G9 | 不可变 generation 目录 + SQLite 单一发布行：提交前故障保留旧代、提交后恢复新代、旧会话固定旧代、Raw ext 文件名不变；固定小 fixture，不代表实际 protobuf/平台权限验证，生产接入在数据维护阶段 |

G2 的具体约束：roundRobin 的 `fallbackTag: block` 需要
`observatory: {subjectSelector: []}` 满足锁定核心的依赖；空 selector 不发探测。
不能省略该依赖，也不能用无条件末尾规则替代 IP 二次匹配。

验证入口不读取开发者主数据库。Android 完成后通过系统 VPN 页正常断开。
macOS 仅构建独立验证入口，没有启动 VPN，没有截图/录屏。
Windows、Linux 原生构建和运行均 **NOT RUN**，纯共享 Dart 测试不等于平台验收。

执行：Pigeon / build_runner 生成、原生模型契约、分层检查；Windows 纯契约与 P1
存储基础合计 25 项通过、1 项 Windows 原生测试跳过。Apple 原生代码由独立入口
`flutter build macos --debug -t ../references/onexray-refactor-validation/android-main.dart`
验证；完整 App 待 P1 服务接线后构建。

本机 Flutter Debug/测试需对单次进程移除 `http_proxy` / `https_proxy` 并设置 localhost
的 `no_proxy`，否则 VM WebSocket 被代理返回错误；不修改系统代理配置。

P0 关闭的是可行性调查阶段，不代表 G0–G9 的完整产品交付。未完成项已对应到后续阶段，
最终全站/平台矩阵不得将它们预先标记为通过。libXray 本阶段无源码改动。

## P1：存储与资产基础

- 在原路径将 schema v1/v2 原位升级到 v3。升级前暂停业务、停止旧运行并以 SQLite
  backup 保存包含 WAL 的一致性快照；DDL、保留列核对和版本号在同一事务提交。
  失败关闭连接、保留原库并提供重试，不清库或自动进入首页。
- 保留 CoreConfig / Subscription / GeoData 的原行与 base64，追加节点探测元数据、
  收藏和订阅失败数，新建 CustomRoutingProfiles。旧 Raw 超额完整保留；普通资产新增
  在事务内限制数量；退休类型退出查询、测速、分享、写入与运行入口。
- Preferences 使用新的 app2 命名空间。资产写入、订阅、测速落库、Geodata 和清理
  纳入维护门，覆盖恢复等待已有写任务结束并拒绝迟到写入。
- 订阅只以非空有效结果覆盖，保护运行/固定/最终出口引用与收藏的原行，保留行不计入
  本次导入数；并行编辑/更新使用来源代次检查。完整运行快照的引用接线在 P3，准确的
  解析失败计数由 P5 的 libXray 扩展提供，当前未知结果不伪造数量。
- ZIP 写 v5、读 v3/v4/v5；保留 Age、ID、全部 Raw 与新增资产/元数据，旧退休类型跳过。
  文件暂存、数据库事务及回滚已有定向验证；Geodata generation 的生产发布在 P7 完成。

验证结果：97 项存储/订阅/维护/分享定向测试通过；全量 342 项通过、1 项 Windows
原生测试跳过。最终补充的退休运行入口和订阅行 UI 回归也通过。静态分析、原生模型契约、
分层检查、完整 App 的 macOS Debug 构建通过；没有启动 macOS VPN 或截图。

Android 运行 `references/onexray-refactor-validation/android-storage.dart`：只打开应用
私有 `p1-storage-1788359907872720/legacy-v2.sqlite` 固定测试库，实际验证 WAL 快照、
v2→v3、Age/ID/subId/base64 原值保留、4 份 Raw、新 Custom 写读、关闭重开和 quick_check。
所有检查通过；不读取开发者主数据库，不调用 VPN。v1 与错误注入在 Dart SQLite 测试覆盖。

P1 不代表新连接/新 UI 已启用；后续按 P2→P9 继续。libXray 本阶段无源码改动。

## P2：配置编译与节点解析

- 新增不依赖 Profile 的值编译器：普通模式固定 `proxy` balancer / 完整 selector，
  1–3 接入、逐接入最终出口副本、默认 loopback、双 Google DNS 和 App 运行字段。
  Raw 原文不变，额外 inbound / 非统计 policy 保留；重复 tag/端口明确拒绝。
- Custom 使用原生 JSON、1–3 个空白槽位、四条件 AND、ruleTag/数组顺序；导入清单与
  持久正文分离，共享校验用于保存和备份。允许省略空 routing/rules 的核心原生默认值。
- 直连地区映射由实际打包的 protobuf 生成，250 个 IP 地区、4 个域名地区；运行时再按
  当前索引过滤。`CATEGORY-PT` 是 Private Tracker，不误当葡萄牙；来源与内容哈希随资产保存。
- 复用串行测速队列，固定每批最多 5 个；逐批提交允许选够 N 个后继续连接，其他任务继续。
  自动测速不受旧开关影响；编辑后的迟到结果、恢复前已排队的旧任务不能污染新数据。
- libXray v3 增量提供 `checkRoute` 和 `testXray.buildOnly`。后者仅构建，不创建 TUN、
  WireGuard 或其他实例；前者使用真实 Router，剥离监听/日志/Webhook 等检查副作用，
  无法安全构造的 WireGuard/VLESS reverse 明确拒绝。同进程已有托管核心时拒绝临时检查。

验证：81 项定向测试、全量 394 项通过，1 项 Windows 原生测试跳过；静态分析、原生
模型与分层检查通过。锁定核心读取 9 份真实 Dart 产物，18 个场景、62 次 Invoke 检查通过。
Android 独立 `p2-compiler-1788362045519363` 目录实际执行新接口，27 项检查通过；
未打开主数据库、未启动 VPN。Android AAR 与 Apple 全部 Go slices 已重新构建并复制。
完整 App macOS Debug 构建通过；没有启动 macOS VPN、截图或录屏。Windows/Linux
原生构建与运行继续 NOT RUN，现有 Pigeon Swift Sendable 警告未当作运行验收通过。

构建工具：Go 1.27.1；gomobile/gobind 为 Go 1.27.0 构建的
`golang.org/x/mobile v0.0.0-20260821190718-4776eadac327`，未升级模块锁定版本。
AAR SHA-256：`2f4c1d2522e24f269adeb2cffc347f3ce3f3ab39dd0d269c83c50b9f66e11b7e`；
macOS archive：`88dba48b8246a5adca63985b9b89613e9d7a414485e89b5d84ce8379cd0036af`。

当前约束：IPv6 关闭时，节点域名须由 P3 预启动解析提供 IPv4 引导地址；显式 IPv6
目标拒绝。Raw 的 `+local` DNS 在要求物理网卡绑定时不允许绕过约束，关闭 IPv6 时
不能验证为 IPv4 的本地 DNS 域名也拒绝；不能只改 queryStrategy 就宣称已强制所有物理出站。
构建/路由检查会读取本地资源且影响核心进程全局值，不宣传为无 IO 或可与活动核心并发。

## P3：运行协调与平台准备

运行协调器、同库提交与补偿、平台 policy 和宿主统计已实现并验证。App 前台通过
Xray 原生 metrics 读取实时计数；libXray 只定期保存本次连接快照。设备累计、按会话
去重及清零属于 App；同进程的临时核心操作不能干扰已运行的托管核心。
停止或恢复失败保留提交 journal 并呈现可重试状态，不提交未确认方案或伪报已断开。

Windows 系统停止直接终止 Job 时，允许丢失最后成功保存后的尾部统计；无需为统计修改
VCore。macOS SE 通过固定 provider 消息读取会话快照和清理已结算归档，App 不直接访问
root 文件。实际离线消息投递和归档清理待手动验证。Windows/Linux 原生验证及 macOS
VPN 验证的禁止边界保持不变。

简化方案重新验证：全量 Flutter 445 项通过、1 项 Windows 原生测试跳过；静态分析、
模型契约及分层检查通过；Go 全量及 race 通过。Android/Apple Go 产物已重新构建复制，
完整 macOS Debug 构建成功。保留已存在的 Swift Sendable / Android 插件 KGP 构建警告。

Android 私有 fixture 实测连接、清零、双节点切换、真实启动失败恢复及正常停止通过。
仅终止 UI 后，原生进程继续转发并独立更新 session 文件，App ledger 不变；重开先合并
文件再使用 metrics，恢复同一 session，最终累计只增加该 session 未结算差值。
原始日志与演练结果位于工作空间 `references/onexray-refactor-validation/runtime-results.md`。
主数据库未被验证入口读取；VCore 无改动。P3 完成不代表 P4 新 UI 已切换或全部平台可发布。
