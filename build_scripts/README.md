# OneXray build scripts

[English](#english) · [简体中文](#简体中文) · [Русский](#русский)

## English

The scripts in this directory build libXray against the local Xray-core
checkout, generate the Flutter FFI bindings, build the OneXray app, and package
the platform-specific outputs.

### Workspace layout

The three repositories must be sibling directories. Build artifacts are written
to the sibling `output` directory.

```text
workspace/
├── OneXray/
├── libXray/
├── Xray-core/
└── output/        # created automatically
```

The scripts use the currently checked-out libXray and Xray-core revisions. They
do not clone or pin those repositories for a local build.

### Prerequisites

- Python 3.12 or newer with `pyyaml`, `requests`, and `typer`.
- Flutter, Dart, and Go available on `PATH`.
- A toolchain for the target operating system. Apple targets require macOS,
  Xcode, CocoaPods, and Fastlane; Android requires a JDK, Android SDK/NDK, and
  Fastlane; Windows and Linux packaging requires Fastforge.
- Signing credentials and platform configuration required by the selected
  Fastlane lane.
- A positive integer in the `BUILD_NUMBER` environment variable. It is added to
  the configured `build_number.base` (currently `400`).

Install the shared Python and desktop packaging dependencies when needed:

```bash
python3 -m pip install pyyaml requests typer
dart pub global activate fastforge
```

`setup_flutter.sh` can install a fresh stable Flutter checkout for CI-like
builds. It deletes and recreates `ONEXRAY_FLUTTER_ROOT`, or
`$HOME/flutter/stable` when the variable is not set, so do not point it at a
Flutter checkout that must be preserved.

### Run a build

Run the entry point from the OneXray repository root:

```bash
export BUILD_NUMBER=1
python3 build_scripts/main.py OneXray <system>
```

Windows PowerShell:

```powershell
$env:BUILD_NUMBER = "1"
python build_scripts/main.py OneXray <system>
```

Use `python3 build_scripts/main.py --help` (or `python` on Windows) to display
the CLI syntax.

### Supported systems

| `system` | Build host | Behavior |
| --- | --- | --- |
| `ios` | macOS | Fastlane build and TestFlight upload. |
| `macos` | macOS | Mac App Store build and upload. |
| `macos_se` | macOS | Signed and notarized Developer ID universal ZIP. |
| `android` | Android toolchain | Play internal AAB upload and universal APK. |
| `windows` | Windows x64 or ARM64 | ZIP and EXE for selected architecture. |
| `linux` | Linux x64 or ARM64 | ZIP and DEB for the host architecture. |

For Windows, the architecture is detected from the host. CI can set
`ONEXRAY_WINDOWS_ARCH` to `x64` or `arm64` when the matching runner and CGo
toolchain are already configured.

### Important behavior

- **The Apple and Android commands are deployment commands.** They can sign,
  notarize, or upload builds to external stores. Verify credentials, version,
  and target before running them.
- Use a clean or disposable worktree. The build updates `pubspec.yaml`, copies
  generated core libraries and data into the app tree, and may update
  platform-specific files.
- `macos_se` replaces the local `macos/` directory with the `macos_se/`
  configuration before building. Preserve any uncommitted macOS changes first.
- Android replaces the `##version_code##` placeholder in
  `android/fastlane/Fastfile` and does not restore it. Start each Android build
  from a clean copy so a repeated build cannot reuse an old version code.
- Outputs are collected in `../output` relative to the OneXray repository.

## 简体中文

本目录中的脚本会使用本地 Xray-core 构建 libXray、生成 Flutter FFI
绑定、构建 OneXray App，并生成各平台对应的安装包。

### 工作区结构

三个仓库必须位于同一级目录。构建产物会写入同级的 `output` 目录。

```text
workspace/
├── OneXray/
├── libXray/
├── Xray-core/
└── output/        # 自动创建
```

本地构建会直接使用 libXray 和 Xray-core 当前检出的版本，不会自动克隆或锁定
这两个仓库的版本。

### 前置条件

- Python 3.12 或更高版本，并安装 `pyyaml`、`requests` 和 `typer`。
- `PATH` 中可以找到 Flutter、Dart 和 Go。
- 安装目标系统所需的工具链。Apple 平台需要 macOS、Xcode、CocoaPods 和
  Fastlane；Android 需要 JDK、Android SDK/NDK 和 Fastlane；Windows 和
  Linux 打包需要 Fastforge。
- 准备所选 Fastlane lane 需要的签名证书、凭据和平台配置。
- 设置正整数环境变量 `BUILD_NUMBER`。脚本会将它加到配置中的
  `build_number.base`（当前为 `400`）上。

按需安装通用 Python 依赖和桌面打包工具：

```bash
python3 -m pip install pyyaml requests typer
dart pub global activate fastforge
```

`setup_flutter.sh` 可以安装一份全新的 Flutter stable，用于模拟 CI
环境。该脚本会删除并重新创建 `ONEXRAY_FLUTTER_ROOT` 指向的目录；未设置时
使用 `$HOME/flutter/stable`。不要将它指向需要保留的 Flutter 工作目录。

### 执行构建

在 OneXray 仓库根目录运行入口脚本：

```bash
export BUILD_NUMBER=1
python3 build_scripts/main.py OneXray <system>
```

Windows PowerShell：

```powershell
$env:BUILD_NUMBER = "1"
python build_scripts/main.py OneXray <system>
```

可以运行 `python3 build_scripts/main.py --help` 查看命令格式；Windows 使用
`python`。

### 支持的系统

| `system` | 构建主机 | 行为 |
| --- | --- | --- |
| `ios` | macOS | Fastlane 构建并上传到 TestFlight。 |
| `macos` | macOS | 构建并上传 Mac App Store 版本。 |
| `macos_se` | macOS | 签名、公证并生成 Developer ID 通用 ZIP。 |
| `android` | Android 工具链 | 上传 Play internal AAB 并获取 universal APK。 |
| `windows` | Windows x64 或 ARM64 | 为所选架构生成 ZIP 和 EXE。 |
| `linux` | Linux x64 或 ARM64 | 为主机架构生成 ZIP 和 DEB。 |

Windows 默认根据主机识别架构。CI 可以在已经配置好对应 runner 和 CGo
工具链的前提下，将 `ONEXRAY_WINDOWS_ARCH` 设置为 `x64` 或 `arm64`。

### 重要行为

- **Apple 和 Android 命令属于部署命令。** 它们可能执行签名、公证或上传到
  外部商店。运行前请确认凭据、版本和目标环境。
- 建议使用干净或可丢弃的 worktree。构建会更新 `pubspec.yaml`，将生成的
  Core 库和数据复制到 App 目录，并可能修改平台文件。
- `macos_se` 会在构建前用 `macos_se/` 配置替换本地 `macos/` 目录。请先
  保存所有尚未提交的 macOS 改动。
- Android 构建会替换 `android/fastlane/Fastfile` 中的
  `##version_code##` 占位符，并且不会自动恢复。每次 Android 构建都应从
  干净副本开始，避免重复构建沿用旧的 version code。
- 所有产物集中在 OneXray 仓库同级的 `../output` 目录。

## Русский

Скрипты из этого каталога собирают libXray с использованием локальной копии
Xray-core, генерируют FFI-привязки Flutter, собирают приложение OneXray и
создают пакеты для выбранной платформы.

### Структура рабочего каталога

Три репозитория должны находиться в соседних каталогах. Результаты сборки
записываются в соседний каталог `output`.

```text
workspace/
├── OneXray/
├── libXray/
├── Xray-core/
└── output/        # создаётся автоматически
```

При локальной сборке используются текущие версии libXray и Xray-core. Скрипты
не клонируют эти репозитории и не закрепляют их ревизии.

### Требования

- Python 3.12 или новее с пакетами `pyyaml`, `requests` и `typer`.
- Flutter, Dart и Go, доступные через `PATH`.
- Инструменты для целевой системы. Для Apple требуются macOS, Xcode, CocoaPods
  и Fastlane; для Android — JDK, Android SDK/NDK и Fastlane; для упаковки под
  Windows и Linux требуется Fastforge.
- Сертификаты, учётные данные и настройки платформы, необходимые выбранному
  lane Fastlane.
- Положительное целое число в переменной окружения `BUILD_NUMBER`. Оно
  прибавляется к параметру `build_number.base` (сейчас `400`).

При необходимости установите общие зависимости Python и инструмент упаковки:

```bash
python3 -m pip install pyyaml requests typer
dart pub global activate fastforge
```

Скрипт `setup_flutter.sh` устанавливает свежую стабильную версию Flutter для
сборки в окружении, похожем на CI. Он удаляет и заново создаёт каталог,
указанный в `ONEXRAY_FLUTTER_ROOT`, либо `$HOME/flutter/stable`, если переменная
не задана. Не указывайте каталог Flutter, который необходимо сохранить.

### Запуск сборки

Запускайте основной скрипт из корня репозитория OneXray:

```bash
export BUILD_NUMBER=1
python3 build_scripts/main.py OneXray <system>
```

Windows PowerShell:

```powershell
$env:BUILD_NUMBER = "1"
python build_scripts/main.py OneXray <system>
```

Команда `python3 build_scripts/main.py --help` выводит синтаксис CLI; в Windows
используйте `python`.

### Поддерживаемые системы

| `system` | Среда сборки | Действие |
| --- | --- | --- |
| `ios` | macOS | Сборка Fastlane и загрузка в TestFlight. |
| `macos` | macOS | Сборка и загрузка версии Mac App Store. |
| `macos_se` | macOS | Подписанный и нотариализированный универсальный ZIP. |
| `android` | Android toolchain | Загрузка AAB в Play internal; universal APK. |
| `windows` | Windows x64 или ARM64 | ZIP и EXE для выбранной архитектуры. |
| `linux` | Linux x64 или ARM64 | ZIP и DEB для архитектуры хоста. |

В Windows архитектура по умолчанию определяется по системе. В CI переменную
`ONEXRAY_WINDOWS_ARCH` можно установить в `x64` или `arm64`, если уже настроены
соответствующий runner и CGo toolchain.

### Важные особенности

- **Команды Apple и Android выполняют развёртывание.** Они могут подписывать,
  нотариализировать или загружать сборки во внешние магазины. Перед запуском
  проверьте учётные данные, версию и целевое окружение.
- Используйте чистый или одноразовый worktree. Сборка изменяет `pubspec.yaml`,
  копирует сгенерированные библиотеки Core и данные в дерево приложения, а
  также может изменять платформенные файлы.
- Перед сборкой `macos_se` локальный каталог `macos/` заменяется конфигурацией
  из `macos_se/`. Сначала сохраните все незакоммиченные изменения macOS.
- При сборке Android заменяется маркер `##version_code##` в файле
  `android/fastlane/Fastfile`, и исходное значение не восстанавливается. Каждую
  сборку Android запускайте из чистой копии, чтобы повторный запуск не
  использовал старый version code.
- Все результаты помещаются в соседний с репозиторием OneXray каталог
  `../output`.
