# OneXray

[English](../README.md) | [简体中文](./README.zh_CN.md)

## О приложении

Подписывайтесь на Telegram-канал: [OneXray](https://t.me/OneXrayApp)

[Документация](https://onexray.com)

[Первый запуск](./FIRST_RUN.ru.md)

## Загрузка

| Платформа | Требования | Загрузка |
| --- | --- | --- |
| iOS | iOS 15.0 и выше, arm64 | [App Store](https://apps.apple.com/us/app/onexray/id6745748773), [IPA](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-ios.ipa) |
| macOS (Mac App Store) | macOS 12.0 и выше, Apple silicon или Intel | [App Store](https://apps.apple.com/us/app/onexray/id6745748773) |
| macOS (вне App Store) | macOS 12.0 и выше, Apple silicon или Intel | Homebrew: `brew install --cask onexrayse`, [Universal ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-macos-universal.zip) |
| Android | Android 10.0 и выше, arm32, arm64 или x86_64 | [Google Play](https://play.google.com/store/apps/details?id=net.yuandev.onexray), [Universal APK](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-android-universal.apk) |
| Windows | Windows 10 или Windows 11, x86_64 | winget: `winget install --id YuanDevLLC.OneXray -e`, [EXE](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.exe), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.zip) |
| Linux x86_64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.deb), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip) |
| Linux arm64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.deb), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.zip) |

## Примечания

### macOS

Версия Mac App Store — отдельный пакет из магазина. Варианты распространения вне App Store (Homebrew и Universal ZIP) используют один и тот же Developer ID пакет `macos_se` и устанавливают `OneXraySE.app`.

```shell
brew install --cask onexrayse
brew uninstall --cask onexrayse
```

### Windows

OneXray можно установить и удалить через winget.

```shell
winget install --id YuanDevLLC.OneXray -e
winget uninstall --id YuanDevLLC.OneXray -e
```

### iOS

Если у вас нет Apple ID или ваш Apple ID не может скачать OneXray, скачайте **OneXray-ios.ipa** и установите его через [AltStore](https://altstore.io/) или другой сторонний инструмент.

### Linux

Если вы используете ZIP-пакет, выполните следующие настройки для нормальной работы OneXray.

Перед выполнением команды проверьте текущий каталог.

```shell
sudo apt install -y procps libcap2-bin libayatana-appindicator3-1
sudo setcap cap_net_admin,cap_net_raw+eip OneXray/bin/OneXrayCore
```

Если вы используете DEB-пакет, для установки и удаления можно использовать команды:

```shell
sudo apt install ./OneXray-linux-x86_64.deb
sudo apt remove onexray
```

Если ваша среда рабочего стола - GNOME, установите расширение [AppIndicator](https://github.com/ubuntu/gnome-shell-extension-appindicator).

Если архитектура процессора вашей машины Arm64, при переключении языка на CJK-язык (китайский, японский или корейский) OneXray сбросит язык интерфейса на английский.

### Обновление ядра

На Linux и Windows вы можете самостоятельно обновить или заменить Xray-core. libXray нужно собирать только как динамическую библиотеку, а для `OneXrayCore` используйте официальный release-бинарник Xray-core.

#### Linux

Замените `OneXray/lib/libXray.so` на артефакт libXray `linux_so/libXray.so`.

Скачайте официальный Linux release-бинарник Xray-core, переименуйте `xray` в `OneXrayCore` и замените `OneXray/bin/OneXrayCore`.

#### Windows

Замените `OneXray/libXray.dll` на артефакт libXray `windows_dll/libXray.dll`.

Скачайте официальный Windows release-бинарник Xray-core, переименуйте `xray.exe` в `OneXrayCore.exe` и замените `OneXray/bin/OneXrayCore.exe`.

## Участие

Если проект оказался полезен, вы можете помочь ему следующими способами:

1. Поставить проекту star.
2. Перевести документацию приложения [onexray.com](https://github.com/OneXray/onexray.com).
3. Поделиться своими routing settings в [Routing](https://github.com/OneXray/Routing).
