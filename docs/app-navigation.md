# 导航与界面

OneXray 使用四个一级入口：主页、订阅、Core 和设置。一级入口各自保留导航栈，切回当前入口时返回该入口根页面。

## 响应式外壳

- 紧凑窗口使用底部导航栏。
- 桌面宽度使用侧边导航栏，更宽时显示文字标签。
- 页面内容可以在宽窗口分栏，但功能入口和数据合同不能因布局变化而改变。
- 有可用 App 更新时，宽布局的侧边导航显示独立提醒并打开更新对话框；紧凑布局只在设置图标显示标记。

## 主页

主页负责连接状态、节点选择和路由模式。界面必须区分：

- 当前选中的配置：下一次启动使用的持久选择。
- 正在运行的配置：本次 Core 启动时的快照。

连接期间更改选择不会伪装成已切换运行配置。Rule、Global、Direct 是路由模式；它们与 Core 运行模式不是同一维度。具体物化规则见 [Xray 配置合同](xray-configuration.md)。

## 订阅

订阅入口展示订阅源和其节点，支持添加、编辑、更新、搜索与分享。订阅刷新是事务替换：新内容下载或解析失败时保留旧节点。导入边界见 [订阅、导入与分享](subscriptions-and-sharing.md)。

## Core

Core 页面分为网络、数据和日志：

- 网络：TUN Settings 和 Ping。Ping 支持用户自定义真实 URL，不提供并发数量设置。
- 数据：Profiles、GeoData，以及打开 Enhanced Routing 外部模板页面的入口。
- 日志：访问日志、错误日志和最终 Xray 配置；部分平台按能力隐藏文件日志或分享操作。

Core 运行模式的 Proxy 选择器只在 iOS Debug 构建中出现。正式构建和其它平台固定使用 TUN，代码与文档不得把 Proxy 描述为跨平台功能。

## 设置

设置页当前包含：

- 数据：自动更新、App 更新检查和清理数据。
- App：General、Backup、主题和语言；Desktop 只在桌面平台出现。
- 图标：iOS 显示 App Icon，macOS 显示 Dock Icon，其它平台不显示该入口。
- 版本与支持：App/Xray 版本、文档、问题反馈、源码、隐私等。

## 平台条件

平台差异统一通过能力或平台策略控制，不在页面中复制另一套业务状态。主要条件包括：

- Proxy：仅 iOS Debug。
- Desktop Settings：仅 macOS、Windows、Linux。
- App/Dock Icon：仅 iOS、macOS。
- 日志文件和系统扩展操作：按平台后端能力显示。

## 主要实现入口

- 一级导航与路由：`lib/pages/main/navigation.dart`、`lib/pages/main/url.dart`
- 响应式外壳：`lib/pages/main/adaptive_shell.dart`
- 主页：`lib/pages/home/`
- Core：`lib/pages/core/`
- 设置：`lib/pages/settings/`
