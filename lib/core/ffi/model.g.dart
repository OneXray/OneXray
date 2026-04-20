// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RunXrayConfig _$RunXrayConfigFromJson(Map<String, dynamic> json) =>
    RunXrayConfig(
      json['tunName'] as String?,
      (json['tunPriority'] as num?)?.toInt(),
      json['dns'] as String?,
      json['bindInterface'] as String?,
      json['datDir'] as String?,
      json['mphCachePath'] as String?,
      json['configPath'] as String?,
    );

Map<String, dynamic> _$RunXrayConfigToJson(RunXrayConfig instance) =>
    <String, dynamic>{
      'tunName': ?instance.tunName,
      'tunPriority': ?instance.tunPriority,
      'dns': ?instance.dns,
      'bindInterface': ?instance.bindInterface,
      'datDir': ?instance.datDir,
      'mphCachePath': ?instance.mphCachePath,
      'configPath': ?instance.configPath,
    };
