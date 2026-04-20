import 'package:collection/collection.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/model/sub_update_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/localizations/service.dart';

enum SubUpdateInterval {
  sixHours(6),
  twelveHours(12),
  oneDay(24),
  threeDays(72),
  oneWeek(168);

  const SubUpdateInterval(this.value);

  final int value;

  static SubUpdateInterval fromInt(int value) {
    final interval = SubUpdateInterval.values.firstWhereOrNull(
      (e) => e.value == value,
    );
    if (interval == null) {
      return SubUpdateInterval.oneDay;
    }
    return interval;
  }

  @override
  String toString() {
    switch (this) {
      case SubUpdateInterval.sixHours:
        return appLocalizationsNoContext().subUpdatePageInterval6Hours;
      case SubUpdateInterval.twelveHours:
        return appLocalizationsNoContext().subUpdatePageInterval12Hours;
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
  }

  Future<void> saveToPreferences() async {
    final subUpdateJson = SubUpdateJson(enable, interval.value, autoPing);
    await PreferencesKey().saveSubUpdate(subUpdateJson.toJson());
  }
}
