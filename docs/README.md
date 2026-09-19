# OneXray App 文档

本目录记录 OneXray App 当前有效的产品行为、数据合同和工程边界。历史实施批次、已经结束的重构计划以及一次性外部调研不作为当前事实来源。

## 文档索引

- [Xray 配置合同](xray-configuration.md)：节点、Smart/Custom、Raw JSON、配置编译和连接生命周期。
- [导航与界面](app-navigation.md)：主入口、关键交互、平台差异和响应式结构。
- [订阅、导入与分享](subscriptions-and-sharing.md)：订阅更新、导入来源、OneXray App Link 和分享边界。
- [Age 加密订阅](age-encrypted-subscriptions.md)：密钥、下载、解密与安全边界。
- [App 启动行为](app-startup.md)：正常启动、首次初始化、权限检查和桌面启动行为。
- [数据管理](data-management.md)：GeoData、自动更新和数据清理。
- [连接配置备份](backup.md)：单文件协议、平台存储、自动备份、离线恢复与安全边界。
- [Windows 构建](windows-build.md)：EXE / MSIX 运行模式、EXE / ZIP / MSIX 打包、本地签名和 CI。
- [验证边界](refactor-validation.md)：按改动选择检查项、平台验证限制和验证数据隔离。

维护要求见 [文档规则](AGENTS.md)，仓库工程入口见 [工程约定](../AGENTS.md)。
[旧原型](../../references/onexray-app-prototype/) 仅供历史视觉参考，不覆盖当前合同，
不据此恢复累计流量、旧 ZIP 备份或旧 Setup 等已删除功能。

## 工程技能配置

- [Issue tracker](agents/issue-tracker.md)：本仓库的 GitHub 操作、审查边界与 Wayfinder 约定。
- [Triage 标签](agents/triage-labels.md)：五个标准角色对应的标签名称。
- [领域文档](agents/domain.md)：单一上下文下 `CONTEXT.md` 和 ADR 的按需读取规则。

这些配置供 Matt Pocock 工程技能读取，不替代上述业务合同；领域术语和决策在需要时记录，不预先创建空文档。

## 进行中的开发计划

- [单文件云备份开发计划](../plans/cloud-backup.md)：已确认范围、插件使用边界、P0–P8 开发步骤及逐步验收要求；
  本机实施结果与真实提供商待验收项单独记录；当前行为以备份合同为准，不用本机检查替代云端验收。
