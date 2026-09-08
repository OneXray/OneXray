# Windows 构建

Windows 构建以 [`.github/workflows/build.yml`](../.github/workflows/build.yml) 为事实来源。本文只记录稳定的工程约束，不固定 runner、工具链版本、Actions、小版本或依赖清单。

## 运行与打包模式

编译期 `ONEXRAY_WINDOWS_MODE` 默认 `exe`，可显式设置为 `msix`。它不是用户偏好，不持久化到数据库；同一个构建值同时控制 App 后端和打包格式，不根据包身份自动降级。

| 模式 | Xray 入站与进程 | 登录项 | 分发产物 |
| --- | --- | --- | --- |
| `exe`（默认） | Native TUN / Wintun；App 通过 UAC 提权启动独立 Core | 当前用户 Startup 快捷方式 | EXE 安装程序与 ZIP |
| `msix` | VCore 系统 VPN；Session Host 启动普通权限 Core，连接其私有 SOCKS 入站 | 包内 `VCoreStartup` | Microsoft Store MSIX |

两种模式都要求选择 Xray 出口网卡。`Windows 系统 VPN` 页面及其策略只用于 MSIX；EXE 不应用这些策略。数据根目录和权限边界见 [App 启动](app-startup.md)，生成配置和进程状态见 [Xray 配置](xray-configuration.md)。

### 本地构建

Windows 原生主机先安装 Flutter / Go / Rust / MSVC 和所选渠道的打包工具。默认构建需要 Fastforge 和 Inno Setup；可通过 `INNO_SETUP_PATH` 指定 Inno Setup 的安装目录，解析规则见 [Fastforge 文档](https://fastforge.dev/makers/exe#custom-inno-setup-installation-path)。MSIX 需要 Windows SDK 的 `makeappx`、`signtool`，不使用 Fastforge。

```powershell
$env:BUILD_NUMBER = "1"
dart pub global activate fastforge
$env:INNO_SETUP_PATH = "C:\Program Files (x86)\Inno Setup 6"

# 默认 EXE 模式：Fastforge 共用一次 Flutter 构建，生成 EXE 和 ZIP
uv run --project build_scripts python build_scripts/main.py OneXray windows

# MSIX 模式：重新编译 Flutter，不复用 EXE 模式二进制
uv run --project build_scripts python build_scripts/main.py OneXray windows --windows-mode msix
```

只做 Flutter Debug 构建时，同样用 `--dart-define=ONEXRAY_WINDOWS_MODE=msix` 选择 MSIX 模式；省略时为 EXE。直接运行 Flutter 前需已准备 `windows/app/` 下的所有原生依赖。MSIX 模式必须以具有包身份的已安装 App 运行，不支持把裸 EXE 当成已安装包。

### EXE 与 ZIP

- EXE 和 ZIP 通过同一次 `fastforge package --platform windows --targets exe,zip` 构建与打包，并显式传入 EXE 模式的 dart-define、构建号与产物名称；不在 Python 编排层重复调用 Flutter build。Flutter 使用原生主机架构，不传入其 Windows 命令不支持的 `--target-platform`。
- EXE 沿用 v26.8.4 的 Fastforge `make_config.yaml` 与 Inno Setup 模板方式，保留安装标识、桌面 / 开始菜单快捷方式及 `onexray:` 协议注册。明确指定 `OneXray.exe` 为主程序，避免把同目录的 Core / VCore 可执行文件当成 App。按当前用户安装，App 本身不要求管理员权限；Core 的启动 / 停止需要时再通过 UAC 提权。
- 构建时按目标架构设置安装器配置，临时使用不含 `+build` 的发布版本号供 Fastforge 打包，并通过 Flutter 参数保留构建号；成功或失败后均恢复安装器配置与完整 `pubspec.yaml`。只归集当前版本、当前架构的 EXE / ZIP，不扫描并混入旧包。
- 卸载只删除指向当前安装位置的 Startup 快捷方式和协议注册，不删除用户数据库，也不关闭其他安装的 Core。安装 / 升级 / 卸载前应先停止 VPN 并退出 App。
- ZIP 由 Fastforge 压缩同一份 Release 目录；必须完整解压后运行，不能只复制 `OneXray.exe`。它不注册协议、不自动创建快捷方式，也不把用户数据放在解压目录；数据根目录与 EXE 安装版相同。
- 提权、查询进程和等待退出在 worker isolate 执行。拒绝 UAC 或启动失败时停在失败状态，不恢复旧连接。

## CI 构建

Windows 矩阵为 `x64 / arm64 × exe / msix`，四个任务各自独立编译 Flutter。依赖 revision、runner 标签、工具链步骤和 artifact 名称查看 [Build workflow](../.github/workflows/build.yml)。Xray-core 版本由 libXray 的 Go module 锁定。

GitHub 发布从 EXE 模式产物读取两种架构的 EXE 和 ZIP；`windows` 单平台发布只上传 Windows 文件。构建凭证包含 `windowsMode`，文件名及 artifact 名以模式区分，禁止用 EXE 凭证满足 MSIX 发布要求。发布检查细节见 [构建脚本](../build_scripts/README.md#release-provenance--发布溯源)。

[`publish-microsoft-store.yml`](../.github/workflows/publish-microsoft-store.yml) 仅手动触发：输入一次成功 Build 的 run ID 后，将两个架构的 MSIX 合并为 MSIX Bundle；来源是 release tag 构建时继续提交到 Microsoft Partner Center，否则只生成 Bundle。

选择或更换 runner 时，必须通过 GitHub Actions 验证镜像实际提供并默认选择了所需的 Visual Studio、CMake 和 Windows SDK 工具链，不能只根据 runner 标签推断。

## 工程约束

- Windows CMake 工程使用 C++17。
- MSVC 编译启用 `/W4 /WX`，警告会导致构建失败。
- Flutter、Go、libXray 生成的 `OneXrayCore.exe`、Wintun 和三个 VCore 产物的架构必须与矩阵项一致。
- CMake 在两种模式下都必须安装 `libXray.dll`、`OneXrayCore.exe`、`wintun.dll` 和三个 VCore 产物；与 App EXE 平铺在同一目录，不使用旧 `bin/` 布局。缺失依赖直接构建失败；MSIX 打包前、Fastforge 产物归集前再次检查运行文件、PE 架构与 Flutter 数据。
- Wintun 从官方发行包获取，固定下载摘要，只提取目标架构的未修改 DLL；下载缓存放在工作区 `references/windows-build/`。App 不增加 Wintun 许可文件或许可 UI，来源与上游分发说明记录在 [文档站](https://onexray.com/zh/docs/credits/)。
- MSIX 最低系统版本为 Windows 10 20H2（build 19042），只声明一个主 Application，但保留完全信任前台、AppContainer VPN Provider 和 full-trust Session Host 三个进程。
- Provider 通过无参数 `FullTrustProcessLauncher` 启动 Session Host。VCore Provider 将系统 IP 包交给 Session Host；Session Host 用 kill-on-close Job Object 启动并监督普通权限 `OneXrayCore.exe`，VCore 再通过动态 loopback SOCKS5 转发。`sessionBackend` 只管理进程存活，不检查端口或 readiness；该 SOCKS5 仅监听 `127.0.0.1`，不是用户代理入口。
- `startVpn` 每次完整发送用户保存的 Windows 策略，不由 VCore 补默认值；CIDR 与 IPv6 / DNS 冲突由 VCore 校验。Session Snapshot token 用于宿主归属校验，其格式与 bridge revision 独立。打包的 `vcore.dll` 必须匹配 [原生桥合同](../lib/core/ffi/windows/native_api.dart)；源码契约测试不代表打包 DLL 或 Windows 实机验证通过。
- MSIX 声明 `networkingVpnProvider`、网络和 `runFullTrust` 能力，注册 `VCore.VpnBackgroundTask` 及默认关闭的 `VCoreStartup`。Provider extension 显式保持 `windowsApp` / `appContainer`，Session Host extension 保持 `packagedClassicApp` / `mediumIL`。Core 不使用 `allowElevation`。
- `msix:create` 生成基础包后，`build_scripts/app/windows_msix.py` 把两个 VCore extension 放入现有主 Application，并补充 package-level in-process server，再由 `makeappx` 原路径重打包。已有 VCore extension 或 Application 数量不为一时直接失败。
- VCore 构建输出必须附带 artifact manifest；复制前校验格式与 package integration revision、架构、build identity、文件集合、全部 SHA-256 及 PE 架构。接受的版本和文件集合以 [构建脚本](../build_scripts/app/windows.py) 为准，任一不匹配都在打包前失败。
- 完成构建和打包后、上传产物前执行 `OneXrayCore.exe -h`，用于发现无法加载或架构错误。
- workflow 中的注释、runner 标签和实际构建步骤必须同步；外部调研结论不替代 GitHub Actions 实机结果。

## 变更验证

修改 Windows runner 或工具链后，至少在 GitHub Actions 验证：

1. x64 与 arm64 job 都能完成依赖安装和 CMake 配置。
2. Flutter Windows runner、插件和 OneXrayCore 编译通过。
3. `/W4 /WX` 下没有新增告警。
4. 生成的 Core 可执行文件能够运行帮助命令。
5. 两个架构分别生成 EXE、ZIP、MSIX，EXE/ZIP 由同一份 EXE 模式 Release 目录打包，MSIX 由独立的 MSIX 模式构建生成；上传名称和凭证不会互相覆盖。
6. Manifest 恰好包含一个 Application、两个 VCore extension、VCore activation class、所需能力和 `VCoreStartup`；没有 helper Id 或 `AppListEntry`，包内三个 VCore 文件均为目标架构且 hash 与 artifact manifest 一致。
7. MSIX 不包含 `allowElevation`，Core 启动不触发 UAC。
8. Microsoft Store workflow 能从两个架构的 MSIX artifact 生成 MSIX Bundle；实际发布必须另行验证 Partner Center 凭据和受限能力审批。
9. EXE 安装版和 ZIP 完整解压版均可启动；原生 TUN、UAC 取消、Core 异常退出、停止 / 重连、登录项和旧版数据库升级在 Windows 实机验证。单纯打包成功不代表这些场景通过。

当前 macOS 开发主机只做配置、适配器、打包逻辑、工作流和发布凭证的静态 / 单元验证，不编译或运行 Windows，不启动 macOS VPN。上述 Windows 验收由后续 CI 与手动测试完成。

## 本地签名包

MSIX 本地测试使用 `--windows-mode msix`，继续走同一 `msix:create` 和 manifest 增强流程。使用带 Code Signing EKU（`1.3.6.1.5.5.7.3.3`）和私钥的开发证书，将 PFX 导入当前用户证书库：

```powershell
$pfxPath = "C:\path\development.pfx"
$password = Read-Host "PFX password" -AsSecureString
$certificate = Import-PfxCertificate `
    -FilePath $pfxPath `
    -Password $password `
    -CertStoreLocation "Cert:\CurrentUser\My"
```

自签名证书还需仅在测试机上信任其公开 CER；第二条命令需要管理员 PowerShell：

```powershell
$cerPath = "C:\path\development.cer"
Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\CurrentUser\Root"
Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople"
```

在执行构建的 PowerShell 中选择该证书：

```powershell
$env:ONEXRAY_DEV_SIGN = "1"
$env:ONEXRAY_DEV_CERT_THUMBPRINT = $certificate.Thumbprint
$env:ONEXRAY_DEV_PUBLISHER = $certificate.Subject
```

构建脚本将开发包身份改为 `OneXray.Dev`，从 `Cert:\CurrentUser\My` 选择已安装私钥，并调用 `signtool verify`。CI 仍可改用 `ONEXRAY_DEV_CERT_PATH` 与 `ONEXRAY_DEV_CERT_PASSWORD`。打包脚本不会生成、导入或删除证书。

不兼容的 Windows 开发包使用清洁安装验证：先停止测试 VPN，再卸载旧开发包并清理其测试数据；不为同一开发周期的旧 bridge revision 增加解码或迁移兼容。该限制不替代正式发布前的 [旧库升级与数据保留验收](data-management.md#原库升级)。

本地不必伪造 GitHub 托管镜像。涉及镜像可用性、预装软件或标签变更时，以 GitHub 官方 runner image 清单和实际 workflow run 为准。

## 主要实现入口

- 构建矩阵：`.github/workflows/build.yml`
- Microsoft Store Bundle 与发布：`.github/workflows/publish-microsoft-store.yml`
- Windows CMake：`windows/CMakeLists.txt`、`windows/app.cmake`
- App 构建编排：`build_scripts/`
- Windows 打包：`build_scripts/app/windows.py`、`build_scripts/app/windows_msix.py`、`windows/packaging/exe/`、`pubspec.yaml`
- VCore host bridge：`lib/core/ffi/windows/native_api.dart`
- Windows 模式与 VPN 生命周期：`lib/core/ffi/windows/mode.dart`、`ffi_api.dart`、`exe_ffi_api.dart`、`msix_ffi_api.dart`
