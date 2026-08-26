# Xray 配置合同

本文描述 OneXray 当前支持的配置类型、编辑边界、运行时物化和兼容约束。历史上的整体重构方案和实施批次不再是有效设计。

## 配置类型

| 类型 | 持久内容 | 运行时角色 |
| --- | --- | --- |
| 单节点出站（Outbound） | 一个完整的 outbound 对象，外层使用 `{"outbounds":[...]}` | 写入当前 Profile 的 `proxy`，可与 Final Outbound 组成链路 |
| 简单 Profile | Preferences 中的产品级选项 | 生成基础 Profile 映射 |
| 自定义 Profile | OneXray 支持的完整根级映射 | 提供共享的 inbounds、DNS、routing、日志和系统 outbound |
| 多节点出站 | `name`、`outbounds`、`dns`、`routing` | 覆盖当前 Profile 的三个 Xray 根字段 |
| Raw JSON | 独立 Xray JSON 对象 | 作为运行主体，但仍接受 App 的 inbound 和运行时修补 |

所有数据库内容继续使用现有 Base64 JSON 包装。`name` 是 OneXray 扩展字段：Profile 根节点、多节点出站根节点和 outbound 对象中的 `name` 都必须保留。

兼容值保持不变：Profile 的数据库类型仍为 `setting`；多节点出站的数据库类型和 App Link `type` 仍为 `full`；历史路由段仍为 `xray-full-config`。这些序列化值不用于用户可见名称。

## 自定义 Profile

自定义 Profile 允许以下根字段：

```text
name
log
routing
dns
inbounds
outbounds
policy
metrics
stats
fakeDns
observatory
burstObservatory
```

约束如下：

- `name` 必须是非空字符串。
- `inbounds`、`outbounds` 必须是数组；`fakeDns` 可以是对象或数组；其余 Xray 根字段必须是对象或 `null`。
- `env` 由 App 在运行时写入，用户不能自定义。
- `api`、`version`、`geodata`、Xray-core 已废弃的根字段和未知根字段不受支持。
- 根字段内部保持开放。App 不维护完整 Xray schema，最终语义由 Xray-core 校验。

新建自定义 Profile 会包含基础 DNS、routing、App 保留的 inbounds/outbounds、FakeDNS，以及启用流量统计的 `policy.system`。`metrics` 和 `stats` 在高级区显示运行时默认值，不提供字段级编辑入口，但完整 Raw JSON 编辑器仍可修改整个 Profile 文档。

页面只为常用内容提供结构化 UI：

- `inbounds`、`outbounds`：根字段 JSON。
- `routing`：`domainStrategy` 和根字段 JSON。
- `dns`：服务器的 `address`、`port`、顺序和根字段 JSON。
- `fakeDns`：IPv4/IPv6 pool 和根字段 JSON。
- `log`：常用日志字段和根字段 JSON。
- `policy`、`observatory`、`burstObservatory`：高级根字段 JSON。
- `metrics`、`stats`：只读展示；需要时使用完整 Raw JSON。

结构化 UI 无法安全识别某个值的 JSON 结构时，该部分只能通过 Raw JSON 编辑，原映射不会回落到默认值。

## 多节点出站

多节点出站不是完整 Xray 配置，只允许：

```text
name
outbounds
dns
routing
```

其中 `name` 只用于 OneXray 身份。覆盖 Profile 时只处理 `outbounds`、`dns`、`routing`：

| 根字段状态 | 物化行为 |
| --- | --- |
| 缺失 | 继承 Profile 对应根字段 |
| `null` | 删除 Profile 对应根字段 |
| 其它值 | 整根替换，不递归合并 |

保存前必须满足：

- `outbounds` 中存在唯一 tag 为 `proxy` 的主出站。
- 所有 outbound tag 非空且唯一。
- `direct`、`fragment`、`block`、`dnsOut` 使用约定的保留协议。
- `dialerProxy` 与 `proxySettings.tag` 不冲突；依赖存在且没有循环。
- Shadowsocks method 和 VMess security 使用 App 支持的规范值。

页面仅有 Outbounds、Routing、DNS 三个分区。每个分区提供有限的结构化 UI 和对应根字段 JSON；页面顶部的 Raw JSON 编辑器只编辑四字段文档。编辑尚未持久化的 DNS 或 Routing 时，可以从当前 Profile 复制有效根字段作为草稿，取消编辑不会写回。

## 单节点出站

Outbound 全链路以完整 `Map<String, dynamic>` 为事实源。表单只映射常用浅层字段；无法映射或分享协议无法表达的内容通过完整 Raw Xray JSON 编辑。普通表单只修改目标字段，不应重建整个对象或删除未知的同级字段。

结构化 UI 当前支持：

- 协议：VLESS、VMess、Shadowsocks、Trojan、SOCKS、Hysteria2。
- Transport：`raw`、`ws`、`grpc`、`httpupgrade`、`xhttp`；Hysteria2 使用固定的 `hysteria` transport。
- TLS：`serverName`、`fingerprint`、`echConfigList`、`pinnedPeerCertSha256`、`verifyPeerCertByName`。
- REALITY：`serverName`、`fingerprint`、`password/publicKey`、`shortId`、`mldsa65Verify`、`spiderX`。

当前没有 ALPN、KCP、`tcp`、`websocket`、`splithttp` 或已废弃 `allowInsecure` 的结构化 UI。已有 JSON 不会因此被自动改写；用户可继续通过 Raw JSON 编辑。

Outbound Raw 编辑器使用以下完整根对象，并要求 `outbounds` 恰好包含一个对象：

```json
{
  "outbounds": [
    {}
  ]
}
```

Shadowsocks method 和 VMess security 是 App 额外维护的最小规范值检查。集合外的值必须在导入、保存、验证、Ping、运行和标准分享路径明确失败；其它 Xray 字段交给 Xray-core 验证。

## Raw JSON 配置

Raw JSON 不使用自定义 Profile 的根字段白名单，但 JSON 顶层必须是对象，并包含非空 `name`。

保存时 App 会将 `inbounds` 规范化为内部 `pingIn`。运行时：

- TUN 模式从当前 Profile 复制 inbounds，再生成或合并 `tunIn` 和 `pingIn`。
- iOS Debug Proxy 模式移除全部原有入站，只加入 App `pingIn`。
- `env`、DNS query strategy、日志、metrics、Ping routing rule 和平台 TUN route 仍由 App 修补。

因此 Raw JSON 是运行主体，但用户定义的运行时入站不拥有最终控制权。TUN 模式需要额外入站时，应在自定义 Profile 中配置；Proxy 模式不保留这些额外入站。

## 编辑与验证边界

完整 Raw 编辑器替换整个目标文档；根字段编辑器只接受空对象或只含目标根字段的对象：

```json
{}
```

空对象表示从当前文档删除该根；只含目标根字段的对象会原样保存它的值，不执行递归合并，也不提供 JSON Patch。`null` 在 Profile 中只是原样保存；只有多节点出站覆盖 Profile 时，`null` 才表示删除对应根。

验证分为两层：

1. App 检查 JSON 根结构、名称、保留 tag、Outbound 依赖和两个规范值集合。
2. App 在副本上补齐验证所需的运行时字段，再调用 Xray-core `testXray` 检查完整语义。

Profile 验证直接使用 Profile 副本；多节点出站验证会先覆盖当前 Profile。Ping 路径并未统一成单一编译器：Outbound 使用单节点包装，Raw JSON 使用保存文本，多节点出站当前只使用自身四字段文档，不覆盖 Profile。文档和代码不得声称验证、Ping、运行已完全共用同一物化结果。

## 运行时物化

启动前先读取当前 Profile 和 TUN Settings，然后按选中配置生成副本：

- 普通 Outbound：写入 `proxy`；配置了 Final Outbound 时，选中节点成为 `chainProxy`，Final Outbound 成为 `proxy`。
- 多节点出站：按三态规则覆盖 Profile 的 `outbounds`、`dns`、`routing`。
- Raw JSON：保留自身主体，并从 Profile 接管运行时入站。
- Direct 且选中项不是多节点出站：忽略选中节点，直接从 Profile 生成配置。

随后 App 写入 `env`、运行时端口、inbounds、Ping rule、日志、metrics、DNS query strategy，以及 Windows/Linux TUN route。所有修改都发生在副本上，不反写数据库中的 JSON 映射。

Core 运行模式与路由模式是两个独立维度。正式版本和非 iOS 平台固定使用 TUN；Proxy 仅在 iOS Debug 中可选。

路由模式当前行为：

- Rule：保留配置中的 DNS 和 routing。
- Global：移除 DNS 和 routing。Profile、Outbound 和多节点出站路径验证 `proxy` 依赖后将它放在首位并保留其它 outbounds；Raw JSON 路径只保留 `proxy` 及其依赖链。
- Direct：不要求普通选中节点，移除 DNS 和 routing，将 `direct` 放在首位并清除它的代理依赖。多节点出站仍先覆盖 Profile，再应用 Direct。

## 分享与兼容

- libXray Invoke API 保持 v2。完整 Xray JSON 导入只读取其中的 outbounds。
- 分享链接和 Clash YAML 导入直接保存 libXray 返回的 outbound 映射，不经过 App DTO 重建。
- 标准协议分享使用 libXray 白名单投影，天然可能丢失协议无法表达的字段；OneXray App Link 保存完整持久映射。
- `sendThrough` 只在标准分享边界充当名称载体，导入后提升为 OneXray `name` 并从 outbound 中移除。
- KCP 分享不支持 seed/header；`allowInsecure` 已移除。
- Profile 和 Multi-node Outbound 不支持 `geodata` 根字段。GeoData 文件仍由 App 的独立数据功能管理，详见 [数据管理](data-management.md)。

## 主要实现入口

- 根字段、复制、根编辑与覆盖：`lib/service/xray/config_map.dart`
- Outbound 映射与 UI 字段映射：`lib/service/xray/outbound/`
- Profile：`lib/service/xray/profile/`
- Multi-node Outbound：`lib/service/xray/multi_node_outbound/`
- Raw JSON 修补：`lib/service/xray/raw/`
- 最终运行配置：`lib/service/vpn/runtime_config.dart`
