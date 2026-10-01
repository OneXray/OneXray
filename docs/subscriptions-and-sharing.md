# 订阅、导入与分享

标准分享用于客户端互通，App Link 与完整 JSON 各有保真边界；备份走 [独立协议](backup.md)，普通导入不猜测备份格式。
导入由显式用户操作提交，系统链接先进入新导入流程。

## 订阅

添加和刷新共用 HTTPS 下载、可选 Age 内存解密、libXray 解析及事务入库。
只有可用节点大于零才创建/替换；网络、HWID、解密、解析、零可用或写库失败均保留旧节点、套餐与更新时间及输入草稿。
报告本轮实际导入数，不比较单节点 hash，不虚报新增/更新或识别失败数量。
普通节点/订阅添加和刷新直接提交，无导入预览或二次确认；含 Raw/Custom/Geodata 的混合导入保留预览确认。

名称、HTTPS URL、Age 成对输入由服务检查；重复 URL 在写入事务中拒绝，下载前快速检查不替代提交复核。
编辑只保存来源设置并使旧请求失效，不下载、不替换现有节点，也不要求已有可用节点。
更新保护当前运行的全部节点、固定节点、最终出口和收藏原行，保护行不计入本轮导入数；
退出保护集合后后续更新才可替换。成功导入进入自动测速队列，不等待测速，不热切换运行节点。

### 套餐信息

从同一次响应的 `Subscription-Userinfo` 读取 `upload/download/total` 非负整数字节和 `expire` Unix 秒。
字段名不区分大小写，未知、重复、无效、溢出及不可展示日期分别按未提供处理，不阻断节点导入。
`total=0` 表示无限，`expire=0` 表示无到期，缺失不等于无限；上下行齐全才计算已用，已用及正额度齐全才计算剩余。
超额剩余显示零，已用保留原值；IEC 单位，日期/获取时间使用本地时间。过期或用尽只提示，不限制连接和选节点。

套餐和节点在同一事务提交，获取时间来自响应；成功但无有效信息清除旧缓存，部分信息不拼接旧响应。
仅重命名保留缓存；URL/Age/HWID 请求设置变化后清空，迟到响应不得覆盖编辑或删除结果。
列表摘要和分组详情明确“提供方信息、非实时”，无数据隐藏区域，缺字段显示未提供。
套餐不是 App 流量，不增加请求、定时器或周期，不进入分享和备份；恢复后由正常更新重新获取。

### 可选设备标识（HWID）

发送开关默认关闭，由用户明确开启，响应和导入链接不能代为开启；Age 与 HWID 可组合。
标识是每订阅独立的随机 UUID，不读取硬件/广告/系统标识。生成后永久保留于该来源：
关闭再开、改名、改 URL/提供商、失败重试、重启和升级均不重建；删除重建或清理数据才产生新标识。
跨源编辑 URL 时关闭发送开关，用户重新开启仍发送原标识。删除本地来源不删除提供商设备记录。

只在本次请求附加 `x-hwid`，不写共享客户端默认头，不附加型号/系统版本。
HTTPS 同源重定向保留，跨源移除且后续跳回也不恢复；同源按协议/主机/端口判断。
Age 公钥沿用同一下载上下文；HTTPS 降级拒绝。跨源服务须由用户直接配置并授权该 URL。
先检查 HWID 拒绝头再解析正文，HTTP 200 空正文/占位节点不能绕过拒绝；非成功状态也保留具体拒绝原因。
HWID、发送开关不随普通分享发出，也不参与 Xray 配置或 VPN 校验。

## Age 加密订阅

`ageSecretKey` 用于本地解密，`agePublicKey` 经 `X-Age-Public-Key` 发给服务端；
两者同时存在或同时为空，App 不从私钥补公钥、不验证是否匹配。
libXray 生成 X25519 或 ML-KEM-768 + X25519 混合密钥；生成覆盖已有输入需确认，手动编辑保存不触发该确认。

libXray 在内存中识别、解密官方 age armor 后解析 outbounds；明文即使带私钥仍按普通订阅处理。
解密明文上限 16 MiB，区分私钥无效/缺少、解密失败、内容过大；损坏 armor 映射为解密失败。
失败不能以空结果覆盖旧订阅。Age 只保护响应负载，不隐藏订阅 URL、不替代 HTTPS 或证明来源可信。

Age App Link 只携带算法，不带公私钥；接收端生成新密钥对，服务端须能响应新公钥。
[备份](backup.md) 保留完整密钥对且文件未加密，写入前明确提示风险；恢复不重新生成。
日志不得记录私钥、完整密钥对、解密正文或含密钥上下文；明文不落临时文件。

## 节点与标准格式

- 支持 VMessAEAD/VLESS 标准链接、Hysteria2（`hysteria2://` / `hy2://`）、SS、SOCKS、Trojan 和 Base64/Age 订阅。
  旧 VMessQrCode（`vmess://Base64(JSON)`）及 Clash/Mihomo 不在范围。
- Hysteria2 支持认证、IPv6、SNI、Salamander、多端口和名称，导出统一 `hysteria2://`；
  禁止跳过 TLS 校验，无法等价转换的 `pinSHA256` 拒绝。字段及导出限制见 [libXray](../../libXray/README.md#parse_share)，
  运行网卡策略见 [配置合同](xray-configuration.md)。
- 链接与普通 Xray JSON 只提取 outbounds，不导入根级 routing/DNS；完整 outbound 映射直接保存，
  不经表单重建。标准分享是协议白名单投影，可能有损；字段接受/拒绝由 libXray 决定。
- 名称使用 `tag`；仅键缺失时兼容旧 `name`，无名以协议补齐。`sendThrough` 保留绑定语义，不参与命名。
  KCP seed/header、废弃 `allowInsecure` 不在标准分享内，App 不另校验协议算法或补写规范字段。
- 文件直接使用系统选择器，扫码仅 iOS/Android。失败保留输入，成功 toast 后提交测速，不等待测速完成。

## App Link

规范 scheme/host 为 `onexray://onexray.com`：

```text
/config/add?type=outbound|raw|custom|custom-advanced&data=<base64>#<name>
/sub/add?url=<https-url>&age=x25519|hybrid#<name>
/dat/add?type=domain|ip&url=<https-url>#<name>
```

解析严格检查 scheme、host、path、类型、重复/未知参数、Base64；订阅和 Geodata URL 只接受 HTTPS。
旧 Profile/full 拒绝，不为退休类型生成链接；类型显式指定，不根据字段猜常规/高级。
Raw 保留原文语义，高级不经过普通模型；两类 Custom 共用名称唯一和三份上限，详见 [配置合同](xray-configuration.md)。

两类 Custom 完整交换可通过 `geodata.assets` 携带非默认 Geodata 的文件名与 HTTPS 来源 URL，存储前移除该交换元数据。
Raw 保留配置原文，依赖通过独立 `/dat/add` 伴随链接提供。
依赖只扫描 routing、DNS、入站嗅探和 DNS outbound 等语义位置的标准 ext 引用，不扫描凭据或任意字符串。
冲突、下载、确认、发布、回滚统一遵循 [Geodata](data-management.md#geodata-发布)。
分享/导出完整配置前提示敏感信息风险；旧超额 Raw 完整保留。

## 系统分享

`OutgoingShare` 在 iOS/Android/macOS/Windows 使用 `share_plus` 发送已有文本；
Linux 显式复制，不使用邮件回退。标题/主题用显示名称，空名回退 OneXray；链接仍是文本，不改 URI 元数据或临时文件。
分发不下载、不保存资产、不启动 VPN；二维码、JSON、日志和运行配置导出仍为明确文件保存。

页面操作负责局部 loading、防重复提交、Raw/Custom 风险确认和异常反馈；分发前测量按钮位置，无有效位置则省略。
准备期间页面已关闭/隐藏不再弹系统窗口；原生分享开始后不取消，迟到结果不导航、不提示无关页面。
原生 success/dismissed/unavailable 静默完成，不证明送达、不触发 toast、复制回退或重试；
抛异常保留具体原因。Linux 复制成功显示两秒 toast 并留在页面，不增加全局分享队列或轮询。

真实提供方、安装包升级、系统分享与输入法等平台检查遵循 [验证边界](validation.md)；自动测试不代替这些验收。
