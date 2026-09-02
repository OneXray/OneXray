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
  id: (json['id'] as num?)?.toInt(),
  subId: (json['subId'] as num?)?.toInt(),
  delay: (json['delay'] as num?)?.toInt(),
  countryCode: json['countryCode'] as String?,
  locationSource: json['locationSource'] as String?,
  lastMeasuredAt: (json['lastMeasuredAt'] as num?)?.toInt(),
  favorite: json['favorite'] as bool?,
);

Map<String, dynamic> _$BackupCoreConfigJsonToJson(
  BackupCoreConfigJson instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'type': ?instance.type,
  'tags': ?instance.tags,
  'data': ?instance.data,
  'subId': ?instance.subId,
  'delay': ?instance.delay,
  'countryCode': ?instance.countryCode,
  'locationSource': ?instance.locationSource,
  'lastMeasuredAt': ?instance.lastMeasuredAt,
  'favorite': ?instance.favorite,
};

BackupSubscriptionJson _$BackupSubscriptionJsonFromJson(
  Map<String, dynamic> json,
) => BackupSubscriptionJson(
  json['name'] as String?,
  json['url'] as String?,
  json['ageSecretKey'] as String?,
  json['agePublicKey'] as String?,
  (json['timestamp'] as num?)?.toInt(),
  json['expanded'] as bool?,
  id: (json['id'] as num?)?.toInt(),
  count: (json['count'] as num?)?.toInt(),
  parseFailureCount: (json['parseFailureCount'] as num?)?.toInt(),
  autoUpdate: json['autoUpdate'] as bool?,
);

Map<String, dynamic> _$BackupSubscriptionJsonToJson(
  BackupSubscriptionJson instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'url': ?instance.url,
  'ageSecretKey': ?instance.ageSecretKey,
  'agePublicKey': ?instance.agePublicKey,
  'timestamp': ?instance.timestamp,
  'expanded': ?instance.expanded,
  'count': ?instance.count,
  'parseFailureCount': ?instance.parseFailureCount,
  'autoUpdate': ?instance.autoUpdate,
};

BackupGeoDataJson _$BackupGeoDataJsonFromJson(Map<String, dynamic> json) =>
    BackupGeoDataJson(
      json['name'] as String?,
      json['type'] as String?,
      json['url'] as String?,
      (json['timestamp'] as num?)?.toInt(),
      (json['categoryCount'] as num?)?.toInt(),
      (json['ruleCount'] as num?)?.toInt(),
      id: (json['id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$BackupGeoDataJsonToJson(BackupGeoDataJson instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'name': ?instance.name,
      'type': ?instance.type,
      'url': ?instance.url,
      'timestamp': ?instance.timestamp,
      'categoryCount': ?instance.categoryCount,
      'ruleCount': ?instance.ruleCount,
    };

BackupCustomRoutingProfileJson _$BackupCustomRoutingProfileJsonFromJson(
  Map<String, dynamic> json,
) => BackupCustomRoutingProfileJson(
  (json['id'] as num?)?.toInt(),
  json['name'] as String?,
  json['data'] as String?,
);

Map<String, dynamic> _$BackupCustomRoutingProfileJsonToJson(
  BackupCustomRoutingProfileJson instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'data': ?instance.data,
};
