import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/settings/app_update/params.dart';
import 'package:onexray/service/app_update/service.dart';

abstract final class AppDialogRoutePath {
  static const appUpdate = "/app-update";
}

enum AppPrimaryDestination {
  connect("/connect"),
  servers("/servers"),
  advanced("/advanced"),
  settings("/settings");

  final String rootPath;

  const AppPrimaryDestination(this.rootPath);

  static AppPrimaryDestination fromPath(String path) {
    for (final destination in values) {
      if (path == destination.rootPath ||
          path.startsWith("${destination.rootPath}/")) {
        return destination;
      }
    }
    return connect;
  }
}

enum AppSecondaryDestination {
  serversImport("servers-import"),
  serverGroup("server-group"),
  serverEditor("server-editor"),
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
  share("share"),
  subscriptionEdit("subscription-edit"),
  ping("ping"),
  logFile("log-file"),
  configFileViewer("config-file-viewer"),
  autoUpdate("auto-update"),
  desktopSettings("desktop-settings"),
  backup("backup"),
  appIcon("app-icon"),
  theme("theme"),
  language("language"),
  aboutOneXray("about-onexray");

  final String segment;

  const AppSecondaryDestination(this.segment);

  static const dialogs = {serversImport, serverEditor, share, subscriptionEdit};
}

extension AppNavigationContext on BuildContext {
  AppPrimaryDestination get currentPrimaryDestination {
    final path = GoRouterState.of(this).uri.path;
    return AppPrimaryDestination.fromPath(path);
  }

  String scopedPath(AppSecondaryDestination destination) {
    final primary = currentPrimaryDestination;
    return "${primary.rootPath}/${destination.segment}";
  }

  void goPrimary(
    StatefulNavigationShell navigationShell,
    AppPrimaryDestination destination,
  ) {
    final index = AppPrimaryDestination.values.indexOf(destination);
    navigationShell.goBranch(
      index,
      initialLocation: navigationShell.currentIndex == index,
    );
  }

  void goPrimaryRoot(AppPrimaryDestination destination) {
    go(destination.rootPath);
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
