import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class GeoLocation {
  String? country;
  String? region;
  String? city;
  @JsonKey(name: 'ip_address')
  String? ipAddress;
  @JsonKey(name: 'ip_version')
  String? ipVersion;

  int? delay;
  String? duration;

  GeoLocation(
    this.country,
    this.city,
    this.region,
    this.ipAddress,
    this.ipVersion,
    this.delay,
    this.duration,
  );

  factory GeoLocation.fromJson(Map<String, dynamic> json) =>
      _$GeoLocationFromJson(json);

  Map<String, dynamic> toJson() => _$GeoLocationToJson(this);
}
