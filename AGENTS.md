# OneXray App

Cross-platform Flutter Xray-core client. Current contracts are indexed in
[docs](docs/README.md); old refactor plans and progress logs are historical evidence.

## Engineering boundaries

- Dependencies flow `pages → service → core`, never backwards. Services own
  business logic; pages compose UI and bind callbacks to their controllers.
- Custom page controllers extend `PageCubit`; use Bloc for observable state,
  including dialogs, loading and expansion. Text/scroll/focus and third-party
  controllers are UI resources, not a second state-management system.
- `ServiceManager` owns normal startup, storage, Geodata and platform/permission
  checks; normal startup must not depend on Setup. Establish a valid absolute
  native data root before storage access.
- Route connection actions, shortcuts and tray actions through
  `ConnectionCoordinator`. Native VPN state is authoritative. After a failed
  stop/start transition, do not restart the previous connection.
- Normal configuration uses `XrayJson`; Raw JSON retains its source and uses
  a separate Map compilation path. Database JSON stays Base64; preserve legacy
  Raw rows above the new-item limit and keep retired Profile/Multi-node rows
  outside product flows.
- Live traffic comes from Xray metrics; saved session counters come from
  libXray HTTP, not file reads. The App owns cumulative totals/reset.
  Keep the iOS Debug local proxy separate from normal UI and business state.
- Prefer shared theme changes in `lib/pages/theme/`. Use `AppTheme.appBarTheme`
  for AppBar styling, `ThemeData.textTheme`/`AppTypography` for typography, and
  `LucideIcons` for icons. Pages must not hardcode font sizes, families, letter spacing
  or line heights; override AppBar styling only when the theme cannot express it.
- UI-only work preserves fields, semantics, platform visibility, persistence
  and validation unless the user explicitly requests those changes.
- Edit source models, ARB files, `pigeon/message.dart` or FFI definitions, then
  regenerate the corresponding outputs. Never hand-edit generated Dart,
  Kotlin, Swift, Drift, FFI or localization code. ARB files are source files.

## Read for the task

- Startup, recovery or permissions: [app startup](docs/app-startup.md).
- Configuration, Raw JSON, connection lifecycle or statistics:
  [Xray configuration](docs/xray-configuration.md).
- Database, migration, Geodata, updates or backup:
  [data management](docs/data-management.md).
- Import, links or sharing: [subscriptions and sharing](docs/subscriptions-and-sharing.md);
  for age keys/decryption, also read [age subscriptions](docs/age-encrypted-subscriptions.md).
- UI/navigation: [navigation](docs/app-navigation.md). For prototype parity,
  use the approved [product model](../references/onexray-app-prototype/PRODUCT-MODEL.md)
  and [prototype source](../references/onexray-app-prototype/src/); reuse its
  approved translations rather than translating again.
- Native contracts: `lib/core/pigeon/`, `pigeon/message.dart`, `swift/`,
  Android's Kotlin bridge, and [libXray API](../libXray/README.md#api).
  Before packaging, read [build scripts](build_scripts/README.md) and, for Windows,
  [Windows builds](docs/windows-build.md). Apple/Android release scripts may
  upload to stores; they are not local validation commands.
- GitHub work: [issue tracker](docs/agents/issue-tracker.md); triage:
  [labels](docs/agents/triage-labels.md); domain/ADR work:
  [domain guidance](docs/agents/domain.md).

## Verification

All `flutter` and `dart` commands must run serially across terminals, tool calls
and agents: they share `.dart_tool` and native-asset state.

- Match generation/checks to the change. Common commands:
  `flutter gen-l10n`, `dart run build_runner build --delete-conflicting-outputs`,
  `dart run tool/check_native_model_contract.dart`,
  `dart run tool/check_layer_dependencies.dart`,
  `dart format --output=none --set-exit-if-changed <changed Dart files>`,
  `flutter analyze`, `flutter test`, `flutter build macos --debug`.
  Regenerate Pigeon outputs from `pigeon/message.dart`; verify changed native
  contracts with the relevant supported platform build.
- UI validation follows [platform limits](docs/refactor-validation.md#平台边界):
  Android emulator may start VPN; macOS must not start VPN or take screenshots.
  Skip Windows/Linux builds and runs on the current macOS host; record skips.
- Keep demos and evidence in workspace `references/`, not system temp.
  Use isolated test data, never the developer's main database; keep demos minimal.
- Run `git diff --check`. Documentation-only work needs path/link checks,
  not Flutter tests or native builds. Broaden or repeat verification only for
  new changes, failures or unresolved concerns; distinguish static checks from
  actual device/VPN validation.
