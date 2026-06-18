import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/network/model.dart';
import 'package:onexray/core/network/standard.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/event_bus/enum.dart';

enum VpnActionState {
  idle,
  preparing,
  waitingForPlatformPermission,
  connecting,
  connected,
  disconnecting,
  failed,
}

enum ConnectivityProbeState { idle, loading, success, failed }

class AppEventBusState {
  final int xraySettingId;
  final bool vpnLoading;
  final int runningId;
  final int pendingConfigId;
  final VpnActionState vpnActionState;
  final PlatformPermissionKind platformPermissionKind;
  final PlatformPermissionState platformPermissionState;
  final String vpnErrorMessage;
  final bool pinging;
  final GeoLocation location;
  final int locationVersion;
  final ConnectivityProbeState pingProbeState;
  final ConnectivityProbeState geoLocationProbeState;
  final bool downloading;
  final bool windowClosed;
  final ThemeCode themeCode;
  final LanguageCode languageCode;

  const AppEventBusState({
    required this.xraySettingId,
    required this.vpnLoading,
    required this.runningId,
    required this.pendingConfigId,
    required this.vpnActionState,
    required this.platformPermissionKind,
    required this.platformPermissionState,
    required this.vpnErrorMessage,
    required this.pinging,
    required this.location,
    this.locationVersion = 0,
    required this.pingProbeState,
    required this.geoLocationProbeState,
    required this.downloading,
    required this.windowClosed,
    required this.themeCode,
    required this.languageCode,
  });

  factory AppEventBusState.initial() => AppEventBusState(
    xraySettingId: DBConstants.defaultId,
    vpnLoading: false,
    runningId: DBConstants.defaultId,
    pendingConfigId: DBConstants.defaultId,
    vpnActionState: VpnActionState.idle,
    platformPermissionKind: PlatformPermissionKind.none,
    platformPermissionState: PlatformPermissionState.notRequired,
    vpnErrorMessage: "",
    pinging: false,
    location: GeoLocationStandard.standard,
    pingProbeState: ConnectivityProbeState.idle,
    geoLocationProbeState: ConnectivityProbeState.idle,
    downloading: false,
    windowClosed: false,
    themeCode: ThemeCode.system,
    languageCode: LanguageCode.en,
  );

  AppEventBusState copyWith({
    int? xraySettingId,
    bool? vpnLoading,
    int? runningId,
    int? pendingConfigId,
    VpnActionState? vpnActionState,
    PlatformPermissionKind? platformPermissionKind,
    PlatformPermissionState? platformPermissionState,
    String? vpnErrorMessage,
    bool? pinging,
    GeoLocation? location,
    int? locationVersion,
    ConnectivityProbeState? pingProbeState,
    ConnectivityProbeState? geoLocationProbeState,
    bool? downloading,
    bool? windowClosed,
    ThemeCode? themeCode,
    LanguageCode? languageCode,
  }) {
    return AppEventBusState(
      xraySettingId: xraySettingId ?? this.xraySettingId,
      vpnLoading: vpnLoading ?? this.vpnLoading,
      runningId: runningId ?? this.runningId,
      pendingConfigId: pendingConfigId ?? this.pendingConfigId,
      vpnActionState: vpnActionState ?? this.vpnActionState,
      platformPermissionKind:
          platformPermissionKind ?? this.platformPermissionKind,
      platformPermissionState:
          platformPermissionState ?? this.platformPermissionState,
      vpnErrorMessage: vpnErrorMessage ?? this.vpnErrorMessage,
      pinging: pinging ?? this.pinging,
      location: location ?? this.location,
      locationVersion: locationVersion ?? this.locationVersion,
      pingProbeState: pingProbeState ?? this.pingProbeState,
      geoLocationProbeState:
          geoLocationProbeState ?? this.geoLocationProbeState,
      downloading: downloading ?? this.downloading,
      windowClosed: windowClosed ?? this.windowClosed,
      themeCode: themeCode ?? this.themeCode,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
