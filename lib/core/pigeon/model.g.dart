// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StartVpnRequest _$StartVpnRequestFromJson(Map<String, dynamic> json) =>
    StartVpnRequest(
      json['tun'] == null
          ? null
          : TunJson.fromJson(json['tun'] as Map<String, dynamic>),
      json['pingPort'] as String?,
      json['coreBase64Text'] as String?,
    );

Map<String, dynamic> _$StartVpnRequestToJson(StartVpnRequest instance) =>
    <String, dynamic>{
      'tun': ?instance.tun?.toJson(),
      'pingPort': ?instance.pingPort,
      'coreBase64Text': ?instance.coreBase64Text,
    };

CallResponse _$CallResponseFromJson(Map<String, dynamic> json) => CallResponse(
  json['success'] as bool?,
  json['data'],
  json['error'] as String?,
);

Map<String, dynamic> _$CallResponseToJson(CallResponse instance) =>
    <String, dynamic>{
      'success': ?instance.success,
      'data': ?instance.data,
      'error': ?instance.error,
    };

InitDnsRequest _$InitDnsRequestFromJson(Map<String, dynamic> json) =>
    InitDnsRequest(json['dns'] as String?, json['deviceName'] as String?);

Map<String, dynamic> _$InitDnsRequestToJson(InitDnsRequest instance) =>
    <String, dynamic>{'dns': ?instance.dns, 'deviceName': ?instance.deviceName};

GetFreePortsResponse _$GetFreePortsResponseFromJson(
  Map<String, dynamic> json,
) => GetFreePortsResponse(
  (json['ports'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
);

Map<String, dynamic> _$GetFreePortsResponseToJson(
  GetFreePortsResponse instance,
) => <String, dynamic>{'ports': ?instance.ports};

CountGeoDataRequest _$CountGeoDataRequestFromJson(Map<String, dynamic> json) =>
    CountGeoDataRequest(
      json['datDir'] as String?,
      json['name'] as String?,
      json['geoType'] as String?,
    );

Map<String, dynamic> _$CountGeoDataRequestToJson(
  CountGeoDataRequest instance,
) => <String, dynamic>{
  'datDir': ?instance.datDir,
  'name': ?instance.name,
  'geoType': ?instance.geoType,
};

ReadGeoFilesResponse _$ReadGeoFilesResponseFromJson(
  Map<String, dynamic> json,
) => ReadGeoFilesResponse(
  (json['domain'] as List<dynamic>?)?.map((e) => e as String).toList(),
  (json['ip'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$ReadGeoFilesResponseToJson(
  ReadGeoFilesResponse instance,
) => <String, dynamic>{'domain': ?instance.domain, 'ip': ?instance.ip};

PingRequest _$PingRequestFromJson(Map<String, dynamic> json) => PingRequest(
  json['datDir'] as String?,
  json['configPath'] as String?,
  (json['timeout'] as num?)?.toInt(),
  json['url'] as String?,
  json['proxy'] as String?,
);

Map<String, dynamic> _$PingRequestToJson(PingRequest instance) =>
    <String, dynamic>{
      'datDir': ?instance.datDir,
      'configPath': ?instance.configPath,
      'timeout': ?instance.timeout,
      'url': ?instance.url,
      'proxy': ?instance.proxy,
    };

RunXrayRequest _$RunXrayRequestFromJson(Map<String, dynamic> json) =>
    RunXrayRequest(
      json['datDir'] as String?,
      json['mphCachePath'] as String?,
      json['configPath'] as String?,
    );

Map<String, dynamic> _$RunXrayRequestToJson(RunXrayRequest instance) =>
    <String, dynamic>{
      'datDir': ?instance.datDir,
      'mphCachePath': ?instance.mphCachePath,
      'configPath': ?instance.configPath,
    };
