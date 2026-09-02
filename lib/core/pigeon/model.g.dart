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
      json['socksPort'] as String?,
      json['pingPort'] as String?,
      json['pingAuth'] == null
          ? null
          : XrayInboundAccount.fromJson(
              json['pingAuth'] as Map<String, dynamic>,
            ),
      json['metricsPort'] as String?,
      json['coreInvokeText'] as String?,
      configId: (json['configId'] as num?)?.toInt(),
      snapshotToken: json['snapshotToken'] as String?,
    );

Map<String, dynamic> _$StartVpnRequestToJson(StartVpnRequest instance) =>
    <String, dynamic>{
      'tun': ?instance.tun?.toJson(),
      'socksPort': ?instance.socksPort,
      'pingPort': ?instance.pingPort,
      'pingAuth': ?instance.pingAuth?.toJson(),
      'metricsPort': ?instance.metricsPort,
      'coreInvokeText': ?instance.coreInvokeText,
      'configId': ?instance.configId,
      'snapshotToken': ?instance.snapshotToken,
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
  location: json['location'] == null
      ? null
      : PingLocationResponse.fromJson(json['location'] as Map<String, dynamic>),
  locationError: json['locationError'] as String?,
);

Map<String, dynamic> _$PingBatchItemResponseToJson(
  PingBatchItemResponse instance,
) => <String, dynamic>{
  'success': ?instance.success,
  'delay': ?instance.delay,
  'error': ?instance.error,
  'location': ?instance.location?.toJson(),
  'locationError': ?instance.locationError,
};

PingLocationResponse _$PingLocationResponseFromJson(
  Map<String, dynamic> json,
) => PingLocationResponse(
  ip: json['ip'] as String?,
  countryCode: json['countryCode'] as String?,
);

Map<String, dynamic> _$PingLocationResponseToJson(
  PingLocationResponse instance,
) => <String, dynamic>{
  'ip': ?instance.ip,
  'countryCode': ?instance.countryCode,
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
      locationUrl: json['locationUrl'] as String?,
    );

Map<String, dynamic> _$PingBatchRequestToJson(PingBatchRequest instance) =>
    <String, dynamic>{
      'configs': ?instance.configs?.map((e) => e.toJson()).toList(),
      'timeout': ?instance.timeout,
      'url': ?instance.url,
      'locationUrl': ?instance.locationUrl,
    };

PingBatchItemRequest _$PingBatchItemRequestFromJson(
  Map<String, dynamic> json,
) => PingBatchItemRequest(
  json['xrayJson'] as String?,
  outboundTag: json['outboundTag'] as String?,
);

Map<String, dynamic> _$PingBatchItemRequestToJson(
  PingBatchItemRequest instance,
) => <String, dynamic>{
  'xrayJson': ?instance.xrayJson,
  'outboundTag': ?instance.outboundTag,
};

RunXrayRequest _$RunXrayRequestFromJson(Map<String, dynamic> json) =>
    RunXrayRequest(
      json['xrayJson'] as String?,
      runtime: json['runtime'] == null
          ? null
          : ManagedRuntimeRequest.fromJson(
              json['runtime'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$RunXrayRequestToJson(RunXrayRequest instance) =>
    <String, dynamic>{
      'xrayJson': ?instance.xrayJson,
      'runtime': ?instance.runtime?.toJson(),
    };

ManagedRuntimeRequest _$ManagedRuntimeRequestFromJson(
  Map<String, dynamic> json,
) => ManagedRuntimeRequest(
  statePath: json['statePath'] as String,
  planId: json['planId'] as String,
  inboundTag: json['inboundTag'] as String? ?? 'tunIn',
);

Map<String, dynamic> _$ManagedRuntimeRequestToJson(
  ManagedRuntimeRequest instance,
) => <String, dynamic>{
  'statePath': instance.statePath,
  'planId': instance.planId,
  'inboundTag': instance.inboundTag,
};

TestXrayRequest _$TestXrayRequestFromJson(Map<String, dynamic> json) =>
    TestXrayRequest(
      json['xrayJson'] as String?,
      buildOnly: json['buildOnly'] as bool?,
    );

Map<String, dynamic> _$TestXrayRequestToJson(TestXrayRequest instance) =>
    <String, dynamic>{
      'xrayJson': ?instance.xrayJson,
      'buildOnly': ?instance.buildOnly,
    };

CheckRouteRequest _$CheckRouteRequestFromJson(Map<String, dynamic> json) =>
    CheckRouteRequest(
      xrayJson: json['xrayJson'] as String,
      domain: json['domain'] as String?,
      ip: json['ip'] as String?,
      port: (json['port'] as num).toInt(),
      network: json['network'] as String,
      inboundTag: json['inboundTag'] as String? ?? 'tunIn',
      timeout: (json['timeout'] as num?)?.toInt() ?? 5000,
    );

Map<String, dynamic> _$CheckRouteRequestToJson(CheckRouteRequest instance) =>
    <String, dynamic>{
      'xrayJson': instance.xrayJson,
      'domain': ?instance.domain,
      'ip': ?instance.ip,
      'port': instance.port,
      'network': instance.network,
      'inboundTag': instance.inboundTag,
      'timeout': instance.timeout,
    };

CheckRouteResponse _$CheckRouteResponseFromJson(Map<String, dynamic> json) =>
    CheckRouteResponse(
      matched: json['matched'] as bool,
      ruleTag: json['ruleTag'] as String,
      outboundTag: json['outboundTag'] as String,
      balancerTag: json['balancerTag'] as String,
      defaulted: json['defaulted'] as bool,
    );

Map<String, dynamic> _$CheckRouteResponseToJson(CheckRouteResponse instance) =>
    <String, dynamic>{
      'matched': instance.matched,
      'ruleTag': instance.ruleTag,
      'outboundTag': instance.outboundTag,
      'balancerTag': instance.balancerTag,
      'defaulted': instance.defaulted,
    };

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
  LibXrayMethod.generateAgeKeyPair: 'generateAgeKeyPair',
  LibXrayMethod.countGeoData: 'countGeoData',
  LibXrayMethod.pingBatch: 'pingBatch',
  LibXrayMethod.testXray: 'testXray',
  LibXrayMethod.checkRoute: 'checkRoute',
  LibXrayMethod.runXray: 'runXray',
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
) => ConvertShareLinksToXrayJsonRequest(
  json['text'] as String?,
  age: json['age'] == null
      ? null
      : AgeDecryptConfig.fromJson(json['age'] as Map<String, dynamic>),
  includeStats: json['includeStats'] as bool?,
);

Map<String, dynamic> _$ConvertShareLinksToXrayJsonRequestToJson(
  ConvertShareLinksToXrayJsonRequest instance,
) => <String, dynamic>{
  'text': ?instance.text,
  'age': ?instance.age?.toJson(),
  'includeStats': ?instance.includeStats,
};

ConvertShareLinksReport _$ConvertShareLinksReportFromJson(
  Map<String, dynamic> json,
) => ConvertShareLinksReport(
  json['config'] as Map<String, dynamic>,
  usableCount: (json['usableCount'] as num?)?.toInt(),
  failedCount: (json['failedCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$ConvertShareLinksReportToJson(
  ConvertShareLinksReport instance,
) => <String, dynamic>{
  'config': instance.config,
  'usableCount': ?instance.usableCount,
  'failedCount': ?instance.failedCount,
};

AgeDecryptConfig _$AgeDecryptConfigFromJson(Map<String, dynamic> json) =>
    AgeDecryptConfig(json['secretKey'] as String?);

Map<String, dynamic> _$AgeDecryptConfigToJson(AgeDecryptConfig instance) =>
    <String, dynamic>{'secretKey': ?instance.secretKey};

GenerateAgeKeyPairRequest _$GenerateAgeKeyPairRequestFromJson(
  Map<String, dynamic> json,
) => GenerateAgeKeyPairRequest(
  $enumDecodeNullable(_$AgeKeyTypeEnumMap, json['keyType']),
);

Map<String, dynamic> _$GenerateAgeKeyPairRequestToJson(
  GenerateAgeKeyPairRequest instance,
) => <String, dynamic>{'keyType': ?_$AgeKeyTypeEnumMap[instance.keyType]};

const _$AgeKeyTypeEnumMap = {
  AgeKeyType.x25519: 'x25519',
  AgeKeyType.hybrid: 'hybrid',
};

GenerateAgeKeyPairResponse _$GenerateAgeKeyPairResponseFromJson(
  Map<String, dynamic> json,
) => GenerateAgeKeyPairResponse(
  json['secretKey'] as String?,
  json['publicKey'] as String?,
);

Map<String, dynamic> _$GenerateAgeKeyPairResponseToJson(
  GenerateAgeKeyPairResponse instance,
) => <String, dynamic>{
  'secretKey': ?instance.secretKey,
  'publicKey': ?instance.publicKey,
};

ConvertXrayJsonToShareLinksRequest _$ConvertXrayJsonToShareLinksRequestFromJson(
  Map<String, dynamic> json,
) => ConvertXrayJsonToShareLinksRequest(json['xrayJson'] as String?);

Map<String, dynamic> _$ConvertXrayJsonToShareLinksRequestToJson(
  ConvertXrayJsonToShareLinksRequest instance,
) => <String, dynamic>{'xrayJson': ?instance.xrayJson};
