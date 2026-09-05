import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/notification/service.dart';
import 'package:collection/collection.dart';
import 'package:onexray/core/tools/platform.dart';

final class ShortCutService {
  static final ShortCutService _singleton = ShortCutService._internal();

  factory ShortCutService() => _singleton;

  ShortCutService._internal();

  //==========================
  final quickActions = const QuickActions();
  VoidCallback? onConnectionFailure;

  Future<void> asyncInit(BuildContext context) async {
    if (!AppPlatform.isMobile) {
      return;
    }
    await quickActions.initialize(_onShortCutClick);
    var playIcon = "play_light";
    var pauseIcon = "pause_light";
    if (context.mounted) {
      if (Theme.of(context).brightness == Brightness.dark) {
        playIcon = "play_dark";
        pauseIcon = "pause_dark";
      }
    }

    await quickActions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: _ShortCutKey.startVpn.name,
        localizedTitle: appLocalizationsNoContext().menuBarStartVpn,
        icon: playIcon,
      ),
      ShortcutItem(
        type: _ShortCutKey.stopVpn.name,
        localizedTitle: appLocalizationsNoContext().menuBarStopVpn,
        icon: pauseIcon,
      ),
    ]);
  }

  void dispose() {
    onConnectionFailure = null;
  }

  Future<void> _onShortCutClick(String action) async {
    final key = _ShortCutKey.fromString(action);
    if (key == null) {
      return;
    }

    try {
      switch (key) {
        case _ShortCutKey.startVpn:
          try {
            await ConnectionCoordinator.instance.connect();
          } catch (_) {
            await NotificationService().pushNotification(
              appLocalizationsNoContext().prototypeConnectionFailed,
            );
            rethrow;
          }
          break;
        case _ShortCutKey.stopVpn:
          await ConnectionCoordinator.instance.disconnect();
          break;
      }
    } catch (_) {
      // The shortcut already opened the App; let its UI show the failed action.
      onConnectionFailure?.call();
    }
  }
}

enum _ShortCutKey {
  startVpn("startVpn"),
  stopVpn("stopVpn");

  const _ShortCutKey(this.name);

  final String name;

  @override
  String toString() => name;

  static _ShortCutKey? fromString(String name) =>
      _ShortCutKey.values.firstWhereOrNull((value) => value.name == name);
}
