<p align="center">
  <img src="../assets/logo.png" width="112" alt="Логотип OneXray">
</p>

<h1 align="center">OneXray</h1>

<p align="center">
  Приватный кроссплатформенный клиент Xray-core для ваших узлов, подписок и конфигураций.
</p>

<p align="center">
  <a href="https://github.com/OneXray/OneXray/releases/latest"><img src="https://img.shields.io/github/v/release/OneXray/OneXray?display_name=tag&sort=semver" alt="Последняя версия"></a>
  <a href="../LICENSE"><img src="https://img.shields.io/github/license/OneXray/OneXray" alt="Лицензия"></a>
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20Android%20%7C%20Windows%20%7C%20Linux-0A84FF" alt="Поддерживаемые платформы">
</p>

<p align="center">
  <a href="https://onexray.com">Документация</a> ·
  <a href="./FIRST_RUN.ru.md">Среда разработки</a> ·
  <a href="https://t.me/OneXrayApp">Telegram</a> ·
  <a href="https://github.com/OneXray/OneXray/releases/latest">Релизы</a>
</p>

<p align="center">
  <a href="../README.md">English</a> · <a href="./README.zh_CN.md">简体中文</a> · Русский
</p>

OneXray позволяет импортировать собственную совместимую конфигурацию сервера или HTTPS-подписку, организовывать узлы и управлять трафиком с помощью структурированных Xray Profiles и инструментов маршрутизации.

OneXray является только клиентом и не предоставляет VPN/прокси-серверы, подписки или сетевой доступ. Приложение не требует учетной записи и не содержит рекламы, analytics, tracking, telemetry или сервисов crash reporting.

## Предварительный просмотр

<p align="center">
  <img src="./images/home-ios.png" width="22%" alt="Главная OneXray на iOS">
  &nbsp;&nbsp;
  <img src="./images/home-macos.png" width="70%" alt="Главная OneXray на macOS">
</p>

## Возможности

- **Кроссплатформенный TUN** — iOS, macOS, Android, Windows и Linux.
- **Гибкая конфигурация** — Simple Profile, переиспользуемые Xray Profiles, Full Config и Raw JSON.
- **Управление маршрутизацией** — режимы Rule, Global и Direct переключаются на Home.
- **Импорт и организация** — поддерживаемые share links и HTTPS-подписки из QR-кодов, изображений, файлов или буфера обмена.
- **Локальные инструменты** — ping узлов, журналы Xray, управление GeoData и rule sets, backup и restore.
- **Интеграция с платформой** — Android Per-App VPN, Apple On Demand, desktop tray и выбор исходящего интерфейса.

## Подписки с age-шифрованием

При добавлении или редактировании HTTPS-подписки откройте раздел
**Encryption** и укажите существующую пару ключей age либо создайте ключ
X25519 или совместимый с Mihomo Hybrid (`ML-KEM-768 + X25519`). OneXray
отправляет только сохранённый публичный recipient в `X-Age-Public-Key`;
секретный ключ хранится локально, а пара повторно используется при
автоматическом обновлении.

HTTPS остается обязательным. Резервные ZIP-файлы OneXray не зашифрованы и
содержат пару ключей age, чтобы подписка работала после восстановления;
храните их в безопасном месте.

## URL-схема OneXray

OneXray может делиться данными и импортировать их через собственные URL
`onexray://`:

```text
onexray://onexray.com/config/add?type=outbound|profile|full|raw&data=<percent-encoded-base64-json>#Name
onexray://onexray.com/sub/add?url=<percent-encoded-https-url>[&age=x25519|hybrid]#Name
onexray://onexray.com/dat/add?type=domain|ip&url=<percent-encoded-https-url>#Name
```

Если конфигурация использует пользовательские GeoData из OneXray, их ссылки
добавляются перед ссылкой конфигурации.

Поддерживаются только перечисленные типы. Устаревший `type=setting`, резервные
копии и другие команды не принимаются. Для ссылки age-подписки приложение
создает новую локальную пару ключей, отправляет при первой загрузке только
публичный ключ и сохраняет пару после успешного импорта.

Android, iOS и установленные приложения macOS регистрируют схему напрямую. В
Windows и Linux используйте EXE/winget или DEB: ZIP-пакеты не регистрируют
схему автоматически. Версия из Mac App Store и OneXraySE используют одну
схему, поэтому при одновременной установке macOS может выбрать любое из них.

## Загрузка

| Платформа | Требования | Загрузка |
| --- | --- | --- |
| iOS | iOS 15.0 и выше, arm64 | [App Store](https://apps.apple.com/us/app/onexray/id6745748773), [IPA](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-ios.ipa) |
| macOS (Mac App Store) | macOS 13.0 и выше, Apple silicon или Intel | [App Store](https://apps.apple.com/us/app/onexray/id6745748773) |
| macOS (вне App Store) | macOS 13.0 и выше, Apple silicon или Intel | Homebrew: `brew install --cask onexrayse`, [Universal ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-macos-universal.zip) |
| Android | Android 10.0 и выше, arm64-v8a или x86_64 | [Google Play](https://play.google.com/store/apps/details?id=net.yuandev.onexray), [Universal APK](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-android-universal.apk) |
| Windows x86_64 | Windows 10 или Windows 11 | winget: `winget install --id YuanDevLLC.OneXray -e`, [EXE](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.exe), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-amd64.zip) |
| Windows ARM64 | Windows 11 | winget: `winget install --id YuanDevLLC.OneXray -e`, [EXE](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-arm64.exe), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-windows-arm64.zip) |
| Linux x86_64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.deb), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-x86_64.zip) |
| Linux arm64 | GLIBC >= 2.39 | [DEB](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.deb), [ZIP](https://github.com/OneXray/OneXray/releases/latest/download/OneXray-linux-aarch64.zip) |

## Примечания по установке

### macOS

Версия Mac App Store является отдельным пакетом. Homebrew и Universal ZIP используют один Developer ID пакет `macos_se` и устанавливают `OneXraySE.app`.

```shell
brew install --cask onexrayse
brew uninstall --cask onexrayse
```

#### Universal ZIP

1. Скачайте и распакуйте `OneXray-macos-universal.zip`.
2. Переместите `OneXraySE.app` в `/Applications` («Программы»). Не запускайте приложение непосредственно из папки «Загрузки» или другой папки: macOS требует, чтобы приложение с System Extension находилось в системном каталоге Applications.
3. Откройте OneXraySE из папки «Программы» и подтвердите первый запуск в macOS.

При первом подключении VPN:

1. Импортируйте подписку или узел, выберите узел и нажмите кнопку запуска.
2. Откройте **Системные настройки > Основные > Объекты входа и расширения**.
3. В разделе **Расширения** откройте **Сетевые расширения**, включите **OneXraySE** и нажмите **Готово**.
4. Если в разделе **Конфиденциальность и безопасность** также отображается запрос, нажмите **Разрешить** и перезапустите Mac, если это потребуется.
5. Вернитесь в OneXraySE и снова нажмите кнопку запуска.

Для обновления ZIP-версии закройте OneXraySE, замените приложение в `/Applications` на новый распакованный `OneXraySE.app` и снова откройте его. Если macOS запросит подтверждение обновления System Extension, разрешите его.

См. [Installing System Extensions and Drivers](https://developer.apple.com/documentation/systemextensions/installing-system-extensions-and-drivers) и [Change Login Items & Extensions settings](https://support.apple.com/guide/mac-help/change-login-items-extension-settings-mtusr003/mac).

### Windows

Winget автоматически выбирает установщик x86_64 или ARM64 для текущего устройства.

```shell
winget install --id YuanDevLLC.OneXray -e
winget uninstall --id YuanDevLLC.OneXray -e
```

### Android

Android поддерживает `arm64-v8a` и `x86_64`. 32-битные ARM-устройства не поддерживаются.

### iOS

Если App Store недоступен для вашего Apple ID, скачайте `OneXray-ios.ipa` и установите его через [AltStore](https://altstore.io/) или другой совместимый инструмент sideloading.

Для самостоятельной установки IPA необходимо повторно подписать OneXray и расширение Packet Tunnel с помощью provisioning profile, разрешающего Network Extension capability. Apple не предоставляет эту возможность бесплатным учетным записям Personal Team, поэтому требуется платное членство в Apple Developer Program. Без него приложение может открываться и проверять задержку узлов, но VPN не запустится. См. [Apple Developer Forums](https://developer.apple.com/forums/thread/128767) и [Поддерживаемые возможности iOS](https://developer.apple.com/help/account/reference/supported-capabilities-ios/).

### Linux

Для DEB-пакета:

```shell
sudo apt install ./OneXray-linux-x86_64.deb
sudo apt remove onexray
```

Для ZIP-пакета выполните команды из каталога, содержащего `OneXray`:

```shell
sudo apt install -y procps libcap2-bin libayatana-appindicator3-1
sudo setcap cap_net_admin,cap_net_raw+eip OneXray/bin/OneXrayCore
```

Пользователям GNOME следует установить расширение [AppIndicator](https://github.com/ubuntu/gnome-shell-extension-appindicator). Linux arm64 в настоящее время использует английский язык для CJK locale.

## Участие

Вы можете помочь проекту:

1. Поставить этому репозиторию Star.
2. Улучшить [документацию OneXray](https://github.com/OneXray/onexray.com).
3. Поделиться routing templates через [OneXray/Routing](https://github.com/OneXray/Routing).

Перед локальной сборкой прочитайте [настройку среды разработки](./FIRST_RUN.ru.md).

## Лицензия

OneXray распространяется по лицензии [GNU General Public License v3.0](../LICENSE).
