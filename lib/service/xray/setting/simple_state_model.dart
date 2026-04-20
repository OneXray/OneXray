import 'package:json_annotation/json_annotation.dart';

part 'simple_state_model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XraySettingSimpleModel {
  SimpleRoutingModel? routing;
  int? dnsId;
  bool? enableLog;

  XraySettingSimpleModel(this.routing, this.dnsId, this.enableLog);

  factory XraySettingSimpleModel.fromJson(Map<String, dynamic> json) =>
      _$XraySettingSimpleModelFromJson(json);

  Map<String, dynamic> toJson() => _$XraySettingSimpleModelToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class SimpleRoutingModel {
  String? domainStrategy;
  String? queryStrategy;
  String? directSet;
  bool? appleDirect;
  bool? localDirect;
  bool? enableIPRule;
  bool? localDns;

  SimpleRoutingModel(
    this.domainStrategy,
    this.queryStrategy,
    this.directSet,
    this.appleDirect,
    this.localDirect,
    this.enableIPRule,
    this.localDns,
  );

  factory SimpleRoutingModel.fromJson(Map<String, dynamic> json) =>
      _$SimpleRoutingModelFromJson(json);

  Map<String, dynamic> toJson() => _$SimpleRoutingModelToJson(this);
}
