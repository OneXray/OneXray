# Локальная среда разработки

[English](./FIRST_RUN.md) · [简体中文](./FIRST_RUN.zh_CN.md) · [Русский](./FIRST_RUN.ru.md)

Подготовьте одну нужную платформу и запустите OneXray в режиме Flutter Debug. Это руководство не предназначено для выпуска или публикации приложения в магазинах.

## 1. Подготовьте инструменты

Установите [Flutter stable](https://docs.flutter.dev/install) с Dart SDK, соответствующим [pubspec.yaml](../pubspec.yaml), Git, Python 3.12+, Go согласно `go.mod` в libXray и LLVM/libclang для [генерации FFI](https://pub.dev/packages/ffigen#requirements).

| Целевая платформа | Система сборки и дополнительные инструменты |
| --- | --- |
| iOS / macOS | macOS, полная установка Xcode и нужные SDK; для отладки в симуляторе установите среду iOS Simulator. |
| Android | Android SDK, JDK (CI использует 21) и версии SDK/NDK из [android/app/build.gradle.kts](../android/app/build.gradle.kts). Задайте `ANDROID_HOME` и `ANDROID_NDK_HOME` для каталогов SDK и NDK. |
| Linux | Linux, GCC/G++, Clang/libclang, CMake, Ninja, pkg-config и зависимости GTK/плагинов из раздела ниже. |
| Windows | Windows, инструменты Visual Studio C++, Windows SDK, LLVM/libclang, совместимые с MinGW `gcc.exe` / `g++.exe` нужной архитектуры, Rust и `uv`. См. [сборку Windows](../docs/windows-build.md) (на китайском). |

Добавьте Flutter и инструменты Go в `PATH`. Сборка Android автоматически устанавливает `gomobile`; каталог установки (`GOBIN` или `GOPATH/bin`, если GOBIN не задан) тоже должен быть в `PATH`.

Проверьте окружение до сборки:

```shell
flutter doctor -v
go version
```

Все команды Flutter/Dart выполняйте последовательно, в том числе в разных терминалах. Перед генерацией, анализом или тестами остановите активный `flutter run`.

## 2. Получите репозитории

В выбранном рабочем каталоге выполните:

```shell
git clone https://github.com/OneXray/OneXray.git
git clone https://github.com/XTLS/libXray.git
cd OneXray
```

**Все дальнейшие команды выполняются из корня репозитория приложения OneXray**, рядом с `pubspec.yaml`. Уже имеющиеся репозитории повторно клонировать не нужно.

```text
workspace/
├── OneXray/    # приложение Flutter; текущий каталог
├── libXray/    # нативные библиотеки и GeoData
└── VCore/      # только для Windows
```

Версии зависимостей должны соответствовать выбранной версии приложения; ссылки CI определены в [Build workflow](../.github/workflows/build.yml). Не используйте старые нативные библиотеки с новым API приложения. Для стандартной сборки libXray отдельный репозиторий Xray-core не нужен.

## 3. Подготовьте нативные библиотеки и GeoData

Выполните только раздел для своей платформы. Эти команды libXray получают зависимости Go и подготавливают `../libXray/dat/`; они не собирают и не публикуют приложение.

### iOS / macOS

```shell
python3 ../libXray/build/main.py apple go
rsync -a --delete ../libXray/LibXray.xcframework/ swift/All/LibXray.xcframework/
```

Обе платформы используют этот framework, включая варианты для симулятора. Синхронизация заменяет только сгенерированный framework; остальные файлы `swift/All/` сохраняются.

Проекты Xcode используют [Swift Package Manager](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers). В репозитории нет Podfile: не запускайте `pod install` и не добавляйте Podfile при настройке. Flutter подготавливает пакет плагинов во время сборки Apple. Если SwiftPM ранее был отключён глобально, включите его командой `flutter config --enable-swift-package-manager`.

### Android

```shell
python3 ../libXray/build/main.py android
mkdir -p android/app/libs
cp ../libXray/libXray.aar ../libXray/libXray-sources.jar android/app/libs/
```

Команды выше предназначены для оболочки macOS/Linux; в Windows используйте соответствующие команды Python и PowerShell. Приложение поддерживает arm64-v8a и x86_64, но не 32-битный ARM. Локальная Debug-сборка использует отладочный keystore; сервисный аккаунт Play и ключ загрузки не нужны.

### Linux

В Debian / Ubuntu установите зависимости сборки и выполнения:

```shell
sudo apt-get update
sudo apt-get install -y build-essential clang libclang-dev cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libblkid-dev libsecret-1-dev libayatana-appindicator3-dev libcap2-bin procps file
python3 ../libXray/build/main.py linux
mkdir -p linux/app
cp ../libXray/linux_so/libXray.so linux/app/
cp ../libXray/bin/xray linux/app/OneXrayCore
chmod +x linux/app/OneXrayCore
```

Архитектура нативных файлов должна совпадать с архитектурой приложения Flutter.

### Windows

Если VCore ещё не подготовлен, выполните из корня приложения:

```powershell
git clone https://github.com/OneXray/VCore.git ../VCore
```

Оба режима Windows требуют `libXray.dll`, `OneXrayCore.exe`, `wintun.dll` и три файла VCore: `vcore.dll`, `vcore-windows-vpn-host.exe` и `vcore-windows-session-host.exe`. Копирования только libXray недостаточно.

Подготовьте зависимости по [руководству Windows](../docs/windows-build.md) (на китайском) и [скриптам сборки](../build_scripts/README.md#русский). Скрипт собирает оба Core, проверяет и копирует VCore, Wintun и GeoData. По умолчанию Fastforge создаёт EXE + ZIP; для EXE дополнительно нужен Inno Setup:

```powershell
$env:BUILD_NUMBER = "1"
uv run --project build_scripts python build_scripts/main.py OneXray windows
```

После подготовки `windows/app/` команда `flutter run -d windows` использует режим EXE и запрашивает UAC только при необходимости для Core. Для MSIX используйте `--windows-mode msix` и [локальную подпись](../docs/windows-build.md#本地签名包); требуется идентичность установленного пакета. Одна команда `dart run msix:create` не добавляет интеграцию VCore. Если VCore находится вне рабочего каталога, задайте `VCORE_DIR`.

### Скопируйте GeoData — обязательно при ручной сборке

После сборки libXray скопируйте **весь** каталог данных, включая JSON-индексы и временную метку, а не только два файла `.dat`:

```shell
mkdir -p assets/dat
cp -R ../libXray/dat/. assets/dat/
```

Эквивалент для PowerShell:

```powershell
New-Item -ItemType Directory -Force assets/dat | Out-Null
Copy-Item ../libXray/dat/* assets/dat/ -Force
```

`assets/dat/` не отслеживается Git. Без этих файлов приложение из свежего клона не сможет подготовить стандартные данные маршрутизации. Скрипт упаковки приложения для Windows уже выполняет это копирование.

## 4. Сгенерируйте локальные файлы Dart

После подготовки нативных библиотек и GeoData:

```shell
flutter pub get
flutter gen-l10n
dart run ffigen
```

Файлы локализации и `lib/core/ffi/generated_bindings.dart` не отслеживаются Git. Их нужно генерировать и для Apple/Android, поскольку общий код Dart импортирует FFI-привязки. Настройки FFI и пути к заголовкам уже есть в `pubspec.yaml`; если libclang не найден, проверьте установку LLVM и `llvm-path`.

Сгенерированные модели, код базы данных, ресурсов и Pigeon уже включены в репозиторий. Для первого запуска повторная генерация не нужна; после изменения исходников используйте команды ниже.

## 5. Запустите отладку

Для Android или iOS Simulator запустите устройство, выведите список и замените `DEVICE_ID` его фактическим идентификатором:

```shell
flutter devices
flutter run -d DEVICE_ID
```

Для macOS:

```shell
flutter run -d macos
```

- **iOS Simulator:** Swift автоматически использует локальный SOCKS-вход и пропускает недоступную авторизацию VPN. Переключателя Proxy в приложении нет; такая проверка не подтверждает работу системного VPN.
- **Подпись Apple:** для своей команды разработчиков согласуйте Bundle ID целей Runner/tunnel, разрешения App Group и [идентификаторы групп в Swift](../swift/All/Constants.swift). Реальным устройствам нужны действительная подпись для разработки и возможности Network Extension; настройки подписи владельца репозитория не подходят автоматически для вашего аккаунта.
- **Linux:** сначала соберите Debug-пакет, выдайте сетевые возможности его Core-файлу, затем запустите. Пример для x64:
  ```shell
  flutter build linux --debug
  sudo setcap cap_net_admin,cap_net_raw+eip build/linux/x64/debug/bundle/OneXrayCore
  flutter run -d linux
  ```
  На ARM64 замените `x64` на `arm64`. Если повторная сборка заменяет Core-файл, выдайте возможности заново.
- **Windows:** для EXE используйте `flutter run -d windows`; для MSIX запустите установленный пакет для разработки.

Завершите первоначальную настройку приложения и при необходимости импортируйте свои тестовые серверы. Требования по платформам описаны в [границах проверки](../docs/refactor-validation.md#平台边界) (на китайском).

## 6. После изменения исходников

| Изменённые файлы | Команда из корня приложения |
| --- | --- |
| Переводы ARB | `flutter gen-l10n` |
| Модели JSON/Drift или объявленные ресурсы | `dart run build_runner build --delete-conflicting-outputs` |
| `pigeon/message.dart` | `dart run pigeon --input pigeon/message.dart` |
| Заголовки или настройки FFI | `dart run ffigen` |
| libXray / нативные библиотеки | Пересоберите и замените соответствующие артефакты, остановите и запустите приложение заново; hot reload не заменяет нативные библиотеки. |

Выбирайте проверки по объёму изменений: `flutter analyze`, нужные `flutter test` и `git diff --check`. Временные демонстрации и тестовые данные храните в `references/` рабочего каталога; не используйте основную базу данных разработчика.

## Отладка — не публикация

Обычный `flutter run` не требует `.env`, `BUILD_NUMBER`, данных Fastlane, ключей App Store Connect или аккаунта загрузки Play. Подпись для разработки Apple и подпись пакета Windows — отдельные требования.

Не используйте `build_scripts/main.py` как универсальную команду отладки: цели Apple/Android могут загружать сборки в магазины, а `macos_se` заменяет локальный каталог `macos/`. Перед упаковкой прочитайте [документацию сборки](../build_scripts/README.md); не запускайте `build_scripts/setup_flutter.sh` для SDK, который хотите сохранить.

[Вернуться к README](./README.ru.md)
