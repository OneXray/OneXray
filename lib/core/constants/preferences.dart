import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/model/core_routing_mode.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesKey {
  final _prefs = SharedPreferencesAsync();
  // New product settings deliberately do not inherit the retired UI's choices.
  // System VPN authorization is maintained by the platform, not these keys.
  static const _namespace = 'app2.';
  static const _defaultXrayProfileId = -1;

  static final PreferencesKey _singleton = PreferencesKey._internal();

  factory PreferencesKey() => _singleton;

  PreferencesKey._internal();

  static const _privacyAccepted = "${_namespace}privacyAccepted";

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

  static const _firstRun = "${_namespace}firstRun";

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

  static const _localSubscriptionExpanded =
      "${_namespace}localSubscriptionExpanded";

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

  static const _runningConfigId = "${_namespace}runningConfigId";

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

  static const _lastConfigId = "${_namespace}lastConfigId";

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

  static const _vpnStartTimestamp = "${_namespace}vpnStartTimestamp";

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

  static const _appUpdateLastCheckTimestamp =
      "${_namespace}appUpdateLastCheckTimestamp";

  Future<DateTime?> readAppUpdateLastCheckTimestamp() async {
    final value = await _prefs.getInt(_appUpdateLastCheckTimestamp);
    if (value == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }

  Future<void> saveAppUpdateLastCheckTimestamp(DateTime date) async {
    final timestamp = date.millisecondsSinceEpoch ~/ 1000;
    await _prefs.setInt(_appUpdateLastCheckTimestamp, timestamp);
  }

  static const _appUpdateSkippedVersion =
      "${_namespace}appUpdateSkippedVersion";

  Future<String?> readAppUpdateSkippedVersion() async {
    return _prefs.getString(_appUpdateSkippedVersion);
  }

  Future<void> saveAppUpdateSkippedVersion(String value) async {
    await _prefs.setString(_appUpdateSkippedVersion, value);
  }

  static const _pingState = "${_namespace}pingState";

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

  static const _xrayProfileId = "${_namespace}xraySettingId";

  Future<int> readXrayProfileId() async {
    final value = await _prefs.getInt(_xrayProfileId);
    if (value == null) {
      return _defaultXrayProfileId;
    }
    if (value == DBConstants.defaultId) {
      return _defaultXrayProfileId;
    }
    return value;
  }

  Future<void> saveXrayProfileId(int value) async {
    final nextValue = value == DBConstants.defaultId
        ? _defaultXrayProfileId
        : value;
    await _prefs.setInt(_xrayProfileId, nextValue);
  }

  static const _coreRoutingMode = "${_namespace}coreRoutingMode";

  Future<CoreRoutingMode> readCoreRoutingMode() async {
    final value = await _prefs.getString(_coreRoutingMode);
    return CoreRoutingMode.fromString(value);
  }

  Future<void> saveCoreRoutingMode(CoreRoutingMode value) async {
    await _prefs.setString(_coreRoutingMode, value.name);
  }

  static const _xrayProfileSimple = "${_namespace}xraySettingSimple";

  Future<Map<String, dynamic>?> readXrayProfileSimple() async {
    final value = await _prefs.getString(_xrayProfileSimple);
    if (value != null) {
      return JsonTool.decodeBase64ToJson(value);
    }
    return null;
  }

  Future<void> saveXrayProfileSimple(Map<String, dynamic> value) async {
    final text = JsonTool.encodeJsonToBase64(value);
    await _prefs.setString(_xrayProfileSimple, text);
  }

  static const _tunSettings = "${_namespace}tunSetting";

  Future<Map<String, dynamic>?> readTunSettings() async {
    final value = await _prefs.getString(_tunSettings);
    if (value != null) {
      return JsonTool.decodeBase64ToJson(value);
    }
    return null;
  }

  Future<void> saveTunSettings(Map<String, dynamic> value) async {
    final text = JsonTool.encodeJsonToBase64(value);
    await _prefs.setString(_tunSettings, text);
  }

  static const _queryAllPackagesAccepted =
      "${_namespace}queryAllPackagesAccepted";

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

  static const _hideDockIcon = "${_namespace}hideIconInDock";

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

  static const _desktopStartHidden = "${_namespace}desktopStartHidden";

  Future<bool> readDesktopStartHidden() async {
    return await _prefs.getBool(_desktopStartHidden) ?? false;
  }

  Future<void> saveDesktopStartHidden(bool value) async {
    await _prefs.setBool(_desktopStartHidden, value);
  }

  static const _connectOnAppLaunch = "${_namespace}connectOnAppLaunch";

  Future<bool> readConnectOnAppLaunch() async {
    return await _prefs.getBool(_connectOnAppLaunch) ?? false;
  }

  Future<void> saveConnectOnAppLaunch(bool value) async {
    await _prefs.setBool(_connectOnAppLaunch, value);
  }

  static const _downloadUserAgentMode = "${_namespace}downloadUserAgentMode";

  Future<DownloadUserAgentMode> readDownloadUserAgentMode() async {
    final value = await _prefs.getString(_downloadUserAgentMode);
    return DownloadUserAgentMode.fromString(value);
  }

  Future<void> saveDownloadUserAgentMode(DownloadUserAgentMode value) async {
    await _prefs.setString(_downloadUserAgentMode, value.name);
  }

  static const _autoUpdate = "${_namespace}autoUpdate";

  Future<Map<String, dynamic>?> readAutoUpdate() async {
    final value = await _prefs.getString(_autoUpdate);
    if (value != null) {
      return JsonTool.decodeBase64ToJson(value);
    }
    return null;
  }

  Future<void> saveAutoUpdate(Map<String, dynamic> value) async {
    final text = JsonTool.encodeJsonToBase64(value);
    await _prefs.setString(_autoUpdate, text);
  }

  static const _themeCode = "${_namespace}themeCode";

  Future<String?> readThemeCode() async {
    return _prefs.getString(_themeCode);
  }

  Future<void> saveThemeCode(String value) async {
    await _prefs.setString(_themeCode, value);
  }

  static const _languageCode = "${_namespace}languageCode";

  Future<String?> readLanguageCode() async {
    return _prefs.getString(_languageCode);
  }

  Future<void> saveLanguageCode(String value) async {
    await _prefs.setString(_languageCode, value);
  }

  Future<void> clearUserDataPreferences() async {
    await Future.wait([
      _prefs.remove(_localSubscriptionExpanded),
      _prefs.remove(_runningConfigId),
      _prefs.remove(_lastConfigId),
      _prefs.remove(_vpnStartTimestamp),
      _prefs.remove(_appUpdateLastCheckTimestamp),
      _prefs.remove(_appUpdateSkippedVersion),
      _prefs.remove(_pingState),
      _prefs.remove(_autoUpdate),
      _prefs.remove(_xrayProfileId),
      _prefs.remove(_desktopStartHidden),
      _prefs.remove(_connectOnAppLaunch),
      _prefs.remove(_downloadUserAgentMode),
    ]);
  }
}
