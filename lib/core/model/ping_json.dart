import 'package:json_annotation/json_annotation.dart';

part 'ping_json.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class PingJson {
  double? timeout;
  double? concurrency;
  String? url;
  bool? autoPingNewConfigs;

  PingJson(this.timeout, this.concurrency, this.url, this.autoPingNewConfigs);

  factory PingJson.fromJson(Map<String, dynamic> json) =>
      _$PingJsonFromJson(json);

  Map<String, dynamic> toJson() => _$PingJsonToJson(this);
}
