import 'package:json_annotation/json_annotation.dart';

part 'sub_update_json.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class SubUpdateJson {
  bool? enabled;
  int? interval;
  bool? autoPing;
  bool? geoDataEnabled;
  int? geoDataInterval;

  SubUpdateJson(
    this.enabled,
    this.interval,
    this.autoPing,
    this.geoDataEnabled,
    this.geoDataInterval,
  );

  factory SubUpdateJson.fromJson(Map<String, dynamic> json) =>
      _$SubUpdateJsonFromJson(json);

  Map<String, dynamic> toJson() => _$SubUpdateJsonToJson(this);
}
