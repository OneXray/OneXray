import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/geo_data/add/page.dart';
import 'package:onexray/pages/geo_data/list/page.dart';
import 'package:onexray/pages/geo_data/list/params.dart';
import 'package:onexray/pages/geo_data/select/page.dart';
import 'package:onexray/pages/geo_data/select/params.dart';
import 'package:onexray/pages/geo_data/show/page.dart';
import 'package:onexray/pages/geo_data/show/params.dart';
import 'package:onexray/pages/home/home/page.dart';
import 'package:onexray/pages/home/node_info/page.dart';
import 'package:onexray/pages/home/qrcode/page.dart';
import 'package:onexray/pages/home/setting_list/page.dart';
import 'package:onexray/pages/home/share/page.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/home/xray/outbound/page.dart';
import 'package:onexray/pages/home/xray/outbound/params.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/download_settings/page.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/download_settings/params.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/page.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/params.dart';
import 'package:onexray/pages/home/xray/raw/page.dart';
import 'package:onexray/pages/home/xray/raw/params.dart';
import 'package:onexray/pages/home/xray/raw_edit/page.dart';
import 'package:onexray/pages/home/xray/raw_edit/params.dart';
import 'package:onexray/pages/home/xray/setting/dns/page.dart';
import 'package:onexray/pages/home/xray/setting/dns/params.dart';
import 'package:onexray/pages/home/xray/setting/dns_hosts/page.dart';
import 'package:onexray/pages/home/xray/setting/dns_hosts/params.dart';
import 'package:onexray/pages/home/xray/setting/dns_server/page.dart';
import 'package:onexray/pages/home/xray/setting/dns_server/params.dart';
import 'package:onexray/pages/home/xray/setting/inbound_ping/page.dart';
import 'package:onexray/pages/home/xray/setting/inbound_ping/params.dart';
import 'package:onexray/pages/home/xray/setting/inbound_sniffing/page.dart';
import 'package:onexray/pages/home/xray/setting/inbound_sniffing/params.dart';
import 'package:onexray/pages/home/xray/setting/inbound_tun/page.dart';
import 'package:onexray/pages/home/xray/setting/inbound_tun/params.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/page.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/params.dart';
import 'package:onexray/pages/home/xray/setting/log/page.dart';
import 'package:onexray/pages/home/xray/setting/log/params.dart';
import 'package:onexray/pages/home/xray/setting/outbound_black_hole/page.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/page.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/params.dart';
import 'package:onexray/pages/home/xray/setting/outbound_fragment/page.dart';
import 'package:onexray/pages/home/xray/setting/outbound_fragment/params.dart';
import 'package:onexray/pages/home/xray/setting/outbound_freedom/page.dart';
import 'package:onexray/pages/home/xray/setting/outbound_freedom/params.dart';
import 'package:onexray/pages/home/xray/setting/outbounds/page.dart';
import 'package:onexray/pages/home/xray/setting/outbounds/params.dart';
import 'package:onexray/pages/home/xray/setting/routing/page.dart';
import 'package:onexray/pages/home/xray/setting/routing/params.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule/page.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule/params.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_dot/page.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_dot/params.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_out/page.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_out/params.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_query/page.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_query/params.dart';
import 'package:onexray/pages/home/xray/setting/simple/page.dart';
import 'package:onexray/pages/home/xray/setting/ui/page.dart';
import 'package:onexray/pages/home/xray/setting/ui/params.dart';
import 'package:onexray/pages/launch/first_run/page.dart';
import 'package:onexray/pages/launch/privacy/page.dart';
import 'package:onexray/pages/launch/splash/page.dart';
import 'package:onexray/pages/main/menu/page.dart';
import 'package:onexray/pages/setting/app_icon/page.dart';
import 'package:onexray/pages/setting/backup/page.dart';
import 'package:onexray/pages/setting/language/page.dart';
import 'package:onexray/pages/setting/log/page.dart';
import 'package:onexray/pages/setting/long_text/page.dart';
import 'package:onexray/pages/setting/long_text/params.dart';
import 'package:onexray/pages/setting/main/page.dart';
import 'package:onexray/pages/setting/ping/page.dart';
import 'package:onexray/pages/setting/sub_update/page.dart';
import 'package:onexray/pages/setting/theme/page.dart';
import 'package:onexray/pages/setting/toolbox/page.dart';
import 'package:onexray/pages/setting/tun/installed_app/page.dart';
import 'package:onexray/pages/setting/tun/installed_app/params.dart';
import 'package:onexray/pages/setting/tun/network_interface/page.dart';
import 'package:onexray/pages/setting/tun/network_interface/params.dart';
import 'package:onexray/pages/setting/tun/on_demand_rule/page.dart';
import 'package:onexray/pages/setting/tun/on_demand_rule/params.dart';
import 'package:onexray/pages/setting/tun/selected_app/page.dart';
import 'package:onexray/pages/setting/tun/selected_app/params.dart';
import 'package:onexray/pages/setting/tun/ui/page.dart';
import 'package:onexray/pages/subscription/add/page.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/subscription/edit/page.dart';
import 'package:onexray/pages/subscription/edit/params.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

abstract final class RouterPath {
  static const splash = "/splash";
  static const privacy = "/privacy";
  static const firstRun = "/firstRun";
  static const home = "/home";
  static const xraySettingList = "/xraySettingList";
  static const xraySettingSimple = "/xraySettingSimple";
  static const xraySettingUI = "/xraySettingUI";
  static const xrayLog = "/xrayLog";
  static const dns = "/dns";
  static const dnsHosts = "/dnsHosts";
  static const dnsServer = "/dnsServer";
  static const routing = "/routing";
  static const routingRule = "/routingRule";
  static const routingRuleDnsQuery = "/routingRuleDnsQuery";
  static const routingRuleDnsOut = "/routingRuleDnsOut";
  static const routingRuleDnsDot = "/routingRuleDnsDot";
  static const inbounds = "/inbounds";
  static const inboundTun = "/inboundTun";
  static const inboundSniffing = "/inboundSniffing";
  static const inboundSocks = "/inboundSocks";
  static const inboundHttp = "/inboundHttp";
  static const inboundPing = "/inboundPing";
  static const outbounds = "/outbounds";
  static const outboundFreedom = "/outboundFreedom";
  static const outboundFragment = "/outboundFragment";
  static const outboundBlackHole = "/outboundBlackHole";
  static const outboundDns = "/outboundDns";
  static const outboundUI = "/outboundUI";
  static const outboundXhttp = "/outboundXhttp";
  static const xhttpDownloadSettings = "/xhttpDownloadSettings";
  static const xrayRaw = "/xrayRaw";
  static const xrayRawEdit = "/xrayRawEdit";
  static const qrcode = "/qrcode";
  static const share = "/share";
  static const subscriptionAdd = "/subscriptionAdd";
  static const subscriptionEdit = "/subscriptionEdit";
  static const nodeInfo = "/nodeInfo";
  static const setting = "/setting";
  static const tunSettingUI = "/tunSettingUI";
  static const onDemandRule = "/onDemandRule";
  static const networkInterface = "/networkInterface";
  static const selectedApp = "/selectedApp";
  static const installedApp = "/installedApp";
  static const ping = "/ping";
  static const subUpdate = "/subUpdate";
  static const geoDataList = "/geoDataList";
  static const geoDatAdd = "/geoDatAdd";
  static const geoDatSelect = "/geoDatSelect";
  static const geoDatShow = "/geoDatShow";
  static const log = "/log";
  static const longText = "/longText";
  static const backup = "/backup";
  static const appIcon = "/appIcon";
  static const toolbox = "/toolbox";
  static const theme = "/theme";
  static const language = "/language";

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
        path: RouterPath.home,
        builder: (_, state) => AppPlatform.isMacOS
            ? const MenuMainScaffold(child: HomePage())
            : const HomePage(),
      ),
      GoRoute(
        path: RouterPath.xraySettingList,
        builder: (_, state) => const XraySettingListPage(),
      ),
      GoRoute(
        path: RouterPath.xraySettingSimple,
        builder: (_, state) => const XraySettingSimplePage(),
      ),
      GoRoute(
        path: RouterPath.xraySettingUI,
        builder: (_, state) =>
            XraySettingUIPage(params: state.extra as XraySettingUIParams),
      ),
      GoRoute(
        path: RouterPath.xrayLog,
        builder: (_, state) =>
            XrayLogPage(params: state.extra as XrayLogParams),
      ),
      GoRoute(
        path: RouterPath.dns,
        builder: (_, state) => DnsPage(params: state.extra as DnsParams),
      ),
      GoRoute(
        path: RouterPath.dnsHosts,
        builder: (_, state) =>
            DnsHostsPage(params: state.extra as DnsHostsParams),
      ),
      GoRoute(
        path: RouterPath.dnsServer,
        builder: (_, state) =>
            DnsServerPage(params: state.extra as DnsServerParams),
      ),
      GoRoute(
        path: RouterPath.routing,
        builder: (_, state) =>
            RoutingPage(params: state.extra as RoutingParams),
      ),
      GoRoute(
        path: RouterPath.routingRule,
        builder: (_, state) =>
            RoutingRulePage(params: state.extra as RoutingRuleParams),
      ),
      GoRoute(
        path: RouterPath.routingRuleDnsQuery,
        builder: (_, state) => RoutingRuleDnsQueryPage(
          params: state.extra as RoutingRuleDnsQueryParams,
        ),
      ),
      GoRoute(
        path: RouterPath.routingRuleDnsOut,
        builder: (_, state) => RoutingRuleDnsOutPage(
          params: state.extra as RoutingRuleDnsOutParams,
        ),
      ),
      GoRoute(
        path: RouterPath.routingRuleDnsDot,
        builder: (_, state) => RoutingRuleDnsDoTPage(
          params: state.extra as RoutingRuleDnsDoTParams,
        ),
      ),

      GoRoute(
        path: RouterPath.inbounds,
        builder: (_, state) =>
            InboundsPage(params: state.extra as InboundsParams),
      ),
      GoRoute(
        path: RouterPath.inboundTun,
        builder: (_, state) =>
            InboundTunPage(params: state.extra as InboundTunParams),
      ),
      GoRoute(
        path: RouterPath.inboundSniffing,
        builder: (_, state) =>
            InboundSniffingPage(params: state.extra as InboundSniffingParams),
      ),
      GoRoute(
        path: RouterPath.inboundPing,
        builder: (_, state) =>
            InboundPingPage(params: state.extra as InboundPingParams),
      ),
      GoRoute(
        path: RouterPath.outbounds,
        builder: (_, state) =>
            OutboundsPage(params: state.extra as OutboundsParams),
      ),
      GoRoute(
        path: RouterPath.outboundFreedom,
        builder: (_, state) =>
            OutboundFreedomPage(params: state.extra as OutboundFreedomParams),
      ),
      GoRoute(
        path: RouterPath.outboundFragment,
        builder: (_, state) =>
            OutboundFragmentPage(params: state.extra as OutboundFragmentParams),
      ),
      GoRoute(
        path: RouterPath.outboundBlackHole,
        builder: (_, state) => const OutboundBlackHolePage(),
      ),
      GoRoute(
        path: RouterPath.outboundDns,
        builder: (_, state) =>
            OutboundDnsPage(params: state.extra as OutboundDnsParams),
      ),
      GoRoute(
        path: RouterPath.outboundUI,
        builder: (_, state) =>
            OutboundUIPage(params: state.extra as OutboundUIParams),
      ),
      GoRoute(
        path: RouterPath.outboundXhttp,
        builder: (_, state) =>
            OutboundXhttpPage(params: state.extra as OutboundXhttpParams),
      ),
      GoRoute(
        path: RouterPath.xhttpDownloadSettings,
        builder: (_, state) => XhttpDownloadSettingsPage(
          params: state.extra as XhttpDownloadSettingsParams,
        ),
      ),
      GoRoute(
        path: RouterPath.xrayRaw,
        builder: (_, state) =>
            XrayRawPage(params: state.extra as XrayRawParams),
      ),
      GoRoute(
        path: RouterPath.xrayRawEdit,
        builder: (_, state) =>
            XrayRawEditPage(params: state.extra as XrayRawEditParams),
      ),
      GoRoute(
        path: RouterPath.qrcode,
        builder: (_, state) => const QrcodePage(),
      ),
      GoRoute(
        path: RouterPath.share,
        builder: (_, state) =>
            SharePage(params: state.extra as SharePageParams),
      ),
      // subscription
      GoRoute(
        path: RouterPath.subscriptionAdd,
        builder: (_, state) => const SubscriptionAddPage(),
      ),
      GoRoute(
        path: RouterPath.subscriptionEdit,
        builder: (_, state) =>
            SubscriptionEditPage(params: state.extra as SubscriptionEditParams),
      ),
      GoRoute(
        path: RouterPath.nodeInfo,
        builder: (_, state) => const NodeInfoPage(),
      ),
      // setting
      GoRoute(
        path: RouterPath.setting,
        builder: (_, state) => const SettingPage(),
      ),
      GoRoute(
        path: RouterPath.tunSettingUI,
        builder: (_, state) => const TunSettingUIPage(),
      ),
      GoRoute(
        path: RouterPath.onDemandRule,
        builder: (_, state) =>
            OnDemandRulePage(params: state.extra as OnDemandRuleParams),
      ),
      GoRoute(
        path: RouterPath.networkInterface,
        builder: (_, state) =>
            NetworkInterfacePage(params: state.extra as NetworkInterfaceParams),
      ),
      GoRoute(
        path: RouterPath.selectedApp,
        builder: (_, state) =>
            SelectedAppPage(params: state.extra as SelectedAppParams),
      ),
      GoRoute(
        path: RouterPath.installedApp,
        builder: (_, state) =>
            InstalledAppPage(params: state.extra as InstalledAppParams),
      ),
      GoRoute(path: RouterPath.ping, builder: (_, state) => const PingPage()),
      GoRoute(
        path: RouterPath.subUpdate,
        builder: (_, state) => const SubUpdatePage(),
      ),
      GoRoute(
        path: RouterPath.geoDataList,
        builder: (_, state) =>
            GeoDataListPage(params: state.extra as GeoDataListParams),
      ),
      GoRoute(
        path: RouterPath.geoDatAdd,
        builder: (_, state) => const GeoDatAddPage(),
      ),
      GoRoute(
        path: RouterPath.geoDatSelect,
        builder: (_, state) =>
            GeoDatSelectPage(params: state.extra as GeoDatSelectParams),
      ),
      GoRoute(
        path: RouterPath.geoDatShow,
        builder: (_, state) =>
            GeoDatShowPage(params: state.extra as GeoDatShowParams),
      ),
      GoRoute(path: RouterPath.log, builder: (_, state) => const LogPage()),
      GoRoute(
        path: RouterPath.longText,
        builder: (_, state) =>
            LongTextPage(params: state.extra as LongTextParams),
      ),
      GoRoute(
        path: RouterPath.backup,
        builder: (_, state) => const BackupPage(),
      ),
      GoRoute(
        path: RouterPath.appIcon,
        builder: (_, state) => const AppIconPage(),
      ),
      GoRoute(
        path: RouterPath.toolbox,
        builder: (_, state) => const ToolboxPage(),
      ),
      GoRoute(path: RouterPath.theme, builder: (_, state) => const ThemePage()),
      GoRoute(
        path: RouterPath.language,
        builder: (_, state) => const LanguagePage(),
      ),
    ],
  );
}
