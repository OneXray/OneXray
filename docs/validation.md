# 验证

以当前源码和[行为合同](README.md)为准。测试验证操作与结果，而不是实现写法；
旧提交的通过记录不代表当前代码通过。全局执行限制见[工程规则](../AGENTS.md#verification)。

## 场景测试

优先复用生产实现，以小型内存数据库、隔离文件、真实本地 HTTP 和可控的原生替身
组织以下场景。替身不代表内核、操作系统或云端已经验收。

| 场景 | 主要结果 |
| --- | --- |
| 启动与恢复 | 服务就绪后首页可用；缺库或默认资源丢失可离线恢复 |
| 导入与选择 | 导入入库、排队测速、列表 Stream 更新、节点选择与数量符合配置 |
| 订阅更新 | 更新替换有效结果，保留正在使用的节点、收藏和稳定的来源身份 |
| 配置与连接 | 普通/高级/Raw 保存、分享往返、编译与节点切换；先停止旧连接再启动 |
| 数据操作 | Geodata 发布、备份恢复、自动周期、清理后的重新使用 |
| 外部入口 | 页面、托盘、快捷入口、HTTP 和 Android 广播调用各自生产路径 |

- 每项先覆盖正常操作与最终状态，再保留真实风险：无效用户 JSON、空订阅保旧、
  权限拒绝、停止失败、过期异步结果、事务/文件回滚、鉴权和破坏性操作准入。
- 同一业务结果在负责层完整验证；页面验证点击、导航、loading 和反馈，不复制服务断言。
  协议往返和关键模型单测保留，分层 lint 独立于 App 场景测试。
- 不用源码字符串、私有函数调用次数或固定测试数量代替行为验证。
  删除旧功能测试；人工破坏本地数据等不可达组合不扩展为产品场景矩阵。
- 每个业务 case 应能对应页面、后台任务、系统事件或公开入口，以及该入口实际产生的数据。
  不为覆盖内部防护，手工添加迁移冲突列/索引、改写私有文件或传入生产方不可能生成的参数。
  用户 JSON、分享链接、备份和网络响应属于真实输入；权限、I/O 与事务失败可在实际依赖边界模拟。
  删除不可达 case 不等于删除生产防护，已发布数据库升级与历史数据保留仍需验证。
- UI 保留主题关键尺寸、颜色、安全区、长文案及 RTL 验证，使用代表性尺寸/语言组合，
  不降低高保真标准，也不全面交叉所有状态。
- fixture 仅共享确实重复的数据库、文件和节点样本；不引入通用场景 DSL 或大型测试基类。
  先补齐等价行为覆盖再删除重复测试，不按正负比例或数量衡量完成。

## 自动验证

按改动选择生成、格式化、分析和测试，命令从 App 根目录执行：

```shell
flutter gen-l10n
dart run build_runner build
dart run tool/check_layer_dependencies.dart
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test
git diff --check
```

Pigeon、FFI、Drift 或本地化变更先生成对应输出；只改测试时不重复生成无关代码。
只改文档时检查路径、锚点和 diff，不运行 App 测试。

- 构建脚本：在 `build_scripts/` 执行 `uv run --locked python -m unittest discover -s tests`。
  外部打包工具替身证明编排，不证明生成包能安装；渠道发布还需实际产物检查。
- macOS SE 文件交接：`bash tool/test_dat_file_transfer.sh` 编译生产 Swift，
  验证完整清单、空集合、消息往返与发布回滚，不启动 App/VPN。
- macOS SE 激活：`bash tool/test_system_extension_activation.sh` 编译生产 Swift，
  验证并发请求合并及完成后的重新激活；使用可控系统回复，不申请真实扩展授权或启动 VPN。
- Android 原生：在 `android/` 执行 `./gradlew :app:testDebugUnitTest`，
  Robolectric 调用正式 Receiver、保存配置和 Widget 资源；不替代真实 VPN 与桌面验收。
- Android Manifest/网络 XML 变更补跑 `./gradlew :app:lintVitalRelease`；
  发布相关修复还需本地 Release AAB 构建，不调用会上传商店的部署脚本。
- 原生桥合同变更验证实际序列化/消费方与对应平台构建；
  `dart run tool/check_native_model_contract.dart` 只检查字段名，不代替行为验证。

## 平台验收

- Android UI 用模拟器验证；系统导入、导出和扫码可记录跳过。Widget 检查 4×2 最小尺寸、
  缩放、旋转、主题、语言与启动/停止。通知和真实代理请求需运行 VPN 后验证。
- Android 自动化需普通第三方 UID 的后台启停、冷进程、Token 撤销和清理/恢复阻断，
  至少联调一款真实工具；shell 广播不等于工具联调。
- macOS 桌面 UI 使用 Flutter Debug 验证；VPN、Apple 授权、按需连接、SE 跨容器交接
  和签名包需单独人工验收，不以纯 Dart/Swift 测试替代。
- Windows/Linux 在对应环境验收；Windows 区分 EXE/ZIP 与 MSIX 的启动、退出、权限和数据根。
- 云备份需真实提供商的授权、文件覆盖、重新打开及跨设备恢复；本地写入成功不等于云端同步完成。
- 完成后区分自动测试、模拟器、真机、签名渠道及未测项；测试目标与数据始终隔离。
