import 'package:json_annotation/json_annotation.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/model/tun_json.dart';
import 'package:onexray/core/tools/json.dart';

part 'model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class StartVpnRequest {
  TunJson? tun;
  String? pingPort;
  XrayInboundAccount? pingAuth;
  String? metricsPort;
  String? coreInvokeText;

  StartVpnRequest(
    this.tun,
    this.pingPort,
    this.pingAuth,
    this.metricsPort,
    this.coreInvokeText,
  );

  factory StartVpnRequest.fromJson(Map<String, dynamic> json) =>
      _$StartVpnRequestFromJson(json);

  Map<String, dynamic> toJson() => _$StartVpnRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class LibXrayInvokeResponse {
  bool? success;
  Map<String, dynamic>? data;
  String? error;

  LibXrayInvokeResponse(this.success, this.data, this.error);

  factory LibXrayInvokeResponse.fromJson(Map<String, dynamic> json) =>
      _$LibXrayInvokeResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LibXrayInvokeResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class GetFreePortsResponse {
  List<int>? ports;

  GetFreePortsResponse(this.ports);

  factory GetFreePortsResponse.fromJson(Map<String, dynamic> json) =>
      _$GetFreePortsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GetFreePortsResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ConvertXrayJsonToShareLinksResponse {
  String? links;

  ConvertXrayJsonToShareLinksResponse(this.links);

  factory ConvertXrayJsonToShareLinksResponse.fromJson(
    Map<String, dynamic> json,
  ) => _$ConvertXrayJsonToShareLinksResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ConvertXrayJsonToShareLinksResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class PingResponse {
  int? delay;

  PingResponse(this.delay);

  factory PingResponse.fromJson(Map<String, dynamic> json) =>
      _$PingResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PingResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayVersionResponse {
  String? version;

  XrayVersionResponse(this.version);

  factory XrayVersionResponse.fromJson(Map<String, dynamic> json) =>
      _$XrayVersionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$XrayVersionResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class GetXrayStateResponse {
  bool? running;

  GetXrayStateResponse(this.running);

  factory GetXrayStateResponse.fromJson(Map<String, dynamic> json) =>
      _$GetXrayStateResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GetXrayStateResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class CountGeoDataRequest {
  String? name;
  String? geoType;

  CountGeoDataRequest(this.name, this.geoType);

  factory CountGeoDataRequest.fromJson(Map<String, dynamic> json) =>
      _$CountGeoDataRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CountGeoDataRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class PingRequest {
  String? configPath;
  int? timeout;
  String? url;
  String? proxy;

  PingRequest(this.configPath, this.timeout, this.url, this.proxy);

  factory PingRequest.fromJson(Map<String, dynamic> json) =>
      _$PingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PingRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class RunXrayRequest {
  String? configPath;

  RunXrayRequest(this.configPath);

  factory RunXrayRequest.fromJson(Map<String, dynamic> json) =>
      _$RunXrayRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RunXrayRequestToJson(this);
}

enum LibXrayMethod {
  @JsonValue("getFreePorts")
  getFreePorts,
  @JsonValue("convertShareLinksToXrayJson")
  convertShareLinksToXrayJson,
  @JsonValue("convertXrayJsonToShareLinks")
  convertXrayJsonToShareLinks,
  @JsonValue("countGeoData")
  countGeoData,
  @JsonValue("ping")
  ping,
  @JsonValue("testXray")
  testXray,
  @JsonValue("runXray")
  runXray,
  @JsonValue("runXrayFromJson")
  runXrayFromJson,
  @JsonValue("stopXray")
  stopXray,
  @JsonValue("xrayVersion")
  xrayVersion,
  @JsonValue("getXrayState")
  getXrayState,
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class LibXrayEnvJson {
  @JsonKey(name: "xray.location.config")
  String? configLocation;
  @JsonKey(name: "xray.location.confdir")
  String? confdirLocation;
  @JsonKey(name: "xray.location.asset")
  String? assetLocation;
  @JsonKey(name: "xray.location.cert")
  String? certLocation;
  @JsonKey(name: "xray.buf.readv")
  String? useReadV;
  @JsonKey(name: "xray.buf.splice")
  String? useFreedomSplice;
  @JsonKey(name: "xray.vmess.padding")
  String? useVmessPadding;
  @JsonKey(name: "xray.cone.disabled")
  String? useCone;
  @JsonKey(name: "xray.json.strict")
  String? useStrictJson;
  @JsonKey(name: "xray.ray.buffer.size")
  String? bufferSize;
  @JsonKey(name: "xray.browser.dialer")
  String? browserDialerAddress;
  @JsonKey(name: "xray.xudp.show")
  String? xudpLog;
  @JsonKey(name: "xray.xudp.basekey")
  String? xudpBaseKey;
  @JsonKey(name: "xray.tun.fd")
  String? tunFd;

  LibXrayEnvJson({
    this.configLocation,
    this.confdirLocation,
    this.assetLocation,
    this.certLocation,
    this.useReadV,
    this.useFreedomSplice,
    this.useVmessPadding,
    this.useCone,
    this.useStrictJson,
    this.bufferSize,
    this.browserDialerAddress,
    this.xudpLog,
    this.xudpBaseKey,
    this.tunFd,
  });

  factory LibXrayEnvJson.fromJson(Map<String, dynamic> json) =>
      _$LibXrayEnvJsonFromJson(json);

  Map<String, dynamic> toJson() => _$LibXrayEnvJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class LibXrayInvokeRequest {
  int? apiVersion;
  LibXrayMethod? method;
  LibXrayEnvJson? env;
  Map<String, dynamic>? payload;

  LibXrayInvokeRequest({this.method, this.env, this.payload}) : apiVersion = 1;

  factory LibXrayInvokeRequest.fromJson(Map<String, dynamic> json) =>
      _$LibXrayInvokeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LibXrayInvokeRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class GetFreePortsRequest {
  int? count;

  GetFreePortsRequest(this.count);

  factory GetFreePortsRequest.fromJson(Map<String, dynamic> json) =>
      _$GetFreePortsRequestFromJson(json);

  Map<String, dynamic> toJson() => _$GetFreePortsRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ConvertShareLinksToXrayJsonRequest {
  String? text;

  ConvertShareLinksToXrayJsonRequest(this.text);

  factory ConvertShareLinksToXrayJsonRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$ConvertShareLinksToXrayJsonRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ConvertShareLinksToXrayJsonRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ConvertXrayJsonToShareLinksRequest {
  String? xrayJson;

  ConvertXrayJsonToShareLinksRequest(this.xrayJson);

  factory ConvertXrayJsonToShareLinksRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$ConvertXrayJsonToShareLinksRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ConvertXrayJsonToShareLinksRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class RunXrayFromJSONRequest {
  String? configJSON;

  RunXrayFromJSONRequest(this.configJSON);

  factory RunXrayFromJSONRequest.fromJson(Map<String, dynamic> json) =>
      _$RunXrayFromJSONRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RunXrayFromJSONRequestToJson(this);
}

class LibXrayRunConfig {
  final LibXrayEnvJson? env;
  final RunXrayRequest request;

  LibXrayRunConfig(this.env, this.request);

  factory LibXrayRunConfig.fromInvokeText(String text) {
    final data = JsonTool.decoder.convert(text) as Map<String, dynamic>;
    final invoke = LibXrayInvokeRequest.fromJson(data);
    final payload = invoke.payload ?? const <String, dynamic>{};
    return LibXrayRunConfig(invoke.env, RunXrayRequest.fromJson(payload));
  }
}
