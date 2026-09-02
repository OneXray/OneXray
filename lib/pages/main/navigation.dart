import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/settings/app_update/params.dart';
import 'package:onexray/service/app_update/service.dart';

abstract final class AppDialogRoutePath {
  static const appUpdate = "/app-update";
}

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
  serversImport("servers-import"),
  serverPicker("server-picker"),
  serverGroup("server-group"),
  serverEditor("server-editor"),
  serverSources("server-sources"),
  serverFinalExitPicker("server-final-exit-picker"),
  rawEditor("raw-editor"),
  smartRouting("smart-routing"),
  directRegions("direct-regions"),
  customRouting("custom-routing"),
  customRule("custom-rule"),
  appleVpn("apple-vpn"),
  appleWifi("apple-wifi"),
  androidVpn("android-vpn"),
  androidApps("android-apps"),
  windowsVpn("windows-vpn"),
  outboundInterface("outbound-interface"),
  routingData("routing-data"),
  routingDataFile("routing-data-file"),
  overview("overview"),
  nodeInfo("node-info"),
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
  // Legacy route segment retained for navigation compatibility.
  xrayMultiNodeOutbound("xray-full-config"),
  xrayProfileSimple("xray-profile-simple"),
  xrayProfileUI("xray-profile-ui"),
  outboundUI("outbound-ui"),
  xrayRaw("xray-raw"),
  xrayRawEdit("xray-raw-edit"),
  geoData("geo-data"),
  geoDatAdd("geo-data-add"),
  geoDatSelect("geo-data-select"),
  geoDatShow("geo-data-show"),
  ping("ping"),
  logFile("log-file"),
  configFileViewer("config-file-viewer"),
  generalSettings("general-settings"),
  autoUpdate("auto-update"),
  desktopSettings("desktop-settings"),
  backup("backup"),
  appIcon("app-icon"),
  theme("theme"),
  language("language"),
  aboutOneXray("about-onexray"),
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

  Future<T?> pushAppUpdateDialog<T>(AppUpdateInfo updateInfo) {
    return push<T>(
      AppDialogRoutePath.appUpdate,
      extra: AppUpdateDialogParams(updateInfo: updateInfo),
    );
  }
}
