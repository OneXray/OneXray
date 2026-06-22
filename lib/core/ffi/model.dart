import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class RunXrayConfig {
  String? tunName;
  int? tunPriority;
  bool? enableIPv6;
  String? datDir;
  String? configPath;
  String? metricsPort;

  RunXrayConfig(
    this.tunName,
    this.tunPriority,
    this.enableIPv6,
    this.datDir,
    this.configPath,
    this.metricsPort,
  );

  factory RunXrayConfig.fromJson(Map<String, dynamic> json) =>
      _$RunXrayConfigFromJson(json);

  Map<String, dynamic> toJson() => _$RunXrayConfigToJson(this);
}
