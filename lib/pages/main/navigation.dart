import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AppPrimaryRoute {
  home("/home"),
  subscriptions("/subscriptions"),
  core("/core"),
  settings("/settings");

  final String rootPath;

  const AppPrimaryRoute(this.rootPath);

  static AppPrimaryRoute fromPath(String path) {
    for (final primary in values) {
      if (path == primary.rootPath || path.startsWith("${primary.rootPath}/")) {
        return primary;
      }
    }
    return home;
  }
}

enum AppSecondaryDestination {
  overview("overview"),
  nodeInfo("node-info"),
  outbound("outbound"),
  raw("raw"),
  qrcode("qrcode"),
  share("share"),
  outboundSelect("outbound-select"),
  subscriptionList("subscription-list"),
  subscriptionNodes("subscription-nodes"),
  subscriptionAdd("subscription-add"),
  subscriptionEdit("subscription-edit"),
  tun("tun"),
  onDemandRule("on-demand-rule"),
  networkInterface("network-interface"),
  selectedApp("selected-app"),
  installedApp("installed-app"),
  xray("xray"),
  xraySettingSimple("xray-setting-simple"),
  xraySettingUI("xray-setting-ui"),
  xrayLog("xray-log"),
  dns("dns"),
  fakeDns("fake-dns"),
  dnsHosts("dns-hosts"),
  dnsServer("dns-server"),
  routing("routing"),
  routingRule("routing-rule"),
  routingRuleDnsQuery("routing-rule-dns-query"),
  routingRuleDnsOut("routing-rule-dns-out"),
  routingRuleDnsDot("routing-rule-dns-dot"),
  inbounds("inbounds"),
  inboundTun("inbound-tun"),
  inboundProxy("inbound-proxy"),
  inboundSniffing("inbound-sniffing"),
  inboundPing("inbound-ping"),
  outbounds("outbounds"),
  outboundFreedom("outbound-freedom"),
  outboundFragment("outbound-fragment"),
  outboundBlackHole("outbound-black-hole"),
  outboundDns("outbound-dns"),
  outboundUI("outbound-ui"),
  xrayRaw("xray-raw"),
  xrayRawEdit("xray-raw-edit"),
  geoData("geo-data"),
  geoDatAdd("geo-data-add"),
  geoDatSelect("geo-data-select"),
  geoDatShow("geo-data-show"),
  ping("ping"),
  logs("logs"),
  longText("long-text"),
  autoUpdate("auto-update"),
  backup("backup"),
  appIcon("app-icon"),
  toolbox("toolbox"),
  theme("theme"),
  language("language"),
  support("support");

  final String segment;

  const AppSecondaryDestination(this.segment);
}

extension AppNavigationContext on BuildContext {
  AppPrimaryRoute get currentPrimaryRoute {
    final path = GoRouterState.of(this).uri.path;
    return AppPrimaryRoute.fromPath(path);
  }

  String scopedPath(AppSecondaryDestination destination) {
    final primary = currentPrimaryRoute;
    return "${primary.rootPath}/${destination.segment}";
  }

  void goPrimary(
    StatefulNavigationShell navigationShell,
    AppPrimaryRoute primary,
  ) {
    final index = AppPrimaryRoute.values.indexOf(primary);
    navigationShell.goBranch(
      index,
      initialLocation: navigationShell.currentIndex == index,
    );
  }

  void goPrimaryRoot(AppPrimaryRoute primary) {
    go(primary.rootPath);
  }

  void goScoped(AppSecondaryDestination destination, {Object? extra}) {
    go(scopedPath(destination), extra: extra);
  }

  Future<T?> pushScoped<T>(
    AppSecondaryDestination destination, {
    Object? extra,
  }) {
    return push<T>(scopedPath(destination), extra: extra);
  }
}
