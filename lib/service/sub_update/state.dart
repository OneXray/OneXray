import 'package:collection/collection.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/model/sub_update_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/localizations/service.dart';

enum SubUpdateInterval {
  oneDay(24),
  threeDays(72),
  oneWeek(168);

  const SubUpdateInterval(this.value);

  final int value;

  static SubUpdateInterval fromInt(
    int value, {
    SubUpdateInterval fallback = SubUpdateInterval.oneDay,
  }) {
    final interval = SubUpdateInterval.values.firstWhereOrNull(
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
      case SubUpdateInterval.oneDay:
        return appLocalizationsNoContext().subUpdatePageIntervalOneDay;
      case SubUpdateInterval.threeDays:
        return appLocalizationsNoContext().subUpdatePageIntervalThreeDays;
      case SubUpdateInterval.oneWeek:
        return appLocalizationsNoContext().subUpdatePageIntervalOneWeek;
    }
  }
}

class SubUpdateState {
  var enable = false;
  var interval = SubUpdateInterval.oneDay;
  var autoPing = false;
  var geoDataEnable = true;
  var geoDataInterval = SubUpdateInterval.oneWeek;

  Future<void> readFromPreferences() async {
    final jsonMap = await PreferencesKey().readSubUpdate();
    if (!EmptyTool.checkMap(jsonMap)) {
      return;
    }
    final subUpdateJson = SubUpdateJson.fromJson(jsonMap!);
    if (subUpdateJson.enabled != null) {
      enable = subUpdateJson.enabled!;
    }
    if (subUpdateJson.interval != null) {
      interval = SubUpdateInterval.fromInt(subUpdateJson.interval!);
    }
    if (subUpdateJson.autoPing != null) {
      autoPing = subUpdateJson.autoPing!;
    }
    if (subUpdateJson.geoDataEnabled != null) {
      geoDataEnable = subUpdateJson.geoDataEnabled!;
    }
    if (subUpdateJson.geoDataInterval != null) {
      geoDataInterval = SubUpdateInterval.fromInt(
        subUpdateJson.geoDataInterval!,
        fallback: SubUpdateInterval.oneWeek,
      );
    }
  }

  Future<void> saveToPreferences() async {
    final subUpdateJson = SubUpdateJson(
      enable,
      interval.value,
      autoPing,
      geoDataEnable,
      geoDataInterval.value,
    );
    await PreferencesKey().saveSubUpdate(subUpdateJson.toJson());
  }
}
