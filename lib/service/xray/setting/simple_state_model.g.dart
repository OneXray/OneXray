// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_state_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

XraySettingSimpleModel _$XraySettingSimpleModelFromJson(
  Map<String, dynamic> json,
) => XraySettingSimpleModel(
  json['routing'] == null
      ? null
      : SimpleRoutingModel.fromJson(json['routing'] as Map<String, dynamic>),
  (json['dnsId'] as num?)?.toInt(),
  json['enableLog'] as bool?,
);

Map<String, dynamic> _$XraySettingSimpleModelToJson(
  XraySettingSimpleModel instance,
) => <String, dynamic>{
  'routing': ?instance.routing?.toJson(),
  'dnsId': ?instance.dnsId,
  'enableLog': ?instance.enableLog,
};

SimpleRoutingModel _$SimpleRoutingModelFromJson(Map<String, dynamic> json) =>
    SimpleRoutingModel(
      json['domainStrategy'] as String?,
      json['queryStrategy'] as String?,
      json['directSet'] as String?,
      json['appleDirect'] as bool?,
      json['localDirect'] as bool?,
      json['enableIPRule'] as bool?,
      json['localDns'] as bool?,
    );

Map<String, dynamic> _$SimpleRoutingModelToJson(SimpleRoutingModel instance) =>
    <String, dynamic>{
      'domainStrategy': ?instance.domainStrategy,
      'queryStrategy': ?instance.queryStrategy,
      'directSet': ?instance.directSet,
      'appleDirect': ?instance.appleDirect,
      'localDirect': ?instance.localDirect,
      'enableIPRule': ?instance.enableIPRule,
      'localDns': ?instance.localDns,
    };
