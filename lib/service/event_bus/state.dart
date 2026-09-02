import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/enum.dart';

class AppEventBusState {
  final bool pinging;
  final bool downloading;
  final AppUpdateInfo? appUpdateInfo;
  final ThemeCode themeCode;
  final LanguageCode languageCode;

  const AppEventBusState({
    required this.pinging,
    required this.downloading,
    required this.appUpdateInfo,
    required this.themeCode,
    required this.languageCode,
  });

  factory AppEventBusState.initial() => const AppEventBusState(
    pinging: false,
    downloading: false,
    appUpdateInfo: null,
    themeCode: ThemeCode.system,
    languageCode: LanguageCode.zh,
  );

  AppEventBusState copyWith({
    bool? pinging,
    bool? downloading,
    AppUpdateInfo? appUpdateInfo,
    bool clearAppUpdateInfo = false,
    ThemeCode? themeCode,
    LanguageCode? languageCode,
  }) {
    return AppEventBusState(
      pinging: pinging ?? this.pinging,
      downloading: downloading ?? this.downloading,
      appUpdateInfo: clearAppUpdateInfo
          ? null
          : appUpdateInfo ?? this.appUpdateInfo,
      themeCode: themeCode ?? this.themeCode,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
