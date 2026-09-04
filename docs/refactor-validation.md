# 重构验证边界

本文只记录当前仍有效的验证合同。已完成阶段、旧实现、历史提交、产物摘要和一次性运行结果
由 Git 历史及工作空间 `references/onexray-refactor-validation/` 保存，不继续作为当前架构说明。
产品和实现事实分别以原型产品文档、[Xray 配置合同](xray-configuration.md)、
[数据管理](data-management.md) 和当前源码为准。

## 当前运行合同

- `ConnectionState` 只保存设置 JSON。App 不保存 `confirmedPlanId`、`ConnectionPlan`、
  `run/plans/<id>`、运行历史或跨进程提交 journal。
- 配置在内存中准备和校验。`run/start.json` 是唯一原生启动请求，并携带 App 重开后识别
  当前运行所需的最小 `metadataJson`；原生 VPN 状态始终是连接状态事实源。
- 准备失败且未触碰宿主时不影响当前连接。一旦已请求停止或启动原生 VPN，后续失败必须
  尽力停止本次运行并停在 `failed`，不得重新启动旧连接或恢复旧运行输入。
- Windows 和 Linux 在旧运行停止后、每次实际 Core 启动前清理 `run/core-inputs`，再生成
  唯一的 `core-inputs/input-*` 输入目录。Windows 的 VCore `snapshotToken` 仍用于宿主归属
  校验，不属于 App 的运行快照机制。
- libXray 只定期覆盖本次会话的 `runtime.json`；`GET /runtime` 只返回当前会话。不存在
  `runtime-sessions`、归档列表或 ACK。App 只保存累计值和一个会话水位，允许异常尾部及
  完全未被 App 观察到的中间会话丢失。
- `VpnConstants.datDir` 是唯一 App 侧 Geodata 读写目录，所有文件平铺。VPN 启动不复制
  Geodata；macOS System Extension 只保留既有 Swift 跨容器传输这一平台边界。

同一 App 版本不为开发过程中的旧数据库、旧备份字段、旧 Plan 文件或旧运行目录增加迁移、
别名及回退读取。数据库 v1/v2 → v3 的正式 SQLite 备份与事务升级属于独立的数据安全合同，
不等同于运行快照。

## 自动验证

根据改动范围串行执行生成、格式化、静态分析和测试，至少覆盖：

```shell
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart run tool/check_native_model_contract.dart
dart run tool/check_layer_dependencies.dart
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test
git diff --check
```

修改 Pigeon 时先从 `pigeon/message.dart` 重新生成 Dart、Kotlin 和 Swift 文件。Flutter 与 Dart
命令必须串行，不得由多个任务同时运行。生成和测试通过只能证明共享合同，不代表平台 VPN、
权限、签名或渠道包已经验证。

## 平台边界

- Android UI 使用模拟器验证，允许启动 VPN；真实导入文件、导出文件和扫码等系统交互可跳过。
- macOS 用于桌面 UI 和构建验证，不启动 VPN；需要 VPN 的分支留人工验证，不使用屏幕截图。
- Windows 和 Linux 不在当前系统强行编译或运行，保留源码、纯 Dart 合同和后续人工验证。
- Apple VPN 授权、System Extension 批准、按需连接、扩展消息及签名包必须在对应环境单独验收。

## 验证工程与提交

Demo、固定 fixture、运行日志和参考工程统一放在工作空间 `references/`，不得使用系统临时
目录。Demo 只验证当前风险点，不建设第二套产品实现。验证入口不得读取或改写开发者主库，
完成后应恢复 VPN 与测试数据状态。

每个实现阶段验证通过后，分别提交 OneXray 和 libXray；不得用尚未提交的跨仓库状态代替
阶段边界。VCore 只有在其自身合同确实变化时才修改，本次统计和 Plan 简化不要求修改 VCore。
