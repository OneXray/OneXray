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
  收藏和订阅失败数，新建路由配置表（现名 RoutingProfile）。旧 Raw 超额完整保留；普通资产新增
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

当前约束：IPv6 关闭时，普通配置拒绝显式 IPv6 目标，节点域名交给 Xray 解析，不额外
生成根级 DNS hosts。Raw 仍由 P3 预启动解析提供 IPv4 引导地址；其 `+local` DNS 在要求物理网卡绑定时不允许绕过约束，关闭 IPv6 时
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

## P4：新外壳与首条完整流程

四根 Tab、独立子路由、固定操作栏和初始化已接入；新首页使用 ConnectionCoordinator，
不初始化旧 Profile/VpnService。普通模式显示冻结的实际路径，专家模式完整替换选择区域；
Raw 保存不自动启用，当前资产变更复用协调器提交与恢复。高级和设置为新根入口，完整
服务器管理、路由编辑及平台详情由 P5–P7 接续，不将最小入口当作全部功能完成。

Android 独立 `references/p4-ui/db.sqlite` 实测：初始化准备不启动 VPN、本地 JSON
检测确认、首页连接、真实速率、累计清零不影响本次、专家视图不切换运行、Raw 保存不
启用、选择取消/确认、无普通节点 Raw 连接、删除当前 Raw 后断开并回空状态。最后已
正常停止 VPN；未读取开发者主库。证据见工作空间 `p4-ui-results.md`。

全量 Flutter 481 项通过、1 项 Windows 原生跳过；五语 622 条原型文本逐值与占位符
检查通过。静态分析、分层、原生模型检查和完整 macOS Debug 构建通过。无 macOS
VPN/截图，Windows/Linux 原生构建与运行 NOT RUN；相机/文件/系统分享完整验收留
相应后续阶段及手测，不以本阶段代表平台可发布。libXray 本阶段无改动。

## P5 — 服务器管理与导入分享（2026-09-03）

位置/订阅共用浏览与节点行、Mobile 独立组详情、当前接入高亮、组使用数量、JSON
节点编辑/收藏/重测/另存/分享/删除、订阅 Name/URL/Age 编辑及来源管理已接入。
订阅新增/更新只在可用节点非空时写入；混合导入先处理订阅，其余资产预览确认，
取消不撤销已成功订阅。来源自动更新字段已加入当前 schema，旧数据/base64/Raw 保留。

libXray API 3 增加可选解析数量和逐节点位置结果，旧响应兼容。自动/手动测速共用队列，
延迟与位置独立，资产回写核对原内容并保持冻结运行计划。Go 全量与 race 通过；Android
及 Apple Go 产物重建复制，VCore 无改动。

Flutter 全量 500 项通过、Windows 原生 1 项跳过。Android 独立入口原生 10 项检查通过；
真实新 UI 实测分组选择并连接、高亮、JSON 编辑取消、连接中测速会话不变、订阅改名
与 Age 完整表单、敏感分享确认。VPN 已正常停止。完整 macOS Debug 构建通过；无
macOS VPN/截图，Windows/Linux 原生 NOT RUN。详细日志和证据见工作空间
`references/onexray-refactor-validation/p5-results.md`。Custom 分享依赖、全站系统外入口
与发行渠道收尾仍由 P6–P9 完成，不能用本阶段代表整站重构已完成。

## P6 — 路由与专家编辑（2026-09-03）

流量弹窗、Smart/真实直连地区/独立最终出口、Custom 四条件规则与自动补全、Raw
编辑/原生网络测试、Custom/Raw 导入分享已接入。草稿保存、取消、未选中编辑与已连接
重连共用协调器；排队后的配置变化与未经确认重连会被拒绝。Custom 仅使用 Xray 字段，
无停用字段；导出根部允许 name，导入 assets 仅用于下载，存储时移除。

共享基础同时落地 Geodata 不可变代次、默认双文件共同发布、资产/备份
事务、固定计划副本和原生只读日志桥接；P7 再接入管理页面。未发布且未启动的草稿会
清理，曾尝试启动/发布的旧代保留，尚未实现自动 GC，不宣称磁盘占用已经长期有界。

Android 真实操作覆盖 Smart 2 接入/CN+RU/最终出口草稿、Custom 域名+端口规则及
双节点连接。Raw 临时测试返回 119 ms，前后 session
`17aa18ae52bec32d9b554778b5b46526`、plan `8766e60447929e57b5e6200a91d5404f`
不变。独立原生配置测试 5 项通过，验证 DNS/路由/阻断、额外监听不绑定及无托管实例发布。
libXray 的 testXray 可选 URL 探测已重建 Android/Apple Go 并复制，Go 全量与根包/xray
race 检查通过；完整 macOS Debug 构建通过，不启动 macOS VPN，不截图。

P6/P7 联合回归、真实页面与受限项详见工作空间
`references/onexray-refactor-validation/{p6-results,p7-results}.md`。
Windows 仅源码/纯 Dart 契约检查；正常离线修改和已确认失败可撤销旧 CLI 输入，事务
失败可恢复，不引入 VCore 新协议，不承诺任意强杀点的跨进程原子启动保证。VCore 未改。

P6 提交：OneXray `f08193c`、libXray `0fe8f5b`。

## P7 — 高级与设置（2026-09-03）

高级接入 VPN 隧道与 Xray 运行两页；只读双栈 TUN/Google DNS、独立 IPv6、平台
详情和 Win/Linux 网卡按能力展示。应用范围两套列表、Apple SSID 及条件开关、Windows
CIDR、保存取消与重连确认共用策略草稿。日志共用开关，DNS 默认开启，access/error
分别查看；数据更新/测速/Geodata/运行配置独立导航。设置补齐图标/语言/备份/启动/关于。

Android 实测真实 App 图标、包含/排除列表独立存储及重开；日志保存后重连，access
可见 DNS 和双接入；Geodata 真实 1539 个分类，自定义 eview.dat HTTPS 下载、索引、
展示及确认删除，默认文件不变。VPN 正常停止。共享卡片 Material ink 断言经红/绿测试
修复，复跑无 Flutter 异常；重复 connected 只在新连接边沿触发一次到期重试。

联合最终 Flutter 579 项通过、1 Windows 原生跳过；分析零问题，模型/分层检查通过，
674 条五语文案逐值与原型一致；完整 macOS Debug 构建通过。SE 固定计划的 Geodata
同步和只读日志桥接已编译/契约检查，实际消息/按需/批准/离线导出留手测。未运行 macOS
VPN/截图或 Windows/Linux 原生构建；外部文件/分享/扫码未冒充实机通过。详情见
`references/onexray-refactor-validation/p7-results.md`。本阶段 libXray 无新增改动。

## P8 — 五语逐页与系统入口（2026-09-03）

真实 App Debug 页面矩阵：macOS Desktop 35 页、Android Mobile 33 页，各五语检查首尾，
标题、文本、RTL、加载状态和 Flutter 异常均已核对。使用隔离私有库，页面矩阵屏蔽系统写入，
不把该结果当作 VPN/权限验收。macOS 首轮 Geosite 长列表跳尾超时，经红绿测试改为原型等高
Sliver 后五语复测通过；完整引用仍可复制，390 宽/1.5 字号的英文及波斯语测试通过。

无效路由回退复用原型批准文案；674 条五语逐值检查通过，26 项首页/RTL/缩放/底栏/导航检查
通过。Android 波斯语深色规则页和软键盘实测：域名 LTR，输入与保存/取消可见，无异常。
Android 系统磁贴真实启停新协调器、VIEW 链接进入预览后取消通过，最终 VPN 关闭。

macOS Debug 构建及非 VPN 检查、Android Debug 构建通过；没有 macOS VPN/截图。
Windows/Linux 原生、Apple 真机/SE 按需消息、最终签名包、完整读屏/主题/键盘及系统导入导出
仍为 NOT RUN 或部分验证，不能宣布目标可发布。完整边界及逐页证据见工作空间
`references/onexray-refactor-validation/p8-results.md`。继续 P9 源码清理和发布收尾。

## P9 — 源码收尾与发布前边界（2026-09-03）

已删除旧 Profile/多节点界面、旧运行构造、旧 ID/模式双写、失效导入器及本地隐私正文，
保留旧库类型识别、协议 JSON 工具、数据与备份保护。合计删除 131 个旧 Dart 源文件、
23 个只验证旧实现的测试及 1 个资产；共享端口、环境与协议保真断言迁至当前实现。
资产生成后无本地隐私引用；订阅引用保护未初始化时拒绝覆盖，保留原节点的回归通过。

最终 Flutter 全量 468 通过、1 Windows 原生跳过；生成、分析、分层、原生模型契约与
674 条五语核对通过。完整 macOS Debug 构建成功；Android 清理后构建/启动、11 个页面和
VIEW 链接预览后取消通过，未写入测试节点，最终无运行 VPN。没有 macOS VPN 或截图。

Windows 包脚本对齐既有 VCore revision 3；Build 单次解析依赖 SHA，libXray 记录有效模块
图与实际 gomobile，App 记录输入、工具链与产物摘要。独立发布流程校验来源、干净初始源码、
run/attempt、tag 和 hash。App Python 25 项、libXray Python 5 项及 Go 全量通过；Android/
Apple Go 产物重建复制且 hash 一致。libXray 提交 `f49c426`；VCore 无改动。

P9 **源码工作已交付，不代表最终发布验收完成**。真实脱敏旧库/ZIP 尚未提供；现有迁移、
WAL、回滚、超额 Raw 与备份证据来自隔离 fixture，不使用主用户库代替。Apple VPN/SE、
Windows/Linux 原生、渠道签名包及完整无障碍/系统交互仍按清单手测；未 push 或触发发布。
实施结果与恢复交接见工作空间 `references/onexray-refactor-validation/{p9-results,p9-release-handoff}.md`。
