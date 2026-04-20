import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/firebase_options.dart';
import 'package:onexray/pages/main/router.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initBridge();
  await _initFirebase();

  if (AppPlatform.isDesktop) {
    await windowManager.ensureInitialized();

    const windowSize = Size(400, 600);
    // mac store
    // const windowSize = Size(1168, 688);
    WindowOptions windowOptions = WindowOptions(
      size: windowSize,
      minimumSize: windowSize,
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

Future<void> _initFirebase() async {
  if (AppPlatform.isWindows || AppPlatform.isLinux) {
    return;
  }
  FirebaseOptions? options;
  if (AppPlatform.isMacOS) {
    final useSystemExtension = await AppHostApi().useSystemExtension();
    if (useSystemExtension) {
      options = DefaultFirebaseOptions.macosSE;
    } else {
      options = DefaultFirebaseOptions.currentPlatform;
    }
  } else {
    options = DefaultFirebaseOptions.currentPlatform;
  }
  await Firebase.initializeApp(options: options);
  if (kReleaseMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }
}
