import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class RunXrayConfig {
  String? tunName;
  int? tunPriority;
  String? dns;
  String? bindInterface;
  String? datDir;
  String? mphCachePath;
  String? configPath;

  RunXrayConfig(
    this.tunName,
    this.tunPriority,
    this.dns,
    this.bindInterface,
    this.datDir,
    this.mphCachePath,
    this.configPath,
  );

  factory RunXrayConfig.fromJson(Map<String, dynamic> json) =>
      _$RunXrayConfigFromJson(json);

  Map<String, dynamic> toJson() => _$RunXrayConfigToJson(this);
}
