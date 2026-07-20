import 'package:json_annotation/json_annotation.dart';

part 'simple_state_model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayProfileSimpleModel {
  SimpleRoutingModel? routing;
  bool? enableLog;
  bool? fakeDns;
  int? finalOutboundId;

  XrayProfileSimpleModel(
    this.routing,
    this.enableLog,
    this.fakeDns,
    this.finalOutboundId,
  );

  factory XrayProfileSimpleModel.fromJson(Map<String, dynamic> json) =>
      _$XrayProfileSimpleModelFromJson(json);

  Map<String, dynamic> toJson() => _$XrayProfileSimpleModelToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class SimpleRoutingModel {
  String? domainStrategy;
  String? directSet;
  bool? appleDirect;
  bool? localDirect;
  bool? enableIPRule;
  bool? localDns;
  bool? blockAds;

  SimpleRoutingModel(
    this.domainStrategy,
    this.directSet,
    this.appleDirect,
    this.localDirect,
    this.enableIPRule,
    this.localDns,
    this.blockAds,
  );

  factory SimpleRoutingModel.fromJson(Map<String, dynamic> json) =>
      _$SimpleRoutingModelFromJson(json);

  Map<String, dynamic> toJson() => _$SimpleRoutingModelToJson(this);
}
