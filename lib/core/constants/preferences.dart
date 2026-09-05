import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesKey {
  final _prefs = SharedPreferencesAsync();
  // New product settings deliberately do not inherit the retired UI's choices.
  // System VPN authorization is maintained by the platform, not these keys.
  static const _namespace = 'app2.';

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

  static const _setupStep = "${_namespace}setupStep";

  Future<String?> readSetupStep() => _prefs.getString(_setupStep);

  Future<void> saveSetupStep(String value) =>
      _prefs.setString(_setupStep, value);

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
      _prefs.remove('app2.runningConfigId'),
      _prefs.remove('app2.lastConfigId'),
      _prefs.remove('app2.vpnStartTimestamp'),
      _prefs.remove(_appUpdateLastCheckTimestamp),
      _prefs.remove(_appUpdateSkippedVersion),
      _prefs.remove(_pingState),
      _prefs.remove(_autoUpdate),
      _prefs.remove('app2.xraySettingId'),
      _prefs.remove(_desktopStartHidden),
      _prefs.remove(_connectOnAppLaunch),
      _prefs.remove(_downloadUserAgentMode),
    ]);
  }
}
