# Age 加密订阅

OneXray 可以下载明文订阅，也可以在内存中解密标准 age armor。该功能保护订阅响应内容，不改变订阅地址本身的可见性，也不替代 HTTPS。

## 密钥模型

每个加密订阅保存两个密钥字段：

- `ageSecretKey`：用于本地解密，属于敏感数据。
- `agePublicKey`：通过请求头交给订阅服务端，用于生成只供该客户端解密的响应。

两者必须同时存在或同时为空，App 不会尝试从私钥推导并补写公钥，也不在本地验证两者是否匹配。当前可以生成 X25519 和 ML-KEM-768 + X25519 混合密钥；使用“生成密钥”覆盖已有输入前必须由用户确认，手动编辑后保存不触发该确认。

密钥由 libXray Invoke API v2 的 `generateAgeKeyPair` 生成。App 只负责保存和传递，不自行实现 age 密码学。

## 下载与解密流程

1. App 使用订阅 URL 发起请求。
2. 加密订阅把已保存的公钥放入 `X-Age-Public-Key` 请求头；重定向链继续使用同一下载上下文。
3. libXray 的 `convertShareLinksToXrayJson` 接收响应文本和可选私钥。
4. 响应为官方 age armor 时，libXray 在内存中解密后继续解析；明文响应即使带有私钥也按普通订阅处理。
5. App 只接受解析结果中的 outbound，并在数据库事务中替换原有节点。

解密后的明文上限为 16 MiB。App 区分私钥无效、缺少私钥、解密失败和内容过大；损坏的 armor 与普通解密失败都映射为“解密失败”。libXray 内部可以保留更细的错误原因。任何失败都不得用空结果覆盖旧订阅。

## 添加、编辑与分享

添加或编辑订阅时，用户可以不启用加密，也可以输入或生成完整密钥对。只填写其中一把密钥属于无效输入。

Age 订阅的 OneXray App Link 只包含算法类型，不携带公钥或私钥。接收端导入时会生成一对新的密钥，因此服务端必须能够根据新公钥提供响应。链接格式由 [订阅、导入与分享](subscriptions-and-sharing.md) 统一定义。

## 备份与安全边界

- 当前备份格式同时保存公钥和私钥；兼容的旧备份可能没有这两个字段。
- 备份 ZIP 本身不加密。包含 Age 私钥的备份必须按敏感文件处理。
- 日志不得记录私钥、完整密钥对、解密后的订阅正文或含密钥的请求上下文。
- 网络请求仍应使用 HTTPS。Age 只加密响应负载，不能验证订阅 URL 是否可信。
- 解密后的内容不写入临时明文文件，由 libXray 直接在内存中解析。

## 主要实现入口

- 数据合同与错误状态：`lib/service/subscription/model.dart`
- 下载和事务替换：`lib/service/subscription/service.dart`
- 请求头与网络行为：`lib/core/network/`
- App Link：`lib/service/share/app_link_parser.dart`、`app_link_generator.dart`、`app_link_importer.dart`
- 备份：`lib/service/share/backup.dart`
- libXray 调用边界：`lib/core/pigeon/host_api.dart`
