// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tun_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TunJson _$TunJsonFromJson(Map<String, dynamic> json) => TunJson(
  json['tunDnsIPv4'] as String?,
  json['tunDnsIPv6'] as String?,
  json['enableDot'] as bool?,
  json['dnsServerName'] as String?,
  json['enableIPv6'] as bool?,
  json['metricsEnabled'] as bool?,
  json['tunName'] as String?,
  json['autoOutboundsInterface'] as String?,
  json['includeAllNetworks'] as bool?,
  json['excludeLocalNetworks'] as bool?,
  json['excludeCellularServices'] as bool?,
  json['excludeAPNs'] as bool?,
  json['excludeDeviceCommunication'] as bool?,
  json['onDemandEnabled'] as bool?,
  (json['onDemandRules'] as List<dynamic>?)
      ?.map((e) => OnDemandRule.fromJson(e as Map<String, dynamic>))
      .toList(),
  json['perAppVPNMode'] as String?,
  (json['allowAppList'] as List<dynamic>?)?.map((e) => e as String).toList(),
  (json['disallowAppList'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$TunJsonToJson(TunJson instance) => <String, dynamic>{
  'tunDnsIPv4': ?instance.tunDnsIPv4,
  'tunDnsIPv6': ?instance.tunDnsIPv6,
  'enableDot': ?instance.enableDot,
  'dnsServerName': ?instance.dnsServerName,
  'enableIPv6': ?instance.enableIPv6,
  'metricsEnabled': ?instance.metricsEnabled,
  'tunName': ?instance.tunName,
  'autoOutboundsInterface': ?instance.autoOutboundsInterface,
  'includeAllNetworks': ?instance.includeAllNetworks,
  'excludeLocalNetworks': ?instance.excludeLocalNetworks,
  'excludeCellularServices': ?instance.excludeCellularServices,
  'excludeAPNs': ?instance.excludeAPNs,
  'excludeDeviceCommunication': ?instance.excludeDeviceCommunication,
  'onDemandEnabled': ?instance.onDemandEnabled,
  'onDemandRules': ?instance.onDemandRules?.map((e) => e.toJson()).toList(),
  'perAppVPNMode': ?instance.perAppVPNMode,
  'allowAppList': ?instance.allowAppList,
  'disallowAppList': ?instance.disallowAppList,
};

OnDemandRule _$OnDemandRuleFromJson(Map<String, dynamic> json) => OnDemandRule(
  json['mode'] as String?,
  json['interfaceType'] as String?,
  (json['ssid'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$OnDemandRuleToJson(OnDemandRule instance) =>
    <String, dynamic>{
      'mode': ?instance.mode,
      'interfaceType': ?instance.interfaceType,
      'ssid': ?instance.ssid,
    };
