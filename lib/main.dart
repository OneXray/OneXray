import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/pages/main/adaptive_shell.dart';
import 'package:onexray/pages/main/router.dart';
import 'package:onexray/service/firebase/service.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await FirebaseService().initializeIfPrivacyAccepted();
    await _initBridge();

    if (AppPlatform.isDesktop) {
      await windowManager.ensureInitialized();

      const windowSize = Size(1200, 800);
      const minimumWindowSize = Size(AdaptiveMainShell.railBreakpoint, 800);
      WindowOptions windowOptions = WindowOptions(
        size: windowSize,
        minimumSize: minimumWindowSize,
        center: true,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    runApp(GoRouteApp());
  }, FirebaseService().reportFatalError);
}

Future<void> _initBridge() async {
  BridgeFlutterApi.setUp(AppFlutterApi());
  await AppHostApi().initTunFilesDir();
}
