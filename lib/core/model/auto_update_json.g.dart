// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_update_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AutoUpdateJson _$AutoUpdateJsonFromJson(Map<String, dynamic> json) =>
    AutoUpdateJson(
      json['subscriptionEnabled'] as bool?,
      (json['subscriptionInterval'] as num?)?.toInt(),
      json['geoDataEnabled'] as bool?,
      (json['geoDataInterval'] as num?)?.toInt(),
      json['geoDataUpdateAfterVpnConnected'] as bool?,
    );

Map<String, dynamic> _$AutoUpdateJsonToJson(
  AutoUpdateJson instance,
) => <String, dynamic>{
  'subscriptionEnabled': ?instance.subscriptionEnabled,
  'subscriptionInterval': ?instance.subscriptionInterval,
  'geoDataEnabled': ?instance.geoDataEnabled,
  'geoDataInterval': ?instance.geoDataInterval,
  'geoDataUpdateAfterVpnConnected': ?instance.geoDataUpdateAfterVpnConnected,
};
