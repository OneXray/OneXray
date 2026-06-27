import 'package:collection/collection.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/model/auto_update_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/localizations/service.dart';

enum AutoUpdateInterval {
  oneDay(24),
  threeDays(72),
  oneWeek(168);

  const AutoUpdateInterval(this.value);

  final int value;

  static AutoUpdateInterval fromInt(
    int value, {
    AutoUpdateInterval fallback = AutoUpdateInterval.threeDays,
  }) {
    final interval = AutoUpdateInterval.values.firstWhereOrNull(
      (e) => e.value == value,
    );
    if (interval == null) {
      return fallback;
    }
    return interval;
  }

  @override
  String toString() {
    switch (this) {
      case AutoUpdateInterval.oneDay:
        return appLocalizationsNoContext().autoUpdatePageIntervalOneDay;
      case AutoUpdateInterval.threeDays:
        return appLocalizationsNoContext().autoUpdatePageIntervalThreeDays;
      case AutoUpdateInterval.oneWeek:
        return appLocalizationsNoContext().autoUpdatePageIntervalOneWeek;
    }
  }
}

class AutoUpdateState {
  var subscriptionEnabled = true;
  var subscriptionInterval = AutoUpdateInterval.threeDays;
  var geoDataEnable = true;
  var geoDataInterval = AutoUpdateInterval.threeDays;
  var geoDataUpdateAfterVpnConnected = true;

  Future<void> readFromPreferences() async {
    final jsonMap = await PreferencesKey().readAutoUpdate();
    if (!EmptyTool.checkMap(jsonMap)) {
      return;
    }
    final autoUpdateJson = AutoUpdateJson.fromJson(jsonMap!);
    if (autoUpdateJson.subscriptionEnabled != null) {
      subscriptionEnabled = autoUpdateJson.subscriptionEnabled!;
    }
    if (autoUpdateJson.subscriptionInterval != null) {
      subscriptionInterval = AutoUpdateInterval.fromInt(
        autoUpdateJson.subscriptionInterval!,
      );
    }
    if (autoUpdateJson.geoDataEnabled != null) {
      geoDataEnable = autoUpdateJson.geoDataEnabled!;
    }
    if (autoUpdateJson.geoDataInterval != null) {
      geoDataInterval = AutoUpdateInterval.fromInt(
        autoUpdateJson.geoDataInterval!,
      );
    }
    if (autoUpdateJson.geoDataUpdateAfterVpnConnected != null) {
      geoDataUpdateAfterVpnConnected =
          autoUpdateJson.geoDataUpdateAfterVpnConnected!;
    }
  }

  Future<void> saveToPreferences() async {
    final autoUpdateJson = AutoUpdateJson(
      subscriptionEnabled,
      subscriptionInterval.value,
      geoDataEnable,
      geoDataInterval.value,
      geoDataUpdateAfterVpnConnected,
    );
    await PreferencesKey().saveAutoUpdate(autoUpdateJson.toJson());
  }
}
