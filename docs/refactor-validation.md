# App 重构实施记录

2026-09-02。产品与阶段定义位于工作空间
`references/onexray-app-prototype/{PRODUCT-MODEL,DEVELOPMENT,APP-REFACTOR-PLAN}.md`。
最小验证工程与完整结果位于 `references/onexray-refactor-validation/`，不使用系统临时目录。

## P0：基线与风险验证

基线：OneXray `3edb2dd`、libXray `c871d2e`、VCore `fb1b53f`。
实际 Android AAR 与 libXray 锁定核心均为 Xray 26.7.28（`5ca6f4b7d4dc`）。
Flutter 3.47.2 / Dart 3.13.2，Android API 37 模拟器。

| 项目 | 本阶段证据与边界 |
| --- | --- |
| G0 | Windows bridge v3、必填完整 policy、生成模型与纯 Dart 契约测试通过；实际 DLL/安装包留手测 |
| G1 | Android 1/2/3 接入节点及每接入对应一个最终出口副本，TCP/UDP、每条接入实际计数通过；本机 SOCKS 固定样例，不代表所有远端协议 |
| G2 | 锁定核心用户态验证域名未命中后 IP 二次匹配、默认 loopback 均衡、空候选 block；生成器接入和 Android 完整路由验收在 P2 |
| G3 | Android VPN `:native` 与 App 临时核心隔离：并发 testXray 后 TCP 和计数不变；App Invoke 增加串行化。Apple 扩展边界保留、互斥代码编译通过；其他平台及 iOS Debug 同进程限制留运行阶段 |
| G4 | 直接使用核心草稿 Router 验证 ruleTag/动作及默认解释，不发布访问流量；公开 Invoke 待 P2 接入 |
| G5 | Android 空有效允许列表在建立隧道前失败，未报告 connected；排除列表为空正常运行。页面保存/连接提示待 P7 |
| G6 | Android 授权不启动 VPN 通过；Apple 查询不隐式创建、申请准备不启动、保存失败返回失败、重建连接态不伪报断开，macOS Debug 编译通过；Apple 实际系统授权留手测 |
| G7 | 两个 8.8.8.8 逻辑 DNS 的不同路由 tag、direct 非通用 fallback、代理节点域名引导在本地 UDP 捕获验证通过；不冒充外部 Google DNS 可达性 |
| G8 | Android UI PID 被终止后，原 VPN 宿主继续转发；tunIn 上行 6182→6212、下行 15012→15097，重开 UI 收到真实 connected。采样由宿主承担；30 秒保存、会话水位/重置/结算在 P3 交付，不把此实验当作最终累计功能 |
| G9 | 不可变 generation 目录 + SQLite 单一发布行：提交前故障保留旧代、提交后恢复新代、旧会话固定旧代、Raw ext 文件名不变；固定小 fixture，不代表实际 protobuf/平台权限验证，生产接入在数据维护阶段 |

G2 的具体约束：roundRobin 的 `fallbackTag: block` 需要
`observatory: {subjectSelector: []}` 满足锁定核心的依赖；空 selector 不发探测。
不能省略该依赖，也不能用无条件末尾规则替代 IP 二次匹配。

验证入口不读取开发者主数据库。Android 完成后通过系统 VPN 页正常断开。
macOS 仅构建独立验证入口，没有启动 VPN，没有截图/录屏。
Windows、Linux 原生构建和运行均 **NOT RUN**，纯共享 Dart 测试不等于平台验收。

执行：Pigeon / build_runner 生成、原生模型契约、分层检查；Windows 纯契约与 P1
存储基础合计 25 项通过、1 项 Windows 原生测试跳过。Apple 原生代码由独立入口
`flutter build macos --debug -t ../references/onexray-refactor-validation/android-main.dart`
验证；完整 App 待 P1 服务接线后构建。

本机 Flutter Debug/测试需对单次进程移除 `http_proxy` / `https_proxy` 并设置 localhost
的 `no_proxy`，否则 VM WebSocket 被代理返回错误；不修改系统代理配置。

P0 关闭的是可行性调查阶段，不代表 G0–G9 的完整产品交付。未完成项已对应到后续阶段，
最终全站/平台矩阵不得将它们预先标记为通过。libXray 本阶段无源码改动。
