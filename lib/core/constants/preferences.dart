import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesKey {
  final _prefs = SharedPreferencesAsync();

  static final PreferencesKey _singleton = PreferencesKey._internal();

  factory PreferencesKey() => _singleton;

  PreferencesKey._internal();

  static const _privacyAccepted = "privacyAccepted02";

  Future<bool> readPrivacyAccepted() async {
    final value = await _prefs.getBool(_privacyAccepted);
    if (value == null) {
      return false;
    }
    return value;
  }

  Future<void> savePrivacyAccepted(bool value) async {
    await _prefs.setBool(_privacyAccepted, value);
  }

  static const _firstRun = "firstRun01";

  Future<bool> readFirstRun() async {
    final value = await _prefs.getBool(_firstRun);
    if (value == null) {
      return true;
    }
    return value;
  }

  Future<void> saveFirstRun(bool value) async {
    await _prefs.setBool(_firstRun, value);
  }

  static const _localSubscriptionExpanded = "localSubscriptionExpanded";

  Future<bool> readLocalSubscriptionExpanded() async {
    final value = await _prefs.getBool(_localSubscriptionExpanded);
    if (value == null) {
      return true;
    }
    return value;
  }

  Future<void> saveLocalSubscriptionExpanded(bool value) async {
    await _prefs.setBool(_localSubscriptionExpanded, value);
  }

  static const _runningConfigId = "runningConfigId";

  Future<int> readRunningConfigId() async {
    final value = await _prefs.getInt(_runningConfigId);
    if (value == null) {
      return DBConstants.defaultId;
    }
    return value;
  }

  Future<void> saveRunningConfigId(int value) async {
    await _prefs.setInt(_runningConfigId, value);
  }

  static const _lastConfigId = "lastConfigId";

  Future<int> readLastConfigId() async {
    final value = await _prefs.getInt(_lastConfigId);
    if (value == null) {
      return DBConstants.defaultId;
    }
    return value;
  }

  Future<void> saveLastConfigId(int value) async {
    await _prefs.setInt(_lastConfigId, value);
  }

  static const _vpnStartTimestamp = "vpnStartTimestamp";

  Future<DateTime> readVpnStartTimestamp() async {
    final value = await _prefs.getInt(_vpnStartTimestamp);
    if (value == null) {
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }

  Future<void> saveVpnStartTimestamp() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _prefs.setInt(_vpnStartTimestamp, timestamp);
  }

  static const _pingState = "pingState";

  Future<Map<String, dynamic>?> readPingState() async {
    final value = await _prefs.getString(_pingState);
    if (value != null) {
      return JsonTool.decodeBase64ToJson(value);
    }
    return null;
  }

  Future<void> savePingState(Map<String, dynamic> value) async {
    final text = JsonTool.encodeJsonToBase64(value);
    await _prefs.setString(_pingState, text);
  }

  static const _xraySettingId = "xraySettingId";

  Future<int> readXraySettingId() async {
    final value = await _prefs.getInt(_xraySettingId);
    if (value == null) {
      return DBConstants.defaultId;
    }
    return value;
  }

  Future<void> saveXraySettingId(int value) async {
    await _prefs.setInt(_xraySettingId, value);
  }

  static const _xraySettingSimple = "xraySettingSimple";

  Future<Map<String, dynamic>?> readXraySettingSimple() async {
    final value = await _prefs.getString(_xraySettingSimple);
    if (value != null) {
      return JsonTool.decodeBase64ToJson(value);
    }
    return null;
  }

  Future<void> saveXraySettingSimple(Map<String, dynamic> value) async {
    final text = JsonTool.encodeJsonToBase64(value);
    await _prefs.setString(_xraySettingSimple, text);
  }

  static const _tunSetting = "tunSetting";

  Future<Map<String, dynamic>?> readTunSetting() async {
    final value = await _prefs.getString(_tunSetting);
    if (value != null) {
      return JsonTool.decodeBase64ToJson(value);
    }
    return null;
  }

  Future<void> saveTunSetting(Map<String, dynamic> value) async {
    final text = JsonTool.encodeJsonToBase64(value);
    await _prefs.setString(_tunSetting, text);
  }

  static const _queryAllPackagesAccepted = "queryAllPackagesAccepted";

  Future<bool> readQueryAllPackagesAccepted() async {
    final value = await _prefs.getBool(_queryAllPackagesAccepted);
    if (value == null) {
      return false;
    }
    return value;
  }

  Future<void> saveQueryAllPackagesAccepted(bool value) async {
    await _prefs.setBool(_queryAllPackagesAccepted, value);
  }

  static const _hideDockIcon = "hideIconInDock";

  Future<bool> readHideDockIcon() async {
    final value = await _prefs.getBool(_hideDockIcon);
    if (value == null) {
      return false;
    }
    return value;
  }

  Future<void> saveHideDockIcon(bool value) async {
    await _prefs.setBool(_hideDockIcon, value);
  }

  static const _subUpdate = "subUpdate";

  Future<Map<String, dynamic>?> readSubUpdate() async {
    final value = await _prefs.getString(_subUpdate);
    if (value != null) {
      return JsonTool.decodeBase64ToJson(value);
    }
    return null;
  }

  Future<void> saveSubUpdate(Map<String, dynamic> value) async {
    final text = JsonTool.encodeJsonToBase64(value);
    await _prefs.setString(_subUpdate, text);
  }

  static const _themeCode = "themeCode";

  Future<String?> readThemeCode() async {
    return _prefs.getString(_themeCode);
  }

  Future<void> saveThemeCode(String value) async {
    await _prefs.setString(_themeCode, value);
  }

  static const _languageCode = "languageCode";

  Future<String?> readLanguageCode() async {
    return _prefs.getString(_languageCode);
  }

  Future<void> saveLanguageCode(String value) async {
    await _prefs.setString(_languageCode, value);
  }
}
