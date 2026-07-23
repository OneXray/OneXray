import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/main/router.dart';
import 'package:window_manager/window_manager.dart';

const _desktopWindowSize = Size(1160, 720);
const _minimumDesktopWindowSize = Size(480, 600);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initBridge();

  if (AppPlatform.isDesktop) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = WindowOptions(
      size: _desktopWindowSize,
      minimumSize: _minimumDesktopWindowSize,
      center: true,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(GoRouteApp());
}

Future<void> _initBridge() async {
  BridgeFlutterApi.setUp(AppFlutterApi());
  await AppHostApi().initTunFilesDir();
}
