import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/geo_data/add/page.dart';
import 'package:onexray/pages/core/geo_data/list/page.dart';
import 'package:onexray/pages/core/geo_data/list/params.dart';
import 'package:onexray/pages/core/geo_data/select/page.dart';
import 'package:onexray/pages/core/geo_data/select/params.dart';
import 'package:onexray/pages/core/geo_data/show/page.dart';
import 'package:onexray/pages/core/geo_data/show/params.dart';
import 'package:onexray/pages/core/log/log_file_viewer/page.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/pages/core/log/config_file_viewer/page.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:onexray/pages/core/ping/page.dart';
import 'package:onexray/pages/core/tun/installed_app/page.dart';
import 'package:onexray/pages/core/tun/installed_app/params.dart';
import 'package:onexray/pages/core/tun/network_interface/page.dart';
import 'package:onexray/pages/core/tun/network_interface/params.dart';
import 'package:onexray/pages/core/tun/on_demand_rule/page.dart';
import 'package:onexray/pages/core/tun/on_demand_rule/params.dart';
import 'package:onexray/pages/core/tun/selected_app/page.dart';
import 'package:onexray/pages/core/tun/selected_app/params.dart';
import 'package:onexray/pages/core/tun/ui/page.dart';
import 'package:onexray/pages/core/xray/outbound/page.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/core/xray/full_config/page.dart';
import 'package:onexray/pages/core/xray/full_config/params.dart';
import 'package:onexray/pages/core/xray/raw/page.dart';
import 'package:onexray/pages/core/xray/raw/params.dart';
import 'package:onexray/pages/core/xray/raw_edit/page.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/core/xray/profile/dns_hosts/page.dart';
import 'package:onexray/pages/core/xray/profile/dns_hosts/params.dart';
import 'package:onexray/pages/core/xray/profile/dns_server/page.dart';
import 'package:onexray/pages/core/xray/profile/dns_server/params.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/page.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/params.dart';
import 'package:onexray/pages/core/xray/profile/inbound_ping/page.dart';
import 'package:onexray/pages/core/xray/profile/inbound_ping/params.dart';
import 'package:onexray/pages/core/xray/profile/inbound_sniffing/page.dart';
import 'package:onexray/pages/core/xray/profile/inbound_sniffing/params.dart';
import 'package:onexray/pages/core/xray/profile/inbound_tun/page.dart';
import 'package:onexray/pages/core/xray/profile/inbound_tun/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_black_hole/page.dart';
import 'package:onexray/pages/core/xray/profile/outbound_dns/page.dart';
import 'package:onexray/pages/core/xray/profile/outbound_dns/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_fragment/page.dart';
import 'package:onexray/pages/core/xray/profile/outbound_fragment/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_freedom/page.dart';
import 'package:onexray/pages/core/xray/profile/outbound_freedom/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule/page.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_dot/page.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_dot/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_out/page.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_out/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_query/page.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_query/params.dart';
import 'package:onexray/pages/core/xray/profile/simple/page.dart';
import 'package:onexray/pages/core/xray/profile/ui/page.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/core/xray/profile_list/page.dart';
import 'package:onexray/pages/home/main/page.dart';
import 'package:onexray/pages/home/node_info/page.dart';
import 'package:onexray/pages/home/node_info/params.dart';
import 'package:onexray/pages/home/outbound_select/page.dart';
import 'package:onexray/pages/home/outbound_select/params.dart';
import 'package:onexray/pages/home/qrcode/page.dart';
import 'package:onexray/pages/home/share/page.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/launch/first_run/page.dart';
import 'package:onexray/pages/launch/privacy/page.dart';
import 'package:onexray/pages/launch/splash/page.dart';
import 'package:onexray/pages/main/adaptive_shell.dart';
import 'package:onexray/pages/main/dialog_page.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/settings/app_update/dialog.dart';
import 'package:onexray/pages/settings/app_update/params.dart';
import 'package:onexray/pages/settings/app_icon/page.dart';
import 'package:onexray/pages/settings/auto_update/page.dart';
import 'package:onexray/pages/settings/backup/page.dart';
import 'package:onexray/pages/settings/desktop/page.dart';
import 'package:onexray/pages/settings/general/page.dart';
import 'package:onexray/pages/settings/language/page.dart';
import 'package:onexray/pages/settings/main/page.dart';
import 'package:onexray/pages/settings/theme/page.dart';
import 'package:onexray/pages/subscriptions/add/page.dart';
import 'package:onexray/pages/subscriptions/edit/page.dart';
import 'package:onexray/pages/subscriptions/edit/params.dart';
import 'package:onexray/pages/subscriptions/list/page.dart';
import 'package:onexray/pages/subscriptions/nodes/page.dart';
import 'package:onexray/pages/subscriptions/nodes/params.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: "root",
);

abstract final class RouterPath {
  static const splash = "/splash";
  static const privacy = "/privacy";
  static const firstRun = "/firstRun";
  static const home = "/home";
  static const subscriptions = "/subscriptions";
  static const core = "/core";
  static const settings = "/settings";

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouterPath.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(path: RouterPath.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: RouterPath.privacy, builder: (_, _) => const PrivacyPage()),
      GoRoute(
        path: RouterPath.firstRun,
        builder: (_, _) => const FirstRunPage(),
      ),
      GoRoute(
        path: AppDialogRoutePath.appUpdate,
        pageBuilder: (_, state) => AppDialogPage<void>(
          builder: (_) => _withDialogExtra<AppUpdateDialogParams>(
            state,
            "AppUpdateDialogParams",
            (params) => AppUpdateDialog(params: params),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) {
          return AdaptiveMainShell(navigationShell: navigationShell);
        },
        branches: AppPrimaryRoute.values.map(_buildPrimaryBranch).toList(),
      ),
    ],
  );
}

final _primaryNavigatorKeys = {
  for (final primary in AppPrimaryRoute.values)
    primary: GlobalKey<NavigatorState>(debugLabel: "${primary.name}Branch"),
};

StatefulShellBranch _buildPrimaryBranch(AppPrimaryRoute primary) {
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
        (route) => GoRoute(
          path: route.destination.segment,
          builder: (context, state) => route.builder(context, state),
        ),
      )
      .toList();
}

typedef _SecondaryRouteBuilder =
    Widget Function(BuildContext context, GoRouterState state);

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
  _route(AppSecondaryDestination.overview, (_, _) => const HomePage()),
  _route(
    AppSecondaryDestination.nodeInfo,
    (_, state) => _withExtra<NodeInfoPageParams>(
      state,
      AppSecondaryDestination.nodeInfo,
      (params) => NodeInfoPage(params: params),
    ),
  ),
  _route(AppSecondaryDestination.qrcode, (_, _) => const QrcodePage()),
  _route(
    AppSecondaryDestination.share,
    (_, state) => _withExtra<SharePageParams>(
      state,
      AppSecondaryDestination.share,
      (params) => SharePage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.outboundSelect,
    (_, state) => _withExtra<OutboundSelectParams>(
      state,
      AppSecondaryDestination.outboundSelect,
      (params) => OutboundSelectPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.subscriptionList,
    (_, _) => const SubscriptionListPage(),
  ),
  _route(
    AppSecondaryDestination.subscriptionNodes,
    (_, state) => _withExtra<SubscriptionNodesParams>(
      state,
      AppSecondaryDestination.subscriptionNodes,
      (params) => SubscriptionNodesPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.subscriptionAdd,
    (_, _) => const SubscriptionAddPage(),
  ),
  _route(
    AppSecondaryDestination.subscriptionEdit,
    (_, state) => _withExtra<SubscriptionEditParams>(
      state,
      AppSecondaryDestination.subscriptionEdit,
      (params) => SubscriptionEditPage(params: params),
    ),
  ),
  _route(AppSecondaryDestination.tun, (_, _) => const TunSettingsPage()),
  _route(
    AppSecondaryDestination.onDemandRule,
    (_, state) => _withExtra<OnDemandRuleParams>(
      state,
      AppSecondaryDestination.onDemandRule,
      (params) => OnDemandRulePage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.networkInterface,
    (_, state) => _withExtra<NetworkInterfaceParams>(
      state,
      AppSecondaryDestination.networkInterface,
      (params) => NetworkInterfacePage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.selectedApp,
    (_, state) => _withExtra<SelectedAppParams>(
      state,
      AppSecondaryDestination.selectedApp,
      (params) => SelectedAppPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.installedApp,
    (_, state) => _withExtra<InstalledAppParams>(
      state,
      AppSecondaryDestination.installedApp,
      (params) => InstalledAppPage(params: params),
    ),
  ),
  _route(AppSecondaryDestination.xray, (_, _) => const XrayProfileListPage()),
  _route(
    AppSecondaryDestination.xrayFullConfig,
    (_, state) => _withExtra<XrayFullConfigParams>(
      state,
      AppSecondaryDestination.xrayFullConfig,
      (params) => XrayFullConfigPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.xrayProfileSimple,
    (_, _) => const XrayProfileSimplePage(),
  ),
  _route(
    AppSecondaryDestination.xrayProfileUI,
    (_, state) => _withExtra<XrayProfileUIParams>(
      state,
      AppSecondaryDestination.xrayProfileUI,
      (params) => XrayProfileUIPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.dnsHosts,
    (_, state) => _withExtra<DnsHostsParams>(
      state,
      AppSecondaryDestination.dnsHosts,
      (params) => DnsHostsPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.dnsServer,
    (_, state) => _withExtra<DnsServerParams>(
      state,
      AppSecondaryDestination.dnsServer,
      (params) => DnsServerPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.routingRule,
    (_, state) => _withExtra<RoutingRuleParams>(
      state,
      AppSecondaryDestination.routingRule,
      (params) => RoutingRulePage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.routingRuleDnsQuery,
    (_, state) => _withExtra<RoutingRuleDnsQueryParams>(
      state,
      AppSecondaryDestination.routingRuleDnsQuery,
      (params) => RoutingRuleDnsQueryPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.routingRuleDnsOut,
    (_, state) => _withExtra<RoutingRuleDnsOutParams>(
      state,
      AppSecondaryDestination.routingRuleDnsOut,
      (params) => RoutingRuleDnsOutPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.routingRuleDnsDot,
    (_, state) => _withExtra<RoutingRuleDnsDoTParams>(
      state,
      AppSecondaryDestination.routingRuleDnsDot,
      (params) => RoutingRuleDnsDoTPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.inboundTun,
    (_, state) => _withExtra<InboundTunParams>(
      state,
      AppSecondaryDestination.inboundTun,
      (params) => InboundTunPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.inboundSniffing,
    (_, state) => _withExtra<InboundSniffingParams>(
      state,
      AppSecondaryDestination.inboundSniffing,
      (params) => InboundSniffingPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.inboundPing,
    (_, state) => _withExtra<InboundPingParams>(
      state,
      AppSecondaryDestination.inboundPing,
      (params) => InboundPingPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.inboundAdditional,
    (_, state) => _withExtra<AdditionalInboundParams>(
      state,
      AppSecondaryDestination.inboundAdditional,
      (params) => AdditionalInboundPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.outboundFreedom,
    (_, state) => _withExtra<OutboundFreedomParams>(
      state,
      AppSecondaryDestination.outboundFreedom,
      (params) => OutboundFreedomPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.outboundFragment,
    (_, state) => _withExtra<OutboundFragmentParams>(
      state,
      AppSecondaryDestination.outboundFragment,
      (params) => OutboundFragmentPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.outboundBlackHole,
    (_, _) => const OutboundBlackHolePage(),
  ),
  _route(
    AppSecondaryDestination.outboundDns,
    (_, state) => _withExtra<OutboundDnsParams>(
      state,
      AppSecondaryDestination.outboundDns,
      (params) => OutboundDnsPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.outboundUI,
    (_, state) => _withExtra<OutboundUIParams>(
      state,
      AppSecondaryDestination.outboundUI,
      (params) => OutboundUIPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.xrayRaw,
    (_, state) => _withExtra<XrayRawParams>(
      state,
      AppSecondaryDestination.xrayRaw,
      (params) => XrayRawPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.xrayRawEdit,
    (_, state) => _withExtra<XrayRawEditParams>(
      state,
      AppSecondaryDestination.xrayRawEdit,
      (params) => XrayRawEditPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.geoData,
    (_, state) => _withExtra<GeoDataListParams>(
      state,
      AppSecondaryDestination.geoData,
      (params) => GeoDataListPage(params: params),
    ),
  ),
  _route(AppSecondaryDestination.geoDatAdd, (_, _) => const GeoDatAddPage()),
  _route(
    AppSecondaryDestination.geoDatSelect,
    (_, state) => _withExtra<GeoDatSelectParams>(
      state,
      AppSecondaryDestination.geoDatSelect,
      (params) => GeoDatSelectPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.geoDatShow,
    (_, state) => _withExtra<GeoDatShowParams>(
      state,
      AppSecondaryDestination.geoDatShow,
      (params) => GeoDatShowPage(params: params),
    ),
  ),
  _route(AppSecondaryDestination.ping, (_, _) => const PingPage()),
  _route(
    AppSecondaryDestination.logFile,
    (_, state) => _withExtra<LogFileViewerParams>(
      state,
      AppSecondaryDestination.logFile,
      (params) => LogFileViewerPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.configFileViewer,
    (_, state) => _withExtra<ConfigFileViewerParams>(
      state,
      AppSecondaryDestination.configFileViewer,
      (params) => ConfigFileViewerPage(params: params),
    ),
  ),
  _route(
    AppSecondaryDestination.generalSettings,
    (_, _) => const GeneralSettingsPage(),
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
  _route(AppSecondaryDestination.support, (_, _) => const SettingsPage()),
];

Widget _withExtra<T>(
  GoRouterState state,
  AppSecondaryDestination destination,
  Widget Function(T params) builder,
) {
  final extra = state.extra;
  if (extra is T) {
    return builder(extra);
  }
  return _InvalidRoutePage(destination: destination, expectedType: "$T");
}

Widget _withDialogExtra<T>(
  GoRouterState state,
  String expectedType,
  Widget Function(T params) builder,
) {
  final extra = state.extra;
  if (extra is T) {
    return builder(extra);
  }
  return _InvalidRouteDialog(expectedType: expectedType);
}

class _InvalidRoutePage extends StatelessWidget {
  const _InvalidRoutePage({
    required this.destination,
    required this.expectedType,
  });

  final AppSecondaryDestination destination;
  final String expectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invalid route")),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Missing or invalid route parameters for "
              "${destination.segment}. Expected $expectedType.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidRouteDialog extends StatelessWidget {
  const _InvalidRouteDialog({required this.expectedType});

  final String expectedType;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Invalid route"),
      content: Text(
        "Missing or invalid route parameters. Expected $expectedType.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
