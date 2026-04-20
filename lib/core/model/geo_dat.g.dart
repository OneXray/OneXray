// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geo_dat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

XrayGeoList _$XrayGeoListFromJson(Map<String, dynamic> json) => XrayGeoList(
  (json['codes'] as List<dynamic>?)
      ?.map((e) => XrayGeoListCodes.fromJson(e as Map<String, dynamic>))
      .toList(),
  (json['categoryCount'] as num?)?.toInt(),
  (json['ruleCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$XrayGeoListToJson(XrayGeoList instance) =>
    <String, dynamic>{
      'codes': ?instance.codes?.map((e) => e.toJson()).toList(),
      'categoryCount': ?instance.categoryCount,
      'ruleCount': ?instance.ruleCount,
    };

XrayGeoListCodes _$XrayGeoListCodesFromJson(Map<String, dynamic> json) =>
    XrayGeoListCodes(
      json['code'] as String?,
      (json['ruleCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$XrayGeoListCodesToJson(XrayGeoListCodes instance) =>
    <String, dynamic>{'code': ?instance.code, 'ruleCount': ?instance.ruleCount};
