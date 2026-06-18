import 'package:json_annotation/json_annotation.dart';

part 'auto_update_json.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class AutoUpdateJson {
  bool? enabled;
  int? interval;
  bool? geoDataEnabled;
  int? geoDataInterval;
  bool? geoDataUpdateAfterVpnConnected;

  AutoUpdateJson(
    this.enabled,
    this.interval,
    this.geoDataEnabled,
    this.geoDataInterval,
    this.geoDataUpdateAfterVpnConnected,
  );

  factory AutoUpdateJson.fromJson(Map<String, dynamic> json) =>
      _$AutoUpdateJsonFromJson(json);

  Map<String, dynamic> toJson() => _$AutoUpdateJsonToJson(this);
}
