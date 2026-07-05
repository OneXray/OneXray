import 'package:json_annotation/json_annotation.dart';

part 'simple_state_model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayProfileSimpleModel {
  SimpleRoutingModel? routing;
  int? dnsId;
  bool? enableLog;
  bool? fakeDns;
  int? chainProxyOutboundId;

  XrayProfileSimpleModel(
    this.routing,
    this.dnsId,
    this.enableLog,
    this.fakeDns,
    this.chainProxyOutboundId,
  );

  factory XrayProfileSimpleModel.fromJson(Map<String, dynamic> json) =>
      _$XrayProfileSimpleModelFromJson(json);

  Map<String, dynamic> toJson() => _$XrayProfileSimpleModelToJson(this);
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
  bool? blockAds;

  SimpleRoutingModel(
    this.domainStrategy,
    this.queryStrategy,
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
