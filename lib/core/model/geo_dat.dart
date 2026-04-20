import 'package:json_annotation/json_annotation.dart';

part 'geo_dat.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayGeoList {
  List<XrayGeoListCodes>? codes;
  int? categoryCount;
  int? ruleCount;

  XrayGeoList(
    this.codes,
    this.categoryCount,
    this.ruleCount,
  );

  factory XrayGeoList.fromJson(Map<String, dynamic> json) =>
      _$XrayGeoListFromJson(json);

  Map<String, dynamic> toJson() => _$XrayGeoListToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayGeoListCodes {
  String? code;
  int? ruleCount;

  XrayGeoListCodes(
    this.code,
    this.ruleCount,
  );

  factory XrayGeoListCodes.fromJson(Map<String, dynamic> json) =>
      _$XrayGeoListCodesFromJson(json);

  Map<String, dynamic> toJson() => _$XrayGeoListCodesToJson(this);
}
