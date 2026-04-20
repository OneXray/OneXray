import 'package:json_annotation/json_annotation.dart';

part 'tun_json.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class TunJson {
  // all
  String? tunDnsIPv4;
  String? tunDnsIPv6;
  // apple
  bool? enableDot;
  String? dnsServerName;
  // all
  bool? enableIPv6;
  // linux, windows
  String? tunName;
  // linux
  int? tunPriority;
  // linux, windows
  String? bindInterface;

  // apple
  bool? onDemandEnabled;
  bool? disconnectOnSleep;
  List<OnDemandRule>? onDemandRules;
  // android
  String? perAppVPNMode;
  List<String>? allowAppList;
  List<String>? disallowAppList;

  TunJson(
    this.tunDnsIPv4,
    this.tunDnsIPv6,
    this.enableDot,
    this.dnsServerName,
    this.enableIPv6,
    this.tunName,
    this.tunPriority,
    this.bindInterface,
    this.onDemandEnabled,
    this.disconnectOnSleep,
    this.onDemandRules,
    this.perAppVPNMode,
    this.allowAppList,
    this.disallowAppList,
  );

  factory TunJson.fromJson(Map<String, dynamic> json) =>
      _$TunJsonFromJson(json);

  Map<String, dynamic> toJson() => _$TunJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class OnDemandRule {
  String? mode;
  String? interfaceType;
  List<String>? ssid;

  OnDemandRule(this.mode, this.interfaceType, this.ssid);

  factory OnDemandRule.fromJson(Map<String, dynamic> json) =>
      _$OnDemandRuleFromJson(json);

  Map<String, dynamic> toJson() => _$OnDemandRuleToJson(this);
}
