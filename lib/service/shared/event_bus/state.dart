import 'package:onexray/service/settings/app_update/service.dart';
import 'package:onexray/service/shared/event_bus/enum.dart';
import 'package:onexray/service/shared/ping/batch.dart';

class AppEventBusState {
  /// Includes queued and automatic node probes, not just page-owned tests.
  final bool pinging;

  /// True while any subscription, Geodata or App update download is running.
  final bool downloading;
  final AppUpdateInfo? appUpdateInfo;
  final ThemeCode themeCode;
  final LanguageCode languageCode;

  /// Latest failed probe per node, in memory only; a successful retry clears it.
  final Map<int, PingBatchResult> pingFailures;

  const AppEventBusState({
    required this.pinging,
    required this.downloading,
    required this.appUpdateInfo,
    required this.themeCode,
    required this.languageCode,
    this.pingFailures = const {},
  });

  factory AppEventBusState.initial() => const AppEventBusState(
    pinging: false,
    downloading: false,
    appUpdateInfo: null,
    themeCode: ThemeCode.system,
    languageCode: LanguageCode.system,
  );

  AppEventBusState copyWith({
    bool? pinging,
    bool? downloading,
    AppUpdateInfo? appUpdateInfo,
    bool clearAppUpdateInfo = false,
    ThemeCode? themeCode,
    LanguageCode? languageCode,
    Map<int, PingBatchResult>? pingFailures,
  }) {
    return AppEventBusState(
      pinging: pinging ?? this.pinging,
      downloading: downloading ?? this.downloading,
      appUpdateInfo: clearAppUpdateInfo
          ? null
          : appUpdateInfo ?? this.appUpdateInfo,
      themeCode: themeCode ?? this.themeCode,
      languageCode: languageCode ?? this.languageCode,
      pingFailures: pingFailures ?? this.pingFailures,
    );
  }
}
