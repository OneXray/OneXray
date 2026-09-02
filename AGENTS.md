# Project Overview

OneXray App is a cross-platform Flutter Xray-core client. Supported platforms include iOS, macOS, macOS SE, Android, Windows, and Linux.

The app manages servers, subscriptions, Smart / Custom routing, Raw Json configs, and GeoData. The four root destinations are Connect, Servers, Advanced, and Settings. Profile and Multi-node Outbound code remains temporarily for staged removal; new product flows use neither. Production builds use platform TUN on Android, Apple, and Linux. Packaged Windows retains VCore's AppContainer VPN Provider and full-trust Session Host to feed a private loopback SOCKS inbound in OneXrayCore. Proxy mode is an independent in-memory iOS Debug-only tool.

For refactor scope, phase gates, and platform verification limits, read `../references/onexray-app-prototype/APP-REFACTOR-PLAN.md` and `DEVELOPMENT.md`; for approved UI behavior and copy, read `PRODUCT-MODEL.md` and the prototype. Execution evidence lives in `../references/onexray-refactor-validation/PROGRESS.md`.

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
| `build_scripts/` | App build scripts, platform packaging scripts, and libXray artifact build/copy logic. |
| `c/include/` | Native C headers used for Dart FFI binding generation. |

# Dart Architecture

`lib/core` is the infrastructure layer. It contains database access, FFI, Pigeon wrappers, common models, network client code, platform tools, and JSON utilities.

`lib/service` is the business layer. It contains subscriptions, sharing, backup, GeoData, Ping, VPN startup, TUN Settings, Xray JSON writing, and runtime fix logic.

`lib/pages` is the UI and routing layer. It is organized by page domain. Page controllers and cubits should handle UI state and page actions only; non-trivial business logic should live in `lib/service`.

`lib/gen` and `lib/l10n` contain generated output. Do not edit generated files in these directories manually.

# Runtime Flow

`SetupService` prepares storage, VPN authorization and required platform settings before Home; optional region and server steps never start VPN. `ServiceManager` initializes `ConnectionCoordinator`, not the legacy `VpnService`.

`lib/service/connection/` owns preparation, immutable plans, serialization, cancellation, commit and recovery. Normal mode always uses the `proxy` balancer with complete node tags, including a single node. Raw retains its source text and extra inbounds; App-managed runtime fields are applied by `ConnectionCompiler`. New page actions, shortcuts and tray actions must use the coordinator, not compose runtime JSON themselves.

The native host reports VPN state. Foreground traffic reads native Xray metrics; libXray periodically saves only the current session, while App owns cumulative totals and reset watermarks. Metrics failure is not proof of disconnection. Packaged Windows uses VCore bridge revision 3 and its Session Host Job Object; statistics require no VCore changes. Preserve iOS Debug-only local proxy isolation from normal UI and business state.

# Native Bridge

Pigeon is defined in `pigeon/message.dart` and generates Dart, Kotlin, and Swift bridge code. Regenerate the corresponding files after changing the Pigeon API.

Shared Apple Swift models, logging, and utilities live in `swift/All`. The App bridge lives in `swift/App`, and the Tunnel provider lives in `swift/Tunnel`.

The Android native bridge and VPN service live under `android/app/src/main/kotlin/net/yuandev/onexray`.

Windows and Linux desktop builds use Dart FFI, generated bindings, platform runners, and libXray's packaged `OneXrayCore` binary. Its process-wide Go resolver sends bootstrap DNS through the selected physical interface. Windows additionally calls revision-3 `VCoreWindowsVpnInvoke` from `vcore.dll`; this bridge requires MSIX package identity and owns the Windows VPN profile, Session Snapshot, optional session backend, and StartupTask. Linux retains App-owned process management and grants the capabilities required by TUN.

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

Run every `flutter` and `dart` command serially. Wait for the current command to exit before starting another `flutter` or `dart` command. This rule applies across terminal sessions, parallel tool calls, and agents; these commands must never overlap because they share `.dart_tool` and native-asset build state.

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

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues for `OneXray/OneXray`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five canonical triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repo. See `docs/agents/domain.md`.
