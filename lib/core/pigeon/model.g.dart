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
      json['pingAuth'] == null
          ? null
          : XrayInboundAccount.fromJson(
              json['pingAuth'] as Map<String, dynamic>,
            ),
      json['metricsPort'] as String?,
      json['coreInvokeText'] as String?,
    );

Map<String, dynamic> _$StartVpnRequestToJson(StartVpnRequest instance) =>
    <String, dynamic>{
      'tun': ?instance.tun?.toJson(),
      'pingPort': ?instance.pingPort,
      'pingAuth': ?instance.pingAuth?.toJson(),
      'metricsPort': ?instance.metricsPort,
      'coreInvokeText': ?instance.coreInvokeText,
    };

LibXrayInvokeResponse _$LibXrayInvokeResponseFromJson(
  Map<String, dynamic> json,
) => LibXrayInvokeResponse(
  json['success'] as bool,
  json['data'] as Map<String, dynamic>?,
  json['error'] as String,
);

Map<String, dynamic> _$LibXrayInvokeResponseToJson(
  LibXrayInvokeResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'data': ?instance.data,
  'error': instance.error,
};

GetFreePortsResponse _$GetFreePortsResponseFromJson(
  Map<String, dynamic> json,
) => GetFreePortsResponse(
  (json['ports'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
);

Map<String, dynamic> _$GetFreePortsResponseToJson(
  GetFreePortsResponse instance,
) => <String, dynamic>{'ports': ?instance.ports};

ConvertXrayJsonToShareLinksResponse
_$ConvertXrayJsonToShareLinksResponseFromJson(Map<String, dynamic> json) =>
    ConvertXrayJsonToShareLinksResponse(json['links'] as String?);

Map<String, dynamic> _$ConvertXrayJsonToShareLinksResponseToJson(
  ConvertXrayJsonToShareLinksResponse instance,
) => <String, dynamic>{'links': ?instance.links};

PingBatchResponse _$PingBatchResponseFromJson(Map<String, dynamic> json) =>
    PingBatchResponse(
      (json['results'] as List<dynamic>?)
          ?.map(
            (e) => PingBatchItemResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$PingBatchResponseToJson(PingBatchResponse instance) =>
    <String, dynamic>{
      'results': ?instance.results?.map((e) => e.toJson()).toList(),
    };

PingBatchItemResponse _$PingBatchItemResponseFromJson(
  Map<String, dynamic> json,
) => PingBatchItemResponse(
  json['success'] as bool?,
  (json['delay'] as num?)?.toInt(),
  json['error'] as String?,
);

Map<String, dynamic> _$PingBatchItemResponseToJson(
  PingBatchItemResponse instance,
) => <String, dynamic>{
  'success': ?instance.success,
  'delay': ?instance.delay,
  'error': ?instance.error,
};

XrayVersionResponse _$XrayVersionResponseFromJson(Map<String, dynamic> json) =>
    XrayVersionResponse(json['version'] as String?);

Map<String, dynamic> _$XrayVersionResponseToJson(
  XrayVersionResponse instance,
) => <String, dynamic>{'version': ?instance.version};

GetXrayStateResponse _$GetXrayStateResponseFromJson(
  Map<String, dynamic> json,
) => GetXrayStateResponse(json['running'] as bool?);

Map<String, dynamic> _$GetXrayStateResponseToJson(
  GetXrayStateResponse instance,
) => <String, dynamic>{'running': ?instance.running};

CountGeoDataRequest _$CountGeoDataRequestFromJson(Map<String, dynamic> json) =>
    CountGeoDataRequest(
      json['name'] as String?,
      json['geoType'] as String?,
      datDir: json['datDir'] as String?,
    );

Map<String, dynamic> _$CountGeoDataRequestToJson(
  CountGeoDataRequest instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'geoType': ?instance.geoType,
  'datDir': ?instance.datDir,
};

PingBatchRequest _$PingBatchRequestFromJson(Map<String, dynamic> json) =>
    PingBatchRequest(
      (json['configs'] as List<dynamic>?)
          ?.map((e) => PingBatchItemRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      (json['timeout'] as num?)?.toInt(),
      json['url'] as String?,
    );

Map<String, dynamic> _$PingBatchRequestToJson(PingBatchRequest instance) =>
    <String, dynamic>{
      'configs': ?instance.configs?.map((e) => e.toJson()).toList(),
      'timeout': ?instance.timeout,
      'url': ?instance.url,
    };

PingBatchItemRequest _$PingBatchItemRequestFromJson(
  Map<String, dynamic> json,
) => PingBatchItemRequest(
  json['configPath'] as String?,
  outboundTag: json['outboundTag'] as String?,
);

Map<String, dynamic> _$PingBatchItemRequestToJson(
  PingBatchItemRequest instance,
) => <String, dynamic>{
  'configPath': ?instance.configPath,
  'outboundTag': ?instance.outboundTag,
};

RunXrayRequest _$RunXrayRequestFromJson(Map<String, dynamic> json) =>
    RunXrayRequest(json['configPath'] as String?);

Map<String, dynamic> _$RunXrayRequestToJson(RunXrayRequest instance) =>
    <String, dynamic>{'configPath': ?instance.configPath};

LibXrayInvokeRequest _$LibXrayInvokeRequestFromJson(
  Map<String, dynamic> json,
) => LibXrayInvokeRequest(
  method: $enumDecodeNullable(_$LibXrayMethodEnumMap, json['method']),
  payload: json['payload'] as Map<String, dynamic>?,
)..apiVersion = (json['apiVersion'] as num?)?.toInt();

Map<String, dynamic> _$LibXrayInvokeRequestToJson(
  LibXrayInvokeRequest instance,
) => <String, dynamic>{
  'apiVersion': ?instance.apiVersion,
  'method': ?_$LibXrayMethodEnumMap[instance.method],
  'payload': ?instance.payload,
};

const _$LibXrayMethodEnumMap = {
  LibXrayMethod.getFreePorts: 'getFreePorts',
  LibXrayMethod.convertShareLinksToXrayJson: 'convertShareLinksToXrayJson',
  LibXrayMethod.convertXrayJsonToShareLinks: 'convertXrayJsonToShareLinks',
  LibXrayMethod.countGeoData: 'countGeoData',
  LibXrayMethod.pingBatch: 'pingBatch',
  LibXrayMethod.testXray: 'testXray',
  LibXrayMethod.runXray: 'runXray',
  LibXrayMethod.runXrayFromJson: 'runXrayFromJson',
  LibXrayMethod.stopXray: 'stopXray',
  LibXrayMethod.xrayVersion: 'xrayVersion',
  LibXrayMethod.getXrayState: 'getXrayState',
};

GetFreePortsRequest _$GetFreePortsRequestFromJson(Map<String, dynamic> json) =>
    GetFreePortsRequest((json['count'] as num?)?.toInt());

Map<String, dynamic> _$GetFreePortsRequestToJson(
  GetFreePortsRequest instance,
) => <String, dynamic>{'count': ?instance.count};

ConvertShareLinksToXrayJsonRequest _$ConvertShareLinksToXrayJsonRequestFromJson(
  Map<String, dynamic> json,
) => ConvertShareLinksToXrayJsonRequest(json['text'] as String?);

Map<String, dynamic> _$ConvertShareLinksToXrayJsonRequestToJson(
  ConvertShareLinksToXrayJsonRequest instance,
) => <String, dynamic>{'text': ?instance.text};

ConvertXrayJsonToShareLinksRequest _$ConvertXrayJsonToShareLinksRequestFromJson(
  Map<String, dynamic> json,
) => ConvertXrayJsonToShareLinksRequest(json['xrayJson'] as String?);

Map<String, dynamic> _$ConvertXrayJsonToShareLinksRequestToJson(
  ConvertXrayJsonToShareLinksRequest instance,
) => <String, dynamic>{'xrayJson': ?instance.xrayJson};

RunXrayFromJSONRequest _$RunXrayFromJSONRequestFromJson(
  Map<String, dynamic> json,
) => RunXrayFromJSONRequest(json['configJSON'] as String?);

Map<String, dynamic> _$RunXrayFromJSONRequestToJson(
  RunXrayFromJSONRequest instance,
) => <String, dynamic>{'configJSON': ?instance.configJSON};
