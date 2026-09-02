# Windows 构建

Windows 构建以 [`.github/workflows/build.yml`](../.github/workflows/build.yml) 为事实来源。本文只记录稳定的工程约束，不固定 runner、工具链版本、Actions、小版本或依赖清单。

## CI 构建

Windows 的构建矩阵、依赖 revision、runner 标签、工具链安装步骤和 artifact 名称直接查看 [Build workflow](../.github/workflows/build.yml)。Xray-core 版本由 libXray 的 Go module 锁定，最终只输出 Microsoft Store MSIX 分发包。

[`publish-microsoft-store.yml`](../.github/workflows/publish-microsoft-store.yml) 仅手动触发：输入一次成功 Build 的 run ID 后，将两个架构的 MSIX 合并为 MSIX Bundle；来源是 release tag 构建时继续提交到 Microsoft Partner Center，否则只生成 Bundle。

选择或更换 runner 时，必须通过 GitHub Actions 验证镜像实际提供并默认选择了所需的 Visual Studio、CMake 和 Windows SDK 工具链，不能只根据 runner 标签推断。

## 工程约束

- Windows CMake 工程使用 C++17。
- MSVC 编译启用 `/W4 /WX`，警告会导致构建失败。
- Flutter、Go、libXray 生成的 `OneXrayCore.exe` 和三个 VCore 产物的架构必须与矩阵项一致。
- MSIX 最低系统版本为 Windows 10 20H2（build 19042），只声明一个主 Application，但保留完全信任前台、AppContainer VPN Provider 和 full-trust Session Host 三个进程。
- Provider 通过无参数 `FullTrustProcessLauncher` 启动 Session Host。VCore Provider 将系统 IP 包交给 Session Host；Session Host 用 kill-on-close Job Object 启动并监督普通权限 `OneXrayCore.exe`，VCore 再通过动态 loopback SOCKS5 转发。`sessionBackend` 只管理进程存活，不检查端口或 readiness；该 SOCKS5 仅监听 `127.0.0.1`，不是用户代理入口。
- App 源码使用 Windows bridge revision 3，`startVpn` 每次必须完整发送 `policy.alwaysOn`、`policy.allowLocalNetwork` 和 `policy.excludedCidrs`。设置接线前 App 显式发送初始值 `false`、`true`、`[]`，VCore 不补默认值；CIDR 与 IPv6 / DNS 冲突由 VCore 校验。Session Snapshot token 仍为 `vcore-session-v2:<sha256>`，与 bridge revision 独立。打包的 `vcore.dll` 必须匹配 revision 3；源码契约测试不代表打包 DLL 或 Windows 实机验证通过。
- MSIX 声明 `networkingVpnProvider`、网络和 `runFullTrust` 能力，注册 `VCore.VpnBackgroundTask` 及默认关闭的 `VCoreStartup`。Provider extension 显式保持 `windowsApp` / `appContainer`，Session Host extension 保持 `packagedClassicApp` / `mediumIL`。Core 不使用 `allowElevation`。
- `msix:create` 生成基础包后，`build_scripts/app/windows_msix.py` 把两个 VCore extension 放入现有主 Application，并补充 package-level in-process server，再由 `makeappx` 原路径重打包。已有 VCore extension 或 Application 数量不为一时直接失败。
- VCore 构建输出必须附带 artifact manifest；复制前校验 package integration revision 2、架构、config schema revision 13、三项文件集合和全部 SHA-256。任一不匹配都在打包前失败。
- 完成构建和打包后、上传产物前执行 `OneXrayCore.exe -h`，用于发现无法加载或架构错误。
- workflow 中的注释、runner 标签和实际构建步骤必须同步；外部调研结论不替代 GitHub Actions 实机结果。

## 变更验证

修改 Windows runner 或工具链后，至少在 GitHub Actions 验证：

1. x64 与 arm64 job 都能完成依赖安装和 CMake 配置。
2. Flutter Windows runner、插件和 OneXrayCore 编译通过。
3. `/W4 /WX` 下没有新增告警。
4. 生成的 Core 可执行文件能够运行帮助命令。
5. 两个架构的 MSIX 和上传产物名称正确，且不再生成 ZIP 或 EXE 安装包。
6. Manifest 恰好包含一个 Application、两个 VCore extension、VCore activation class、所需能力和 `VCoreStartup`；没有 helper Id 或 `AppListEntry`，包内三个 VCore 文件均为目标架构且 hash 与 artifact manifest 一致。
7. MSIX 不包含 `allowElevation`，Core 启动不触发 UAC。
8. Microsoft Store workflow 能从两个架构的 MSIX artifact 生成 MSIX Bundle；实际发布必须另行验证 Partner Center 凭据和受限能力审批。

## 本地签名包

本地测试继续走同一 `msix:create` 和 manifest 增强流程。使用带 Code Signing EKU（`1.3.6.1.5.5.7.3.3`）和私钥的开发证书，将 PFX 导入当前用户证书库：

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

开发阶段只验证目标版本清洁安装。测试前停止活动 VPN，卸载旧开发包并删除测试 profile、LocalState、Snapshot 和测试数据库；不执行原位升级、降级、旧数据保留或协议互通测试。脚本不包含旧 revision decoder、迁移或 fallback。

本地不必伪造 GitHub 托管镜像。涉及镜像可用性、预装软件或标签变更时，以 GitHub 官方 runner image 清单和实际 workflow run 为准。

## 主要实现入口

- 构建矩阵：`.github/workflows/build.yml`
- Microsoft Store Bundle 与发布：`.github/workflows/publish-microsoft-store.yml`
- Windows CMake：`windows/CMakeLists.txt`、`windows/app.cmake`
- App 构建编排：`build_scripts/`
- Windows 打包：`build_scripts/app/windows.py`、`build_scripts/app/windows_msix.py`、`pubspec.yaml`
- VCore host bridge：`lib/core/ffi/windows/native_api.dart`
- Windows VPN 生命周期：`lib/core/ffi/windows/ffi_api.dart`
