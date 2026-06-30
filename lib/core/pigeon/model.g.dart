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
          : PingAuth.fromJson(json['pingAuth'] as Map<String, dynamic>),
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

PingAuth _$PingAuthFromJson(Map<String, dynamic> json) =>
    PingAuth(json['user'] as String?, json['pass'] as String?);

Map<String, dynamic> _$PingAuthToJson(PingAuth instance) => <String, dynamic>{
  'user': ?instance.user,
  'pass': ?instance.pass,
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

GetFreePortsResponse _$GetFreePortsResponseFromJson(
  Map<String, dynamic> json,
) => GetFreePortsResponse(
  (json['ports'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
);

Map<String, dynamic> _$GetFreePortsResponseToJson(
  GetFreePortsResponse instance,
) => <String, dynamic>{'ports': ?instance.ports};

CountGeoDataRequest _$CountGeoDataRequestFromJson(Map<String, dynamic> json) =>
    CountGeoDataRequest(json['name'] as String?, json['geoType'] as String?);

Map<String, dynamic> _$CountGeoDataRequestToJson(
  CountGeoDataRequest instance,
) => <String, dynamic>{'name': ?instance.name, 'geoType': ?instance.geoType};

PingRequest _$PingRequestFromJson(Map<String, dynamic> json) => PingRequest(
  json['configPath'] as String?,
  (json['timeout'] as num?)?.toInt(),
  json['url'] as String?,
  json['proxy'] as String?,
);

Map<String, dynamic> _$PingRequestToJson(PingRequest instance) =>
    <String, dynamic>{
      'configPath': ?instance.configPath,
      'timeout': ?instance.timeout,
      'url': ?instance.url,
      'proxy': ?instance.proxy,
    };

RunXrayRequest _$RunXrayRequestFromJson(Map<String, dynamic> json) =>
    RunXrayRequest(json['configPath'] as String?);

Map<String, dynamic> _$RunXrayRequestToJson(RunXrayRequest instance) =>
    <String, dynamic>{'configPath': ?instance.configPath};

LibXrayEnvJson _$LibXrayEnvJsonFromJson(Map<String, dynamic> json) =>
    LibXrayEnvJson(
      configLocation: json['xray.location.config'] as String?,
      confdirLocation: json['xray.location.confdir'] as String?,
      assetLocation: json['xray.location.asset'] as String?,
      certLocation: json['xray.location.cert'] as String?,
      useReadV: json['xray.buf.readv'] as String?,
      useFreedomSplice: json['xray.buf.splice'] as String?,
      useVmessPadding: json['xray.vmess.padding'] as String?,
      useCone: json['xray.cone.disabled'] as String?,
      useStrictJson: json['xray.json.strict'] as String?,
      bufferSize: json['xray.ray.buffer.size'] as String?,
      browserDialerAddress: json['xray.browser.dialer'] as String?,
      xudpLog: json['xray.xudp.show'] as String?,
      xudpBaseKey: json['xray.xudp.basekey'] as String?,
      tunFd: json['xray.tun.fd'] as String?,
    );

Map<String, dynamic> _$LibXrayEnvJsonToJson(LibXrayEnvJson instance) =>
    <String, dynamic>{
      'xray.location.config': ?instance.configLocation,
      'xray.location.confdir': ?instance.confdirLocation,
      'xray.location.asset': ?instance.assetLocation,
      'xray.location.cert': ?instance.certLocation,
      'xray.buf.readv': ?instance.useReadV,
      'xray.buf.splice': ?instance.useFreedomSplice,
      'xray.vmess.padding': ?instance.useVmessPadding,
      'xray.cone.disabled': ?instance.useCone,
      'xray.json.strict': ?instance.useStrictJson,
      'xray.ray.buffer.size': ?instance.bufferSize,
      'xray.browser.dialer': ?instance.browserDialerAddress,
      'xray.xudp.show': ?instance.xudpLog,
      'xray.xudp.basekey': ?instance.xudpBaseKey,
      'xray.tun.fd': ?instance.tunFd,
    };

LibXrayInvokeRequest _$LibXrayInvokeRequestFromJson(
  Map<String, dynamic> json,
) => LibXrayInvokeRequest(
  method: $enumDecodeNullable(_$LibXrayMethodEnumMap, json['method']),
  env: json['env'] == null
      ? null
      : LibXrayEnvJson.fromJson(json['env'] as Map<String, dynamic>),
  payload: json['payload'],
)..apiVersion = (json['apiVersion'] as num?)?.toInt();

Map<String, dynamic> _$LibXrayInvokeRequestToJson(
  LibXrayInvokeRequest instance,
) => <String, dynamic>{
  'apiVersion': ?instance.apiVersion,
  'method': ?_$LibXrayMethodEnumMap[instance.method],
  'env': ?instance.env?.toJson(),
  'payload': ?instance.payload,
};

const _$LibXrayMethodEnumMap = {
  LibXrayMethod.getFreePorts: 'getFreePorts',
  LibXrayMethod.convertShareLinksToXrayJson: 'convertShareLinksToXrayJson',
  LibXrayMethod.convertXrayJsonToShareLinks: 'convertXrayJsonToShareLinks',
  LibXrayMethod.countGeoData: 'countGeoData',
  LibXrayMethod.ping: 'ping',
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

RunXrayFromJsonRequest _$RunXrayFromJsonRequestFromJson(
  Map<String, dynamic> json,
) => RunXrayFromJsonRequest(json['configJSON'] as String?);

Map<String, dynamic> _$RunXrayFromJsonRequestToJson(
  RunXrayFromJsonRequest instance,
) => <String, dynamic>{'configJSON': ?instance.configJSON};
