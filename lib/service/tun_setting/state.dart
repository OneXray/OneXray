import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/model/tun_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/tun_setting/enum.dart';
import 'package:onexray/service/tun_setting/interface.dart';
import 'package:onexray/service/tun_setting/standart.dart';
import 'package:onexray/core/tools/platform.dart';

class TunSettingState {
  // linux, windows
  final tunName = "OneXrayTun";
  var tunPriority = "20";
  var tunDnsIPv4 = "8.8.8.8";
  var tunDnsIPv6 = "2001:4860:4860::8888";
  var enableDot = false;
  var dnsServerName = "dns.google";
  var enableIPv6 = false;

  var bindInterface = "";

  var onDemandEnabled = false;
  var disconnectOnSleep = false;
  var onDemandRules = <OnDemandRuleState>[];
  var perAppVPNMode = PerAppVPNMode.allow;
  var allowAppList = <String>{};
  var disallowAppList = <String>{};

  Future<void> readFromPreferences() async {
    final jsonMap = await PreferencesKey().readTunSetting();
    if (!EmptyTool.checkMap(jsonMap)) {
      return;
    }
    final tunJson = TunJson.fromJson(jsonMap!);
    if (tunJson.tunPriority != null) {
      tunPriority = "${tunJson.tunPriority!}";
    }
    if (EmptyTool.checkString(tunJson.tunDnsIPv4)) {
      tunDnsIPv4 = tunJson.tunDnsIPv4!;
    }
    if (EmptyTool.checkString(tunJson.tunDnsIPv6)) {
      tunDnsIPv6 = tunJson.tunDnsIPv6!;
    }
    if (tunJson.enableDot != null) {
      enableDot = tunJson.enableDot!;
    }
    if (EmptyTool.checkString(tunJson.dnsServerName)) {
      dnsServerName = tunJson.dnsServerName!;
    }
    if (tunJson.enableIPv6 != null) {
      enableIPv6 = tunJson.enableIPv6!;
    }

    if (EmptyTool.checkString(tunJson.bindInterface)) {
      bindInterface = tunJson.bindInterface!;
    }

    if (tunJson.onDemandEnabled != null) {
      onDemandEnabled = tunJson.onDemandEnabled!;
    }
    if (tunJson.disconnectOnSleep != null) {
      disconnectOnSleep = tunJson.disconnectOnSleep!;
    }
    if (EmptyTool.checkList(tunJson.onDemandRules)) {
      final rules = OnDemandRuleState.readFromJsonList(tunJson.onDemandRules!);
      onDemandRules.addAll(rules);
    }

    if (tunJson.perAppVPNMode != null) {
      final perAppVPNMode = PerAppVPNMode.fromString(tunJson.perAppVPNMode!);
      if (perAppVPNMode != null) {
        this.perAppVPNMode = perAppVPNMode;
      }
    }
    if (EmptyTool.checkList(tunJson.allowAppList)) {
      allowAppList.addAll(tunJson.allowAppList!);
    }
    if (EmptyTool.checkList(tunJson.disallowAppList)) {
      disallowAppList.addAll(tunJson.disallowAppList!);
    }
  }

  Future<void> saveToPreferences() async {
    await PreferencesKey().saveTunSetting(tunJson.toJson());
  }

  TunJson get tunJson {
    final tunJson = TunJsonStandard.standard;
    tunJson.tunName = tunName;
    if (tunPriority.isNotEmpty) {
      tunJson.tunPriority = int.tryParse(tunPriority);
    }
    tunJson.tunDnsIPv4 = tunDnsIPv4;
    tunJson.tunDnsIPv6 = tunDnsIPv6;
    tunJson.enableDot = enableDot;
    tunJson.dnsServerName = dnsServerName;
    tunJson.enableIPv6 = enableIPv6;

    tunJson.bindInterface = bindInterface;

    tunJson.onDemandEnabled = onDemandEnabled;
    tunJson.disconnectOnSleep = disconnectOnSleep;
    tunJson.onDemandRules = onDemandRules.map((e) => e.tunJson).toList();

    tunJson.perAppVPNMode = perAppVPNMode.name;
    tunJson.allowAppList = allowAppList.toList();
    tunJson.disallowAppList = disallowAppList.toList();

    return tunJson;
  }

  bool get shouldFixInterface {
    return AppPlatform.isLinux || AppPlatform.isWindows;
  }

  Future<String?> get networkInterface async {
    if (bindInterface.isNotEmpty) {
      return bindInterface;
    }
    final interfaces = await queryInterfaceList();
    if (interfaces.isNotEmpty) {
      return interfaces.first.name;
    }
    return null;
  }
}

class OnDemandRuleState {
  var mode = OnDemandRuleMode.connect;
  var interfaceType = OnDemandRuleInterfaceType.any;
  var ssid = <String>{};

  static List<OnDemandRuleState> readFromJsonList(List<OnDemandRule> rules) {
    final states = <OnDemandRuleState>[];
    for (final rule in rules) {
      final state = OnDemandRuleState();
      state.readFromJson(rule);
      states.add(state);
    }
    return states;
  }

  void readFromJson(OnDemandRule rule) {
    if (rule.mode != null) {
      final mode = OnDemandRuleMode.fromString(rule.mode!);
      if (mode != null) {
        this.mode = mode;
      }
    }
    if (rule.interfaceType != null) {
      final interfaceType = OnDemandRuleInterfaceType.fromString(
        rule.interfaceType!,
      );
      if (interfaceType != null) {
        this.interfaceType = interfaceType;
      }
    }
    if (EmptyTool.checkList(rule.ssid)) {
      ssid.addAll(rule.ssid!);
    }
  }

  OnDemandRule get tunJson {
    final rule = OnDemandRuleStandard.standard;
    rule.mode = mode.name;
    rule.interfaceType = interfaceType.name;
    if (interfaceType == OnDemandRuleInterfaceType.wifi) {
      if (ssid.isNotEmpty) {
        rule.ssid = ssid.toList();
      }
    }

    return rule;
  }
}
