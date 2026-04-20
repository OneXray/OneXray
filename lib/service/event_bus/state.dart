import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/network/model.dart';
import 'package:onexray/core/network/standard.dart';
import 'package:onexray/service/event_bus/enum.dart';

class AppEventBusState {
  final int xraySettingId;
  final bool vpnLoading;
  final int runningId;
  final bool pinging;
  final GeoLocation location;
  final int locationVersion;
  final bool downloading;
  final bool windowClosed;
  final ThemeCode themeCode;
  final LanguageCode languageCode;

  const AppEventBusState({
    required this.xraySettingId,
    required this.vpnLoading,
    required this.runningId,
    required this.pinging,
    required this.location,
    this.locationVersion = 0,
    required this.downloading,
    required this.windowClosed,
    required this.themeCode,
    required this.languageCode,
  });

  factory AppEventBusState.initial() => AppEventBusState(
        xraySettingId: DBConstants.defaultId,
        vpnLoading: false,
        runningId: DBConstants.defaultId,
        pinging: false,
        location: GeoLocationStandard.standard,
        downloading: false,
        windowClosed: false,
        themeCode: ThemeCode.system,
        languageCode: LanguageCode.en,
      );

  AppEventBusState copyWith({
    int? xraySettingId,
    bool? vpnLoading,
    int? runningId,
    bool? pinging,
    GeoLocation? location,
    int? locationVersion,
    bool? downloading,
    bool? windowClosed,
    ThemeCode? themeCode,
    LanguageCode? languageCode,
  }) {
    return AppEventBusState(
      xraySettingId: xraySettingId ?? this.xraySettingId,
      vpnLoading: vpnLoading ?? this.vpnLoading,
      runningId: runningId ?? this.runningId,
      pinging: pinging ?? this.pinging,
      location: location ?? this.location,
      locationVersion: locationVersion ?? this.locationVersion,
      downloading: downloading ?? this.downloading,
      windowClosed: windowClosed ?? this.windowClosed,
      themeCode: themeCode ?? this.themeCode,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
