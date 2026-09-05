# 验证边界

验证以当前源码和 [文档索引](README.md) 中的对应行为合同为准，不重复维护实现清单。
历史运行结果只证明当时验证过的版本，不能替代当前改动的检查。

## 自动验证

按改动范围选择所需的生成、格式化、静态分析和测试命令，不要求每次全部运行：

```shell
flutter gen-l10n
dart run build_runner build
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

仅修改文档时检查本地路径、链接和 `git diff --check`，不运行 Flutter 测试或原生构建。

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
阶段边界。VCore 只有在其自身合同确实变化时才修改。
