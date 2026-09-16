import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

@JsonSerializable(explicitToJson: true, disallowUnrecognizedKeys: true)
class BackupDocument {
  final String format;
  final int version;
  final int createdAt;
  final List<BackupCoreConfig> coreConfigs;
  final List<BackupSubscription> subscriptions;
  final List<BackupRoutingProfile> routingProfiles;
  final BackupSmartRouting smartRouting;
  final List<BackupGeoData> geoData;

  const BackupDocument({
    this.format = 'onexray-backup',
    this.version = 1,
    required this.createdAt,
    required this.coreConfigs,
    required this.subscriptions,
    required this.routingProfiles,
    required this.smartRouting,
    required this.geoData,
  });

  factory BackupDocument.fromJson(Map<String, dynamic> json) =>
      _$BackupDocumentFromJson(json);
  Map<String, dynamic> toJson() => _$BackupDocumentToJson(this);
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class BackupCoreConfig {
  final String name;
  final String type;
  final String tags;
  final String data;

  const BackupCoreConfig(this.name, this.type, this.tags, this.data);
  factory BackupCoreConfig.fromJson(Map<String, dynamic> json) =>
      _$BackupCoreConfigFromJson(json);
  Map<String, dynamic> toJson() => _$BackupCoreConfigToJson(this);
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class BackupSubscription {
  final String name;
  final String url;
  final String? ageSecretKey;
  final String? agePublicKey;
  final bool hwidEnabled;
  final String? hwid;

  const BackupSubscription(
    this.name,
    this.url,
    this.ageSecretKey,
    this.agePublicKey,
    this.hwidEnabled,
    this.hwid,
  );
  factory BackupSubscription.fromJson(Map<String, dynamic> json) =>
      _$BackupSubscriptionFromJson(json);
  Map<String, dynamic> toJson() => _$BackupSubscriptionToJson(this);
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class BackupRoutingProfile {
  final String name;
  final bool advanced;
  final String data;

  const BackupRoutingProfile(this.name, this.advanced, this.data);
  factory BackupRoutingProfile.fromJson(Map<String, dynamic> json) =>
      _$BackupRoutingProfileFromJson(json);
  Map<String, dynamic> toJson() => _$BackupRoutingProfileToJson(this);
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class BackupGeoData {
  final String name;
  final String type;
  final String url;

  const BackupGeoData(this.name, this.type, this.url);
  factory BackupGeoData.fromJson(Map<String, dynamic> json) =>
      _$BackupGeoDataFromJson(json);
  Map<String, dynamic> toJson() => _$BackupGeoDataToJson(this);
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class BackupSmartRouting {
  final int entryCount;
  final List<String> directRegions;
  final bool directPrivate;
  final bool directApple;
  final bool directWindows;
  final bool directDns;
  final String directDnsAddress;
  final bool fakeDns;
  final bool blockAds;

  const BackupSmartRouting({
    required this.entryCount,
    required this.directRegions,
    required this.directPrivate,
    required this.directApple,
    required this.directWindows,
    required this.directDns,
    required this.directDnsAddress,
    required this.fakeDns,
    required this.blockAds,
  });
  factory BackupSmartRouting.fromJson(Map<String, dynamic> json) =>
      _$BackupSmartRoutingFromJson(json);
  Map<String, dynamic> toJson() => _$BackupSmartRoutingToJson(this);
}
