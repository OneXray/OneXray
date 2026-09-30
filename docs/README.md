# OneXray App 文档

只记录当前实现与非显然的行为边界；同一规则只有一个权威出处。
历史方案、阶段授权和运行记录使用 Git 历史，不作为当前验收证据。

## 当前合同

- [App 行为](app.md)：启动、初始化、权限、导航、主题和桌面窗口。
- [Xray 配置](xray-configuration.md)：配置模式、编译、连接生命周期与流量读取。
- [数据管理](data-management.md)：数据库、Geodata、队列、更新和清理。
- [服务器与分享](subscriptions-and-sharing.md)：订阅、套餐、Age、导入和分享协议。
- [备份](backup.md)：单文件协议、平台存储、调度与离线恢复。
- [外部接口](external-interfaces.md)：本地 HTTP API 和 Android 自动化的独立授权边界。
- [验证](validation.md)：场景测试、检查命令与平台验收。

本地开发从 [FIRST_RUN](../readme/FIRST_RUN.md) 开始；打包、签名和发布以
[构建手册](../build_scripts/README.md) 为准。维护规则见 [AGENTS](AGENTS.md)。

## 工程技能配置

[Issue tracker](agents/issue-tracker.md)、[Triage 标签](agents/triage-labels.md) 和
[领域文档](agents/domain.md) 保持独立，供工程技能按需读取。
