import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/manager.dart';

class AppEventBus extends Cubit<AppEventBusState> {
  static late AppEventBus instance;

  bool _closing = false;

  bool get _isActive => !_closing && !isClosed;

  AppEventBus() : super(AppEventBusState.initial()) {
    instance = this;
  }

  Future<void> asyncInitTheme() async {
    final themeCode = await PreferencesKey().readThemeCode();
    final languageCode = await PreferencesKey().readLanguageCode();
    if (!_isActive) {
      return;
    }
    emit(
      state.copyWith(
        themeCode: ThemeCode.fromString(themeCode),
        languageCode: LanguageCode.fromString(languageCode),
      ),
    );
  }

  void updatePinging(bool value) {
    emit(state.copyWith(pinging: value));
  }

  void updateDownloading(bool value) {
    emit(state.copyWith(downloading: value));
  }

  void updateAppUpdateInfo(AppUpdateInfo? value) {
    emit(
      value == null
          ? state.copyWith(clearAppUpdateInfo: true)
          : state.copyWith(appUpdateInfo: value),
    );
  }

  Future<void> updateThemeCode(ThemeCode value) async {
    await PreferencesKey().saveThemeCode(value.name);
    if (!_isActive) {
      return;
    }
    emit(state.copyWith(themeCode: value));
  }

  Future<void> updateLanguageCode(LanguageCode value) async {
    await PreferencesKey().saveLanguageCode(value.name);
    if (!_isActive) {
      return;
    }
    emit(state.copyWith(languageCode: value));
  }

  @override
  void emit(AppEventBusState state) {
    if (!_isActive) {
      return;
    }
    super.emit(state);
  }

  @override
  Future<void> close() {
    if (_closing || isClosed) {
      return Future.value();
    }
    _closing = true;
    ServiceManager.serviceDispose();
    return super.close();
  }
}
