// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_update_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AutoUpdateJson _$AutoUpdateJsonFromJson(Map<String, dynamic> json) =>
    AutoUpdateJson(
      json['enabled'] as bool?,
      (json['interval'] as num?)?.toInt(),
      json['geoDataEnabled'] as bool?,
      (json['geoDataInterval'] as num?)?.toInt(),
      json['geoDataUpdateAfterVpnConnected'] as bool?,
    );

Map<String, dynamic> _$AutoUpdateJsonToJson(
  AutoUpdateJson instance,
) => <String, dynamic>{
  'enabled': ?instance.enabled,
  'interval': ?instance.interval,
  'geoDataEnabled': ?instance.geoDataEnabled,
  'geoDataInterval': ?instance.geoDataInterval,
  'geoDataUpdateAfterVpnConnected': ?instance.geoDataUpdateAfterVpnConnected,
};
