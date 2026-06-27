// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BackupManifestJson _$BackupManifestJsonFromJson(Map<String, dynamic> json) =>
    BackupManifestJson(
      (json['version'] as num?)?.toInt(),
      (json['createdAt'] as num?)?.toInt(),
    );

Map<String, dynamic> _$BackupManifestJsonToJson(BackupManifestJson instance) =>
    <String, dynamic>{
      'version': ?instance.version,
      'createdAt': ?instance.createdAt,
    };

BackupCoreConfigJson _$BackupCoreConfigJsonFromJson(
  Map<String, dynamic> json,
) => BackupCoreConfigJson(
  json['name'] as String?,
  json['type'] as String?,
  json['tags'] as String?,
  json['data'] as String?,
);

Map<String, dynamic> _$BackupCoreConfigJsonToJson(
  BackupCoreConfigJson instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'type': ?instance.type,
  'tags': ?instance.tags,
  'data': ?instance.data,
};

BackupSubscriptionJson _$BackupSubscriptionJsonFromJson(
  Map<String, dynamic> json,
) => BackupSubscriptionJson(
  json['name'] as String?,
  json['url'] as String?,
  (json['timestamp'] as num?)?.toInt(),
  json['expanded'] as bool?,
);

Map<String, dynamic> _$BackupSubscriptionJsonToJson(
  BackupSubscriptionJson instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'url': ?instance.url,
  'timestamp': ?instance.timestamp,
  'expanded': ?instance.expanded,
};

BackupGeoDataJson _$BackupGeoDataJsonFromJson(Map<String, dynamic> json) =>
    BackupGeoDataJson(
      json['name'] as String?,
      json['type'] as String?,
      json['url'] as String?,
      (json['timestamp'] as num?)?.toInt(),
      (json['categoryCount'] as num?)?.toInt(),
      (json['ruleCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$BackupGeoDataJsonToJson(BackupGeoDataJson instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'type': ?instance.type,
      'url': ?instance.url,
      'timestamp': ?instance.timestamp,
      'categoryCount': ?instance.categoryCount,
      'ruleCount': ?instance.ruleCount,
    };
