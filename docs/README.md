# OneXray App 文档

本目录记录 OneXray App 当前有效的产品行为、数据合同和工程边界。历史实施批次、已经结束的重构计划以及一次性外部调研不作为当前事实来源。

## 文档索引

- [Xray 配置合同](xray-configuration.md)：Outbound、Profile、多节点出站、Raw JSON、运行时物化和兼容边界。
- [导航与界面](app-navigation.md)：主入口、关键交互、平台差异和响应式结构。
- [订阅、导入与分享](subscriptions-and-sharing.md)：订阅更新、导入来源、OneXray App Link 和分享边界。
- [Age 加密订阅](age-encrypted-subscriptions.md)：密钥、下载、解密、备份与安全边界。
- [App 启动行为](app-startup.md)：启动时连接、桌面隐藏启动和登录时启动。
- [数据管理](data-management.md)：GeoData、自动更新、备份和恢复。
- [Windows 构建](windows-build.md)：VCore/MSIX 打包、本地签名和 GitHub Actions 构建矩阵。

## 维护原则

- 文档描述当前行为，不保留已经完成或放弃的阶段计划；历史由 Git 保存。
- 代码和工作流是易变实现细节的事实来源，文档只保留跨模块合同、兼容原因和容易误解的行为。
- 同一主题只更新一份文档。实现变化时同步更新对应文档和验证项。
- 所有正文使用中文；JSON key、类名、协议名和平台 API 保留原始拼写。
