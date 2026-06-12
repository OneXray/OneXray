import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/ads/service.dart';
import 'package:onexray/service/analytics/service.dart';
import 'package:onexray/service/automation/service.dart';
import 'package:onexray/service/background_task/service.dart';
import 'package:onexray/service/menu/short_cut/service.dart';
import 'package:onexray/service/menu/tray/service.dart';
import 'package:onexray/service/menu/window/service.dart';
import 'package:onexray/service/notification/service.dart';
import 'package:onexray/service/share/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/vpn/service.dart';

abstract final class ServiceManager {
  static Future<void>? _initFuture;
  static var _initialized = false;

  static Future<void> serviceInit(BuildContext context) {
    if (_initialized) {
      return Future.value();
    }
    final initFuture = _initFuture;
    if (initFuture != null) {
      return initFuture;
    }

    final nextInitFuture = _serviceInit(context);
    _initFuture = nextInitFuture;
    return nextInitFuture;
  }

  static Future<void> _serviceInit(BuildContext context) async {
    unawaited(_initAdsService());
    await _runInit("NetClient", () => NetClient().asyncInit());
    await _runInit("TrayService", () => TrayService().init());
    await _runInit("VpnService", () => VpnService().asyncInit());
    await _runInit("AutomationService", () => AutomationService().asyncInit());
    await _runInit("ShareService", () => ShareService().init());
    await _runInit(
      "NotificationService",
      () => NotificationService().asyncInit(),
    );
    if (context.mounted) {
      await _runInit(
        "ShortCutService",
        () => ShortCutService().asyncInit(context),
      );
    }
    await _runInit("WindowService", () => WindowService().asyncInit());
    await _runInit("AnalyticsService", () => AnalyticsService().init());
    await _runInit("ToastService", () => ToastService().init());
    _initialized = true;
  }

  static Future<void> _initAdsService() async {
    try {
      await AdsService().init();
    } catch (e, stackTrace) {
      ygLogger("ads init error: $e\n$stackTrace");
    }
  }

  static Future<void> _runInit(
    String name,
    FutureOr<void> Function() init,
  ) async {
    try {
      await init();
    } catch (e, stackTrace) {
      ygLogger("$name init error: $e\n$stackTrace");
    }
  }

  static void serviceDispose() {
    _initFuture = null;
    _initialized = false;
    AdsService().dispose();
    AutomationService().dispose();
    TrayService().dispose();
    VpnService().dispose();
    ShareService().dispose();
    NotificationService().dispose();
    ShortCutService().dispose();
    WindowService().dispose();
    AnalyticsService().dispose();
    BackgroundTaskService().dispose();
    ToastService().dispose();
  }
}
