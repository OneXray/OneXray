# Xray 配置合同

普通模式使用节点、智能/自定义路由和 App 平台策略；专家模式使用完整 Raw JSON。
自定义路由分为常规表单和独立的高级 JSON 模板，两者都复用 App 已导入节点。
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
  配置写入经协调器串行执行，保留旧草稿内容校验；清空数据或备份恢复阻止新任务，不额外保存提交修订号。

## 普通配置编译

`ConnectionCompiler` 接收不可变输入，在副本中产生配置，不自行读库、分配端口或启动 Core。
`XrayJson` 是智能与常规自定义配置生成的唯一结构。运行编译直接构造模型及嵌套模型，完成运行设置后
一次序列化；不能先拼完整 Map，再经过 `fromJson → toJson` 筛选或重新组装。`fromJson` 用于
外部输入和数据库读取，不作为内部构造器。模型不解析 Raw JSON；outbounds 的元素保持
`Map<String, dynamic>`，便于完整保留代理协议字段。
`XrayJson` 文件只定义字段映射和标准 `fromJson` / `toJson`，不负责协议分派、校验或
运行配置构造。TUN、SOCKS 入站与系统出站由 `runtime_inbounds.dart` 和
`runtime_outbounds.dart` 返回类型模型，只在模型声明的 Map 字段处序列化对应 payload；系统出站的最小
`streamSettings.sockopt` 只包含实际生成的 `dialerProxy` 和 `interface`。
运行设置直接填入模型字段，不得向普通配置注入模型外字段。
高级自定义模板和完整 Raw 使用独立的 Map 编译路径，未由 App 管理的允许字段原样保留。
高级模板先经过自身字段边界检查；完整 Raw 不受该白名单限制。

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

智能路由和常规自定义路由的 `routing.domainStrategy` 固定为 `IPIfNonMatch`，不提供开关：
域名首轮未命中才解析为 IP 重新匹配。常规自定义的导入、读取不保留该字段的定制值，
保存、导出、校验及运行编译统一输出固定值；高级自定义和 Raw JSON 保留用户设置，全部使用 VPN 仍为 `AsIs`。
App 生成的所有 rule 均省略可选的 `type: field`，且不增加无条件 catch-all 提前截断 IP
第二轮匹配。Custom 导入将 `type` 视为不支持的字段并直接拒绝；完整 Raw JSON 保留用户
原文，包括用户自行填写的 `type`。

智能路由将局域网、Apple 服务、Windows 服务和所选地区的直连条件合并：域名与 IP 各输出一条规则，
同类条件去重后以 OR 匹配，域名和 IP 不合并到同一条规则。没有对应条件时省略该类规则，
不生成空条件规则；广告阻断仍排在这两条直连规则之前。
智能路由除广告拦截和 FakeDNS 外，所有开关默认开启；已保存的开关值保持不变。
Windows 服务直连开关在所有平台显示；开启后使用 Microsoft、Bing 两类 Geosite
域名，Windows、Office 的相关域名已包含在 Microsoft 分类中。同时在合并的域名/IP 直连
规则之前生成 `geosite:GITHUB → balancerTag: proxy`，避免 GitHub 被 Microsoft 分类或
地区直连条件先命中；广告阻断仍在这条代理规则之前。关闭该开关时一并移除 GitHub 代理
规则。规则生成共用于预览、保存变更比较和运行编译，不增加独立开关，也不影响 Custom 或 Raw。

“所有流量经过 VPN”只生成一个走 proxy 的 `8.8.8.8` DNS server，不生成直连 DNS server
及其路由规则；`dnsOut` 对非 A/AAAA 查询的转发也走当前代理节点。
智能路由和常规自定义路由保留 proxy/direct 两个使用独立 tag 的真实 DNS server。代理 DNS 固定为 `8.8.8.8`；
直连 DNS 默认使用该地址，可在各份路由配置中独立修改。智能路由关闭直连 DNS 开关后，
保留已保存的地址，但运行时使用原默认地址且不匹配直连域名，直到重新开启开关。
直连 DNS 地址的语法由 libXray 校验，App 不另行检查协议或连通性。
direct server 的 domains 仅从不带其他匹配条件的 direct 域名规则提取，且不作为通用
fallback。包含目标 IP/端口、网络、协议、操作系统或入站标签的
组合规则不向该域名列表贡献条目；校验与运行共用同一提取逻辑。DNS 不判断后续连接的条件，
同一域名若另有纯域名直连规则，仍可能匹配该服务器；连接始终按完整路由规则处理。
普通模式只给每个 server 设置查询策略，不生成根级 `hosts` 或
`queryStrategy`。直连地区依据安装的官方 Geosite/GeoIP 分类和随包地区映射生成。

## FakeDNS

智能路由和每份常规自定义路由独立提供“使用 FakeDNS”，默认关闭，与本地 DNS 地址一起编辑；
“所有流量经过 VPN”不受该开关影响。开启后，在 proxy/direct DNS 之前添加
`app-dns-fake`（`address: fakedns`）。命中 direct server 域名列表的查询仍优先使用真实
直连 DNS；其它经 `dnsOut` 处理的 A/AAAA 查询优先返回虚拟 IP。内核路由的
`IPIfNonMatch` 第二轮真实解析会跳过 FakeDNS，保留 proxy DNS 用于真实 IP 查询。
连接路由仍遵循完整规则，不把 FakeDNS 等同于强制代理，也不保证拦截应用自带的 DoH/DoT。

普通配置使用固定池 `198.19.0.0/16` 和 `fc00:1::/64`，每池容量 32768，避开隧道自身
`198.18.0.1` / `fc00::1`。池始终成对生成；是否返回 IPv6 只由已有 DNS 查询策略控制，
不添加 IPv6 阻断或额外系统路由。`XrayJson.fakedns` 仅包含 `ipPool` / `poolSize`；
普通校验和运行共用生成逻辑。受管理的 TUN/SOCKS 入站在原 HTTP/TLS/QUIC 嗅探基础上
增加 `fakedns`，将虚拟目的地址还原为域名后再路由，不关闭内容嗅探。

Raw JSON 的 DNS server 使用 `fakedns`（字符串或对象地址），或声明根级 FakeDNS 池时，
App 只为新建的 `tunIn` 启用上述还原；已有 Raw 入站的 sniffing 原样保留，不因 FakeDNS 自动修改。
高级模板没有提供 sniffing 时也使用 App 默认值，显式提供则按整对象保留。用户原文、DNS 地址、池及额外入站保持不变，
不以普通模式固定池覆盖 Raw，也不向 Raw 添加新的开关或 DNS server。
没有显式池时由 Xray 使用自身默认池；其范围与用户系统地址、排除路由的兼容性仍由 Raw 作者负责。

FakeDNS 映射仅随本次 Core 存活，不保存到数据库。停止或重启 Core 后，应用/系统缓存的
虚拟 IP 可能无法还原；不承诺无缝缓存恢复。界面说明这一限制，App 不自动清理系统 DNS
缓存，也不擅自覆盖用户排除路由。开启后访问的 Fake IP 必须能通过系统路由进入 VPN。

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

## Apple 路由与 VPN 图标

Apple 的排除网段作为独立平台策略保存，只在关闭 `includeAllNetworks` 时传给原生
`NEIPv4Settings.excludedRoutes` / `NEIPv6Settings.excludedRoutes`，不改写 Xray 路由或 DNS。
默认列表为空，不自动加入私网；原生仍安装默认 TUN 路由。开启全流量接管时保留列表，
但不校验、应用或因这份停用列表的变化重连。IPv6 关闭时保留 IPv6 条目，但不传入或
配置 IPv6 排除路由。保存仅检查原生路由需要的 CIDR/网络地址格式，不沿用 Windows
的条数、重复项或隧道 DNS 限制。这项功能不提供自动企业 Split DNS。

iOS/iPadOS 提供“隐藏 VPN 图标”，默认关闭，仅在关闭 `includeAllNetworks` 时生效。
原生保留默认 TUN 路由，在用户排除列表的运行副本中追加 `0.0.0.0/31`，IPv6 开启时再追加
`::/127`，相同条目不重复添加。特殊网段不写回用户列表，不修改 Xray 配置或 VPN 状态来源。
这是基于系统路由行为的间接实现，可能影响网络切换，不承诺所有系统版本都能隐藏图标。
全流量接管开启时禁用此开关但保留选择，运行请求不携带该选项；其他平台不显示或应用。
修改生效中的选项复用保存及确认重连流程，停用选项变化不要求重连。

## IPv6 策略

关闭 IPv6 时，Apple、Android 不配置隧道 IPv6 地址、路由和 DNS，传给 Native 的 TUN
参数也不携带 IPv6 地址和 DNS。Linux 由 Xray-core 创建网卡，其 `tunIn.settings` 中同样
省略 IPv6 网卡参数。Windows EXE 使用相同的原生 TUN 参数规则；MSIX 的 tun2socks / VCore
配置保持原有处理。

除此之外，Dart 编译只将 DNS 查询策略设为 `UseIPv4`，开启时为 `UseIP`：普通模式设置
每个 DNS server 的 `queryStrategy`，Raw 同时设置根级和对象形式 server 的查询策略。
不生成 IPv6 阻断规则、不注入 `ForceIPv4` 或 DNS hosts、不预解析节点域名，也不因关闭
IPv6 而拒绝 IPv6 节点或 DNS 地址。Raw 中用户自带的路由、hosts、出站解析策略和地址
保持不变；关闭开关不代表 Xray 的所有 IPv6 流量都被禁止。

## 常规自定义路由

自定义路由通过 `dns.servers: [{"tag":"app-dns-direct","address":"8.8.8.8"}]`
存储和分享直连 DNS 地址。开启 FakeDNS 时另存
`{"tag":"app-dns-fake","address":"fakedns"}`，通过该服务器的存在表示启用，不使用自定义字段。
使用固定 tag 标记服务器，不依赖数组位置；直连服务器编辑 `address`，FakeDNS 仅切换开关。
池、域名匹配、回退和查询策略在校验及运行编译时生成，不存储或
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

规则支持域名、目标 IP/端口、网络类型，以及 `protocol`、`localOS`。
不同条件为 AND；列表和 IP 反选的匹配语义遵循 Xray。建议只填一种条件。
规则顺序决定匹配顺序，名称使用原生 `ruleTag`，没有启用/停用自定义字段。
动作只允许 `balancerTag: proxy` 或 `outboundTag: direct|block`。

协议指嗅探到的 HTTP/TLS/QUIC/BitTorrent 流量，不是节点的代理协议；不承诺识别全部流量。
`localOS` 指运行 Xray 的系统，使用内核值 `ios/android/darwin/windows/linux`，空列表不限制系统。
未设置的新增字段不输出；这些字段仍保存在现有 Base64 JSON 列中，不改变数据库 schema。

编辑器支持逐条域名、目标 IP 输入及实际安装 Geodata 分类补全。新增条件位于折叠的
“更多匹配条件”中，已有扩展条件的规则自动展示该区域及各条件摘要；协议和系统使用多选。
移动端规则详情与桌面嵌入表单复用实现。
常规自定义当前不开放来源 IP/端口、HTTP 属性、进程匹配、入站选择、本地监听地址/端口、用户、
VLESS 入站路由或 webhook；`sourceIP`、`sourcePort` 不进入普通模式模型或编辑状态。
HTTP 属性 `attrs` 的无效正则在当前内核构造配置时可能触发 panic，因此本次不增加模型字段或
UI，Custom 导入也继续拒绝该字段；Raw JSON 现有通道不变。本次不修改 libXray。
不支持的结构拒绝导入为
常规 Custom，不静默丢字段；更多路由能力使用下节的高级模板，自带节点的完整配置使用 Raw。
导入、导出的根部允许 `name`。
规则子页只更新草稿，不在 Dart 中判断域名/IP、端口、网络及空条件是否合法。整份
Custom 保存或导入提交前，由 libXray 构造临时 instance 校验；空接入槽只在最小验证配置中
替换为本地 freedom 出站，补齐与运行一致的 proxy balancer、所需 Observatory、direct/block
与资源路径，不选择真实节点、不启动 VPN。实际节点与路由的组合交由 Core 启动处理，不再连接前预检。
依赖的 Geodata 先发布，校验失败
则回滚且不覆盖原路由。

分享 JSON 可携带 `geodata.assets: [{"file":"other.dat","url":"https://…"}]`，省略默认
geoip/geosite。依赖扫描包含 IP 反选引用；Raw 另扫描 `sourceIP`（及内核的 `source`
别名）和 `localIP` 中的外部数据，HTTP 属性值不作为资源声明。导入冲突、暂存、发布与回滚见
[Geodata 发布合同](data-management.md#geodata-发布)。

## 高级自定义路由

高级模板使用 `AdvancedRoutingProfile` 独立保存 Map，与常规 State 仅共享 `RoutingConfiguration`
身份、名称、节点数量和保存流程。类型保存在 `RoutingProfile.advanced`，不嵌入 JSON；
两种类型共用三份限额，不支持修改已有记录的类型。Base64 不变。

`outbounds` 必须以 1–3 个连续空槽开头，随后仅支持 freedom/blackhole/dns 辅助出站。
固定单节点选择替换整个槽区域；自动、订阅、地区保持所需数量。实际节点位于运行出站最顶部，
随后保留用户辅助出站顺序，最后补 direct/block。App 生成 proxy roundRobin balancer、
完整 selector、direct 回退及 Observatory；用户不得定义 direct/block/proxy，不能引用内部
app-entry-*/app-exit-*。dnsOut 由模板需要时自行定义，dialerProxy 不支持 balancer。

用户完整管理 DNS、routing.domainStrategy、rules 顺序与 ruleTag。不调用普通 DNS/规则
生成器，不隐式补 DNS server、直连域名、53/853 规则或兜底规则。未命中仍走第一个 outbound。
根级及 server queryStrategy 为 App 托管字段，模板拒绝填写；运行按全局 IPv6 处理。
日志、metrics、统计、policy、env、balancers、observatory、出口网卡同样不作为模板输入。

额外入站支持 socks/http/tunnel，各有独立监听、多个用户账户和 sniffing；不新增 TUN。
模板中的 tunIn 只接受 tag/sniffing，平台部分由 App 生成。sniffing 支持 enabled、routeOnly、
destOverride、metadataOnly、domainsExcluded、ipsExcluded，提供时不隐式修正，省略时使用 App 默认值。
规则在普通范围外支持 inboundTag、localIP、localPort；不开放 process、source/sourceIP/sourcePort、
attrs、user 或 HTTP allowTransparent。辅助出站仅开放 tag/protocol/settings 和 sockopt.dialerProxy。
DNS 使用当前内核字段，FakeDNS 池保留用户配置，省略池遵循 Core 默认值。

保存与导入复用原有协调器、Geodata 事务和冲突保护。校验通过同一填槽逻辑加入本地 freedom
占位，保留 DNS/辅助出站/额外入站/规则；用户 TUN sniffing 由安全 SOCKS 入站承载校验。
不 Start、不测速、不增加启动预检。编译与端口分配复用 Raw 平台策略，但不向完整 Raw 施加模板字段白名单。
导出仅含槽和用户字段，geodata.assets 仅为交换元数据，依赖扫描覆盖 DNS/嗅探等语义位置。

## Raw JSON

Raw 保存完整原文，不经过 Profile 或 `XrayJson`，不因保存或校验改写原始 inbounds。
运行时直接解析为 Map 并在深副本上应用 App 策略。运行副本保留用户
额外入站，但 App 接管 `tunIn`、metrics、统计、日志、DNS 查询策略、运行路径及适用
平台的出口网卡；额外 TUN、保留端口冲突或无法满足平台网络策略的配置明确失败。

已有 tunIn 不再整体重建：保持数组位置、sniffing（包括缺省或关闭）及非托管内容。
仅合并 settings 的 name、mtu、gateway、dns、autoSystemRoutingTable、autoOutboundsInterface。
Windows EXE/Linux 按平台生成六项；Apple/Android 移除不适用的后四项，只更新 name/mtu，
保留 desc、userLevel 等其他设置。settings 格式无效、重复 tunIn 或 TUN 平台协议不符时报错。
整条 tunIn 缺失时才创建默认入站。MSIX/iOS 模拟器明确转换 protocol/listen/port/settings 为
内部 SOCKS，仍保留用户 sniffing 和其他无需转换的内容。数据库及源 JSON 不变。

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
更新任务和运行资源，关闭日志与统计采集，保留用户节点、路由、DNS 和模块依赖。
tunIn 替换为无 TUN 副作用的最小 SOCKS 入站，同时保留用户 sniffing 等待检字段；
不能因为位于托管入站下就跳过嗅探和相关 Geodata 的校验。
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
再创建唯一的 `core-inputs/input-*/xray.json`。Linux 和 Windows EXE/MSIX 同时由 App 创建空的
`xray.json.error`，通过桌面 Core 的 `-error-file` 参数接收实际配置加载、构造或启动错误。
Core 退出后读取本次文件，保留原始错误；没有诊断时才使用通用退出提示，不重新运行
`testXray`。该文件独立于 Xray 的日志开关，不是运行状态或流量记录；Windows 提权 Core
复用 App 预创建文件的读取权限。发布时必须同时打包支持该参数的桌面 Core。
MSIX 通过已有的 `sessionBackend.processes[].arguments` 传入诊断路径，启动失败并清理
本次会话后读取；文件为空或不可读时保留原生启动错误。VCore 继续只负责进程生命周期，
不解析或传输 Core 诊断，MSIX 的连接状态仍由系统 VPN 提供。
输入目录不复用，也不保留历史。Windows MSIX 的
`snapshotToken` 仅用于 VCore Session Snapshot 的宿主归属校验，不能删除或当作 App 运行快照。
Windows EXE 使用系统进程列表按精确进程名 `OneXrayCore.exe` 管理所有存活匹配进程，
按 Windows 名称规则忽略大小写，不匹配完整命令行、名称前缀或其它 `xray` 进程。不保存或
读取旧 PID 记录，不按安装路径、创建时间、用户、Windows session 或配置参数筛选；重开
App 同样直接发现匹配进程。启动前先停止全部匹配进程，再准备新输入；启动确认必须找到
本次新启动的进程，不能由其它同名进程掩盖启动失败。
EXE 的按名停止也会影响其它安装、用户、session 或 MSIX 启动的同名 Core；MSIX 自身的
Provider / Session Host 管理和系统 VPN 状态来源保持独立，不以进程名判断 MSIX 已连接。
停止优先使用匹配进程的句柄终止，权限不足时通过 UAC 提权按名终止，不连带结束其它名称
的子进程。只有退出得到确认且再次查询没有存活匹配进程，才报告已断开；查询、监测、提权
取消或部分停止失败均保留错误，不伪装为已断开。PID 和句柄只用于本次操作及可取消的退出
等待，不作为持久归属记录。进程查询、UAC 和有界退出等待在 worker isolate 内执行，不阻塞 Flutter UI。
Linux 使用系统 `procps` 工具按精确进程名 `OneXrayCore` 管理所有匹配进程，不保存或读取
旧 PID 记录，不校验可执行路径、启动时间、UID 或配置参数。`pgrep -x` 配合存活状态筛选
查询 PID，不再由 Dart 逐个读取 `/proc`；僵尸和已退出进程不视为已连接，也不依赖受
capabilities 保护的 `/proc/<pid>/exe`。工具缺失、执行失败或无效输出不等于已断开。
停止使用 `pkill -TERM -x OneXrayCore`，等待进程退出事件；超时仍存在时才使用
`pkill -KILL -x OneXrayCore`。发送信号成功不等于停止完成，只有再次查询确认没有存活
匹配进程才报告已断开。匹配的是进程名而非完整命令行，不处理其它 `xray` 或名称前缀相似的进程。
每次新进程查询都使之前未完成的查询失效，包括同一监听周期内的一次性状态读取。
退出监听取消或请求停止旧运行时同样使待完成查询失效，即使停止失败也不接受旧查询。
过期结果和错误均不发布通知，也不替换后续查询建立的进程监听；停止失败时保留仍有效的
存活进程监听，不增加轮询或缓存 VPN 状态。

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
- Windows EXE 查询所有同名进程，使用各进程句柄的退出事件；单个退出后重新查询，仍有
  匹配进程时保持已连接，全部退出才通知已断开。Linux 自行启动的进程使用 `Process.exitCode`，
  接管旧进程使用 `pidfd` 退出事件。Linux 接管监测要求内核
  5.3 或更新版本，不支持时明确报错，不退回轮询。
- 仅 Windows MSIX 在自身实现内每 5 秒检查系统 VPN，并在启停期间执行有界的快速确认。
  该监测随 App 进程存活，不随窗口隐藏或失焦停止；必要的去重状态留在 MSIX 内部。
  只读查询不停止 VPN，无效恢复会话由 MSIX 的会话检查显式处理。

`startVpn` / `stopVpn` 成功返回时必须附带已确认的 `connected` / `disconnected`，不再仅表示
“已提交命令”。业务层不追加统一的 200ms 查询循环，各平台只保留自身必要的命令过渡态。
主动查询直接返回状态与权限，不再通过回调事件回传；原生通知只处理系统
主动变化和启停进度。每次同步只读取一次 `start.json`，运行描述缺失时仍保留已确认的
原生状态。

App 的连接页在窗口可见、页面可见且已连接时，按秒读取 Xray 原生 metrics。Flutter 的
`resumed` 和 `inactive` 均视为可见；`hidden`、`paused` 和 `detached` 停止采样。
单纯失焦或重新获得焦点不取消正在读取的样本，也不重置速率基线。连接页作为根页或二级页
时各自报告可见性；只要仍有一个可见连接页，就共享同一个采样器。关闭或隐藏一个页面不会
覆盖其他页面的需求。macOS 菜单栏是独立的后台订阅方，App 驻留时即使切换 Tab 或隐藏窗口，
仍使用同一采样器；页面显隐不重置这份持续采样的速率基线。其他平台没有后台订阅方时，
切换 Tab、打开其他全页而不再有可见连接页，或隐藏窗口、进入后台后停止。断开连接一律停止；
重新显示先建立速率基线，不把隐藏时间摊入
实时速率。流量样本只重建连接页的流量区域。高级页运行时长使用独立的本地时钟，
遵循相同的窗口可见性规则，同时要求 Xray Tab 可见，不触发 metrics 查询。

所有平台直接读取 Xray 的 `GET /debug/vars`，从 `stats.inbound.tunIn` 取得本次连接的
上下行计数，并用相邻有效样本计算速率。空闲时尚未创建的计数器按零显示；请求失败保留
内存中的当前连接计数、将速率标记为不可用，下一次成功读取重新建立基线。

libXray 不再采样、持久化或提供独立统计 HTTP 服务；App 不保存历史/累计流量，不提供清零。
断开后清空内存样本。App 重开通过 `run/start.json` 还原运行描述并定位 metrics 端口；
连接是否成功只由原生状态确认，不依赖 metrics 读取结果。运行时长使用启动请求的时间。

Android 的 VPN 通知和桌面 Widget 共用 `OneVpnService` 内的原生采样器，读取本次启动请求的
metrics 端口；独立于 Flutter 页面及主进程。亮屏时按秒采样，熄屏暂停并清除速率，亮屏后
重新建立基线；不使用 WorkManager、定时闹钟或额外前台服务保持秒级刷新。采样失败保留本次
计数但清除速率，不修改 VPN 状态、不重连。停止、撤销授权和服务正常销毁时取消采样，Widget
回到断开状态。服务异常终止后的 Widget 最终刷新仍取决于系统后续回调，不保证强杀时即时刷新。
HTTP 明文例外仅开放 `127.0.0.1`，不放宽外部域名的传输策略。

Widget 使用 `home_widget` 的原生 Provider、启动 PendingIntent 和 Flutter 固定入口；Provider
与 VPN 服务共处 `:native`，内存传递当前展示值，不将流量写入 SharedPreferences 或文件，
不增加另一套 VPN 状态查询依据。Android 通知和 Widget 使用系统语言、Widget 使用系统明暗主题。
Widget 顶部显示应用图标与连接状态，中间按下载、上传分栏显示速率及本次流量；底部按钮在
未连接时启动、已连接时关闭 VPN，原生启停期间显示按钮内进度并禁止重复点击。
Widget 和快捷设置 Tile 共用原生启动入口：现有 `run/start.json` 包含完整启动请求且 VPN、
局域网权限就绪时，直接启动 `OneVpnService`，不启动 Flutter 引擎、不显示 App。
必要输入不存在、不可读或不完整，以及需要授权时，才打开 App 并复用 `startVpn` 快捷入口。
只检查原生启动所需的包装字段，Xray 配置与本地依赖错误由实际启动报告，不额外运行校验或下载。

快捷启动复用最近一次生成的节点、路由、端口及隧道配置，不读取数据库重新选节点、
测速或更新订阅；保存设置但尚未在 App 中重新生成运行配置时，快捷启动仍使用旧输入。
每次快捷启动原子更新同一 `start.json` 的会话起始时间，原生重新创建 TUN 并注入新 fd；
本次流量由新 Core 的 metrics 重新开始。常规 App 连接仍由协调器编译和写入启动请求。
快捷启动失败停止本次运行，通知显示具体原因并提供打开 App 的入口，不自动重试或拉起页面。
关闭沿用 VPN 通知的原生停止入口，不依赖 Flutter 进程。点击标题或数据区域只打开 App。
iOS、Windows、Linux 本次不增加系统流量展示入口。

## 实现入口

- 编译、选择与运行：`lib/service/connect/`
- 自定义模板与地区：`lib/service/connect/routing/`
- 节点映射及兼容：`lib/service/servers/outbound/map.dart`、`state_db.dart`
- Raw 存储与边界：`lib/service/connect/raw/db.dart`、`validator.dart`
- 订阅与分享：[交换合同](subscriptions-and-sharing.md)；升级与清理：[数据管理](data-management.md)
