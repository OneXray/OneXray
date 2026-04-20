import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/network/model.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/manager.dart';

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
    await _asyncInitState();
    if (context.mounted) {
      await ServiceManager.serviceInit(context);
    }
  }

  Future<void> _asyncInitState() async {
    final xraySettingId = await PreferencesKey().readXraySettingId();
    final runningId = await PreferencesKey().readRunningConfigId();
    emit(state.copyWith(xraySettingId: xraySettingId, runningId: runningId));
  }

  void updateXraySettingId(int value) {
    emit(state.copyWith(xraySettingId: value));
  }

  void updateVpnLoading(bool value) {
    emit(state.copyWith(vpnLoading: value));
  }

  void updateRunningId(int value) {
    emit(state.copyWith(runningId: value));
  }

  void updatePinging(bool value) {
    emit(state.copyWith(pinging: value));
  }

  void updateLocation(GeoLocation value) {
    emit(state.copyWith(location: value));
  }

  void updateLocationDuration(String duration) {
    final loc = state.location;
    loc.duration = duration;
    emit(
      state.copyWith(location: loc, locationVersion: state.locationVersion + 1),
    );
  }

  void updateDownloading(bool value) {
    emit(state.copyWith(downloading: value));
  }

  void updateWindowClosed(bool value) {
    emit(state.copyWith(windowClosed: value));
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
