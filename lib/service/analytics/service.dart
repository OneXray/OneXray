import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:onexray/core/tools/platform.dart';

class AnalyticsService {
  static final AnalyticsService _singleton = AnalyticsService._internal();

  factory AnalyticsService() => _singleton;

  AnalyticsService._internal();

  //======================
  FirebaseAnalytics? _analytics;

  void init() {
    if (AppPlatform.isIOS || AppPlatform.isMacOS || AppPlatform.isAndroid) {
      _analytics = FirebaseAnalytics.instance;
    }
  }

  void dispose() {}

  void logEvent(String name) {
    if (AppPlatform.isIOS || AppPlatform.isMacOS || AppPlatform.isAndroid) {
      _analytics?.logEvent(name: name);
    }
  }
}
