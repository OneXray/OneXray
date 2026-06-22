// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RunXrayConfig _$RunXrayConfigFromJson(Map<String, dynamic> json) =>
    RunXrayConfig(
      json['tunName'] as String?,
      (json['tunPriority'] as num?)?.toInt(),
      json['enableIPv6'] as bool?,
      json['datDir'] as String?,
      json['configPath'] as String?,
      json['metricsPort'] as String?,
    );

Map<String, dynamic> _$RunXrayConfigToJson(RunXrayConfig instance) =>
    <String, dynamic>{
      'tunName': ?instance.tunName,
      'tunPriority': ?instance.tunPriority,
      'enableIPv6': ?instance.enableIPv6,
      'datDir': ?instance.datDir,
      'configPath': ?instance.configPath,
      'metricsPort': ?instance.metricsPort,
    };
