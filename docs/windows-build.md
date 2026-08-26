# Windows 构建

Windows 构建以 `.github/workflows/build.yml` 为事实来源。本文只记录选择 runner 时必须保留的工程约束，不固定 Actions、小版本或依赖清单。

## 构建矩阵

- x64 使用 `windows-2025`，目标环境为该镜像提供的 Visual Studio 2026 工具链。
- arm64 使用 `windows-11-arm`。
- 两个架构都从同一组 OneXray、libXray 和 Xray-core 源码构建，并上传独立产物。

当前 job 没有显式安装 Visual Studio，也没有固定 CMake generator 或 toolset。构建脚本依赖 runner 镜像的默认工具链发现。因此把 x64 image 改为其它标签时，必须把“镜像实际预装并默认选择所需 Visual Studio/CMake 工具链”作为验证项，不能只根据标签名称推断。

## 工程约束

- Windows CMake 工程使用 C++17。
- MSVC 编译启用 `/W4 /WX`，警告会导致构建失败。
- Flutter、Go 和 Xray-core 的架构必须与矩阵项一致。
- 完成构建和打包后、上传产物前执行 `OneXrayCore.exe -h`，用于发现无法加载或架构错误。
- workflow 中的注释、runner 标签和实际构建步骤必须同步；外部调研结论不替代 GitHub Actions 实机结果。

## 变更验证

修改 Windows runner 或工具链后，至少在 GitHub Actions 验证：

1. x64 与 arm64 job 都能完成依赖安装和 CMake 配置。
2. Flutter Windows runner、插件和 OneXrayCore 编译通过。
3. `/W4 /WX` 下没有新增告警。
4. 生成的 Core 可执行文件能够运行帮助命令。
5. 两个架构的安装包和上传产物名称正确。

本地不必伪造 GitHub 托管镜像。涉及镜像可用性、预装软件或标签变更时，以 GitHub 官方 runner image 清单和实际 workflow run 为准。

## 主要实现入口

- 构建矩阵：`.github/workflows/build.yml`
- Windows CMake：`windows/CMakeLists.txt`、`windows/app.cmake`
- App 构建编排：`build_scripts/`
- Windows 打包：`windows/packaging/`
