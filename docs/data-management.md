# 数据管理

## 原库升级

首次业务访问前先停止旧运行、暂停写入并保留升级前快照。SQLite 结构修改与版本提升
在同一事务完成；已有 ID、订阅关系、Base64 内容及 Age 密钥保持不变，不做全量编码转换。
`setting/full` 退休行不进入新业务；所有旧 Raw 保留，包括超过新增上限的情况。
运行偏好重置，已有订阅缓存及有效 Geodata 原位复用。

升级前快照用于恢复，不意味着旧 App 能直接打开新 schema；新版 ZIP 也不承诺旧版可读。
不要对主用户数据执行验证迁移，使用隔离样本。真实旧库样本与安装包升级须单独验收。

## Geodata 发布

默认 `geoip.dat` 与 `geosite.dat` 是一组，只能一起更新且不能删除。自定义数据按文件名
保存，支持 HTTPS 添加、更新和删除，不提供本地导入。添加成功即有效，不加“可用”标签。

下载先进入暂存目录，libXray 校验 DAT 并生成分类索引，文件封存为不可变 generation 后，
数据库事务发布唯一引用。默认双文件、索引和元数据一起切换；失败不覆盖当前版本。
没有 generation 的旧自定义记录仍可读取原文件，不做无条件重写。

运行计划复制同一发布快照的资源，所以更新和删除不会改变本次连接使用的文件。
删除移除发布引用；旧 generation 暂保留，尚未实现自动回收，不承诺即时释放磁盘。
macOS System Extension 只同步固定计划目录，通过暂存/确认完成后才启动；真实按需启动
及扩展消息链路的设备验收与普通文件事务测试分开记录。

## 自动更新

数据更新位于高级的 Xray 运行与诊断，订阅与 Geodata 分别保存自动开关和 24/72/168 小时
周期。启动、前台恢复、每小时与真实连接边沿触发到期检查；重复 connected 不反复调度。
到期检查串行运行，独立自定义数据不会因默认组更新失败而被长期跳过。更新不重新选择
本次运行节点。测速只暴露超时与 URL，沿用自动队列，不暴露并发数量/自动测速开关。

## 备份与恢复

ZIP 当前格式为版本 5，兼容读取旧 v3/v4，包含 manifest、CoreConfig、订阅、Custom 路由
及引用的 Geodata/索引。保留全部 Raw、订阅缓存、收藏和 Age 密钥；旧退休类型不重新导入业务。
ZIP 未加密，可能包含节点凭据、订阅 URL 与 Age 私钥，必须提示并按敏感文件处理。

恢复先安全解压和校验，再停止运行。Geodata 封存与所有数据库资产在同一发布事务内
切换；失败保留原资产，成功重置运行选择且不自动连接，保留桌面登录项。
旧备份没有缓存的订阅在维护门释放后刷新，新备份不以重新下载替代缓存恢复。
清理全部数据前先取消平台登录项，失败则不继续破坏性清理。

## 实现入口

- 升级与维护门：`lib/service/launch/storage_preparation.dart`、`lib/service/maintenance/`
- 数据发布：`lib/service/geo_data/service.dart`
- 更新：`lib/service/background_task/service.dart`、`lib/service/data_update/service.dart`
- ZIP：`lib/service/share/backup.dart`、`backup_archive.dart`、`backup_database.dart`
- 清理：`lib/service/data_cleanup/`
