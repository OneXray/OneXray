# 订阅、导入与分享

标准分享格式用于与其它客户端互通；OneXray App Link、完整 JSON 与资产备份承担不同的
保真边界，不能互相替代。所有导入在显式用户操作后提交，系统链接先进入新导入流程。

## 订阅

添加和刷新复用相同流程：下载正文、可选 Age 内存解密、libXray 解析、App 校验，
可用节点大于零才创建/更新。没有导入预览或二次确认；零可用、网络/解析/事务失败保留
旧数据与表单。只报告本轮导入的可用数及识别失败数，不比较单节点 hash，不虚报新增/更新数。

编辑只保存名称、URL 和 Age 设置，并使旧下载请求失效；不下载、不替换现有节点，也不要求
当前已有可用节点。新的 URL 和密钥用于后续刷新。

替换时保留当前运行中的全部节点、当前固定节点、配置的最终出口及收藏原行；
这些保留行不计入本轮导入数。退出整个保护集合后才允许后续更新替换。
成功结果进入现有自动测速队列，测量延迟与出口地区；后台结果不热切换当前连接。

Age 公钥和私钥保存在订阅及敏感备份内，不随普通分享发出。分享只含算法，接收端生成
新的密钥对。详见 [Age 合同](age-encrypted-subscriptions.md)。

## 节点与标准格式

- 分享链接、Clash YAML 与普通 Xray JSON 节点导入只提取 outbounds，不导入其根级路由/DNS。
- 完整 outbound 映射直接保存，不经过字段表单重建；标准分享是协议白名单投影，可能有损。
- 节点名称使用 `tag`；仅在键不存在时兼容旧 `name`，已有 tag 优先，无名节点以协议名补齐。
- `sendThrough` 保留本地绑定语义，不参与命名。不支持的节点或规范值明确失败，不静默改写。
- KCP seed/header 和已废弃 `allowInsecure` 不在标准分享合同内。
- 文件直接调用系统选择器；扫码仅 iOS/Android，不能用桌面入口冒充相机支持。

## App Link

固定 scheme/host 为 `onexray://onexray.com`，当前接受：

```text
/config/add?type=outbound|raw|custom&data=<base64>#<name>
/sub/add?url=<https-url>&age=x25519|hybrid#<name>
/dat/add?type=domain|ip&url=<https-url>#<name>
```

旧 Profile/full 类型拒绝导入；旧库中保留的退休行不重新进入业务。
解析器严格检查 scheme、host、path、类型、重复/未知参数与 Base64。订阅和 Geodata URL
只接受 HTTPS。分享生成上述规范格式，不为退休类型生成链接。

Raw/Custom 使用共享完整配置交换服务。根部允许 name；Custom 导出附带需要的
`geodata.assets` 文件名和 HTTPS 下载地址，省略默认数据。导入在 `VpnConstants.datDir` 的
同级临时目录下载、校验并生成索引，文件名冲突拒绝；成功后资产只发布到平铺的
`VpnConstants.datDir`，并与配置提交共用失败回滚边界。存储移除导入专用 geodata 字段，
prepare 阶段不发布正式文件，保存提交成功后才完成发布；未完成发布在冷启动时按数据库
manifest 收敛。连接准备和启动不复制这些资产。Raw 保留用户配置原文的运行语义，不能把普通节点导入误认为
完整 Raw 导入。

分享或导出前提示敏感数据风险；不要把 Age 私钥、完整配置或解密正文写入日志。
备份、超额旧 Raw 与恢复边界见 [数据管理](data-management.md)。

## 实现入口

- 新导入：`lib/service/assets/import.dart`、`lib/pages/servers/import/`
- 订阅：`lib/service/subscription/`
- 标准解析：`lib/service/share/xray_share_reader.dart`
- 链接：`lib/service/share/app_link_parser.dart`、`app_link_generator.dart`
- Raw/Custom 交换：`lib/service/share/configuration_transfer.dart`
- 节点/订阅分享页：`lib/pages/home/share/`
