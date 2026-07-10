import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/firebase_options.dart';
import 'package:onexray/pages/main/adaptive_shell.dart';
import 'package:onexray/pages/main/router.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await _initFirebase();
    _installErrorHandlers();
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
  }, _reportUncaughtError);
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
}

void _installErrorHandlers() {
  if (!kReleaseMode || AppPlatform.isWindows || AppPlatform.isLinux) {
    return;
  }
  configureAppErrorReporter((error, stackTrace, reason) {
    return FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: false,
    );
  });
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true),
    );
    return true;
  };
}

void _reportUncaughtError(Object error, StackTrace stackTrace) {
  if (kReleaseMode &&
      !AppPlatform.isWindows &&
      !AppPlatform.isLinux &&
      Firebase.apps.isNotEmpty) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true),
    );
    return;
  }
  ygLogger('uncaught error: $error\n$stackTrace');
}
