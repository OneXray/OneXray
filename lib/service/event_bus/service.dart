import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/network/model.dart';
import 'package:onexray/core/network/standard.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/manager.dart';
import 'package:onexray/service/xray/metrics/state.dart';

class AppEventBus extends Cubit<AppEventBusState> {
  static late AppEventBus instance;

  AppEventBus() : super(AppEventBusState.initial()) {
    instance = this;
  }

  Future<void> asyncInitTheme() async {
    final themeCode = await PreferencesKey().readThemeCode();
    final languageCode = await PreferencesKey().readLanguageCode();
    emit(
      state.copyWith(
        themeCode: ThemeCode.fromString(themeCode),
        languageCode: LanguageCode.fromString(languageCode),
      ),
    );
  }

  Future<void> asyncInitService(BuildContext context) async {
    await asyncInitState();
    if (context.mounted) {
      await ServiceManager.serviceInit(context);
    }
  }

  Future<void> asyncInitState() async {
    final xraySettingId = await PreferencesKey().readXraySettingId();
    final coreRunMode = await PreferencesKey().readCoreRunMode();
    final runningId = await PreferencesKey().readRunningConfigId();
    emit(
      state.copyWith(
        xraySettingId: xraySettingId,
        coreRunMode: coreRunMode,
        runningId: runningId,
      ),
    );
  }

  void updateXraySettingId(int value) {
    emit(state.copyWith(xraySettingId: value));
  }

  void updateCoreRunMode(CoreRunMode value) {
    emit(state.copyWith(coreRunMode: value));
  }

  void updateVpnActionState(VpnActionState value) {
    emit(
      state.copyWith(
        vpnActionState: value,
        vpnLoading:
            value == VpnActionState.preparing ||
            value == VpnActionState.connecting ||
            value == VpnActionState.disconnecting,
      ),
    );
  }

  void updateRunningId(int value) {
    emit(state.copyWith(runningId: value));
  }

  void updatePendingConfigId(int value) {
    emit(state.copyWith(pendingConfigId: value));
  }

  void updatePlatformPermission(PlatformPermissionResult value) {
    emit(
      state.copyWith(
        platformPermissionKind: value.kind,
        platformPermissionState: value.state,
      ),
    );
  }

  void updateVpnErrorMessage(String value) {
    emit(state.copyWith(vpnErrorMessage: value));
  }

  void updatePinging(bool value) {
    emit(state.copyWith(pinging: value));
  }

  void updateLocation(GeoLocation value) {
    emit(state.copyWith(location: value));
  }

  void startConnectivityProbe() {
    final location = state.location;
    emit(
      state.copyWith(
        location: GeoLocation(
          null,
          null,
          null,
          null,
          null,
          null,
          location.duration,
        ),
        locationVersion: state.locationVersion + 1,
        pingProbeState: ConnectivityProbeState.loading,
        geoLocationProbeState: ConnectivityProbeState.loading,
      ),
    );
  }

  void updateLocationDelay(int delay) {
    final location = state.location;
    emit(
      state.copyWith(
        location: GeoLocation(
          location.country,
          location.city,
          location.region,
          location.ipAddress,
          location.ipVersion,
          delay,
          location.duration,
        ),
        locationVersion: state.locationVersion + 1,
        pingProbeState: ConnectivityProbeState.success,
      ),
    );
  }

  void updateLocationPingFailed() {
    final location = state.location;
    emit(
      state.copyWith(
        location: GeoLocation(
          location.country,
          location.city,
          location.region,
          location.ipAddress,
          location.ipVersion,
          null,
          location.duration,
        ),
        locationVersion: state.locationVersion + 1,
        pingProbeState: ConnectivityProbeState.failed,
      ),
    );
  }

  void updateGeoLocation(GeoLocation value) {
    final location = state.location;
    emit(
      state.copyWith(
        location: GeoLocation(
          value.country,
          value.city,
          value.region,
          value.ipAddress,
          value.ipVersion,
          location.delay,
          location.duration,
        ),
        locationVersion: state.locationVersion + 1,
        geoLocationProbeState: ConnectivityProbeState.success,
      ),
    );
  }

  void updateGeoLocationFailed() {
    final location = state.location;
    emit(
      state.copyWith(
        location: GeoLocation(
          null,
          null,
          null,
          null,
          null,
          location.delay,
          location.duration,
        ),
        locationVersion: state.locationVersion + 1,
        geoLocationProbeState: ConnectivityProbeState.failed,
      ),
    );
  }

  void resetConnectivityProbe() {
    emit(
      state.copyWith(
        location: GeoLocationStandard.standard,
        locationVersion: state.locationVersion + 1,
        pingProbeState: ConnectivityProbeState.idle,
        geoLocationProbeState: ConnectivityProbeState.idle,
      ),
    );
  }

  void updateTrafficMetrics(TrafficMetricsState value) {
    emit(state.copyWith(trafficMetrics: value));
  }

  void resetTrafficMetrics() {
    emit(
      state.copyWith(trafficMetrics: const TrafficMetricsState.unavailable()),
    );
  }

  void updateLocationDuration(String duration) {
    final loc = state.location;
    emit(
      state.copyWith(
        location: GeoLocation(
          loc.country,
          loc.city,
          loc.region,
          loc.ipAddress,
          loc.ipVersion,
          loc.delay,
          duration,
        ),
        locationVersion: state.locationVersion + 1,
      ),
    );
  }

  void updateDownloading(bool value) {
    emit(state.copyWith(downloading: value));
  }

  Future<void> updateThemeCode(ThemeCode value) async {
    await PreferencesKey().saveThemeCode(value.name);
    emit(state.copyWith(themeCode: value));
  }

  Future<void> updateLanguageCode(LanguageCode value) async {
    await PreferencesKey().saveLanguageCode(value.name);
    emit(state.copyWith(languageCode: value));
  }

  @override
  Future<void> close() {
    ServiceManager.serviceDispose();
    return super.close();
  }
}
