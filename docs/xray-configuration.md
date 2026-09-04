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
  `ConnectionConfig` 只保存当前连接配置 JSON，不保存 VPN 状态、`confirmedPlanId`、运行快照
  或提交日志。
  配置写入经协调器串行执行，保留旧草稿内容校验与独占维护门，不额外保存提交修订号。

## 普通配置编译

`ConnectionCompiler` 接收不可变输入，在副本中产生配置，不自行读库、分配端口或启动 Core。
`XrayJson` 是普通模式最终配置的唯一结构；除明确声明为 Map 的 payload 外不保留未知
字段，也不解析 Raw JSON。outbounds 的元素保持 `Map<String, dynamic>`，便于直接插入
完整代理节点。
`XrayJson` 文件只定义字段映射和标准 `fromJson` / `toJson`，不负责协议分派、校验或
运行配置构造。TUN、SOCKS、HTTP 入站设置及系统出站使用类型模型，具体运行配置由
`runtime_inbounds.dart` 和 `runtime_outbounds.dart` 构造后写入对应 Map；系统出站的最小
`streamSettings.sockopt` 只包含实际生成的 `dialerProxy` 和 `interface`。
运行时调整后仍须由 `XrayJson` 重新序列化，不得向普通配置注入模型外字段。
Raw 使用独立的 Map 编译路径，未由 App 管理的根字段和嵌套字段原样保留。
接入按选择范围与测速结果确定；已运行节点不会因后台测速或订阅更新而被热替换。
测速状态直接由已有延迟值区分未检测、成功、失败与超时；地区使用出口国家代码，不保存
测量来源或时间，也不引入时间过期判定或新的“是否测过”字段。

普通配置中显式选择代理的规则始终使用 `balancerTag: proxy`，即使只有一个节点。
selector 填写生成节点完整 tag，采用 round-robin，失败回退为阻止。未命中规则的流量不
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

智能路由 IP 补匹配打开时使用 `IPIfNonMatch`：域名首轮未命中才解析为 IP 重新匹配；
关闭为 `AsIs`，按请求已有域名或 IP 匹配。这里配置的是 `routing.domainStrategy`；App
生成的所有 rule 均省略可选的 `type: field`，且不增加无条件 catch-all 提前截断 IP
第二轮匹配。Custom 导入将 `type` 视为不支持的字段并直接拒绝；完整 Raw JSON 保留用户
原文，包括用户自行填写的 `type`。

App DNS 固定两个 `8.8.8.8` server，以独立 tag 分别走 proxy/direct。direct server 的
domains 从当前 direct 规则提取，且不作为通用 fallback；DNS 阶段不宣称已判断 IP、端口
或网络条件。普通模式只给每个 server 设置查询策略，不生成根级 `hosts` 或
`queryStrategy`。直连地区依据安装的官方 Geosite/GeoIP 分类和随包地区映射生成。

## 自定义路由

普通 Custom 的持久化链路固定为 `RoutingProfile` 表 ↔ `XrayJson` ↔
`RoutingProfileState`：数据库适配层负责 Base64 解码、模型解析和规范化重编码，业务与 UI
只使用 State。名称仍保存在 `RoutingProfile.name` 列，不写入配置根部。
`XrayJson.geodata` 只承载导入所需的 `assets`，每项仅含 `file` / `url`；导入完成后保存前
移除 `geodata`。完整 Raw JSON 使用独立 Map 链路，不经过上述转换。

规则只允许域名、IP、端口、网络四类条件。不同条件为 AND，同类多值为 OR；建议只填
一种条件。规则顺序决定匹配顺序，名称使用原生 `ruleTag`，没有启用/停用自定义字段。
动作只允许 `balancerTag: proxy` 或 `outboundTag: direct|block`。

编辑器支持逐条域名/IP 输入及实际安装 Geodata 分类补全。不支持的结构拒绝导入为
Custom，不静默丢字段；完整高级配置使用 Raw。根部允许 `name`。

分享 JSON 可携带 `geodata.assets: [{"file":"other.dat","url":"https://…"}]`，省略默认
geoip/geosite。导入先在同级临时目录下载、校验并生成索引，文件名冲突拒绝；资产发布到
`VpnConstants.datDir` 的平铺根目录且路由成功提交后，持久 JSON 删除导入专用 `geodata`
字段。详见 [数据管理](data-management.md)。

## Raw JSON

Raw 保存完整原文，不经过 Profile 或 `XrayJson`，不因保存或测试改写原始 inbounds。
运行时直接解析为 Map 并在深副本上应用 App 策略。运行副本保留用户
额外入站，但 App 接管 `tunIn`、metrics、统计、日志、IPv6、运行路径及适用
平台的出口网卡；额外 TUN、保留端口冲突或无法满足平台网络策略的配置明确失败。

Windows 的 `tunIn` 是私有 loopback SOCKS，系统流量由 VCore Provider/Session Host 转交；
Android、Apple、Linux 使用平台 TUN。Windows 只给 Xray 绑定所选网卡，不给 VCore 新增
绑定要求。iOS Debug 本地代理仅替换调试入口，不改变正常持久配置或正常 UI 逻辑。

Raw 真实测试通过 libXray 临时实例执行 DNS、路由与 URL 探测，不调用 Core.Start 或绑定
用户入站；WireGuard/VLESS reverse 等构造即有副作用的路径拒绝。构建校验与实际可连接
是不同门槛，不能用测试结果冒充所有平台 VPN 启动成功。

## 运行协调与统计

`ConnectionCoordinator` 串行完成内存准备、停止旧运行、启动并确认新运行，最后提交数据库
设置。`ConnectionRuntime` 不单独序列化；`run/start.json` 是唯一原生启动请求，其中
`coreInvokeText` 保存实际 Xray 输入，`metadataJson` 只保存重开 App 后显示运行路径和保护
节点所需的配置及节点信息。不创建 `ConnectionPlan`、`run/plans/<id>`、`confirmedPlanId`
或跨进程提交日志。

准备阶段先完成 Windows/Linux 出口网卡存在性检查，再对最终配置执行一次
`libXray.testXray(buildOnly: true)` 构建校验；两者均发生在停止旧运行或启动原生 VPN 之前。
build-only 校验只提前发现配置构建错误，不保证所有平台资源、端口或 handler 运行时错误。

准备失败且尚未触碰宿主时，当前运行不变。一旦已请求停止或启动原生 VPN，后续启动、确认、
资产写入或数据库提交失败时，协调器尽力停止本次运行并进入 `failed`；不重新启动旧连接，
也不恢复旧输入。若停止无法确认，原生状态仍是 VPN 状态依据，并继续显示能够确认的实际
运行信息；metrics 或运行描述不可用不等于已断开。重试时重新查询宿主，不从缓存推断状态。

Windows 和 Linux 每次实际启动桌面 Core 前，在旧运行停止后清理整个 `run/core-inputs`，
再创建唯一的 `core-inputs/input-*/xray.json`；托管运行同时写同目录的
`runtime-config.json`。输入目录不复用，也不保留历史。Windows 的 `snapshotToken` 仅用于
VCore Session Snapshot 的宿主归属校验，不能删除或当作 App 运行快照；Linux 只额外保存
验证进程归属所需的 PID、启动时间和本次输入路径。

`VpnConstants.datDir` 是 App 管理的唯一 Geodata 读写目录，DAT、同名索引和时间戳均平铺
存放。普通运行环境的 `xray.location.asset` 与 `xray.location.cert` 始终指向该目录，VPN
准备和启动过程不创建 Geodata 快照。macOS System Extension 因容器隔离可以沿用现有 Swift
实现传输 Geodata；这是原生平台边界的唯一例外，不改变 App 侧单目录合同。

状态同步与实时流量读取分开：初始化先订阅原生通知，再校准一次状态；恢复前台时再校准
一次。Apple/Android 使用原生状态通知，不常驻轮询。Windows 暂用前台 5 秒状态查询兜底；
Linux 仅在接管已有进程、没有当前 `Process` 退出通知时使用相同兜底。启停操作保留有界
状态/就绪确认。查询回包仍广播，重复值仅抑制重复日志与重复状态处理。

仅在 App 前台、连接页或其流量弹窗可见且已连接时，按秒读取 Xray 原生 metrics；切换
Tab、打开其他全页、进入后台或断开后停止。重新显示先建立速率基线，不把隐藏时间摊入
实时速率；高级页运行时长使用独立的可见性受控本地时钟，不触发 metrics 查询。

libXray 以 30 秒为目标原子覆盖本次会话的 `runtime.json`，正常停止时尽力最终保存；新会话
直接覆盖旧会话。带 Bearer 认证的回环 `GET /runtime` 只返回当前会话计数，不创建
`runtime-sessions`，也没有归档、ACK 或清理接口。该接口不提供 VPN 启停或累计清零；实时
计数继续读取 Xray 原生 metrics，不修改 VCore。

所有平台使用同一统计读取链路，App 不读 libXray 会话文件，macOS SE 也不再通过原生
消息代读；libXray 自己持有文件权限，日志与 DAT 的原生消息保持独立。HTTP 地址与随机
令牌属于私有启动请求，不允许 Raw 覆盖，不写入日志或分享内容。App 重开从
`run/start.json` 定位当前候选端点，但只有原生状态与 HTTP 当前会话能够确认实际运行。

App 在 `traffic-totals.json` 中只保存设备累计、一个会话的消费水位和最后显示值。离线清零
保留当前水位，不影响本次连接后续增量。这里不做严格计费：异常退出可能丢失尚未保存的
尾部；若 App 未观察到两个 Core 启动之间的完整会话，该会话也可能全部丢失。统计 HTTP
随 Core 停止，端点不可用时只显示 App 缓存，不把缓存当成当前连接事实。

## 实现入口

- 编译、选择与运行：`lib/service/connection/`
- 自定义模板与地区：`lib/service/routing/`
- 节点映射及兼容：`lib/service/xray/outbound/map.dart`、`state_db.dart`
- Raw 存储与边界：`lib/service/xray/raw/db.dart`、`validator.dart`
- 订阅与分享：[交换合同](subscriptions-and-sharing.md)；升级与恢复：[数据管理](data-management.md)
