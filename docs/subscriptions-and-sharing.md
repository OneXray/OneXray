# 订阅、导入与分享

标准分享格式用于与其它客户端互通；OneXray App Link 与完整 JSON承担不同的
保真边界，不能互相替代。所有导入在显式用户操作后提交，系统链接先进入新导入流程。

## 订阅

添加和刷新复用相同流程：下载正文、可选 Age 内存解密、libXray 解析及校验、App 映射入库，
可用节点大于零才创建/更新。没有导入预览或二次确认；零可用、网络/解析/事务失败保留
旧数据与表单。libXray 只返回有效节点列表，App 只报告本轮实际导入的节点数，
不统计识别失败数，不比较单节点 hash，不虚报新增/更新数。

编辑只保存名称、URL、Age 和 HWID 设置，并使旧下载请求失效；不下载、不替换现有节点，也不要求
当前已有可用节点。新的 URL、密钥和 HWID 设置用于后续刷新。

替换时保留当前运行中的全部节点、当前固定节点、配置的最终出口及收藏原行；
这些保留行不计入本轮导入数。退出整个保护集合后才允许后续更新替换。
成功结果进入现有自动测速队列，测量延迟与出口地区；后台结果不热切换当前连接。

Age 公钥和私钥仅保存在订阅中，不随普通分享发出。分享只含算法，接收端生成
新的密钥对。详见 [Age 合同](age-encrypted-subscriptions.md)。

### 可选设备标识（HWID）

添加和编辑共用“发送设备标识（HWID）”开关，默认关闭，只有用户明确开启后才发送。
初次下载使用表单选择，后续手动、自动和快捷操作的更新使用已保存设置；服务器响应和导入链接
不能自动开启。Age 与 HWID 可以组合使用，互不替代。

标识为每个订阅独立生成的随机 UUID，不读取硬件、广告或系统设备标识。一旦生成即保持不变：
关闭再开启、改名、修改订阅地址（包括更换提供商）以及 App 重启/升级都保留原标识。
表单中的失败重试、清空后重新填写地址同样沿用草稿标识，保存时不重新生成。
跨源修改地址时表单仍关闭发送开关；用户重新开启后发送原标识，而不是生成新标识。
同源指协议、主机和端口相同。只有删除后重建订阅或清除数据才会获得新标识，可能占用
提供商的另一个设备名额；关闭开关或删除本地订阅不会删除提供商保存的设备记录。

仅在这次订阅请求中附加 `x-hwid`，保留现有 User-Agent，不发送额外的设备型号或系统版本字段。
不得把标识写入共享 HTTP 客户端默认头。HTTPS 同源重定向保留标识，跨源跳转时移除，
即使后续跳回原站也不恢复；Age 公钥维持原有重定向行为。需要在另一个源接收 HWID 的提供商，
应由用户确认并直接配置该源的订阅地址，不自动扩大授权范围。

下载完成后先检查 HWID 拒绝响应头，再交给 libXray 解密和解析。HTTP 200 中的空正文或占位节点
不能绕过拒绝结果。区分“需要受支持的标识”“设备上限或注册失败”和旧协议的笼统拒绝；
非成功 HTTP 状态也优先保留这些具体原因。拒绝时不新建/覆盖节点、不修改时间戳、不触发测速、
重连或 VPN 状态变更。只有正常解析得到可用节点后才按原有事务边界提交。

订阅分享不包含 HWID、发送开关或 Age 密钥。HWID 只是提供商在订阅下载时使用的客户端标识，
不等同于硬件认证，不参与 Xray 配置或 VPN 启动校验。

## 节点与标准格式

- 分享链接与普通 Xray JSON 节点导入只提取 outbounds，不导入其根级路由/DNS。
- 完整 outbound 映射直接保存，不经过字段表单重建；标准分享是协议白名单投影，可能有损。
- 节点名称使用 `tag`；仅在键不存在时兼容旧 `name`，已有 tag 优先，无名节点以协议名补齐。
- `sendThrough` 保留本地绑定语义，不参与命名。协议与字段的接受/拒绝以 libXray 为准，
  App 不再额外检查 VMess security、Shadowsocks method 等规范值，也不自行补写这些字段。
- KCP seed/header 和已废弃 `allowInsecure` 不在标准分享合同内。
- 文件直接调用系统选择器；扫码仅 iOS/Android，不能用桌面入口冒充相机支持。
- 普通节点在用户提交文本/JSON、选中文件或完成扫码后直接解析并写入，不展示导入预览或
  二次确认。解析和写入期间保留 loading；无有效节点不写入，失败保留输入供重试。
  成功后显示 toast 并进入自动测速队列，但不等待测速结束。
- 混合输入中含 Raw、Custom 或 Geodata 时，保留完整配置与数据文件的预览确认流程。

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

Raw/Custom 使用共享完整配置交换服务，根部允许 `name`。Custom 导出附带所需的
`geodata.assets` 文件名和 HTTPS 下载地址，省略默认数据；文件名冲突拒绝，存储时移除
导入专用 `geodata`。下载、确认、发布、回滚及冷启动恢复统一遵循
[Geodata 发布合同](data-management.md#geodata-发布)。Raw 保留用户原文的运行语义，
普通节点导入不能代替完整 Raw 导入。

分享或导出前提示敏感数据风险；不要把 Age 私钥、完整配置或解密正文写入日志。
超额旧 Raw 与升级边界见 [数据管理](data-management.md)。

## 系统分享

`OutgoingShare` 在 iOS、Android、macOS 和 Windows 通过 `share_plus` 发送已准备的文本；
Linux 使用明确的复制操作，不使用插件的邮件回退。Windows EXE 与 MSIX 共用分发策略。
文本、链接顺序和配置编码仍由现有生成器负责；分发不下载 Geodata、不持久化数据或启动 VPN。
原生标题与主题使用显示名称，空名称回退为 `OneXray`。链接仍作为文本发送，不改为
URI 元数据或临时文件分享。

共享页面操作负责按钮内 loading、防重复提交、Raw/Custom 敏感数据确认和调用失败提示。
分发前测量实际按钮位置；位置缺失或不可用时省略，让原生插件定位。准备期间页面已关闭
或隐藏时，不再弹出分享窗口；原生分享开始后离开页面，不等待或取消系统操作。
迟到的结果不导航，也不在无关页面显示提示。

原生 `success`、`dismissed` 和 `unavailable` 均静默完成，不代表送达，不触发成功/失败
toast、复制回退、重试或自动关闭页面。抛出的异常保留具体原因。Linux 仅在复制成功后
显示两秒 toast，并保留页面。不增加全局分享队列、生命周期轮询或额外的原生超时。

二维码图片保存与 JSON、日志、运行配置导出仍是明确的文件保存操作。
入站 App Link 与配置导入事务独立于对外系统分享。

## 实现入口

- 新导入：`lib/service/servers/import.dart`、`lib/pages/servers/import/`
- 订阅：`lib/service/servers/subscription/`
- 标准解析：`lib/service/shared/share/xray_share_reader.dart`
- 链接：`lib/service/shared/share/app_link_parser.dart`、`app_link_generator.dart`
- Raw/Custom 交换：`lib/service/shared/share/configuration_transfer.dart`
- 节点/订阅分享页：`lib/pages/shared/share/`
- 对外分发：`lib/service/shared/share/outgoing_share.dart`
- 共享界面操作：`lib/pages/shared/share/action.dart`
