// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_state_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

XrayProfileSimpleModel _$XrayProfileSimpleModelFromJson(
  Map<String, dynamic> json,
) => XrayProfileSimpleModel(
  json['routing'] == null
      ? null
      : SimpleRoutingModel.fromJson(json['routing'] as Map<String, dynamic>),
  json['enableLog'] as bool?,
  json['fakeDns'] as bool?,
  (json['finalOutboundId'] as num?)?.toInt(),
);

Map<String, dynamic> _$XrayProfileSimpleModelToJson(
  XrayProfileSimpleModel instance,
) => <String, dynamic>{
  'routing': ?instance.routing?.toJson(),
  'enableLog': ?instance.enableLog,
  'fakeDns': ?instance.fakeDns,
  'finalOutboundId': ?instance.finalOutboundId,
};

SimpleRoutingModel _$SimpleRoutingModelFromJson(Map<String, dynamic> json) =>
    SimpleRoutingModel(
      json['domainStrategy'] as String?,
      json['directSet'] as String?,
      json['appleDirect'] as bool?,
      json['localDirect'] as bool?,
      json['enableIPRule'] as bool?,
      json['localDns'] as bool?,
      json['blockAds'] as bool?,
    );

Map<String, dynamic> _$SimpleRoutingModelToJson(SimpleRoutingModel instance) =>
    <String, dynamic>{
      'domainStrategy': ?instance.domainStrategy,
      'directSet': ?instance.directSet,
      'appleDirect': ?instance.appleDirect,
      'localDirect': ?instance.localDirect,
      'enableIPRule': ?instance.enableIPRule,
      'localDns': ?instance.localDns,
      'blockAds': ?instance.blockAds,
    };
