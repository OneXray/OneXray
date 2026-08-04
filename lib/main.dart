import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/main/router.dart';
import 'package:onexray/service/app_startup/service.dart';
import 'package:onexray/service/share/service.dart';
import 'package:window_manager/window_manager.dart';

const _desktopWindowSize = Size(1160, 720);
const _minimumDesktopWindowSize = Size(480, 600);

Future<void> main(List<String> _) async {
  WidgetsFlutterBinding.ensureInitialized();

  ShareService().startAppLinks();
  await _initBridge();
  final appStartup = AppStartupService();
  await appStartup.prepare();

  if (AppPlatform.isDesktop) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = WindowOptions(
      size: _desktopWindowSize,
      minimumSize: _minimumDesktopWindowSize,
      center: true,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await appStartup.onWindowReady();
    });
  }

  runApp(GoRouteApp());
}

Future<void> _initBridge() async {
  BridgeFlutterApi.setUp(AppFlutterApi());
  await AppHostApi().initTunFilesDir();
}
