# Настройка Debug-окружения

Этот документ предназначен для разработчиков OneXray. Он описывает минимальную настройку **локального debug-окружения** и не покрывает release, публикацию в stores, подпись или fastlane publishing.

## 1. Инициализация проекта

Репозиторий фиксирует версию Flutter через `.fvmrc`. После клонирования сначала установите FVM:

```shell
# macOS / Linux
curl -fsSL https://fvm.app/install.sh | bash
export PATH="$HOME/fvm/bin:$PATH"

# Windows
choco install fvm
```

Затем выполните в корне репозитория:

```shell
fvm install
fvm flutter pub get
```

После этого подготовьте локальные конфигурационные файлы для debug:

```shell
cp .env.example .env
cp firebase.json.example firebase.json
cp lib/firebase_options.dart.example lib/firebase_options.dart
cp android/app/google-services.json.example android/app/google-services.json
cp swift/AppStore/GoogleService-Info.plist.example swift/AppStore/GoogleService-Info.plist
cp swift/macOSSE/GoogleService-Info.plist.example swift/macOSSE/GoogleService-Info.plist
```

Файлов `.example` достаточно для локальной разработки. Позже замените их своими конфигурациями, если нужно тестировать настоящий Firebase или AdMob.

## 2. Подготовка артефактов libXray

Локальная отладка OneXray зависит от артефактов, собранных из соседнего репозитория `libXray`. Основные выходные файлы из `libXray/build`:

- Apple: `LibXray.xcframework`
- Android: `libXray.aar`, `libXray-sources.jar`
- Linux: `linux_so/libXray.so`, `bin/xray`
- Windows: `windows_dll/libXray.dll`, `bin/xray.exe`

Сначала соберите нужные targets в `libXray`:

```shell
cd ../libXray
python3 build/main.py apple go
python3 build/main.py android
python3 build/main.py linux
python3 build/main.py windows
```

Затем скопируйте артефакты в соответствующие каталоги OneXray.

### iOS / macOS

Apple-платформы используют общий `LibXray.xcframework`. Скопируйте его в `swift/All/`:

```shell
cp -R ../libXray/LibXray.xcframework swift/All/
```

В `swift/All/` уже есть Swift integration files, такие как `BridgeHeader.h`; обычно здесь нужно обновлять только `LibXray.xcframework`.

### Android

Android использует `aar` и sources jar. Скопируйте их в `android/app/libs/`:

```shell
mkdir -p android/app/libs
cp ../libXray/libXray.aar android/app/libs/
cp ../libXray/libXray-sources.jar android/app/libs/
```

### Linux

`linux/app.cmake` линкует `libXray.so` из `linux/app/` и устанавливает `OneXrayCore` в итоговый bundle. Скопируйте Linux-артефакты в `linux/app/` и переименуйте `bin/xray` в имя, которое ожидает OneXray:

```shell
mkdir -p linux/app
cp ../libXray/linux_so/libXray.so linux/app/
cp ../libXray/bin/xray linux/app/OneXrayCore
```

### Windows

`windows/app.cmake` устанавливает `libXray.dll` и `OneXrayCore.exe` из `windows/app/`. Скопируйте Windows-артефакты в `windows/app/` и переименуйте `bin/xray.exe` в имя, которое ожидает OneXray:

```shell
mkdir -p windows/app
cp ../libXray/windows_dll/libXray.dll windows/app/
cp ../libXray/bin/xray.exe windows/app/OneXrayCore.exe
```

> `windows/app.cmake` также упаковывает `wintun.dll`. Этот файл не входит в `libXray`; его нужно подготовить отдельно в Windows development environment.

## 3. Запуск отладки

Запустите нужную платформу:

```shell
fvm flutter run -d android
fvm flutter run -d macos
```

Перед отладкой Linux установите локальные build dependencies:

```shell
sudo apt-get update
sudo apt-get install -y \
  ninja-build clang cmake pkg-config \
  libgtk-3-dev liblzma-dev libblkid-dev libsecret-1-dev \
  libayatana-appindicator3-dev \
  file
fvm flutter run -d linux
```

Перед отладкой iOS установите CocoaPods dependencies:

```shell
cd ios
pod install
cd ..
fvm flutter run -d ios
```

## 4. Примечания к `.env`

Для локального debug `.env` обычно может оставаться пустым:

- Если `ADMOB_APP_ID_ANDROID` или `ADMOB_APP_ID_IOS` пустой, OneXray использует официальный test App ID от Google.
- Если `ADMOB_AD_UNIT_ID_ANDROID` или `ADMOB_AD_UNIT_ID_IOS` пустой, настоящие ad unit IDs не внедряются.
- Переменные `FASTLANE_*` нужны только для release flows и не требуются для debug.

`source .env` и `BUILD_NUMBER` нужны только при запуске packaging scripts из репозитория.

## 5. Файлы, связанные с `.gitignore`

Следующие пути игнорируются в `.gitignore`. В **debug-окружении** их следует понимать так:

| Путь | Роль в debug setup | Примечания |
| ---- | ------------------ | ---------- |
| `android/fastlane/playservice.json` | Не используется | Только для публикации в Play Store. |
| `android/keystore/` | Не используется | Только для Android release signing; локальный debug использует debug keystore. |
| `ios/fastlane/AuthKey.p8` | Не используется | Только для iOS release. |
| `macos/fastlane/AuthKey.p8` | Не используется | Только для Mac App Store release. |
| `macos_se/fastlane/AuthKey.p8` | Не используется | Только для macOS SE release / notarization. |
| `ios/Flutter/AdMob.xcconfig` | Опционально | Если отсутствует, iOS использует default test App ID; release scripts также могут создать его автоматически. |
| `swift/AppStore/GoogleService-Info.plist` | Предоставить при необходимости | Используется при debug iOS / macOS с включенным Firebase. |
| `swift/macOSSE/GoogleService-Info.plist` | Предоставить при необходимости | Используется при debug macOS SE с включенным Firebase. |

## 6. Файлы, часто используемые в debug

В локальной разработке чаще всего используются эти файлы:

| Путь | Назначение |
| ---- | ---------- |
| `swift/All/LibXray.xcframework` | Apple-артефакт libXray для iOS / macOS. |
| `android/app/libs/libXray.aar` | Android package libXray. |
| `android/app/libs/libXray-sources.jar` | Соответствующий sources jar для Android. |
| `linux/app/libXray.so` | Shared library, которую линкует Linux desktop app. |
| `linux/app/OneXrayCore` | Core binary для Linux desktop app. |
| `windows/app/libXray.dll` | Dynamic library, загружаемая Windows desktop app. |
| `windows/app/OneXrayCore.exe` | Core binary для Windows desktop app. |
| `lib/firebase_options.dart` | Flutter-side Firebase initialization config. |
| `android/app/google-services.json` | Android Firebase config. |
| `swift/AppStore/GoogleService-Info.plist` | Firebase plist для iOS / macOS App Store targets. |
| `swift/macOSSE/GoogleService-Info.plist` | Firebase plist для macOS SE target. |

Репозиторий уже содержит соответствующие `.example` файлы. Для первой настройки debug достаточно их скопировать.

## 7. Минимальная настройка

Для локальной разработки и breakpoint debugging минимальные шаги такие:

1. Скопировать `.example` конфигурационные файлы.
2. Собрать `libXray` и скопировать его артефакты в соответствующие каталоги OneXray.
3. Выполнить `fvm install` и `fvm flutter pub get`.
4. Установить platform-specific dependencies, например `pod install` на Apple platforms и `libayatana-appindicator3-dev` на Linux.
5. Запустить приложение через `fvm flutter run -d <device>`.

Файлы вроде `playservice.json`, `android/keystore/` и платформенных `AuthKey.p8` относятся к release workflow, а не к bootstrap debug-окружения.
