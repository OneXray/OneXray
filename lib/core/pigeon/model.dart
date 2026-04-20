import 'package:json_annotation/json_annotation.dart';
import 'package:onexray/core/model/tun_json.dart';

part 'model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class StartVpnRequest {
  TunJson? tun;
  String? pingPort;
  String? coreBase64Text;

  StartVpnRequest(this.tun, this.pingPort, this.coreBase64Text);

  factory StartVpnRequest.fromJson(Map<String, dynamic> json) =>
      _$StartVpnRequestFromJson(json);

  Map<String, dynamic> toJson() => _$StartVpnRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class CallResponse {
  bool? success;
  dynamic data;
  String? error;

  CallResponse(this.success, this.data, this.error);

  factory CallResponse.fromJson(Map<String, dynamic> json) =>
      _$CallResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CallResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class InitDnsRequest {
  String? dns;
  String? deviceName;

  InitDnsRequest(this.dns, this.deviceName);

  factory InitDnsRequest.fromJson(Map<String, dynamic> json) =>
      _$InitDnsRequestFromJson(json);

  Map<String, dynamic> toJson() => _$InitDnsRequestToJson(this);
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
class CountGeoDataRequest {
  String? datDir;
  String? name;
  String? geoType;

  CountGeoDataRequest(this.datDir, this.name, this.geoType);

  factory CountGeoDataRequest.fromJson(Map<String, dynamic> json) =>
      _$CountGeoDataRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CountGeoDataRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ReadGeoFilesResponse {
  List<String>? domain;
  List<String>? ip;

  ReadGeoFilesResponse(this.domain, this.ip);

  factory ReadGeoFilesResponse.fromJson(Map<String, dynamic> json) =>
      _$ReadGeoFilesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ReadGeoFilesResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class PingRequest {
  String? datDir;
  String? configPath;
  int? timeout;
  String? url;
  String? proxy;

  PingRequest(this.datDir, this.configPath, this.timeout, this.url, this.proxy);

  factory PingRequest.fromJson(Map<String, dynamic> json) =>
      _$PingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PingRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class RunXrayRequest {
  String? datDir;
  String? mphCachePath;
  String? configPath;

  RunXrayRequest(this.datDir, this.mphCachePath, this.configPath);

  factory RunXrayRequest.fromJson(Map<String, dynamic> json) =>
      _$RunXrayRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RunXrayRequestToJson(this);
}
