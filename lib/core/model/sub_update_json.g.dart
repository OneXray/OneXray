// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sub_update_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubUpdateJson _$SubUpdateJsonFromJson(Map<String, dynamic> json) =>
    SubUpdateJson(
      json['enabled'] as bool?,
      (json['interval'] as num?)?.toInt(),
      json['autoPing'] as bool?,
    );

Map<String, dynamic> _$SubUpdateJsonToJson(SubUpdateJson instance) =>
    <String, dynamic>{
      'enabled': ?instance.enabled,
      'interval': ?instance.interval,
      'autoPing': ?instance.autoPing,
    };
