# Xray 配置合同

普通模式使用节点、智能/自定义路由和 App 平台策略；专家模式使用完整 Raw JSON。
旧 Profile（`setting`）和多节点出站（`full`）不参与新业务，不是新配置的运行依赖。

## 持久数据

- `CoreConfig` 原库增量升级，保留 ID、subId、已有 Base64 data；新 JSON 仍使用 Base64。
  本地节点、订阅和全部旧 Raw 保留。退休类型留在原库但不显示、不运行。
- 单节点以完整 outbound 映射为事实源，名称只用 `tag`；仅当 `tag` 键不存在时把旧
  `name` 作为别名，然后移除 outbound 的 `name`。`sendThrough` 不参与命名。
- Custom 使用新表保存原生 Xray JSON；`outbounds` 中 1–3 个空对象表示接入数量。
- Custom 最多三份、名称唯一；Raw 新增最多三份，旧库超过三份不裁剪、不隐藏旧行。
- 连接选择、Smart、隧道和日志策略在同一数据库事务提交；外观等非运行偏好仍可用 Preferences。
  `ConnectionConfig` 只保存当前连接配置 JSON，不保存 VPN 状态或运行历史。
  配置写入经协调器串行执行，保留旧草稿内容校验；仅清空数据阻止新任务，不额外保存提交修订号。

## 普通配置编译

`ConnectionCompiler` 接收不可变输入，在副本中产生配置，不自行读库、分配端口或启动 Core。
`XrayJson` 是普通模式配置生成的唯一结构。运行编译直接构造模型及嵌套模型，完成运行设置后
一次序列化；不能先拼完整 Map，再经过 `fromJson → toJson` 筛选或重新组装。`fromJson` 用于
外部输入和数据库读取，不作为内部构造器。模型不解析 Raw JSON；outbounds 的元素保持
`Map<String, dynamic>`，便于完整保留代理协议字段。
`XrayJson` 文件只定义字段映射和标准 `fromJson` / `toJson`，不负责协议分派、校验或
运行配置构造。TUN、SOCKS 入站与系统出站由 `runtime_inbounds.dart` 和
`runtime_outbounds.dart` 返回类型模型，只在模型声明的 Map 字段处序列化对应 payload；系统出站的最小
`streamSettings.sockopt` 只包含实际生成的 `dialerProxy` 和 `interface`。
运行设置直接填入模型字段，不得向普通配置注入模型外字段。
Raw 使用独立的 Map 编译路径，未由 App 管理的根字段和嵌套字段原样保留。

节点测速使用模型封装节点列表；节点编辑、App Link 和手写节点 JSON 的校验使用最小
`XrayJson`，保留完整 outbound 与本地资源路径，关闭日志，不添加运行入站和 metrics。
启动编译只产生实际 `runXray` 使用的运行 JSON，不生成验证副本，也不在 App 中通过
`testXray` 预先构造 instance。智能路由预览直接消费 `XrayRoutingRule`，
自定义规则由编辑 State 生成模型；界面预览、验证与运行编译共用规则生成逻辑。

Xray 字段的有效性以 libXray 为准。App 不维护协议、加密算法、端口、网络类型、重复
tag 等额外校验规则，也不因 VMess 省略 security 而拒绝内核已接受的节点。标准分享解析、
测速和分享生成采用对应 libXray API 的结果；节点编辑、手写导入和完整配置保存使用
`testXray`，连接启动不再调用该预检。App 保留自定义名称校验，以及文件/链接安全、资产数量与事务完整性、
编辑器可表达范围和平台网络策略等自身职责内的必要检查。

接入按选择范围与测速结果确定；已运行节点不会因后台测速或订阅更新而被热替换。
测速状态直接由已有延迟值区分未检测、成功、失败与超时；地区使用出口国家代码，不保存
测量来源或时间，也不引入时间过期判定或新的“是否测过”字段。

普通配置中显式选择代理的规则始终使用 `balancerTag: proxy`，即使只有一个节点。
selector 填写生成节点完整 tag，采用 round-robin，回退出站为 `direct`（直连）。未命中规则的流量不
经过 balancer，而是遵循 Xray 默认行为使用第一个 outbound。智能路由最终出口独立于
接入；每条接入链使用自己的出口副本，副本的 `dialerProxy` 指向对应接入节点，避免链式
依赖互相覆盖。Custom 不绑定具体节点或最终出口。

没有最终出口时，接入节点按用户选择顺序放在 `outbounds` 最顶部；存在最终出口时，最终
出口副本按接入顺序位于顶部，随后才是它们依赖的接入节点。显式代理规则通过 balancer 在
这些副本间负载均衡，未命中规则的流量默认使用第一份完整链路。其后追加系统出站。普通
配置不再生成内部 loopback outbound。
系统出站的 tag 固定为 `direct`、`block`、`dnsOut`。普通配置不在 outbound 的 `settings` 或
`streamSettings.sockopt` 中写入 `domainStrategy`；完整 Raw JSON 中的用户字段不属于此
简化范围。

智能路由和自定义路由的 `routing.domainStrategy` 固定为 `IPIfNonMatch`，不提供开关：
域名首轮未命中才解析为 IP 重新匹配。自定义路由的导入、读取不保留该字段的定制值，
保存、导出、校验及运行编译统一输出固定值；Raw JSON 保留用户设置，全部使用 VPN 仍为 `AsIs`。
App 生成的所有 rule 均省略可选的 `type: field`，且不增加无条件 catch-all 提前截断 IP
第二轮匹配。Custom 导入将 `type` 视为不支持的字段并直接拒绝；完整 Raw JSON 保留用户
原文，包括用户自行填写的 `type`。

智能路由将局域网、Apple 服务、Windows 服务和所选地区的直连条件合并：域名与 IP 各输出一条规则，
同类条件去重后以 OR 匹配，域名和 IP 不合并到同一条规则。没有对应条件时省略该类规则，
不生成空条件规则；广告阻断仍排在这两条直连规则之前。
智能路由除广告拦截外，所有开关默认开启；已保存的开关值保持不变。
Windows 服务直连开关在所有平台显示；开启后使用 Microsoft、Bing 两类 Geosite
域名，Windows、Office 的相关域名已包含在 Microsoft 分类中；与其他直连条件共用预览、
保存和重连逻辑。

“所有流量经过 VPN”只生成一个走 proxy 的 `8.8.8.8` DNS server，不生成直连 DNS server
及其路由规则；`dnsOut` 对非 A/AAAA 查询的转发也走当前代理节点。
智能路由和自定义路由保留两个使用独立 tag 的 DNS server。代理 DNS 固定为 `8.8.8.8`；
直连 DNS 默认使用该地址，可在各份路由配置中独立修改。智能路由关闭直连 DNS 开关后，
保留已保存的地址，但运行时使用原默认地址且不匹配直连域名，直到重新开启开关。
直连 DNS 地址的语法由 libXray 校验，App 不另行检查协议或连通性。
direct server 的 domains 从当前 direct 规则提取，且不作为通用 fallback；DNS 阶段不
宣称已判断 IP、端口或网络条件。普通模式只给每个 server 设置查询策略，不生成根级 `hosts` 或
`queryStrategy`。直连地区依据安装的官方 Geosite/GeoIP 分类和随包地区映射生成。

## 隧道 DNS

VPN 隧道页可编辑 IPv4 DNS、IPv6 DNS 和 DNS 服务器域名，保存在现有平台策略 JSON 中。
缺失字段沿用原 Google 默认值。这些全局设置独立于各份路由的直连 DNS，不修改 Raw JSON
自身的 DNS 地址，无需新增数据库列或升级 schema。

现有原生 TUN 请求将配置的地址传给 Apple 和 Android；Linux 和 Windows EXE 生成的 Xray
TUN 入站也使用这些地址。Windows MSIX 将其用于网络设置和排除规则校验，保持现有 IPv6
处理方式。原生 DNS 地址必须是对应地址族的 IP 字面量；未生效的 IPv6 值仅保留，不应用。

服务器域名仅用于 Apple DNS over TLS，不作为搜索域。开启 DoT 时，地址与域名必须属于
同一服务，并与其 TLS 证书匹配。有效 DNS 设置的修改复用现有保存及确认重连流程；修改
未生效的服务器域名或 IPv6 设置不触发重连。恢复默认只修改草稿，保存后才生效。

## IPv6 策略

Apple 的排除网段作为独立平台策略保存，只在关闭 `includeAllNetworks` 时传给原生
`NEIPv4Settings.excludedRoutes` / `NEIPv6Settings.excludedRoutes`，不改写 Xray 路由或 DNS。
默认列表为空，不自动加入私网；原生仍安装默认 TUN 路由。开启全流量接管时保留列表，
但不校验、应用或因这份停用列表的变化重连。IPv6 关闭时保留 IPv6 条目，但不传入或
配置 IPv6 排除路由。保存仅检查原生路由需要的 CIDR/网络地址格式，不沿用 Windows
的条数、重复项或隧道 DNS 限制。这项功能不提供自动企业 Split DNS。

关闭 IPv6 时，Apple、Android 不配置隧道 IPv6 地址、路由和 DNS，传给 Native 的 TUN
参数也不携带 IPv6 地址和 DNS。Linux 由 Xray-core 创建网卡，其 `tunIn.settings` 中同样
省略 IPv6 网卡参数。Windows EXE 使用相同的原生 TUN 参数规则；MSIX 的 tun2socks / VCore
配置保持原有处理。

除此之外，Dart 编译只将 DNS 查询策略设为 `UseIPv4`，开启时为 `UseIP`：普通模式设置
每个 DNS server 的 `queryStrategy`，Raw 同时设置根级和对象形式 server 的查询策略。
不生成 IPv6 阻断规则、不注入 `ForceIPv4` 或 DNS hosts、不预解析节点域名，也不因关闭
IPv6 而拒绝 IPv6 节点或 DNS 地址。Raw 中用户自带的路由、hosts、出站解析策略和地址
保持不变；关闭开关不代表 Xray 的所有 IPv6 流量都被禁止。

## 自定义路由

自定义路由通过 `dns.servers: [{"tag":"app-dns-direct","address":"8.8.8.8"}]`
存储和分享直连 DNS 地址。使用固定 tag 标记服务器，不依赖数组位置；仅允许编辑这一条
带标签服务器的 `address`。域名匹配、回退和查询策略在校验及运行编译时生成，不存储或
导出。已有配置未包含 DNS 时沿用原默认值；不支持的 DNS 字段、无标签服务器和重复
服务器直接拒绝，不静默丢弃。

普通 Custom 的持久化链路固定为 `RoutingProfile` 表 ↔ `XrayJson` ↔
`RoutingProfileState`：数据库适配层负责 Base64 解码、模型解析和规范化重编码，业务与 UI
只使用 State。名称仍保存在 `RoutingProfile.name` 列，不写入配置根部。
存储和导出的 `outbounds` 仅包含 1–3 个空接入槽；导入、读取拒绝任何非空出站定义，
包括 `direct` / `block`，不进行旧格式转换。系统出站仅在校验和运行编译时生成，
规则中的 `outboundTag: direct|block` 动作引用保留。
`XrayJson.geodata` 只承载导入所需的 `assets`，每项仅含 `file` / `url`；导入完成后保存前
移除 `geodata`。完整 Raw JSON 使用独立 Map 链路，不经过上述转换。

规则只允许域名、IP、端口、网络四类条件。不同条件为 AND，同类多值为 OR；建议只填
一种条件。规则顺序决定匹配顺序，名称使用原生 `ruleTag`，没有启用/停用自定义字段。
动作只允许 `balancerTag: proxy` 或 `outboundTag: direct|block`。

编辑器支持逐条域名/IP 输入及实际安装 Geodata 分类补全。不支持的结构拒绝导入为
Custom，不静默丢字段；完整高级配置使用 Raw。导入、导出的根部允许 `name`。
规则子页只更新草稿，不在 Dart 中判断域名/IP、端口、网络及空条件是否合法。整份
Custom 保存或导入提交前，由 libXray 构造临时 instance 校验；空接入槽只在最小验证配置中
替换为本地 freedom 出站，补齐与运行一致的 proxy balancer、所需 Observatory、direct/block
与资源路径，不选择真实节点、不启动 VPN。实际节点与路由的组合交由 Core 启动处理，不再连接前预检。
依赖的 Geodata 先发布，校验失败
则回滚且不覆盖原路由。

分享 JSON 可携带 `geodata.assets: [{"file":"other.dat","url":"https://…"}]`，省略默认
geoip/geosite。导入先在同级临时目录下载、校验并生成索引，文件名冲突拒绝；资产发布到
`VpnConstants.datDir` 的平铺根目录且路由成功提交后，持久 JSON 删除导入专用 `geodata`
字段。详见 [数据管理](data-management.md)。

## Raw JSON

Raw 保存完整原文，不经过 Profile 或 `XrayJson`，不因保存或校验改写原始 inbounds。
运行时直接解析为 Map 并在深副本上应用 App 策略。运行副本保留用户
额外入站，但 App 接管 `tunIn`、metrics、统计、日志、DNS 查询策略、运行路径及适用
平台的出口网卡；额外 TUN、保留端口冲突或无法满足平台网络策略的配置明确失败。

Windows 默认 EXE 模式的 `tunIn` 使用 Xray 原生 TUN 和 Wintun，网关、DNS、系统路由及
出口网卡由 App 生成；MSIX 模式的 `tunIn` 是私有 loopback SOCKS，系统流量由 VCore
Provider/Session Host 转交。普通和 Raw 使用相同的运行入站选择，保留 `tunIn` 标签。
Android、Apple、Linux 使用平台 TUN。两种 Windows 模式都给 Xray 绑定所选网卡，不给
VCore 新增绑定要求。Dart 不提供 iOS Debug Proxy 开关或独立的启停分支，始终使用原生 VPN 接口。
Swift 仅在 `targetEnvironment(simulator)` 时将请求中的 `tunIn` 改为本地 SOCKS，保留
其 tag、嗅探和其他入站。转换后的请求原子写入 `run/start.json`，再把同一份
`coreInvokeText` 传给 libXray；写入失败则不启动 Core。原始编译输入、数据库配置及运行
元数据保持不变。模拟器直接调用 `runXray` / `stopXray`，以 `getXrayState` 为状态来源，
通过原有原生状态通知更新 App；真机和 macOS 仍使用系统 VPN。

Raw 保存使用 `XrayValidation` 的 Map 投影，只处理验证副本：排除 App 管理的
入站、更新任务和运行资源，关闭日志与统计采集，保留用户节点、路由、DNS 和模块依赖。
统计模块以最小配置保留，避免用户 API 等依赖因裁剪而产生假错误；只处理被 App 接管的
嵌套项，不删除整个 DNS、policy 或 streamSettings。字段清单以投影与编译代码为准。
数据库原文和真实运行配置不受验证裁剪影响，未检查的 App 管理项仍由运行策略负责。

`testXray` 使用 `core.LoadConfig → core.New → Close`，不调用 `Start`。节点、路由和
本地 Geodata 的构造错误由内核返回；允许环境变量、日志/DNS 引用等进程级副作用，
不增加进程环境快照或恢复机制。成功只表示传入配置能完成实例构造及关闭，不代表被排除
的配置已验证，也不覆盖监听端口、TUN、系统权限及连通性。缺失必要本地文件直接报错，
校验不通过下载兜底。节点延迟和位置检测继续使用 `pingBatch`。

## 运行协调与统计

`ConnectionCoordinator` 串行停止并确认旧运行、准备新配置、启动并确认新运行，最后提交数据库
设置。`ConnectionRuntime` 不单独序列化；`run/start.json` 是唯一原生启动请求，其中
`coreInvokeText` 保存实际 Xray 输入，`metadataJson` 只保存重开 App 后显示运行路径和保护
节点所需的配置、节点信息及启动时间。不另存运行计划、快照或跨进程提交日志。

Raw 与自定义路由编辑先完成用户确认，再进入连接队列。携带 Geodata 的保存由导入模块
统一管理文件发布与回滚；连接队列取得执行权后才进入文件队列，在同一文件访问范围内
完成配置校验、必要的启停和数据库提交。普通命令不登记全局维护任务；清空数据时暂停
连接队列并取消未开始的命令。只读状态与 metrics 不进入该队列，清理
停止连接时同样使先前读取回调失效。

当前 VPN 尚未断开时，先停止并确认断开，再进入启动准备；停止失败不执行资产校验、配置准备或启动。
准备阶段完成 Windows/Linux 出口网卡存在性检查、节点解析、运行端口分配和配置编译，
不调用 `libXray.testXray`；配置加载、实例构造及启动错误由实际启动路径报告。
编辑/导入触发重连时，资产保存校验仍在停止旧运行后执行；不涉及启停的编辑继续独立校验并保存。
这些编辑校验调用的 `testXray` 在加载配置前拒绝同进程已有的受管理 Xray instance；模拟器同样遵循先停后校验，
不绕过 libXray 的生命周期检查。需要与运行中 Core 同时校验的调用方仍须自行隔离进程。

一旦已请求停止或启动原生 VPN，后续准备、校验、启动、确认、
资产写入或数据库提交失败时，协调器尽力停止本次运行并进入 `failed`；不重新启动旧连接，
也不恢复旧输入。若停止无法确认，原生状态仍是 VPN 状态依据，并继续显示能够确认的实际
运行信息；metrics 或运行描述不可用不等于已断开。重试时重新查询宿主，不从缓存推断状态。

清空数据前统一调用原生停止接口，不在 Dart 中按模拟器权限跳过。Swift 在模拟器中停止
libXray，未运行时同样成功；真实 Apple VPN 即使已断开，也仍执行停止命令以关闭按需
连接。状态查询或实际停止失败时继续阻止数据替换，不将失败当作空闲。

Windows 和 Linux 每次实际启动桌面 Core 前，在旧运行停止后清理整个 `run/core-inputs`，
再创建唯一的 `core-inputs/input-*/xray.json`。输入目录不复用，也不保留历史。Windows MSIX 的
`snapshotToken` 仅用于 VCore Session Snapshot 的宿主归属校验，不能删除或当作 App 运行快照。
Windows EXE 额外保存验证进程归属所需的 PID、启动时间和本次输入路径，使用 Win32 进程
状态，验证路径、创建时间和当前 Windows session 后才停止目标；不按进程名批量结束 Core。
v26.8.4 的 EXE PID-only 记录仅接管同一安装目录下旧 bin 路径的 Core。
EXE 的 UAC 和有界退出等待在 worker isolate 内执行，不阻塞 Flutter UI。
Linux 使用系统 `procps` 工具按精确进程名 `OneXrayCore` 管理所有匹配进程，不保存或读取
旧 PID 记录，不校验可执行路径、启动时间、UID 或配置参数。`pgrep -x` 配合存活状态筛选
查询 PID，不再由 Dart 逐个读取 `/proc`；僵尸和已退出进程不视为已连接，也不依赖受
capabilities 保护的 `/proc/<pid>/exe`。工具缺失、执行失败或无效输出不等于已断开。
停止使用 `pkill -TERM -x OneXrayCore`，等待进程退出事件；超时仍存在时才使用
`pkill -KILL -x OneXrayCore`。发送信号成功不等于停止完成，只有再次查询确认没有存活
匹配进程才报告已断开。匹配的是进程名而非完整命令行，不处理其它 `xray` 或名称前缀相似的进程。

普通运行环境的 `xray.location.asset` 与 `xray.location.cert` 始终指向唯一、平铺的
`VpnConstants.datDir`，VPN 准备和启动不复制资产。发布事务与 macOS System Extension
跨容器传输边界见 [Geodata 发布](data-management.md#geodata-发布)。

状态同步与实时流量读取分开：初始化先订阅原生通知，再读取状态；正常主界面按
[启动权限流程](app-startup.md#平台前置条件与权限)完成必要授权，申请后重新校准状态。
窗口重新可见或重新获得焦点时校准状态，不重启已有的流量采样。业务层不定时查询 VPN，
也不缓存一份原生状态用于启停判断；操作前直接查询平台，UI 状态仅用于展示。

- Apple 直接读取 `NEVPNConnection.status`，由 `NEVPNStatusDidChange` 通知变化；启停和
  System Extension 就绪确认都等待通知，超时仅用于结束无响应的操作，不循环查询。
- Android 直接向已运行的 VPN Service 查询资源状态，通过生命周期广播及绑定服务的
  进程退出通知同步变化；撤销授权立即断开。桥接层不保存上次 VPN 状态，也不延迟断开通知。
- Windows EXE 读取经过身份验证的进程状态，使用进程句柄的退出事件；Linux 自行启动的
  进程使用 `Process.exitCode`，接管旧进程使用 `pidfd` 退出事件。Linux 接管监测要求内核
  5.3 或更新版本，不支持时明确报错，不退回轮询。
- 仅 Windows MSIX 在自身实现内每 5 秒检查系统 VPN，并在启停期间执行有界的快速确认。
  该监测随 App 进程存活，不随窗口隐藏或失焦停止；必要的去重状态留在 MSIX 内部。
  只读查询不停止 VPN，无效恢复会话由 MSIX 的会话检查显式处理。

`startVpn` / `stopVpn` 成功返回时必须附带已确认的 `connected` / `disconnected`，不再仅表示
“已提交命令”。业务层不追加统一的 200ms 查询循环，各平台只保留自身必要的命令过渡态。
主动查询直接返回状态与权限，不再通过回调事件回传；原生通知只处理系统
主动变化和启停进度。每次同步只读取一次 `start.json`，运行描述缺失时仍保留已确认的
原生状态。

仅在 App 窗口可见、连接页可见且已连接时，按秒读取 Xray 原生 metrics。Flutter 的
`resumed` 和 `inactive` 均视为可见；`hidden`、`paused` 和 `detached` 停止采样。
单纯失焦或重新获得焦点不取消正在读取的样本，也不重置速率基线。切换 Tab、打开其他
全页、隐藏窗口、进入后台或断开后停止；重新显示先建立速率基线，不把隐藏时间摊入
实时速率。流量样本只重建连接页的流量区域。高级页运行时长使用独立的本地时钟，
遵循相同的窗口可见性规则，同时要求 Xray Tab 可见，不触发 metrics 查询。

所有平台直接读取 Xray 的 `GET /debug/vars`，从 `stats.inbound.tunIn` 取得本次连接的
上下行计数，并用相邻有效样本计算速率。空闲时尚未创建的计数器按零显示；请求失败保留
内存中的当前连接计数、将速率标记为不可用，下一次成功读取重新建立基线。

libXray 不再采样、持久化或提供独立统计 HTTP 服务；App 不保存历史/累计流量，不提供清零。
断开后清空内存样本。App 重开通过 `run/start.json` 还原运行描述并定位 metrics 端口；
连接是否成功只由原生状态确认，不依赖 metrics 读取结果。运行时长使用启动请求的时间。

## 实现入口

- 编译、选择与运行：`lib/service/connect/`
- 自定义模板与地区：`lib/service/connect/routing/`
- 节点映射及兼容：`lib/service/servers/outbound/map.dart`、`state_db.dart`
- Raw 存储与边界：`lib/service/connect/raw/db.dart`、`validator.dart`
- 订阅与分享：[交换合同](subscriptions-and-sharing.md)；升级与清理：[数据管理](data-management.md)
