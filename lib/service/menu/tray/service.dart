import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:collection/collection.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:window_manager/window_manager.dart';

final class TrayService with TrayListener {
  static final TrayService _singleton = TrayService._internal();

  factory TrayService() => _singleton;

  TrayService._internal();

  //==========================

  void init() {
    if (!AppPlatform.isDesktop) {
      return;
    }

    trayManager.addListener(this);
  }

  void dispose() {
    if (!AppPlatform.isDesktop) {
      return;
    }
    trayManager.removeListener(this);
  }

  Future<void> refreshTrayManager() async {
    if (!AppPlatform.isDesktop) {
      return;
    }

    var running = VpnService().vpnRunning;

    await _setTrayIcon(running);

    final items = <MenuItem>[];
    if (running) {
      items.add(
        MenuItem(
          key: _TrayMenuKey.stopVpn.name,
          label: appLocalizationsNoContext().menuBarStopVpn,
        ),
      );
    } else {
      items.add(
        MenuItem(
          key: _TrayMenuKey.startVpn.name,
          label: appLocalizationsNoContext().menuBarStartVpn,
        ),
      );
    }
    items.add(MenuItem.separator());
    items.add(
      MenuItem(
        key: _TrayMenuKey.showApp.name,
        label: appLocalizationsNoContext().menuBarShowApp,
      ),
    );
    items.add(
      MenuItem(
        key: _TrayMenuKey.quitApp.name,
        label: appLocalizationsNoContext().menuBarQuitApp,
      ),
    );
    if (AppPlatform.isMacOS) {
      items.add(
        MenuItem(
          key: _TrayMenuKey.quitAndStopVpn.name,
          label: appLocalizationsNoContext().menuBarQuitAndStopVpn,
        ),
      );
    }

    final menu = Menu(items: items);
    await trayManager.setContextMenu(menu);
  }

  Future<void> _setTrayIcon(bool running) async {
    var icon = "";
    if (AppPlatform.isWindows) {
      if (running) {
        icon = Assets.icon.trayRunningIco;
      } else {
        icon = Assets.icon.trayNotRunningIco;
      }
    } else {
      if (running) {
        icon = Assets.icon.trayRunningPng.path;
      } else {
        icon = Assets.icon.trayNotRunningPng.path;
      }
    }
    await trayManager.setIcon(icon);
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
    super.onTrayIconMouseDown();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
    super.onTrayIconRightMouseDown();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == null) {
      return;
    }
    final key = _TrayMenuKey.fromString(menuItem.key!);
    if (key == null) {
      return;
    }

    switch (key) {
      case _TrayMenuKey.startVpn:
        await VpnService().startDefaultVpn();
        break;
      case _TrayMenuKey.stopVpn:
        await VpnService().stopDefaultVpn();
        break;
      case _TrayMenuKey.showApp:
        await windowManager.show();
        await windowManager.focus();
        break;
      case _TrayMenuKey.quitApp:
        if (AppPlatform.isLinux || AppPlatform.isWindows) {
          await VpnService().stopDefaultVpn();
        }
        ServicesBinding.instance.exitApplication(AppExitType.cancelable);
        break;
      case _TrayMenuKey.quitAndStopVpn:
        await VpnService().stopDefaultVpn();
        ServicesBinding.instance.exitApplication(AppExitType.cancelable);
        break;
    }
  }
}

enum _TrayMenuKey {
  startVpn("startVpn"),
  stopVpn("stopVpn"),
  showApp("showApp"),
  quitApp("quitApp"),
  quitAndStopVpn("quitAndStopVpn");

  const _TrayMenuKey(this.name);

  final String name;

  @override
  String toString() => name;

  static _TrayMenuKey? fromString(String name) =>
      _TrayMenuKey.values.firstWhereOrNull((value) => value.name == name);
}
