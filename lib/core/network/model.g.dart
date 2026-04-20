// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeoLocation _$GeoLocationFromJson(Map<String, dynamic> json) => GeoLocation(
  json['country'] as String?,
  json['city'] as String?,
  json['region'] as String?,
  json['ip_address'] as String?,
  json['ip_version'] as String?,
  (json['delay'] as num?)?.toInt(),
  json['duration'] as String?,
);

Map<String, dynamic> _$GeoLocationToJson(GeoLocation instance) =>
    <String, dynamic>{
      'country': ?instance.country,
      'region': ?instance.region,
      'city': ?instance.city,
      'ip_address': ?instance.ipAddress,
      'ip_version': ?instance.ipVersion,
      'delay': ?instance.delay,
      'duration': ?instance.duration,
    };
