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
- Current-session traffic and speed come only from Xray metrics HTTP while the
  connection page and app view are visible; input focus is not required. Do not
  persist traffic or maintain device totals.
  iOS simulator SOCKS adaptation belongs in Swift, not App UI or business state.
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
- Database, migration, Geodata or updates:
  [data management](docs/data-management.md).
- Import, links or sharing: [subscriptions and sharing](docs/subscriptions-and-sharing.md);
  for age keys/decryption, also read [age subscriptions](docs/age-encrypted-subscriptions.md).
- UI/navigation: [navigation](docs/app-navigation.md). For requested visual parity,
  consult the relevant [prototype source](../references/onexray-app-prototype/src/)
  and reuse approved translations for unchanged features. The old
  [product model](../references/onexray-app-prototype/PRODUCT-MODEL.md) is historical:
  current App contracts take precedence; do not restore retired features from it.
- Native contracts: `lib/core/pigeon/`, `pigeon/message.dart`, `swift/`,
  Android's Kotlin bridge, and [libXray API](../libXray/README.md#api).
  Before packaging, read [build scripts](build_scripts/README.md) and, for Windows,
  [Windows builds](docs/windows-build.md). Apple/Android release scripts may
  upload to stores; they are not local validation commands.

## GitHub and reviews

- Use explicit `--repo OneXray/OneXray` or repository API endpoints; the Git
  remote uses an SSH alias. Write issue/PR titles, descriptions and comments in
  English. Keep PR content self-contained without references to other repos' PRs.
- Review the PR's actual remote base/head, not unpushed local changes; record
  the commit IDs without switching the checkout. Report Standards and Spec
  separately, with severity, location, concrete impact and evidence.
- A review does not authorize edits, comments, label changes, closure or pushes.
  Check actual labels when an authorized action needs them; no triage setup is required.

## Verification

All `flutter` and `dart` commands must run serially across terminals, tool calls
and agents: they share `.dart_tool` and native-asset state.

- Match generation/checks to the change; available checks are in
  [verification](docs/refactor-validation.md#自动验证). Verify changed native
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
