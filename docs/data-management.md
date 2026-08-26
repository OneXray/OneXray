# 数据管理

本文说明 GeoData、自动更新、备份和恢复之间的边界。Xray Profile 不再拥有 `geodata` 根字段；文件由 App 的独立数据服务管理。

## 系统 GeoData

App 随包提供 `geosite.dat`、`geoip.dat` 和时间戳。`SystemGeoDatService.checkAssets()` 在以下时机尝试把资源准备到 Core 可访问目录：

- 用户手动启动 VPN 前；
- App 启动后自动连接前。

目标时间戳不存在时复制整套资源；包内时间戳更新时覆盖整套资源。目录不可用时会跳过，手动连接路径也会记录检查错误后继续，因此当前实现是启动前的尽力准备，不是阻止 Core 启动的强校验。

在 macOS System Extension 的 App 主动启动路径中，Provider 先等待 App 信号。App 比较两侧全部文件的文件名和修改时间；任一不一致时，把本地整套文件发送到 Provider 暂存目录并请求整体切换，然后发送启动信号。按需启动会跳过同步，直接使用 Provider 已有文件。当前 App 没有把每个 Provider 返回的错误响应提升为启动失败，不能把这条路径描述成严格的文件存在保证。

## 自定义 GeoData

自定义条目保存名称、domain/ip 类型、下载 URL、更新时间和统计数量。添加或更新时：

1. 下载 `<name>.dat` 到缓存目录。
2. 调用 libXray `countGeoData` 校验并生成 `<name>.json` 索引。
3. 更新数据库记录，再把 `.dat`、`.json` 逐文件复制到运行目录。

删除自定义条目时同时删除数据库记录和对应的 `.dat`、`.json`。系统 GeoData 与自定义条目在界面中分组，不共享删除语义。

数据库更新、文件复制和缓存清理不是一个事务；复制异常可能留下部分文件或缓存。文档不得把当前流程描述成原子替换。

## 自动更新

后台服务在启动时立即检查，此后每小时检查一次。订阅和 GeoData 可以分别启用，更新周期支持 24、72 或 168 小时。

GeoData 可以设置为 VPN 连接后更新。此时未连接不会下载；连接成功并稳定 3 秒后重新检查。并发下载或已有更新任务进行中时跳过重复任务。

系统 GeoData 先整组下载和生成索引，成功后写入时间戳并逐文件复制；自定义 GeoData 逐条更新。这些运行目录写入同样不是原子替换。

## 备份格式

当前备份版本为 4，并兼容读取版本 3。ZIP 包包含：

```text
manifest.json
core_configs.json
subscriptions.json
geo_data.json
dat/
```

版本 4 的订阅记录包含 Age 公钥和私钥；版本 3 可以没有。备份中的 `dat/` 只保存数据库记录引用的自定义 GeoData 文件及索引；恢复暂存时再加入当前 App 随包的系统资源。

备份 ZIP 不加密，必须按敏感文件处理。它可能包含订阅 URL、完整配置和 Age 私钥。

## 恢复边界

恢复会替换现有数据库和 GeoData，按以下顺序执行：

1. 安全解压，只接受预期根文件和 `dat/` 内容。
2. 校验 `manifest.json` 版本、JSON 顶层结构、必要元数据，以及自定义 GeoData 文件是否存在；这里不验证 Xray-core 语义、订阅 URL 或 DAT 内容。
3. 停止 VPN 并清理运行文件；保留用户偏好和桌面登录项。
4. 用备份中的自定义文件和当前随包系统资源建立暂存目录，再切换 GeoData 目录。
5. 在数据库事务中替换配置、订阅和 GeoData 元数据。
6. 成功后提交文件切换、重置运行选择，并尽力刷新已恢复订阅。

切换后的 GeoData 在提交前发生异常会尝试回滚；数据库替换使用事务。文件切换与数据库事务仍不是同一个原子事务。

## 主要实现入口

- 系统资源：`lib/service/geo_data/system_dat_service.dart`
- 自定义 GeoData：`lib/service/geo_data/service.dart`
- 后台更新：`lib/service/background_task/service.dart`、`lib/service/data_update/service.dart`
- 备份和恢复：`lib/service/share/backup.dart`、`backup_archive.dart`、`backup_dat_stager.dart`
- 数据清理：`lib/service/data_cleanup/`
