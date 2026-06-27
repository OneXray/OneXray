import 'package:json_annotation/json_annotation.dart';

part 'backup_model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class BackupManifestJson {
  final int? version;
  final int? createdAt;

  const BackupManifestJson(this.version, this.createdAt);

  factory BackupManifestJson.fromJson(Map<String, dynamic> json) =>
      _$BackupManifestJsonFromJson(json);

  Map<String, dynamic> toJson() => _$BackupManifestJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class BackupCoreConfigJson {
  final String? name;
  final String? type;
  final String? tags;
  final String? data;

  const BackupCoreConfigJson(this.name, this.type, this.tags, this.data);

  factory BackupCoreConfigJson.fromJson(Map<String, dynamic> json) =>
      _$BackupCoreConfigJsonFromJson(json);

  Map<String, dynamic> toJson() => _$BackupCoreConfigJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class BackupSubscriptionJson {
  final String? name;
  final String? url;
  final int? timestamp;
  final bool? expanded;

  const BackupSubscriptionJson(
    this.name,
    this.url,
    this.timestamp,
    this.expanded,
  );

  factory BackupSubscriptionJson.fromJson(Map<String, dynamic> json) =>
      _$BackupSubscriptionJsonFromJson(json);

  Map<String, dynamic> toJson() => _$BackupSubscriptionJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class BackupGeoDataJson {
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
    this.ruleCount,
  );

  factory BackupGeoDataJson.fromJson(Map<String, dynamic> json) =>
      _$BackupGeoDataJsonFromJson(json);

  Map<String, dynamic> toJson() => _$BackupGeoDataJsonToJson(this);
}
