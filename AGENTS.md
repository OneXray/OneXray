# Project Overview

OneXray App is a cross-platform Flutter Xray-core client. Supported platforms include iOS, macOS, macOS SE, Android, Windows, and Linux.

The app manages nodes, subscriptions, Xray Profiles, Full Configs, Raw Json configs, GeoData, and TUN / Proxy runtime modes. Before startup, it composes and writes the final runtime Xray JSON.

# Repository Layout

| Path | Purpose |
| --- | --- |
| `lib/` | Main Flutter / Dart application code. |
| `assets/` | App icons, tray icons, bundled GeoData, Markdown files, and other static assets. |
| `pigeon/` | Pigeon API definitions used to generate Dart / Kotlin / Swift bridge code. |
| `swift/` | Shared Apple Swift code, App bridge, Tunnel provider, and shared macOS resources. |
| `android/` | Android Flutter host, VPN service, Kotlin bridge, and Fastlane configuration. |
| `ios/` | iOS Runner, Tunnel extension, and Fastlane configuration. |
| `macos/` | Mac App Store Runner, Tunnel extension, and Fastlane configuration. |
| `macos_se/` | Developer ID / System Extension macOS package project. |
| `windows/` | Windows Runner, FFI / Core startup code, and packaging resources. |
| `linux/` | Linux Runner, packaging configuration, and runtime resource installation logic. |
| `build_scripts/` | App build scripts, platform packaging scripts, and libXray / Xray-core artifact copy logic. |
| `c/include/` | libXray C headers used for Dart FFI binding generation. |

# Dart Architecture

`lib/core` is the infrastructure layer. It contains database access, FFI, Pigeon wrappers, common models, network client code, platform tools, and JSON utilities.

`lib/service` is the business layer. It contains subscriptions, sharing, backup, GeoData, Ping, VPN startup, TUN Settings, Xray JSON writing, and runtime fix logic.

`lib/pages` is the UI and routing layer. It is organized by page domain. Page controllers and cubits should handle UI state and page actions only; non-trivial business logic should live in `lib/service`.

`lib/gen` and `lib/l10n` contain generated output. Do not edit generated files in these directories manually.

# Runtime Flow

After a node is selected on Home, `VpnService` reads the selected node, selected Xray Profile, current TUN / Proxy mode, and TUN Settings.

When starting a normal Outbound node, the selected node is written as the runtime `proxy` outbound. When starting a Full Config, the Full Config overrides the selected Xray Profile's `outbounds`, `routing`, and `dns`; FakeDNS remains managed by the selected Xray Profile. When starting a Raw Json config, Raw Json remains the main JSON body, but runtime inbounds are generated from the selected Xray Profile and current runtime mode.

After the final runtime Xray JSON is written, TUN mode enters the platform VPN / TUN startup path. Proxy mode starts local Xray core and exposes SOCKS / HTTP proxy ports.

# Native Bridge

Pigeon is defined in `pigeon/message.dart` and generates Dart, Kotlin, and Swift bridge code. Regenerate the corresponding files after changing the Pigeon API.

Shared Apple Swift models, logging, and utilities live in `swift/All`. The App bridge lives in `swift/App`, and the Tunnel provider lives in `swift/Tunnel`.

The Android native bridge and VPN service live under `android/app/src/main/kotlin/net/yuandev/onexray`.

Windows and Linux desktop builds use Dart FFI, platform runners, and the packaged `OneXrayCore` binary to start core. Windows TUN mode requires elevated core startup; Proxy mode must not require administrator privileges.

# Generated Files

The following files or directories are generated and should not be edited manually:

- `*.g.dart`
- `lib/core/pigeon/messages.g.dart`
- `android/app/src/main/kotlin/net/yuandev/onexray/pigeon/Messages.g.kt`
- `swift/App/pigeon/Messages.g.swift`
- Flutter l10n generated outputs
- Drift generated database code
- FFI generated bindings

When source models, ARB files, Pigeon definitions, or Drift schema files change, run the matching generation command instead of editing generated output directly.

# Validation Commands

Common validation commands:

```shell
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart run tool/check_native_model_contract.dart
dart run tool/check_layer_dependencies.dart
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test
flutter build macos --debug
git diff --check
```

Choose validation commands based on the change scope. Changes touching Pigeon, JSON models, l10n, Drift, or native bridge code must also run the matching generation and platform build checks.

# Development Rules

1. The app's `core`, `service`, and `pages` layers must strictly follow the layering rules. Reverse calls are forbidden.
2. Page and view files must not contain business logic. Data access, validation, data transformation, navigation decisions, and page actions must be managed by the corresponding controller. Pages and views should only compose UI and bind callbacks.
3. UI refactoring may reorganize UI elements and change interaction patterns. It must not add or remove fields without explicit approval from the project owner. Existing field semantics, platform visibility, persistence, validation, and runtime behavior must remain intact.
4. App bar visual styling must be defined by `AppTheme.appBarTheme`. Page-level `AppBar` instances should only declare semantic content such as `title`, `leading`, `actions`, and `bottom`, unless a behavior cannot be expressed by the shared theme.
5. Flutter UI icons must use `LucideIcons`. Do not introduce Material `Icons` or `CupertinoIcons` constants.
6. UI typography must use `ThemeData.textTheme` or semantic styles from `AppTypography`. Page and view files must not define numeric font sizes, font families, letter spacing, or line heights directly. Code, logs, metrics, and compact labels must use their corresponding `AppTypography` styles.
