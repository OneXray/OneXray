# 订阅、导入与分享

OneXray 有两类不同的交换边界：标准代理分享格式用于与其它客户端互通；OneXray App Link 用于保留 OneXray 自身配置。两者不能承诺相同的保真度。

## 订阅更新

订阅保存名称、URL、更新时间、节点数量和可选 Age 密钥对。添加、编辑或刷新时的共同流程是：

1. 下载订阅正文。
2. 如配置 Age，在内存中解密。
3. 由 libXray 严格解析分享链接、Clash YAML 或 Xray JSON。
4. App 只读取结果中的 outbounds，并过滤不满足规范值检查的节点。
5. 在数据库事务中替换该订阅的全部节点。

下载、解密、解析或写入失败时保留旧数据。单个订阅成功导入后安排节点测速；批量导入不会让大量自动测速长期占用桌面端串行 libXray 工作线程。

订阅自动更新使用统一后台更新服务，检查频率与周期由 [数据管理](data-management.md) 统一说明。

## 标准导入边界

- 标准分享链接和 Clash YAML 只能表达各自协议支持的字段。
- 完整 Xray JSON 导入只返回其中的 outbounds，不会导入根级 DNS、routing 或其它配置。
- App 直接保存 libXray 返回的 outbound 映射，不通过旧 DTO 重建。
- libXray 和 App 都使用 outbound `tag` 传递并保存节点名称；无名称的单节点以协议名补齐 `tag`。
- 历史 outbound 仅在 `tag` 不存在时把 `name` 作为别名迁移到 `tag`；已有 `tag` 优先。
- `sendThrough` 保留 Xray 的本地绑定地址语义，不参与节点命名，也不会在导入时删除。
- 不支持的节点或非规范值明确失败或跳过，不静默改写为新默认值。
- KCP seed/header 和已废弃的 `allowInsecure` 不在当前分享合同中。

标准分享是有损投影。需要完整保留 OneXray 配置时必须使用 App Link 或 JSON 文件。

## OneXray App Link

固定 scheme 与 host 为：

```text
onexray://onexray.com
```

支持三类路径：

```text
/config/add?type=outbound|profile|full|raw&data=<base64>#<name>
/sub/add?url=<https-url>&age=x25519|hybrid#<name>
/dat/add?type=domain|ip&url=<https-url>#<name>
```

其中 `full` 是多节点出站为兼容旧数据保留的序列化值，不表示完整 Xray 配置。配置链接的 `data` 保存完整持久 JSON；订阅和 GeoData 链接只接受 HTTPS URL。

解析器执行严格边界检查：scheme、host、path 和参数名必须匹配；必填参数只能出现一次；未知参数、重复参数、无效类型和损坏 Base64 都拒绝。fragment 只作为显示名称。

Age App Link 只分享算法类型，不分享密钥；接收端会生成新的密钥对。详细行为见 [Age 加密订阅](age-encrypted-subscriptions.md)。

## 分享形式

- Outbound：可以生成标准分享链接；能否表示所有字段取决于协议白名单。
- Profile、Multi-node Outbound、Raw JSON：可以导出 JSON 文件和 OneXray App Link。
- Subscription：可以分享原订阅 URL 和 OneXray App Link。
- GeoData：可以分享 OneXray App Link。

生成 App Link 前使用同一解析器做回读校验，避免产生自身无法导入的链接。标准分享与 App Link 的配置细节见 [Xray 配置合同](xray-configuration.md)。

## 主要实现入口

- 订阅服务：`lib/service/subscription/`
- 标准分享解析：`lib/service/share/xray_share_reader.dart`
- App Link：`lib/service/share/app_link_model.dart`、`app_link_parser.dart`、`app_link_generator.dart`、`app_link_importer.dart`
- 分享页面：`lib/pages/home/share/`
- libXray 桥接：`lib/core/pigeon/host_api.dart`
