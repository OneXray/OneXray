// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xray_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

XrayJson _$XrayJsonFromJson(Map<String, dynamic> json) => XrayJson(
  json['name'] as String?,
  json['log'] == null
      ? null
      : XrayLog.fromJson(json['log'] as Map<String, dynamic>),
  json['dns'] == null
      ? null
      : XrayDns.fromJson(json['dns'] as Map<String, dynamic>),
  json['routing'] == null
      ? null
      : XrayRouting.fromJson(json['routing'] as Map<String, dynamic>),
  (json['inbounds'] as List<dynamic>?)
      ?.map((e) => XrayInbound.fromJson(e as Map<String, dynamic>))
      .toList(),
  (json['outbounds'] as List<dynamic>?)
      ?.map((e) => XrayOutbound.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$XrayJsonToJson(XrayJson instance) => <String, dynamic>{
  'name': ?instance.name,
  'log': ?instance.log?.toJson(),
  'dns': ?instance.dns?.toJson(),
  'routing': ?instance.routing?.toJson(),
  'inbounds': ?instance.inbounds?.map((e) => e.toJson()).toList(),
  'outbounds': ?instance.outbounds?.map((e) => e.toJson()).toList(),
};

XrayLog _$XrayLogFromJson(Map<String, dynamic> json) => XrayLog(
  json['access'] as String?,
  json['error'] as String?,
  json['loglevel'] as String?,
  json['dnsLog'] as bool?,
  json['maskAddress'] as String?,
);

Map<String, dynamic> _$XrayLogToJson(XrayLog instance) => <String, dynamic>{
  'access': ?instance.access,
  'error': ?instance.error,
  'loglevel': ?instance.logLevel,
  'dnsLog': ?instance.dnsLog,
  'maskAddress': ?instance.maskAddress,
};

XrayDns _$XrayDnsFromJson(Map<String, dynamic> json) => XrayDns(
  (json['hosts'] as Map<String, dynamic>?)?.map(
    (k, e) =>
        MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
  ),
  (json['servers'] as List<dynamic>?)
      ?.map((e) => XrayDnsServer.fromJson(e as Map<String, dynamic>))
      .toList(),
  json['tag'] as String?,
  json['queryStrategy'] as String?,
  json['disableCache'] as bool?,
  json['disableFallback'] as bool?,
  json['disableFallbackIfMatch'] as bool?,
  json['useSystemHosts'] as bool?,
);

Map<String, dynamic> _$XrayDnsToJson(XrayDns instance) => <String, dynamic>{
  'hosts': ?instance.hosts,
  'servers': ?instance.servers?.map((e) => e.toJson()).toList(),
  'tag': ?instance.tag,
  'queryStrategy': ?instance.queryStrategy,
  'disableCache': ?instance.disableCache,
  'disableFallback': ?instance.disableFallback,
  'disableFallbackIfMatch': ?instance.disableFallbackIfMatch,
  'useSystemHosts': ?instance.useSystemHosts,
};

XrayDnsServer _$XrayDnsServerFromJson(Map<String, dynamic> json) =>
    XrayDnsServer(
      json['address'] as String?,
      json['skipFallback'] as bool?,
      (json['port'] as num?)?.toInt(),
      (json['domains'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['expectedIPs'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['unexpectedIPs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      json['queryStrategy'] as String?,
      json['tag'] as String?,
      json['disableCache'] as bool?,
      json['finalQuery'] as bool?,
    );

Map<String, dynamic> _$XrayDnsServerToJson(XrayDnsServer instance) =>
    <String, dynamic>{
      'address': ?instance.address,
      'port': ?instance.port,
      'skipFallback': ?instance.skipFallback,
      'domains': ?instance.domains,
      'expectedIPs': ?instance.expectedIPs,
      'unexpectedIPs': ?instance.unexpectedIPs,
      'queryStrategy': ?instance.queryStrategy,
      'tag': ?instance.tag,
      'disableCache': ?instance.disableCache,
      'finalQuery': ?instance.finalQuery,
    };

XrayRouting _$XrayRoutingFromJson(Map<String, dynamic> json) => XrayRouting(
  json['domainStrategy'] as String?,
  (json['rules'] as List<dynamic>?)
      ?.map((e) => XrayRoutingRule.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$XrayRoutingToJson(XrayRouting instance) =>
    <String, dynamic>{
      'domainStrategy': ?instance.domainStrategy,
      'rules': ?instance.rules?.map((e) => e.toJson()).toList(),
    };

XrayRoutingRule _$XrayRoutingRuleFromJson(Map<String, dynamic> json) =>
    XrayRoutingRule(
      (json['domain'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['ip'] as List<dynamic>?)?.map((e) => e as String).toList(),
      json['port'] as String?,
      json['sourcePort'] as String?,
      json['localPort'] as String?,
      json['network'] as String?,
      (json['sourceIP'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['localIP'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['user'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['inboundTag'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['protocol'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['attrs'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      json['outboundTag'] as String?,
      json['ruleTag'] as String?,
    );

Map<String, dynamic> _$XrayRoutingRuleToJson(XrayRoutingRule instance) =>
    <String, dynamic>{
      'domain': ?instance.domain,
      'ip': ?instance.ip,
      'port': ?instance.port,
      'sourcePort': ?instance.sourcePort,
      'localPort': ?instance.localPort,
      'network': ?instance.network,
      'sourceIP': ?instance.sourceIP,
      'localIP': ?instance.localIP,
      'user': ?instance.user,
      'inboundTag': ?instance.inboundTag,
      'protocol': ?instance.protocol,
      'attrs': ?instance.attrs,
      'outboundTag': ?instance.outboundTag,
      'ruleTag': ?instance.ruleTag,
    };

XrayInbound _$XrayInboundFromJson(Map<String, dynamic> json) => XrayInbound(
  json['listen'] as String?,
  json['port'] as String?,
  json['protocol'] as String?,
  json['settings'] as Map<String, dynamic>?,
  json['tag'] as String?,
  json['sniffing'] == null
      ? null
      : XrayInboundSniffing.fromJson(json['sniffing'] as Map<String, dynamic>),
);

Map<String, dynamic> _$XrayInboundToJson(XrayInbound instance) =>
    <String, dynamic>{
      'listen': ?instance.listen,
      'port': ?instance.port,
      'protocol': ?instance.protocol,
      'settings': ?instance.settings,
      'tag': ?instance.tag,
      'sniffing': ?instance.sniffing?.toJson(),
    };

XrayInboundSniffing _$XrayInboundSniffingFromJson(
  Map<String, dynamic> json,
) => XrayInboundSniffing(
  json['enabled'] as bool?,
  (json['destOverride'] as List<dynamic>?)?.map((e) => e as String).toList(),
  (json['domainsExcluded'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$XrayInboundSniffingToJson(
  XrayInboundSniffing instance,
) => <String, dynamic>{
  'enabled': ?instance.enabled,
  'destOverride': ?instance.destOverride,
  'domainsExcluded': ?instance.domainsExcluded,
};

XrayInboundTun _$XrayInboundTunFromJson(Map<String, dynamic> json) =>
    XrayInboundTun(json['name'] as String?, (json['MTU'] as num?)?.toInt());

Map<String, dynamic> _$XrayInboundTunToJson(XrayInboundTun instance) =>
    <String, dynamic>{'name': ?instance.name, 'MTU': ?instance.mtu};

XrayOutbound _$XrayOutboundFromJson(Map<String, dynamic> json) => XrayOutbound(
  json['name'] as String?,
  json['sendThrough'] as String?,
  json['protocol'] as String?,
  json['settings'] as Map<String, dynamic>?,
  json['tag'] as String?,
  json['streamSettings'] == null
      ? null
      : XrayStreamSettings.fromJson(
          json['streamSettings'] as Map<String, dynamic>,
        ),
  json['mux'] == null
      ? null
      : XrayMux.fromJson(json['mux'] as Map<String, dynamic>),
);

Map<String, dynamic> _$XrayOutboundToJson(XrayOutbound instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'sendThrough': ?instance.sendThrough,
      'protocol': ?instance.protocol,
      'settings': ?instance.settings,
      'tag': ?instance.tag,
      'streamSettings': ?instance.streamSettings?.toJson(),
      'mux': ?instance.mux?.toJson(),
    };

XrayOutboundShadowsocks _$XrayOutboundShadowsocksFromJson(
  Map<String, dynamic> json,
) => XrayOutboundShadowsocks(
  json['address'] as String?,
  (json['port'] as num?)?.toInt(),
  json['method'] as String?,
  json['password'] as String?,
  json['uot'] as bool?,
  (json['UoTVersion'] as num?)?.toInt(),
);

Map<String, dynamic> _$XrayOutboundShadowsocksToJson(
  XrayOutboundShadowsocks instance,
) => <String, dynamic>{
  'address': ?instance.address,
  'port': ?instance.port,
  'method': ?instance.method,
  'password': ?instance.password,
  'uot': ?instance.uot,
  'UoTVersion': ?instance.uotVersion,
};

XrayOutboundSocks _$XrayOutboundSocksFromJson(Map<String, dynamic> json) =>
    XrayOutboundSocks(
      json['address'] as String?,
      (json['port'] as num?)?.toInt(),
      json['user'] as String?,
      json['pass'] as String?,
    );

Map<String, dynamic> _$XrayOutboundSocksToJson(XrayOutboundSocks instance) =>
    <String, dynamic>{
      'address': ?instance.address,
      'port': ?instance.port,
      'user': ?instance.user,
      'pass': ?instance.pass,
    };

XrayOutboundTrojan _$XrayOutboundTrojanFromJson(Map<String, dynamic> json) =>
    XrayOutboundTrojan(
      json['address'] as String?,
      (json['port'] as num?)?.toInt(),
      json['password'] as String?,
    );

Map<String, dynamic> _$XrayOutboundTrojanToJson(XrayOutboundTrojan instance) =>
    <String, dynamic>{
      'address': ?instance.address,
      'port': ?instance.port,
      'password': ?instance.password,
    };

XrayOutboundVLESS _$XrayOutboundVLESSFromJson(Map<String, dynamic> json) =>
    XrayOutboundVLESS(
      json['address'] as String?,
      (json['port'] as num?)?.toInt(),
      json['id'] as String?,
      json['flow'] as String?,
      json['encryption'] as String?,
      json['reverse'] == null
          ? null
          : XrayOutboundVLESSReverse.fromJson(
              json['reverse'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$XrayOutboundVLESSToJson(XrayOutboundVLESS instance) =>
    <String, dynamic>{
      'address': ?instance.address,
      'port': ?instance.port,
      'id': ?instance.id,
      'flow': ?instance.flow,
      'encryption': ?instance.encryption,
      'reverse': ?instance.reverse?.toJson(),
    };

XrayOutboundVLESSReverse _$XrayOutboundVLESSReverseFromJson(
  Map<String, dynamic> json,
) => XrayOutboundVLESSReverse(json['tag'] as String?);

Map<String, dynamic> _$XrayOutboundVLESSReverseToJson(
  XrayOutboundVLESSReverse instance,
) => <String, dynamic>{'tag': ?instance.tag};

XrayOutboundVMess _$XrayOutboundVMessFromJson(Map<String, dynamic> json) =>
    XrayOutboundVMess(
      json['address'] as String?,
      (json['port'] as num?)?.toInt(),
      json['id'] as String?,
      json['security'] as String?,
    );

Map<String, dynamic> _$XrayOutboundVMessToJson(XrayOutboundVMess instance) =>
    <String, dynamic>{
      'address': ?instance.address,
      'port': ?instance.port,
      'id': ?instance.id,
      'security': ?instance.security,
    };

XrayOutboundHysteria _$XrayOutboundHysteriaFromJson(
  Map<String, dynamic> json,
) => XrayOutboundHysteria(
  (json['version'] as num?)?.toInt(),
  json['address'] as String?,
  (json['port'] as num?)?.toInt(),
);

Map<String, dynamic> _$XrayOutboundHysteriaToJson(
  XrayOutboundHysteria instance,
) => <String, dynamic>{
  'version': ?instance.version,
  'address': ?instance.address,
  'port': ?instance.port,
};

XrayOutboundFreedom _$XrayOutboundFreedomFromJson(Map<String, dynamic> json) =>
    XrayOutboundFreedom(
      json['fragment'] == null
          ? null
          : XrayOutboundFreedomFragment.fromJson(
              json['fragment'] as Map<String, dynamic>,
            ),
      (json['noises'] as List<dynamic>?)
          ?.map(
            (e) =>
                XrayOutboundFreedomNoises.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$XrayOutboundFreedomToJson(
  XrayOutboundFreedom instance,
) => <String, dynamic>{
  'fragment': ?instance.fragment?.toJson(),
  'noises': ?instance.noises?.map((e) => e.toJson()).toList(),
};

XrayOutboundFreedomFragment _$XrayOutboundFreedomFragmentFromJson(
  Map<String, dynamic> json,
) => XrayOutboundFreedomFragment(
  json['packets'] as String?,
  json['length'] as String?,
  json['interval'] as String?,
);

Map<String, dynamic> _$XrayOutboundFreedomFragmentToJson(
  XrayOutboundFreedomFragment instance,
) => <String, dynamic>{
  'packets': ?instance.packets,
  'length': ?instance.length,
  'interval': ?instance.interval,
};

XrayOutboundFreedomNoises _$XrayOutboundFreedomNoisesFromJson(
  Map<String, dynamic> json,
) => XrayOutboundFreedomNoises(
  json['type'] as String?,
  json['packet'] as String?,
  json['delay'] as String?,
);

Map<String, dynamic> _$XrayOutboundFreedomNoisesToJson(
  XrayOutboundFreedomNoises instance,
) => <String, dynamic>{
  'type': ?instance.type,
  'packet': ?instance.packet,
  'delay': ?instance.delay,
};

XrayOutboundDns _$XrayOutboundDnsFromJson(Map<String, dynamic> json) =>
    XrayOutboundDns(
      json['network'] as String?,
      json['address'] as String?,
      (json['port'] as num?)?.toInt(),
      json['nonIPQuery'] as String?,
    );

Map<String, dynamic> _$XrayOutboundDnsToJson(XrayOutboundDns instance) =>
    <String, dynamic>{
      'network': ?instance.network,
      'address': ?instance.address,
      'port': ?instance.port,
      'nonIPQuery': ?instance.nonIPQuery,
    };

XrayStreamSettings _$XrayStreamSettingsFromJson(
  Map<String, dynamic> json,
) => XrayStreamSettings(
  json['address'] as String?,
  (json['port'] as num?)?.toInt(),
  json['network'] as String?,
  json['security'] as String?,
  json['tlsSettings'] == null
      ? null
      : XrayTlsSettings.fromJson(json['tlsSettings'] as Map<String, dynamic>),
  json['realitySettings'] == null
      ? null
      : XrayRealitySettings.fromJson(
          json['realitySettings'] as Map<String, dynamic>,
        ),
  json['rawSettings'] == null
      ? null
      : XrayRawSettings.fromJson(json['rawSettings'] as Map<String, dynamic>),
  json['kcpSettings'] == null
      ? null
      : XrayKcpSettings.fromJson(json['kcpSettings'] as Map<String, dynamic>),
  json['wsSettings'] == null
      ? null
      : XrayWsSettings.fromJson(json['wsSettings'] as Map<String, dynamic>),
  json['grpcSettings'] == null
      ? null
      : XrayGrpcSettings.fromJson(json['grpcSettings'] as Map<String, dynamic>),
  json['httpupgradeSettings'] == null
      ? null
      : XrayHttpupgradeSettings.fromJson(
          json['httpupgradeSettings'] as Map<String, dynamic>,
        ),
  json['xhttpSettings'] == null
      ? null
      : XrayXhttpSettings.fromJson(
          json['xhttpSettings'] as Map<String, dynamic>,
        ),
  json['hysteriaSettings'] == null
      ? null
      : XrayHysteriaSettings.fromJson(
          json['hysteriaSettings'] as Map<String, dynamic>,
        ),
  json['finalmask'] as Map<String, dynamic>?,
  json['sockopt'] == null
      ? null
      : XraySockopt.fromJson(json['sockopt'] as Map<String, dynamic>),
);

Map<String, dynamic> _$XrayStreamSettingsToJson(XrayStreamSettings instance) =>
    <String, dynamic>{
      'address': ?instance.address,
      'port': ?instance.port,
      'network': ?instance.network,
      'security': ?instance.security,
      'tlsSettings': ?instance.tlsSettings?.toJson(),
      'realitySettings': ?instance.realitySettings?.toJson(),
      'rawSettings': ?instance.rawSettings?.toJson(),
      'kcpSettings': ?instance.kcpSettings?.toJson(),
      'wsSettings': ?instance.wsSettings?.toJson(),
      'grpcSettings': ?instance.grpcSettings?.toJson(),
      'httpupgradeSettings': ?instance.httpupgradeSettings?.toJson(),
      'xhttpSettings': ?instance.xhttpSettings?.toJson(),
      'hysteriaSettings': ?instance.hysteriaSettings?.toJson(),
      'finalmask': ?instance.finalmask,
      'sockopt': ?instance.sockopt?.toJson(),
    };

XrayTlsSettings _$XrayTlsSettingsFromJson(Map<String, dynamic> json) =>
    XrayTlsSettings(
      json['serverName'] as String?,
      (json['alpn'] as List<dynamic>?)?.map((e) => e as String).toList(),
      json['fingerprint'] as String?,
      json['pinnedPeerCertSha256'] as String?,
      json['verifyPeerCertByName'] as String?,
      json['echConfigList'] as String?,
      json['echForceQuery'] as String?,
    );

Map<String, dynamic> _$XrayTlsSettingsToJson(XrayTlsSettings instance) =>
    <String, dynamic>{
      'serverName': ?instance.serverName,
      'alpn': ?instance.alpn,
      'fingerprint': ?instance.fingerprint,
      'pinnedPeerCertSha256': ?instance.pinnedPeerCertSha256,
      'verifyPeerCertByName': ?instance.verifyPeerCertByName,
      'echConfigList': ?instance.echConfigList,
      'echForceQuery': ?instance.echForceQuery,
    };

XrayRealitySettings _$XrayRealitySettingsFromJson(Map<String, dynamic> json) =>
    XrayRealitySettings(
      json['show'] as bool?,
      json['fingerprint'] as String?,
      json['serverName'] as String?,
      json['publicKey'] as String?,
      json['password'] as String?,
      json['shortId'] as String?,
      json['mldsa65Verify'] as String?,
      json['spiderX'] as String?,
    );

Map<String, dynamic> _$XrayRealitySettingsToJson(
  XrayRealitySettings instance,
) => <String, dynamic>{
  'show': ?instance.show,
  'fingerprint': ?instance.fingerprint,
  'serverName': ?instance.serverName,
  'publicKey': ?instance.publicKey,
  'password': ?instance.password,
  'shortId': ?instance.shortId,
  'mldsa65Verify': ?instance.mldsa65Verify,
  'spiderX': ?instance.spiderX,
};

XrayRawSettings _$XrayRawSettingsFromJson(Map<String, dynamic> json) =>
    XrayRawSettings(
      json['header'] == null
          ? null
          : XrayRawSettingsHeader.fromJson(
              json['header'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$XrayRawSettingsToJson(XrayRawSettings instance) =>
    <String, dynamic>{'header': ?instance.header?.toJson()};

XrayRawSettingsHeader _$XrayRawSettingsHeaderFromJson(
  Map<String, dynamic> json,
) => XrayRawSettingsHeader(
  json['type'] as String?,
  json['request'] == null
      ? null
      : XrayRawSettingsHeaderRequest.fromJson(
          json['request'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$XrayRawSettingsHeaderToJson(
  XrayRawSettingsHeader instance,
) => <String, dynamic>{
  'type': ?instance.type,
  'request': ?instance.request?.toJson(),
};

XrayRawSettingsHeaderRequest _$XrayRawSettingsHeaderRequestFromJson(
  Map<String, dynamic> json,
) => XrayRawSettingsHeaderRequest(
  (json['path'] as List<dynamic>?)?.map((e) => e as String).toList(),
  json['headers'] == null
      ? null
      : XrayRawSettingsHeaderRequestHeaders.fromJson(
          json['headers'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$XrayRawSettingsHeaderRequestToJson(
  XrayRawSettingsHeaderRequest instance,
) => <String, dynamic>{
  'path': ?instance.path,
  'headers': ?instance.headers?.toJson(),
};

XrayRawSettingsHeaderRequestHeaders
_$XrayRawSettingsHeaderRequestHeadersFromJson(Map<String, dynamic> json) =>
    XrayRawSettingsHeaderRequestHeaders(
      (json['Host'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$XrayRawSettingsHeaderRequestHeadersToJson(
  XrayRawSettingsHeaderRequestHeaders instance,
) => <String, dynamic>{'Host': ?instance.host};

XrayKcpSettings _$XrayKcpSettingsFromJson(Map<String, dynamic> json) =>
    XrayKcpSettings(
      json['header'] == null
          ? null
          : XrayKcpHeader.fromJson(json['header'] as Map<String, dynamic>),
      json['seed'] as String?,
    );

Map<String, dynamic> _$XrayKcpSettingsToJson(XrayKcpSettings instance) =>
    <String, dynamic>{
      'header': ?instance.header?.toJson(),
      'seed': ?instance.seed,
    };

XrayKcpHeader _$XrayKcpHeaderFromJson(Map<String, dynamic> json) =>
    XrayKcpHeader(json['type'] as String?, json['domain'] as String?);

Map<String, dynamic> _$XrayKcpHeaderToJson(XrayKcpHeader instance) =>
    <String, dynamic>{'type': ?instance.type, 'domain': ?instance.domain};

XrayWsSettings _$XrayWsSettingsFromJson(Map<String, dynamic> json) =>
    XrayWsSettings(json['path'] as String?, json['host'] as String?);

Map<String, dynamic> _$XrayWsSettingsToJson(XrayWsSettings instance) =>
    <String, dynamic>{'path': ?instance.path, 'host': ?instance.host};

XrayGrpcSettings _$XrayGrpcSettingsFromJson(Map<String, dynamic> json) =>
    XrayGrpcSettings(
      json['authority'] as String?,
      json['serviceName'] as String?,
      json['multiMode'] as bool?,
    );

Map<String, dynamic> _$XrayGrpcSettingsToJson(XrayGrpcSettings instance) =>
    <String, dynamic>{
      'authority': ?instance.authority,
      'serviceName': ?instance.serviceName,
      'multiMode': ?instance.multiMode,
    };

XrayHttpupgradeSettings _$XrayHttpupgradeSettingsFromJson(
  Map<String, dynamic> json,
) => XrayHttpupgradeSettings(json['host'] as String?, json['path'] as String?);

Map<String, dynamic> _$XrayHttpupgradeSettingsToJson(
  XrayHttpupgradeSettings instance,
) => <String, dynamic>{'host': ?instance.host, 'path': ?instance.path};

XrayXhttpSettings _$XrayXhttpSettingsFromJson(Map<String, dynamic> json) =>
    XrayXhttpSettings(
      json['host'] as String?,
      json['path'] as String?,
      json['mode'] as String?,
      (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      json['xPaddingBytes'] as String?,
      json['noGRPCHeader'] as bool?,
      json['scMaxEachPostBytes'] as String?,
      json['scMinPostsIntervalMs'] as String?,
      json['xmux'] == null
          ? null
          : XrayXhttpSettingsXmux.fromJson(
              json['xmux'] as Map<String, dynamic>,
            ),
      json['downloadSettings'] == null
          ? null
          : XrayStreamSettings.fromJson(
              json['downloadSettings'] as Map<String, dynamic>,
            ),
      json['extra'] == null
          ? null
          : XrayXhttpSettings.fromJson(json['extra'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$XrayXhttpSettingsToJson(XrayXhttpSettings instance) =>
    <String, dynamic>{
      'host': ?instance.host,
      'path': ?instance.path,
      'mode': ?instance.mode,
      'headers': ?instance.headers,
      'xPaddingBytes': ?instance.xPaddingBytes,
      'noGRPCHeader': ?instance.noGRPCHeader,
      'scMaxEachPostBytes': ?instance.scMaxEachPostBytes,
      'scMinPostsIntervalMs': ?instance.scMinPostsIntervalMs,
      'xmux': ?instance.xmux?.toJson(),
      'downloadSettings': ?instance.downloadSettings?.toJson(),
      'extra': ?instance.extra?.toJson(),
    };

XrayXhttpSettingsXmux _$XrayXhttpSettingsXmuxFromJson(
  Map<String, dynamic> json,
) => XrayXhttpSettingsXmux(
  json['maxConcurrency'] as String?,
  json['maxConnections'] as String?,
  json['cMaxReuseTimes'] as String?,
  json['hMaxReusableSecs'] as String?,
  json['hMaxRequestTimes'] as String?,
  (json['hKeepAlivePeriod'] as num?)?.toInt(),
);

Map<String, dynamic> _$XrayXhttpSettingsXmuxToJson(
  XrayXhttpSettingsXmux instance,
) => <String, dynamic>{
  'maxConcurrency': ?instance.maxConcurrency,
  'maxConnections': ?instance.maxConnections,
  'cMaxReuseTimes': ?instance.cMaxReuseTimes,
  'hMaxReusableSecs': ?instance.hMaxReusableSecs,
  'hMaxRequestTimes': ?instance.hMaxRequestTimes,
  'hKeepAlivePeriod': ?instance.hKeepAlivePeriod,
};

XrayHysteriaSettings _$XrayHysteriaSettingsFromJson(
  Map<String, dynamic> json,
) => XrayHysteriaSettings(
  (json['version'] as num?)?.toInt(),
  json['auth'] as String?,
  json['up'] as String?,
  json['down'] as String?,
  json['udphop'] == null
      ? null
      : XrayHysteriaSettingsUdphop.fromJson(
          json['udphop'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$XrayHysteriaSettingsToJson(
  XrayHysteriaSettings instance,
) => <String, dynamic>{
  'version': ?instance.version,
  'auth': ?instance.auth,
  'up': ?instance.up,
  'down': ?instance.down,
  'udphop': ?instance.udphop?.toJson(),
};

XrayHysteriaSettingsUdphop _$XrayHysteriaSettingsUdphopFromJson(
  Map<String, dynamic> json,
) => XrayHysteriaSettingsUdphop(
  json['port'] as String?,
  (json['interval'] as num?)?.toInt(),
);

Map<String, dynamic> _$XrayHysteriaSettingsUdphopToJson(
  XrayHysteriaSettingsUdphop instance,
) => <String, dynamic>{'port': ?instance.port, 'interval': ?instance.interval};

XraySockopt _$XraySockoptFromJson(Map<String, dynamic> json) => XraySockopt(
  json['dialerProxy'] as String?,
  json['tcpFastOpen'] as bool?,
  json['interface'] as String?,
  json['tcpMptcp'] as bool?,
);

Map<String, dynamic> _$XraySockoptToJson(XraySockopt instance) =>
    <String, dynamic>{
      'dialerProxy': ?instance.dialerProxy,
      'tcpFastOpen': ?instance.tcpFastOpen,
      'interface': ?instance.interface,
      'tcpMptcp': ?instance.tcpMptcp,
    };

XrayMux _$XrayMuxFromJson(Map<String, dynamic> json) => XrayMux(
  json['enabled'] as bool?,
  (json['concurrency'] as num?)?.toInt(),
  (json['xudpConcurrency'] as num?)?.toInt(),
  json['xudpProxyUDP443'] as String?,
);

Map<String, dynamic> _$XrayMuxToJson(XrayMux instance) => <String, dynamic>{
  'enabled': ?instance.enabled,
  'concurrency': ?instance.concurrency,
  'xudpConcurrency': ?instance.xudpConcurrency,
  'xudpProxyUDP443': ?instance.xudpProxyUDP443,
};
