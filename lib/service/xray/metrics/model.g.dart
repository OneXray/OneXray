// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

XrayMetricsVars _$XrayMetricsVarsFromJson(Map<String, dynamic> json) =>
    XrayMetricsVars(
      json['stats'] == null
          ? null
          : XrayMetricsStats.fromJson(json['stats'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$XrayMetricsVarsToJson(XrayMetricsVars instance) =>
    <String, dynamic>{'stats': ?instance.stats?.toJson()};

XrayMetricsStats _$XrayMetricsStatsFromJson(Map<String, dynamic> json) =>
    XrayMetricsStats(
      json['inbound'] == null
          ? null
          : XrayMetricsInboundStats.fromJson(
              json['inbound'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$XrayMetricsStatsToJson(XrayMetricsStats instance) =>
    <String, dynamic>{'inbound': ?instance.inbound?.toJson()};

XrayMetricsInboundStats _$XrayMetricsInboundStatsFromJson(
  Map<String, dynamic> json,
) => XrayMetricsInboundStats(
  json['tunIn'] == null
      ? null
      : XrayTrafficCounter.fromJson(json['tunIn'] as Map<String, dynamic>),
  json['socksIn'] == null
      ? null
      : XrayTrafficCounter.fromJson(json['socksIn'] as Map<String, dynamic>),
  json['httpIn'] == null
      ? null
      : XrayTrafficCounter.fromJson(json['httpIn'] as Map<String, dynamic>),
);

Map<String, dynamic> _$XrayMetricsInboundStatsToJson(
  XrayMetricsInboundStats instance,
) => <String, dynamic>{
  'tunIn': ?instance.tunIn?.toJson(),
  'socksIn': ?instance.socksIn?.toJson(),
  'httpIn': ?instance.httpIn?.toJson(),
};

XrayTrafficCounter _$XrayTrafficCounterFromJson(Map<String, dynamic> json) =>
    XrayTrafficCounter(
      (json['uplink'] as num?)?.toInt(),
      (json['downlink'] as num?)?.toInt(),
    );

Map<String, dynamic> _$XrayTrafficCounterToJson(XrayTrafficCounter instance) =>
    <String, dynamic>{
      'uplink': ?instance.uplink,
      'downlink': ?instance.downlink,
    };
