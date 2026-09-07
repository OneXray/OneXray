import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/xray/log/page.dart';
import 'package:onexray/pages/advanced/xray/log/params.dart';
import 'package:onexray/pages/advanced/xray/config/page.dart';
import 'package:onexray/pages/advanced/xray/config/params.dart';
import 'package:onexray/pages/advanced/xray/ping/page.dart';
import 'package:onexray/pages/settings/about/page.dart';
import 'package:onexray/pages/advanced/tunnel/apple/page.dart';
import 'package:onexray/pages/advanced/tunnel/apple/wifi.dart';
import 'package:onexray/pages/advanced/tunnel/android/page.dart';
import 'package:onexray/pages/advanced/tunnel/android/apps.dart';
import 'package:onexray/pages/advanced/tunnel/windows/page.dart';
import 'package:onexray/pages/advanced/tunnel/interface/page.dart';
import 'package:onexray/pages/advanced/xray/geodata/page.dart';
import 'package:onexray/pages/advanced/xray/geodata/detail.dart';
import 'package:onexray/service/advanced/policy_editor.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';
import 'package:onexray/pages/shared/share/page.dart';
import 'package:onexray/pages/shared/share/params.dart';
import 'package:onexray/pages/launch/splash/page.dart';
import 'package:onexray/pages/main/adaptive_shell.dart';
import 'package:onexray/pages/main/dialog_page.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/shared/widgets/adaptive_dialog.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/launch/setup/page.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/servers/import/page.dart';
import 'package:onexray/pages/servers/page.dart';
import 'package:onexray/pages/connect/routing/smart/exit_picker.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/editor/page.dart';
import 'package:onexray/pages/servers/subscription/page.dart';
import 'package:onexray/pages/connect/raw_editor/page.dart';
import 'package:onexray/pages/connect/routing/smart/page.dart';
import 'package:onexray/pages/connect/routing/smart/regions.dart';
import 'package:onexray/pages/connect/routing/custom/page.dart';
import 'package:onexray/pages/connect/routing/custom/rule_page.dart';
import 'package:onexray/pages/settings/app_update/dialog.dart';
import 'package:onexray/pages/settings/app_update/params.dart';
import 'package:onexray/pages/settings/app_icon/page.dart';
import 'package:onexray/pages/advanced/xray/data_update/page.dart';
import 'package:onexray/pages/settings/backup/page.dart';
import 'package:onexray/pages/settings/desktop/page.dart';
import 'package:onexray/pages/settings/language/page.dart';
import 'package:onexray/pages/settings/theme/page.dart';
import 'package:onexray/pages/servers/subscription/params.dart';
import 'package:onexray/pages/theme/theme.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: "root",
);

abstract final class RouterPath {
  static const splash = "/splash";
  static const privacy = "/privacy";
  static const firstRun = "/firstRun";
  static const setup = "/setup";
  static const connect = "/connect";

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouterPath.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(path: RouterPath.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: RouterPath.setup,
        builder: (_, _) => const SetupPage(addServers: openServerImportAction),
      ),
      GoRoute(
        path: '/setup/privacy',
        builder: (_, _) => const SetupPrivacyPage(),
      ),
      GoRoute(
        path: '/setup/interface',
        redirect: (_, state) =>
            state.extra is SetupInterfaceParams ? null : RouterPath.setup,
        builder: (_, state) =>
            SetupInterfacePage(params: state.extra as SetupInterfaceParams),
      ),
      GoRoute(
        path: '/setup/region',
        redirect: (_, state) =>
            state.extra is SetupRegionParams ? null : RouterPath.setup,
        builder: (_, state) =>
            SetupRegionPage(params: state.extra as SetupRegionParams),
      ),
      GoRoute(path: RouterPath.privacy, redirect: (_, _) => RouterPath.setup),
      GoRoute(path: RouterPath.firstRun, redirect: (_, _) => RouterPath.setup),
      GoRoute(
        path: AppDialogRoutePath.appUpdate,
        pageBuilder: (_, state) => AppDialogPage<void>(
          builder: (_) => _withDialogExtra<AppUpdateDialogParams>(
            state,
            (params) => AppUpdateDialog(params: params),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) {
          return AdaptiveMainShell(navigationShell: navigationShell);
        },
        branches: AppPrimaryDestination.values
            .map(_buildPrimaryBranch)
            .toList(),
      ),
    ],
  );
}

final _primaryNavigatorKeys = {
  for (final primary in AppPrimaryDestination.values)
    primary: GlobalKey<NavigatorState>(debugLabel: "${primary.name}Branch"),
};

StatefulShellBranch _buildPrimaryBranch(AppPrimaryDestination primary) {
  return StatefulShellBranch(
    navigatorKey: _primaryNavigatorKeys[primary],
    routes: [
      GoRoute(
        path: primary.rootPath,
        builder: (_, _) => PrimaryRootContent(primary: primary),
        routes: _buildSharedSecondaryRoutes(),
      ),
    ],
  );
}

List<GoRoute> _buildSharedSecondaryRoutes() {
  return _sharedSecondaryRoutes
      .map(
        (route) => AppSecondaryDestination.dialogs.contains(route.destination)
            ? GoRoute(
                path: route.destination.segment,
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => AppDialogPage<dynamic>(
                  key: state.pageKey,
                  barrierColor: ColorManager.palette(context).overlay,
                  useSafeArea: false,
                  builder: (context) =>
                      AppDialogFrame(child: route.builder(context, state)),
                ),
              )
            : GoRoute(
                path: route.destination.segment,
                builder: (context, state) => Theme(
                  data: AppTheme.secondaryPage(context),
                  child: Builder(
                    builder: (context) => route.builder(context, state),
                  ),
                ),
              ),
      )
      .toList();
}

typedef _SecondaryRouteBuilder = Widget Function(
  BuildContext context,
  GoRouterState state,
);

class _SharedSecondaryRoute {
  final AppSecondaryDestination destination;
  final _SecondaryRouteBuilder builder;

  const _SharedSecondaryRoute(this.destination, this.builder);
}

_SharedSecondaryRoute _route(
  AppSecondaryDestination destination,
  _SecondaryRouteBuilder builder,
) {
  return _SharedSecondaryRoute(destination, builder);
}

final _sharedSecondaryRoutes = <_SharedSecondaryRoute>[
  _route(
    AppSecondaryDestination.appleVpn,
    (_, state) => _withExtra<PolicyEditorDraft>(
      state,
      (draft) => AppleVpnPage(
        draft: draft,
        openWifi: (context, draft) => context.pushScoped<bool>(
          AppSecondaryDestination.appleWifi,
          extra: draft,
        ),
      ),
    ),
  ),
  _route(
    AppSecondaryDestination.appleWifi,
    (_, state) => _withExtra<PolicyEditorDraft>(
      state,
      (draft) => AppleWifiPage(draft: draft),
    ),
  ),
  _route(
    AppSecondaryDestination.androidVpn,
    (_, state) => _withExtra<PolicyEditorDraft>(
      state,
      (draft) => AndroidVpnPage(
        draft: draft,
        openApps: (context, mode, selected) => context.pushScoped<List<String>>(
          AppSecondaryDestination.androidApps,
          extra: (mode, selected),
        ),
      ),
    ),
  ),
  _route(
    AppSecondaryDestination.androidApps,
    (_, state) => _withExtra<(String, List<String>)>(
      state,
      (params) => AndroidAppsPage(mode: params.$1, selected: params.$2),
    ),
  ),
  _route(
    AppSecondaryDestination.windowsVpn,
    (_, state) => _withExtra<PolicyEditorDraft>(
      state,
      (draft) => WindowsVpnPage(
        draft: draft,
        openInterface: (context, draft) => context.pushScoped<bool>(
          AppSecondaryDestination.outboundInterface,
          extra: draft,
        ),
      ),
    ),
  ),
  _route(
    AppSecondaryDestination.outboundInterface,
    (_, state) => _withExtra<PolicyEditorDraft>(
      state,
      (draft) => OutboundInterfacePage(draft: draft),
    ),
  ),
  _route(
    AppSecondaryDestination.routingData,
    (_, _) => GeoDataPage(
      openFile: (context, id) => context.pushScoped(
        AppSecondaryDestination.routingDataFile,
        extra: id,
      ),
    ),
  ),
  _route(
    AppSecondaryDestination.routingDataFile,
    (_, state) => _withExtra<int>(state, (id) => GeoDataFilePage(fileId: id)),
  ),
  _route(
    AppSecondaryDestination.serversImport,
    (_, state) => ServersImportPage(initialText: state.extra as String?),
  ),
  _route(
    AppSecondaryDestination.serverGroup,
    (_, state) => _withExtra<ServerGroupParams>(
      state,
      (params) => ServerGroupPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.serverEditor,
    (_, state) =>
        _withExtra<int>(state, (id) => ServerEditorPage(serverId: id)),
  ),
  _route(
    AppSecondaryDestination.serverFinalExitPicker,
    (_, state) => _withExtra<ServerExitPickerParams>(
      state,
      (params) => ServerExitPickerPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.rawEditor,
    (_, state) => RawEditorPage(rawId: state.extra as int?),
  ),
  _route(
    AppSecondaryDestination.smartRouting,
    (_, _) => SmartRoutingEditorPage(
      openRegions: (context, selected) => context.pushScoped<List<String>>(
        AppSecondaryDestination.directRegions,
        extra: selected,
      ),
      openFinalExit: (context, params) => context.pushScoped<ServerExitChoice>(
        AppSecondaryDestination.serverFinalExitPicker,
        extra: params,
      ),
    ),
  ),
  _route(
    AppSecondaryDestination.directRegions,
    (_, state) => DirectRegionsPage(
      selectedCodes: (state.extra as List?)?.cast<String>() ?? [],
    ),
  ),
  _route(
    AppSecondaryDestination.customRouting,
    (_, state) => CustomRoutingEditorPage(
      profileId: state.extra as int?,
      openRule: (context, rule) => context.pushScoped<RoutingRuleState>(
        AppSecondaryDestination.customRule,
        extra: rule,
      ),
    ),
  ),
  _route(
    AppSecondaryDestination.customRule,
    (_, state) => CustomRoutingRulePage(rule: state.extra as RoutingRuleState?),
  ),
  _route(
    AppSecondaryDestination.share,
    (_, state) => _withExtra<SharePageParams>(
      state,
      (params) => SharePage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.subscriptionEdit,
    (_, state) => _withExtra<SubscriptionEditParams>(
      state,
      (params) => SubscriptionEditorPage(subscriptionId: params.id),
    ),
  ),
  _route(AppSecondaryDestination.ping, (_, _) => const PingPage()),
  _route(
    AppSecondaryDestination.logFile,
    (_, state) => _withExtra<LogFileViewerParams>(
      state,
      (params) => LogFileViewerPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.configFileViewer,
    (_, state) => _withExtra<ConfigFileViewerParams>(
      state,
      (params) => ConfigFileViewerPage(params: params),
    ),
  ),
  _route(AppSecondaryDestination.autoUpdate, (_, _) => const AutoUpdatePage()),
  _route(
    AppSecondaryDestination.desktopSettings,
    (_, _) => const DesktopSettingsPage(),
  ),
  _route(AppSecondaryDestination.backup, (_, _) => const BackupPage()),
  _route(AppSecondaryDestination.appIcon, (_, _) => const AppIconPage()),
  _route(AppSecondaryDestination.theme, (_, _) => const ThemePage()),
  _route(AppSecondaryDestination.language, (_, _) => const LanguagePage()),
  _route(
    AppSecondaryDestination.aboutOneXray,
    (_, _) => const AboutOneXrayPage(),
  ),
];

Widget _withExtra<T>(GoRouterState state, Widget Function(T params) builder) {
  final extra = state.extra;
  if (extra is T) {
    return builder(extra);
  }
  return const _InvalidRoutePage();
}

Widget _withDialogExtra<T>(
  GoRouterState state,
  Widget Function(T params) builder,
) {
  final extra = state.extra;
  if (extra is T) {
    return builder(extra);
  }
  return const _InvalidRouteDialog();
}

class _InvalidRoutePage extends StatelessWidget {
  const _InvalidRoutePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.prototypeTemporarilyUnavailable,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppLocalizations.of(context)!.prototypeTemporarilyUnavailable,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidRouteDialog extends StatelessWidget {
  const _InvalidRouteDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        AppLocalizations.of(context)!.prototypeTemporarilyUnavailable,
      ),
      content: Text(
        AppLocalizations.of(context)!.prototypeTemporarilyUnavailable,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.prototypeClose),
        ),
      ],
    );
  }
}
