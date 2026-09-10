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

标识为每个订阅独立生成的随机 UUID，不读取硬件、广告或系统设备标识。关闭再开启、改名、
同源地址修改以及 App 重启/升级都保留原标识。表单中的失败重试沿用同一草稿标识。
跨源修改地址时表单关闭开关，原标识不再用于新提供商；用户重新开启后使用新标识。
同源指协议、主机和端口相同。删除后重建订阅、清除数据或更换提供商会获得新标识，可能占用
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

Raw/Custom 使用共享完整配置交换服务。根部允许 name；Custom 导出附带需要的
`geodata.assets` 文件名和 HTTPS 下载地址，省略默认数据。导入在 `VpnConstants.datDir` 的
同级临时目录下载、校验并生成索引，文件名冲突拒绝；成功后资产只发布到平铺的
`VpnConstants.datDir`，并与配置提交共用失败回滚边界。存储移除导入专用 geodata 字段，
prepare 阶段不发布正式文件，完成用户确认后的保存通过统一导入操作发布、提交及回滚，
文件队列保护整个过程。页面不接触 Geodata 发布句柄，分享只传递依赖声明；未完成发布在
冷启动时按数据库 manifest 收敛。连接准备和启动不复制这些资产。Raw 保留用户配置原文的运行语义，不能把普通节点导入误认为
完整 Raw 导入。

分享或导出前提示敏感数据风险；不要把 Age 私钥、完整配置或解密正文写入日志。
超额旧 Raw 与升级边界见 [数据管理](data-management.md)。

## Outgoing system sharing

`OutgoingShare` dispatches prepared text through `share_plus` on iOS, Android,
macOS and Windows. Linux uses an explicit clipboard action instead of the
plugin's mail fallback. Windows EXE and MSIX use the same dispatch policy.
Text, link ordering and configuration encoding stay with the existing content
generators; dispatch does not download Geodata, persist data or start a VPN.
Native title and subject use the display name, falling back to `OneXray` when
the name is empty. Links remain text, not URI-metadata or temporary-file shares.

The shared page action owns button-local loading, re-entry prevention, the
existing Raw/custom sensitive-content warning and invocation-error feedback.
It measures the actual button immediately before dispatch. Missing or unusable
geometry is omitted so the native plugin can position its own UI. Closing or
hiding the originating page during preparation prevents a late share dialog;
leaving during native sharing does not wait for or cancel the OS operation.
Late results do not navigate or display feedback on an unrelated page.

Native `success`, `dismissed` and `unavailable` are all quiet completions, not
delivery receipts. None causes a success/failure toast, clipboard fallback,
retry or automatic page dismissal. A thrown error retains its concrete cause.
Explicit Linux copy shows the existing two-second toast only after the write
succeeds, and keeps the page open. No global share queue, lifecycle polling or
synthetic native timeout is added.

QR image saving and JSON/log/runtime-configuration exports remain explicit
file-save operations. Incoming App Links and configuration import transactions
are independent of outgoing system sharing.

## 实现入口

- 新导入：`lib/service/servers/import.dart`、`lib/pages/servers/import/`
- 订阅：`lib/service/servers/subscription/`
- 标准解析：`lib/service/shared/share/xray_share_reader.dart`
- 链接：`lib/service/shared/share/app_link_parser.dart`、`app_link_generator.dart`
- Raw/Custom 交换：`lib/service/shared/share/configuration_transfer.dart`
- 节点/订阅分享页：`lib/pages/shared/share/`
- Outgoing dispatch: `lib/service/shared/share/outgoing_share.dart`
- Shared UI action: `lib/pages/shared/share/action.dart`
