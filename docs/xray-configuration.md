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

## 普通配置编译

`ConnectionCompiler` 接收不可变输入，在副本中产生配置，不自行读库、分配端口或启动 Core。
接入按选择范围与测速结果确定；已运行节点不会因后台测速或订阅更新而被热替换。

普通配置始终使用 `balancerTag: proxy`，即使只有一个节点。selector 填写生成节点完整
tag，采用 round-robin，失败回退为阻止。智能路由最终出口独立于接入；每条接入链使用
自己的出口副本，避免链式依赖互相覆盖。Custom 不绑定具体节点或最终出口。

智能路由 IP 补匹配打开时使用 `IPIfNonMatch`：域名首轮未命中才解析为 IP 重新匹配；
关闭为 `AsIs`，按请求已有域名或 IP 匹配。默认 VPN 通过内部 loopback 入站交给
balancer，不用无条件 catch-all 提前截断 IP 第二轮匹配。

App DNS 固定两个 `8.8.8.8` server，以独立 tag 分别走 proxy/direct。direct server 的
domains 从当前 direct 规则提取，且不作为通用 fallback；DNS 阶段不宣称已判断 IP、端口
或网络条件。直连地区依据安装的官方 Geosite/GeoIP 分类和随包地区映射生成。

## 自定义路由

规则只允许域名、IP、端口、网络四类条件。不同条件为 AND，同类多值为 OR；建议只填
一种条件。规则顺序决定匹配顺序，名称使用原生 `ruleTag`，没有启用/停用自定义字段。
动作只允许 `balancerTag: proxy` 或 `outboundTag: direct|block`。

编辑器支持逐条域名/IP 输入及实际安装 Geodata 分类补全。不支持的结构拒绝导入为
Custom，不静默丢字段；完整高级配置使用 Raw。根部允许 `name`。

分享 JSON 可携带 `geodata.assets: [{"file":"other.dat","url":"https://…"}]`，省略默认
geoip/geosite。导入先校验、下载并生成索引，文件名冲突拒绝；资产与路由成功提交后，
持久 JSON 删除导入专用 `geodata` 字段。详见 [数据管理](data-management.md)。

## Raw JSON

Raw 保存完整原文，不经过 Profile，不因保存或测试改写原始 inbounds。运行副本保留用户
额外入站，但 App 接管 `tunIn`、`pingIn`、metrics、统计、日志、IPv6、运行路径及适用
平台的出口网卡；额外 TUN、保留端口冲突或无法满足平台网络策略的配置明确失败。

Windows 的 `tunIn` 是私有 loopback SOCKS，系统流量由 VCore Provider/Session Host 转交；
Android、Apple、Linux 使用平台 TUN。Windows 只给 Xray 绑定所选网卡，不给 VCore 新增
绑定要求。iOS Debug 本地代理仅替换调试入口，不改变正常持久配置或正常 UI 逻辑。

Raw 真实测试通过 libXray 临时实例执行 DNS、路由与 URL 探测，不调用 Core.Start 或绑定
用户入站；WireGuard/VLESS reverse 等构造即有副作用的路径拒绝。构建校验与实际可连接
是不同门槛，不能用测试结果冒充所有平台 VPN 启动成功。

## 运行协调与统计

`ConnectionCoordinator` 串行准备、启动、确认、提交与恢复。一次连接有不可变计划、独立
运行文件和 Geodata 副本；原生状态是 VPN 状态依据，metrics 失败不等于断开。
重连新配置或数据库提交失败时补偿旧方案，停止失败保留恢复记录，不虚报成功。

前台直接读取 Xray 原生 metrics。libXray 以 30 秒为目标保存本次会话累积数据，正常停止
尽力保存，下次启动前归档；App 将累计与消费水位原子保存，负责累计清零与归档清理。
前后台无职责交接协议，异常退出允许丢失未保存尾部，不新增 HTTP 控制服务或修改 VCore。

## 实现入口

- 编译/选择/计划/运行：`lib/service/connection/`
- 自定义模板与地区：`lib/service/routing/`
- 节点映射及兼容：`lib/service/xray/outbound/map.dart`、`state_db.dart`
- Raw 存储与边界：`lib/service/xray/raw/db.dart`、`validator.dart`
- 订阅与分享：[交换合同](subscriptions-and-sharing.md)；升级与恢复：[数据管理](data-management.md)
