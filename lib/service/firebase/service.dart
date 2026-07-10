import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/firebase_options.dart';

final class FirebaseService {
  static final FirebaseService _singleton = FirebaseService._internal();

  factory FirebaseService() => _singleton;

  FirebaseService._internal();

  Future<void>? _initFuture;
  var _initialized = false;

  Future<void> initializeIfPrivacyAccepted() async {
    if (!await PreferencesKey().readPrivacyAccepted()) {
      return;
    }
    await initializeAfterPrivacyAccepted();
  }

  Future<void> initializeAfterPrivacyAccepted() {
    if (_initialized || !_supported) {
      return Future<void>.value();
    }
    final existing = _initFuture;
    if (existing != null) {
      return existing;
    }
    final future = _initializeSafely();
    _initFuture = future;
    return future;
  }

  Future<void> _initializeSafely() async {
    try {
      await _initialize();
      _initialized = true;
    } catch (error, stackTrace) {
      _initFuture = null;
      ygLogger('Firebase initialization failed: $error\n$stackTrace');
    }
  }

  Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) {
      FirebaseOptions options;
      if (AppPlatform.isMacOS && await AppHostApi().useSystemExtension()) {
        options = DefaultFirebaseOptions.macosSE;
      } else {
        options = DefaultFirebaseOptions.currentPlatform;
      }
      await Firebase.initializeApp(options: options);
    }

    final analytics = FirebaseAnalytics.instance;
    if (AppPlatform.isIOS || AppPlatform.isAndroid) {
      await analytics.setConsent(
        analyticsStorageConsentGranted: true,
        adStorageConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
        adUserDataConsentGranted: false,
      );
    }
    await analytics.setAnalyticsCollectionEnabled(true);

    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(true);
    if (kReleaseMode) {
      configureAppErrorReporter((error, stackTrace, reason) {
        return crashlytics.recordError(
          error,
          stackTrace,
          reason: reason,
          fatal: false,
        );
      });
      FlutterError.onError = crashlytics.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        unawaited(crashlytics.recordError(error, stackTrace, fatal: true));
        return true;
      };
    }
  }

  void reportFatalError(Object error, StackTrace stackTrace) {
    if (_initialized && kReleaseMode) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: true,
        ),
      );
      return;
    }
    ygLogger('uncaught error: $error\n$stackTrace');
  }

  Future<void> logEvent(String name) async {
    if (!_initialized) {
      return;
    }
    await FirebaseAnalytics.instance.logEvent(name: name);
  }

  bool get _supported =>
      AppPlatform.isIOS || AppPlatform.isMacOS || AppPlatform.isAndroid;
}
