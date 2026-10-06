# Xray 配置与运行

## 配置边界

普通模式使用 App 节点与智能/常规自定义路由；高级自定义是仍复用 App 节点的 JSON 模板；
专家模式使用自带节点的完整 Raw JSON。高级模板不提供逐字段表单，不与常规表单双向转换。
常规/高级自定义共用三份上限，已有记录类型不可切换。Raw 新增最多三份，旧库超额行完整保留、可选和可编辑。
持久化、升级和导入事务见 [数据管理](data-management.md) 与 [服务器及分享](subscriptions-and-sharing.md)。

普通运行直接构造 `XrayJson` 及嵌套模型，最终一次序列化；不先拼完整 Map 再 `fromJson → toJson`。
模型只定义必要字段及标准序列化，不承担构造或协议解析。节点 outbound 保持完整 Map。
高级模板/Raw 使用独立 Map 编译路径，分别按模板边界或完整配置保留用户字段，不经普通模型裁剪。
编译器是纯值转换：不读库、分配端口、写文件或启动 Core；App 运行字段只由对应编译路径生成。

Xray 字段有效性以 libXray 为准，App 不重复维护协议、算法、网络、端口或重复 tag 等内核校验。
App 保留自身名称、资产数量/交换格式、文件链接安全、事务和平台网络策略检查。
分享解析/生成及测速直接采用 libXray 对应 API；手写节点、路由、Raw 保存使用 `testXray`。
连接启动不重复预检，实际加载、构造和启动错误由启动路径返回。

## 普通配置编译

自动/订阅/地区按路由要求选择 1–3 个可用接入节点；固定节点及全部使用 VPN 使用一个。
已运行节点不因后台测速或订阅更新热替换；节点命名与排序见 [服务器及分享](subscriptions-and-sharing.md)。

代理规则固定使用 `balancerTag: proxy`，单节点同样使用 balancer。selector 填完整运行 tag，
策略为 round-robin，`fallbackTag: direct`。未命中保持 Xray 默认行为：走第一个 outbound，
不增加 loopback 或无条件 catch-all。
无最终出口时接入节点按顺序位于最顶部；智能路由有最终出口时，每条接入各生成出口副本，
副本的 `dialerProxy` 指向对应接入，出口副本按顺序置顶，接入节点随后。
balancer 选择这些完整链路，接入选择排除最终出口；自定义路由不绑定具体节点或最终出口。
系统出站随后追加，固定 tag 为 `direct`、`block`、`dnsOut`。
普通出站不输出 settings/sockopt 的 `domainStrategy`，Raw 用户字段不适用此删减。

智能/常规自定义固定 `routing.domainStrategy: IPIfNonMatch`：域名首轮未命中再解析 IP 重匹配。
全部使用 VPN 为 `AsIs`，高级/Raw 保留用户值。App 生成规则省略可选 `type: field`。
智能路由把直连域名/IP 分别去重合并为一条规则，无条件时省略对应规则。
顺序为广告阻断、Windows 开关对应的 GitHub 代理、合并域名直连、合并 IP 直连。
Windows 服务直连使用 Microsoft/Bing 分类，同时优先代理 GitHub；该开关在所有平台显示。
直连地区来自安装的官方分类与随包映射。广告、FakeDNS、Fragment 默认关闭，其余智能开关默认开启；保留已保存值。

### DNS

代理 DNS 固定 `8.8.8.8`，直连 DNS 可在每份智能/常规路由中独立配置，使用固定 tag 区分。
直连服务器只匹配从纯 direct 域名规则提取的 domains，不作通用 fallback；带 IP/端口/网络/协议/系统/入站等
附加条件的规则不贡献域名，因为 DNS 不知道后续连接条件。
智能直连 DNS 关闭时保留地址，运行使用默认地址且不匹配直连域名。
全部使用 VPN 只生成代理 DNS，非 A/AAAA 的 `dnsOut` 转发也走代理，不产生第二个直连服务器。
普通模式仅设置各服务器查询策略，不额外生成根级 hosts/queryStrategy。

### FakeDNS

智能与各常规自定义分别保存 FakeDNS 开关，全部使用 VPN 不受影响。
开启后添加 `app-dns-fake`，直连域名仍使用真实直连 DNS，其余经 dnsOut 的 A/AAAA 可返回虚拟地址；
`IPIfNonMatch` 的真实解析跳过 FakeDNS。连接仍按完整规则，不保证拦截应用自带 DoH/DoT。
普通池为 `198.19.0.0/16`、`fc00:1::/64`，各 32768，始终成对生成，IPv6 返回由 DNS 查询策略决定。
托管入站默认 HTTP/TLS/QUIC 嗅探增加 `fakedns` 以还原域名。

高级/Raw 的池和 DNS 保留用户配置，根级 `fakeDns`/`fakedns` 两种写法均识别。
Raw 只给新建 tunIn 添加默认还原，已有 sniffing 不自动修改；高级模板省略 sniffing 时使用默认值，显式填写整对象保留。
池映射随 Core 销毁，重启后的缓存虚拟地址可能无法还原；App 不清系统 DNS 缓存或改用户排除路由。

### Fragment

智能与各常规自定义分别保存 Fragment 开关，默认关闭，全部使用 VPN 不受影响。
开启时使用 `protocol: freedom`、`tag: fragment` 的辅助出站；默认 `settings.fragment` 为
`packets: tlshello`、`length: 100-200`、`interval: 10-20`。
运行把接入节点接到该出站；智能最终出口链路保持 `最终出口 → 接入 → fragment`，balancer 仍选择完整链路。
Windows/Linux 给 fragment 的物理 socket 绑定已选网卡。

常规路由导入后保留辅助出站的自定义参数，编辑其他字段不重写它们。
高级模板存在该 freedom 出站即开启，填槽时自动接入所选节点，参数仍由模板管理。
Raw 保留用户链路，App 不根据 fragment tag 自动接线。

## 常规自定义路由

`RoutingProfile` 经 Base64 解码为 `XrayJson`，再转换 `RoutingProfileState` 供业务/UI 使用。
持久化/导出的 outbounds 以 1–3 个空接入槽开始，随后可有一个 [Fragment](#fragment) freedom 辅助出站；
其它非空节点（含 direct/block）拒绝导入，不兼容转换。
direct/block 只在校验/运行时生成，规则的动作引用保留。名称存于表列，交换 JSON 根部可用 `name`。

规则支持域名、目标 IP、目标端口、网络、协议和 localOS；不同条件为 AND，列表/反选遵循内核语义，建议填单一条件。
名称使用 `ruleTag`，顺序决定匹配，无自定义停用字段。
动作仅 `balancerTag: proxy` 或 `outboundTag: direct|block`。
协议是嗅探到的流量协议而非节点协议；localOS 是 Core 所在系统。
逐条域名/IP 输入使用实际安装 Geodata 补全；协议/系统位于“更多匹配条件”，已有值展开并保留。
普通模型不开放 process、来源 IP/端口、HTTP attrs 或额外入站等高级匹配。
不支持的结构拒绝导入，不静默丢字段；更多能力使用高级模板或 Raw。

DNS 使用标准 servers，固定 `app-dns-direct` 保存直连地址，存在 `app-dns-fake` 表示 FakeDNS。
运行池、domains、fallback 和 queryStrategy 编译时产生，不保存/导出。
缺省沿用默认；不支持的 DNS 结构拒绝，不依赖数组位置标记服务器。
`geodata.assets` 仅为交换依赖元数据，导入后从存储 JSON 删除，省略默认文件，详见 [数据管理](data-management.md)。

规则子页只改草稿，不重复验证内核字段。保存/导入用 freedom 占位替换空槽，补齐相同 proxy balancer、
Observatory、direct/block、DNS 和资产路径，再由 libXray 构造验证；不选真实节点、不启动 VPN。
依赖发布和失败回滚复用导入事务，实际节点组合由运行 Core 处理。

## 高级自定义路由

高级模板保留 Map，类型存于 `RoutingProfile.advanced`，不嵌入 JSON；共享名称、数量和保存流程。
outbounds 以 1–3 个连续空槽开始，后续只开放 freedom/blackhole/dns 辅助出站。
运行以真实节点替换槽并置顶，随后用户辅助出站，最后 App direct/block；固定节点选择替换整个槽区。
App 添加固定 proxy balancer、完整 selector、direct 回退与 Observatory。
模板不能定义 direct/block/proxy 或引用内部 app-entry/app-exit tag，dialerProxy 不支持 balancer。

模板完整管理 DNS、routing.domainStrategy、rules 顺序与 ruleTag；不隐式补 DNS server、53/853 或兜底规则。
App 管理日志、metrics、统计、policy、env、balancers、observatory、出口网卡和 DNS 查询策略。
额外入站开放 socks/http/tunnel；tunIn 只开放 tag/sniffing，平台部分由 App 生成。
额外规则开放 inboundTag/localIP/localPort，不开放 process、source/sourceIP/sourcePort、attrs 或 user。
辅助出站 streamSettings 仅开放 sockopt.dialerProxy。其他当前字段边界由模板解析器维护，不推广到完整 Raw。

校验使用同一填槽逻辑与本地 freedom，保留 DNS/辅助出站/额外入站/规则，tunIn sniffing 用安全 SOCKS 验证。
不测速、不 Start、不加启动预检；保存、依赖发布、回滚与普通路由共享。
导出只含槽和用户配置，依赖声明仍仅为交换元数据。

## Raw JSON

Raw 保存原文，不经过 `XrayJson` 或常规 State，运行只改深副本。
App 接管 tunIn 的有限平台设置、metrics、统计、日志、DNS 查询策略、资源路径及出口网卡；其余内容保留。
不允许额外 TUN、重复 tunIn 或占用 App 保留端口。运行端口分配避开用户入站、本地 HTTP API 的保存端口及已启用的共享端口。

已有 tunIn 保持数组位置、sniffing（含缺省/关闭）和非托管设置；仅覆盖 name、mtu、gateway、dns、
autoSystemRoutingTable、autoOutboundsInterface。原生 TUN 平台生成六项，Apple/Android 仅 name/mtu，移除其余托管项。
无 tunIn 才新建。MSIX 转为私有 loopback SOCKS，保留不需转换的内容。
Windows EXE 默认补 autoSystemWfpBlockLeak，显式列表保留；Linux autoSystemDnsToGateway 保留用户值。
系统 DNS/TUN 特定要求见 [隧道与平台策略](#隧道与平台策略)。

iOS 模拟器完全由 Swift 判断，将 tunIn 转为 SOCKS，原子写回 run/start.json，再用同一 coreInvokeText 调用 libXray。
写入失败不启动，数据库/编译输入不变；状态使用 getXrayState 和原生通知，启停直接调用 libXray。
真机和 macOS 使用系统 VPN，Dart 无 debug 模式分支。

保存校验投影仅裁剪 App 托管项：去除下载任务/metrics，关闭日志与采集，tunIn 转最小 SOCKS 但保留待检 sniffing。
保留用户节点、路由、DNS 和必要模块依赖，stats 使用最小对象避免 API 假错误；不删除整个 policy/DNS/streamSettings。
原文及运行配置不受投影影响。
`testXray` 执行 LoadConfig → New → Close，不 Start；允许进程级副作用，不做环境快照恢复。
通过只证明投影能构造/关闭，不保证监听、TUN、授权或连通性；必要本地文件缺失直接报错，不下载兜底。
同进程已有受管理 Core 时 testXray 拒绝，需重连的编辑遵循先停后校验，不绕过生命周期。

## 局域网代理共享

设备级平台策略保存共享开关及端口，默认关闭、端口 `11024`；不写入智能/自定义路由或 Raw 原文，
不随连接配置备份跨设备恢复。所有运行编译路径开启后追加一个 `app-lan-proxy` 入站：
`protocol: socks`、`listen: 0.0.0.0`、`auth: noauth`、`udp: true`，不额外创建 HTTP 入站。
监听地址不可修改；同一端口兼容 HTTP（含 CONNECT）与 SOCKS5，UDP 仅通过 SOCKS5 UDP ASSOCIATE。
内核为 UDP 会话动态分配中继端口，不保证只放行 `11024/UDP` 即可使用。

这是显式代理，不接管其他设备的网关或热点转发。客户端需要填写此设备实际网络地址和共享端口。
`0.0.0.0` 是通配监听而非来源限制；任何可达客户端均可使用，无认证，仅应在可信网络开启。
App HTTP API 和 metrics 仍只监听 loopback。共享流量沿用当前路由；不强制代理或改写用户 `inboundTag`，
只匹配 `tunIn` 的规则不会匹配共享入站。共享入站使用托管嗅探，并在需要时增加 FakeDNS 还原。

共享端口允许 `1024–65535`，开启时检查本地 HTTP API 保存端口及当前高级/Raw 用户入站的端口/tag 冲突；
不静默替换用户入站。修改 API 端口也避开启用的共享端口，实际外部占用由 Xray 启动返回原因。
VPN 已连接时切换共享需确认重启，取消保持原状态；端口生效变化同样确认。
未连接仅保存，不主动启动；关闭 VPN 同时关闭共享。离线有效修改使旧 saved-start 失效，
Android Widget/Tile 回到 App 重新编译；Apple 同时清除旧 provider request 与按需连接，避免旧配置重新开放端口。

UI 与配置支持全平台，不等于各平台均已实机验收。Apple 明确不支持在 Packet Tunnel Provider 中托管监听器/
代理服务器；当前扩展内运行的实现仍存在官方支持与审核风险，iOS 主 App 后台也不能作为长期共享保证。
参见 [Apple TN3120](https://developer.apple.com/documentation/technotes/tn3120-expected-use-cases-for-network-extension-packet-tunnel-providers)。
跨设备连通、UDP、防火墙、锁屏和签名渠道需要对应平台验收。

## 隧道与平台策略

TUN 地址只读，隧道 IPv4/IPv6 DNS 与 Apple DoT 域名可编辑，独立于路由 DNS，保存在平台策略 JSON。
原生 DNS 必须是对应地址族 IP；DoT 域名不是搜索域，需与服务器证书匹配。
有效设置变化按已连接确认重连；停用的域名/IPv6 设置保留，不因其变化重连。
Windows/Linux 给 Xray 明确绑定已选网卡，VCore 不新增绑定要求，Raw 不能覆盖。
Windows EXE 使用 Xray 原生 TUN/Wintun，MSIX 使用私有 SOCKS 和 VCore 系统隧道。

EXE 默认 autoSystemWfpBlockLeak: [dns]，Raw 可用 [] 关闭；不启用 misconfigtun，也不承诺阻断所有 DoH。
Linux 不默认接管系统 DNS；Raw 的 autoSystemDnsToGateway 依赖可工作的 systemd-resolved/resolvectl、
独立 Core DNS 及相应 DNS 出站规则，App 不探测发行版或失败回退。
强杀后系统 DNS 可能需手动恢复；这些 Core 平台能力不在 Dart 重复实现。

### Apple 路由与 VPN 图标

排除网段仅在关闭 includeAllNetworks 时传入 NE excludedRoutes，默认空，不自动加私网或修改 Xray/DNS。
开启全流量时保留但不校验/应用停用列表，其变化不重连；关闭 IPv6 同样不传对应路由。
保存只检查原生 CIDR/网络地址要求，不沿用 Windows 限制，不提供企业 Split DNS。
iOS/iPadOS 隐藏图标默认关闭，仅非全流量时生效：运行副本追加 0.0.0.0/31，IPv6 开启另加 ::/127。
不写回用户列表，不改变状态来源；依赖系统路由行为，可能影响网络切换，不保证所有系统版本隐藏。

### IPv6 策略

关闭时 Apple/Android/Linux/EXE 不配置隧道 IPv6 地址、路由和 DNS；MSIX/VCore 保留自身处理。
Dart 只把 DNS 查询设为 UseIPv4，开启 UseIP；普通按 server，Raw 同时根级和对象 server。
不额外屏蔽 IPv6 流量、不加 ForceIPv4/hosts/预解析，也不拒绝 IPv6 节点；Raw 用户其他 IPv6 字段保留。

## JSON 编辑辅助

节点、高级模板与 Raw 共用 re_editor、本地诊断和轻量补全，常规路由继续表单。
语法错误按原文 UTF-16 offset 给出行列；App 结构错误可给明确字段路径，歧义不强行定位。
libXray 原始原因完整可复制，不猜字段，不把投影行号当原文位置。
改文本清除旧错误，光标移动不清除；迟到结果不标记新草稿，保存期间的新编辑保留并提示未保存。
停顿只查本地语法，显式保存才走既有验证/依赖流程，不自动重连或修复用户 JSON。
补全按类型/位置过滤常用字段、枚举、tag 和安装的 Geodata，不作白名单、不猜凭据。
保留引用与撤销历史，组字/非折叠选区不补全；候选支持点击与键盘，内容 LTR、文案跟随语言。
文件/剪贴板错误完整展示，仅原 JSON 语法错误提供原文位置，不把链接/下载失败伪装成编辑位置。

## 运行协调与统计

`ConnectionCoordinator` 串行停止并确认旧运行，再准备/启动/确认新运行，最后提交设置。
run/start.json 是唯一原生启动请求：coreInvokeText 为实际输入，metadataJson 仅还原运行描述、节点保护和起始时间。
不另存 App 计划、快照或跨进程提交日志。文件队列在连接命令取得执行权后进入；只读状态/metrics 不入队。
停止失败不继续准备；启停已开始后的失败尽力停止本次运行并进入 failed，不恢复旧连接/输入。
不能确认停止时仍以原生状态为准，缺少 metrics 或描述不等于断开。

桌面启动前在旧 Core 停止后清理 core-inputs，生成本次唯一输入和 error 文件，通过 -error-file 获取加载/构造/启动原因，
无诊断才用通用错误，不再运行 testXray。发布需包含支持该参数的 Core。
MSIX snapshotToken 只验证 VCore 宿主会话，不是可删的 App 快照。
EXE/Linux 按精确 Core 进程名管理全部匹配实例，不保存 PID/路径归属记录；停止可影响其他安装的同名 Core。
只有确认全部退出才断开，查询/提权/监测失败不伪装空闲；过期查询不更新状态。
Geodata 始终使用唯一平铺 datDir，启动不复制文件；SE 跨容器传输见 [数据管理](data-management.md)。

### 状态同步

先订阅再读原生状态，必要授权见 [App 启动](app.md#平台前置条件与权限)；回前台/可见或重新获焦时校准。
业务层无统一状态轮询或启停缓存，操作前查询平台；UI 状态只展示。
Apple 使用 NE 状态通知，Android 使用资源查询/生命周期广播/进程退出通知；EXE 用进程句柄退出，
Linux 用自身 exitCode 或接管 pidfd（不支持时报错，不降级轮询）。
仅 MSIX 内部每 5 秒检查系统 VPN，启停有界快速确认，不随隐藏/失焦停止。
startVpn/stopVpn 成功返回已确认状态，不仅是“提交命令”；只读返回不通过回调绕行，每次同步只读一次 start.json。

### 本次流量

可见连接页且已连接时共享一个秒级 metrics 采样器；resumed/inactive 均可见，失焦不重置基线。
无可见连接页、隐藏/后台或断开停止；重新显示建立新速率基线。仅重建流量区域，高级时长用独立本地时钟。
GET /debug/vars 汇总 stats.inbound 的 `tunIn` 与 `app-lan-proxy` 本次上下行，其他用户入站不计入；
相邻有效样本算速率，未创建计数按零。Android 通知/Widget 使用相同汇总范围。
失败保留内存计数、速率不可用，恢复重建基线。断开清空，无累计持久化/清零/独立 libXray 统计服务。
运行描述定位 metrics 端口，不以读取成功判断连接状态。

Android OneVpnService 独立秒级采样供通知/Widget，亮屏运行、熄屏暂停清速率，失败不重连。
不使用额外前台服务/WorkManager/闹钟；正常停止、撤权、销毁取消，强杀不保证即时 Widget 刷新。
Provider 与 VPN 同处 :native，流量只在内存传递，不写文件/Preferences。仅 localhost 开放 metrics 明文例外。
Widget 使用系统语言/主题、4×2 紧凑布局；语言/尺寸变化只刷新展示，不启动采样。

Widget/Tile 共享原生 saved-start：完整 start.json 且权限就绪则直接启动 VPNService，不打开 Flutter。
缺输入/权限才复用 App 启动入口；不重复预检或下载，重复启动按服务自身资源处理。
复用最后生成的配置/端口/节点，不读库重选或测速，更新会话时间并重新创建 TUN/fd；失败通知，不自动重试。
关闭直接原生停止，数据区只打开 App。广播自动化复用此入口但有独立授权及清理阻断，见 [外部接口](external-interfaces.md)。
