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

节点测速和编辑使用模型封装单节点或节点列表，手写节点 JSON 提取 outbounds 后直接交给
libXray 校验，通过后才映射入库；启动前 `testXray` 与实际 `runXray`
使用同一份已编译 JSON，不再次生成配置。智能路由预览直接消费 `XrayRoutingRule`，自定义
规则由编辑 State 生成模型；界面预览与运行编译共用规则生成逻辑。

Xray 字段的有效性以 libXray 为准。App 不维护协议、加密算法、端口、网络类型、重复
tag 等额外校验规则，也不因 VMess 省略 security 而拒绝内核已接受的节点。标准分享解析、
测速和分享生成采用对应 libXray API 的结果；节点编辑、手写导入、完整配置保存和启动
预检使用 `testXray`。App 保留自定义名称校验，以及文件/链接安全、资产数量与事务完整性、
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
智能路由和自定义路由保留两个 `8.8.8.8` server，以独立 tag 分别走 proxy/direct。
direct server 的 domains 从当前 direct 规则提取，且不作为通用 fallback；DNS 阶段不
宣称已判断 IP、端口或网络条件。普通模式只给每个 server 设置查询策略，不生成根级 `hosts` 或
`queryStrategy`。直连地区依据安装的官方 Geosite/GeoIP 分类和随包地区映射生成。

## IPv6 策略

关闭 IPv6 时，Apple、Android 不配置隧道 IPv6 地址、路由和 DNS，传给 Native 的 TUN
参数也不携带 IPv6 地址和 DNS。Linux 由 Xray-core 创建网卡，其 `tunIn.settings` 中同样
省略 IPv6 网卡参数。Windows 的 tun2socks / VCore 配置不受此次简化影响，保持原有处理。

除此之外，Dart 编译只将 DNS 查询策略设为 `UseIPv4`，开启时为 `UseIP`：普通模式设置
每个 DNS server 的 `queryStrategy`，Raw 同时设置根级和对象形式 server 的查询策略。
不生成 IPv6 阻断规则、不注入 `ForceIPv4` 或 DNS hosts、不预解析节点域名，也不因关闭
IPv6 而拒绝 IPv6 节点或 DNS 地址。Raw 中用户自带的路由、hosts、出站解析策略和地址
保持不变；关闭开关不代表 Xray 的所有 IPv6 流量都被禁止。

## 自定义路由

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
Custom 保存或导入提交前，由 libXray 校验；空接入槽只在校验副本中替换为本地 freedom
出站，并补齐固定 proxy balancer，不选择真实节点、不启动 VPN。依赖的 Geodata 先发布，
校验失败则回滚且不覆盖原路由。

分享 JSON 可携带 `geodata.assets: [{"file":"other.dat","url":"https://…"}]`，省略默认
geoip/geosite。导入先在同级临时目录下载、校验并生成索引，文件名冲突拒绝；资产发布到
`VpnConstants.datDir` 的平铺根目录且路由成功提交后，持久 JSON 删除导入专用 `geodata`
字段。详见 [数据管理](data-management.md)。

## Raw JSON

Raw 保存完整原文，不经过 Profile 或 `XrayJson`，不因保存或校验改写原始 inbounds。
运行时直接解析为 Map 并在深副本上应用 App 策略。运行副本保留用户
额外入站，但 App 接管 `tunIn`、metrics、统计、日志、DNS 查询策略、运行路径及适用
平台的出口网卡；额外 TUN、保留端口冲突或无法满足平台网络策略的配置明确失败。

Windows 的 `tunIn` 是私有 loopback SOCKS，系统流量由 VCore Provider/Session Host 转交；
Android、Apple、Linux 使用平台 TUN。Windows 只给 Xray 绑定所选网卡，不给 VCore 新增
绑定要求。iOS Debug 本地代理仅替换调试入口，不改变正常持久配置或正常 UI 逻辑。
Debug 启动时将入站替换为 SOCKS 的请求副本原子写入 `run/start.json`，再把同一份
`coreInvokeText` 传给 libXray；写入失败则不启动 Core。原始编译输入、数据库配置及运行
元数据保持不变，Debug 开关本身不持久化。

Raw 配置校验使用 libXray 的 `testXray` 加载并构建配置，不创建或启动 Xray instance。
构建器仍可能读取本地资产、证书并应用根 `env`；校验成功只说明配置可以构建，不保证
运行时资源可用、VPN 可以启动或网络可以连接。节点延迟和位置检测使用 `pingBatch`。

## 运行协调与统计

`ConnectionCoordinator` 串行完成内存准备、停止旧运行、启动并确认新运行，最后提交数据库
设置。`ConnectionRuntime` 不单独序列化；`run/start.json` 是唯一原生启动请求，其中
`coreInvokeText` 保存实际 Xray 输入，`metadataJson` 只保存重开 App 后显示运行路径和保护
节点所需的配置、节点信息及启动时间。不另存运行计划、快照或跨进程提交日志。

Raw 与自定义路由编辑先完成用户确认，再进入连接队列。携带 Geodata 的保存由导入模块
统一管理文件发布与回滚；连接队列取得执行权后才进入文件队列，在同一文件访问范围内
完成配置校验、必要的启停和数据库提交。只读状态与 metrics 不进入数据维护保护，清理
停止连接时同样使先前读取回调失效。

准备阶段先完成 Windows/Linux 出口网卡存在性检查，再对最终配置执行一次
`libXray.testXray` 构建校验；两者均发生在停止旧运行或启动原生 VPN 之前。
`testXray` 在加载配置前拒绝同进程已有的受管理 Xray instance；调用方负责进程隔离。

准备失败且尚未触碰宿主时，当前运行不变。一旦已请求停止或启动原生 VPN，后续启动、确认、
资产写入或数据库提交失败时，协调器尽力停止本次运行并进入 `failed`；不重新启动旧连接，
也不恢复旧输入。若停止无法确认，原生状态仍是 VPN 状态依据，并继续显示能够确认的实际
运行信息；metrics 或运行描述不可用不等于已断开。重试时重新查询宿主，不从缓存推断状态。

清空数据前，若宿主已断开，且 Apple 原生权限明确返回“不需要”（iOS 模拟器），
则直接完成停止步骤，不调用系统 VPN 停止接口。正在运行的 iOS Debug 本地代理仍通过
libXray 停止；真实 Apple VPN 即使已断开，也仍执行停止命令以关闭按需连接。状态查询或
实际停止失败时继续阻止数据替换，不将失败当作空闲。

Windows 和 Linux 每次实际启动桌面 Core 前，在旧运行停止后清理整个 `run/core-inputs`，
再创建唯一的 `core-inputs/input-*/xray.json`。输入目录不复用，也不保留历史。Windows 的 `snapshotToken` 仅用于
VCore Session Snapshot 的宿主归属校验，不能删除或当作 App 运行快照；Linux 只额外保存
验证进程归属所需的 PID、启动时间和本次输入路径。

普通运行环境的 `xray.location.asset` 与 `xray.location.cert` 始终指向唯一、平铺的
`VpnConstants.datDir`，VPN 准备和启动不复制资产。发布事务与 macOS System Extension
跨容器传输边界见 [Geodata 发布](data-management.md#geodata-发布)。

状态同步与实时流量读取分开：初始化先订阅原生通知，再校准一次状态；恢复前台时再校准
一次。Apple/Android 使用原生状态通知，不常驻轮询。Windows 暂用前台 5 秒状态查询兜底；
Linux 仅在接管已有进程、没有当前 `Process` 退出通知时使用相同兜底。启停操作保留有界
状态/就绪确认。查询回包仍广播，重复值仅抑制重复日志与重复状态处理。

仅在 App 前台、连接页或其流量弹窗可见且已连接时，按秒读取 Xray 原生 metrics；切换
Tab、打开其他全页、进入后台或断开后停止。重新显示先建立速率基线，不把隐藏时间摊入
实时速率；高级页运行时长使用独立的可见性受控本地时钟，不触发 metrics 查询。

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
