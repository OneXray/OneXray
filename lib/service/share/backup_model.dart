import 'package:json_annotation/json_annotation.dart';

part 'backup_model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class BackupManifestJson {
  static const currentVersion = 5;
  static const supportedVersions = {3, 4, currentVersion};

  final int? version;
  final int? createdAt;

  const BackupManifestJson(this.version, this.createdAt);

  factory BackupManifestJson.fromJson(Map<String, dynamic> json) =>
      _$BackupManifestJsonFromJson(json);

  Map<String, dynamic> toJson() => _$BackupManifestJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class BackupCoreConfigJson {
  final int? id;
  final String? name;
  final String? type;
  final String? tags;
  final String? data;
  final int? subId;
  final int? delay;
  final String? countryCode;
  final bool? favorite;

  const BackupCoreConfigJson(
    this.name,
    this.type,
    this.tags,
    this.data, {
    this.id,
    this.subId,
    this.delay,
    this.countryCode,
    this.favorite,
  });

  factory BackupCoreConfigJson.fromJson(Map<String, dynamic> json) =>
      _$BackupCoreConfigJsonFromJson(json);

  Map<String, dynamic> toJson() => _$BackupCoreConfigJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class BackupSubscriptionJson {
  final int? id;
  final String? name;
  final String? url;
  final String? ageSecretKey;
  final String? agePublicKey;
  final int? timestamp;
  final bool? expanded;
  final int? count;
  final bool? autoUpdate;

  const BackupSubscriptionJson(
    this.name,
    this.url,
    this.ageSecretKey,
    this.agePublicKey,
    this.timestamp,
    this.expanded, {
    this.id,
    this.count,
    this.autoUpdate,
  });

  factory BackupSubscriptionJson.fromJson(Map<String, dynamic> json) =>
      _$BackupSubscriptionJsonFromJson(json);

  Map<String, dynamic> toJson() => _$BackupSubscriptionJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class BackupGeoDataJson {
  final int? id;
  final String? name;
  final String? type;
  final String? url;
  final int? timestamp;
  final int? categoryCount;
  final int? ruleCount;

  const BackupGeoDataJson(
    this.name,
    this.type,
    this.url,
    this.timestamp,
    this.categoryCount,
    this.ruleCount, {
    this.id,
  });

  factory BackupGeoDataJson.fromJson(Map<String, dynamic> json) =>
      _$BackupGeoDataJsonFromJson(json);

  Map<String, dynamic> toJson() => _$BackupGeoDataJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class BackupRoutingProfileJson {
  final int? id;
  final String? name;
  final String? data;

  const BackupRoutingProfileJson(this.id, this.name, this.data);

  factory BackupRoutingProfileJson.fromJson(Map<String, dynamic> json) =>
      _$BackupRoutingProfileJsonFromJson(json);

  Map<String, dynamic> toJson() => _$BackupRoutingProfileJsonToJson(this);
}
