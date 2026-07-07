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
  json['policy'] == null
      ? null
      : XrayPolicy.fromJson(json['policy'] as Map<String, dynamic>),
  json['stats'] == null
      ? null
      : XrayStats.fromJson(json['stats'] as Map<String, dynamic>),
  json['metrics'] == null
      ? null
      : XrayMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
  (json['fakeDns'] as List<dynamic>?)
      ?.map((e) => XrayFakeDns.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$XrayJsonToJson(XrayJson instance) => <String, dynamic>{
  'name': ?instance.name,
  'log': ?instance.log?.toJson(),
  'dns': ?instance.dns?.toJson(),
  'routing': ?instance.routing?.toJson(),
  'inbounds': ?instance.inbounds?.map((e) => e.toJson()).toList(),
  'outbounds': ?instance.outbounds?.map((e) => e.toJson()).toList(),
  'policy': ?instance.policy?.toJson(),
  'stats': ?instance.stats?.toJson(),
  'metrics': ?instance.metrics?.toJson(),
  'fakeDns': ?instance.fakeDns?.map((e) => e.toJson()).toList(),
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

XrayPolicy _$XrayPolicyFromJson(Map<String, dynamic> json) => XrayPolicy(
  (json['levels'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, XrayPolicyLevel.fromJson(e as Map<String, dynamic>)),
  ),
  json['system'] == null
      ? null
      : XrayPolicySystem.fromJson(json['system'] as Map<String, dynamic>),
);

Map<String, dynamic> _$XrayPolicyToJson(XrayPolicy instance) =>
    <String, dynamic>{
      'levels': ?instance.levels?.map((k, e) => MapEntry(k, e.toJson())),
      'system': ?instance.system?.toJson(),
    };

XrayPolicyLevel _$XrayPolicyLevelFromJson(Map<String, dynamic> json) =>
    XrayPolicyLevel(
      (json['handshake'] as num?)?.toInt(),
      (json['connIdle'] as num?)?.toInt(),
      (json['uplinkOnly'] as num?)?.toInt(),
      (json['downlinkOnly'] as num?)?.toInt(),
      json['statsUserUplink'] as bool?,
      json['statsUserDownlink'] as bool?,
      json['statsUserOnline'] as bool?,
      (json['bufferSize'] as num?)?.toInt(),
    );

Map<String, dynamic> _$XrayPolicyLevelToJson(XrayPolicyLevel instance) =>
    <String, dynamic>{
      'handshake': ?instance.handshake,
      'connIdle': ?instance.connIdle,
      'uplinkOnly': ?instance.uplinkOnly,
      'downlinkOnly': ?instance.downlinkOnly,
      'statsUserUplink': ?instance.statsUserUplink,
      'statsUserDownlink': ?instance.statsUserDownlink,
      'statsUserOnline': ?instance.statsUserOnline,
      'bufferSize': ?instance.bufferSize,
    };

XrayPolicySystem _$XrayPolicySystemFromJson(Map<String, dynamic> json) =>
    XrayPolicySystem(
      json['statsInboundUplink'] as bool?,
      json['statsInboundDownlink'] as bool?,
      json['statsOutboundUplink'] as bool?,
      json['statsOutboundDownlink'] as bool?,
    );

Map<String, dynamic> _$XrayPolicySystemToJson(XrayPolicySystem instance) =>
    <String, dynamic>{
      'statsInboundUplink': ?instance.statsInboundUplink,
      'statsInboundDownlink': ?instance.statsInboundDownlink,
      'statsOutboundUplink': ?instance.statsOutboundUplink,
      'statsOutboundDownlink': ?instance.statsOutboundDownlink,
    };

XrayStats _$XrayStatsFromJson(Map<String, dynamic> json) => XrayStats();

Map<String, dynamic> _$XrayStatsToJson(XrayStats instance) =>
    <String, dynamic>{};

XrayMetrics _$XrayMetricsFromJson(Map<String, dynamic> json) =>
    XrayMetrics(json['listen'] as String?);

Map<String, dynamic> _$XrayMetricsToJson(XrayMetrics instance) =>
    <String, dynamic>{'listen': ?instance.listen};

XrayDns _$XrayDnsFromJson(Map<String, dynamic> json) => XrayDns(
  (json['hosts'] as Map<String, dynamic>?)?.map(
    (k, e) =>
        MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
  ),
  (json['servers'] as List<dynamic>?)
      ?.map((e) => XrayDnsServer.fromJson(e as Map<String, dynamic>))
      .toList(),
  json['clientIp'] as String?,
  json['tag'] as String?,
  json['queryStrategy'] as String?,
  json['disableCache'] as bool?,
  json['serveStale'] as bool?,
  (json['serveExpiredTTL'] as num?)?.toInt(),
  json['disableFallback'] as bool?,
  json['disableFallbackIfMatch'] as bool?,
  json['enableParallelQuery'] as bool?,
  json['useSystemHosts'] as bool?,
);

Map<String, dynamic> _$XrayDnsToJson(XrayDns instance) => <String, dynamic>{
  'hosts': ?instance.hosts,
  'servers': ?instance.servers?.map((e) => e.toJson()).toList(),
  'clientIp': ?instance.clientIp,
  'tag': ?instance.tag,
  'queryStrategy': ?instance.queryStrategy,
  'disableCache': ?instance.disableCache,
  'serveStale': ?instance.serveStale,
  'serveExpiredTTL': ?instance.serveExpiredTTL,
  'disableFallback': ?instance.disableFallback,
  'disableFallbackIfMatch': ?instance.disableFallbackIfMatch,
  'enableParallelQuery': ?instance.enableParallelQuery,
  'useSystemHosts': ?instance.useSystemHosts,
};

XrayDnsServer _$XrayDnsServerFromJson(Map<String, dynamic> json) =>
    XrayDnsServer(
      json['address'] as String?,
      json['clientIp'] as String?,
      json['skipFallback'] as bool?,
      (json['port'] as num?)?.toInt(),
      (json['domains'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['expectedIPs'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['unexpectedIPs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      json['queryStrategy'] as String?,
      json['tag'] as String?,
      (json['timeoutMs'] as num?)?.toInt(),
      json['disableCache'] as bool?,
      json['serveStale'] as bool?,
      (json['serveExpiredTTL'] as num?)?.toInt(),
      json['finalQuery'] as bool?,
    );

Map<String, dynamic> _$XrayDnsServerToJson(XrayDnsServer instance) =>
    <String, dynamic>{
      'address': ?instance.address,
      'clientIp': ?instance.clientIp,
      'port': ?instance.port,
      'skipFallback': ?instance.skipFallback,
      'domains': ?instance.domains,
      'expectedIPs': ?instance.expectedIPs,
      'unexpectedIPs': ?instance.unexpectedIPs,
      'queryStrategy': ?instance.queryStrategy,
      'tag': ?instance.tag,
      'timeoutMs': ?instance.timeoutMs,
      'disableCache': ?instance.disableCache,
      'serveStale': ?instance.serveStale,
      'serveExpiredTTL': ?instance.serveExpiredTTL,
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
      (json['process'] as List<dynamic>?)?.map((e) => e as String).toList(),
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
      'process': ?instance.process,
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

XrayInboundAccount _$XrayInboundAccountFromJson(Map<String, dynamic> json) =>
    XrayInboundAccount(json['user'] as String?, json['pass'] as String?);

Map<String, dynamic> _$XrayInboundAccountToJson(XrayInboundAccount instance) =>
    <String, dynamic>{'user': ?instance.user, 'pass': ?instance.pass};

XrayInboundSocksSettings _$XrayInboundSocksSettingsFromJson(
  Map<String, dynamic> json,
) => XrayInboundSocksSettings(
  json['auth'] as String?,
  json['udp'] as bool?,
  (json['users'] as List<dynamic>?)
      ?.map((e) => XrayInboundAccount.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$XrayInboundSocksSettingsToJson(
  XrayInboundSocksSettings instance,
) => <String, dynamic>{
  'auth': ?instance.auth,
  'udp': ?instance.udp,
  'users': ?instance.users?.map((e) => e.toJson()).toList(),
};

XrayInboundHttpSettings _$XrayInboundHttpSettingsFromJson(
  Map<String, dynamic> json,
) => XrayInboundHttpSettings(
  json['allowTransparent'] as bool?,
  (json['users'] as List<dynamic>?)
      ?.map((e) => XrayInboundAccount.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$XrayInboundHttpSettingsToJson(
  XrayInboundHttpSettings instance,
) => <String, dynamic>{
  'allowTransparent': ?instance.allowTransparent,
  'users': ?instance.users?.map((e) => e.toJson()).toList(),
};

XrayInboundSniffing _$XrayInboundSniffingFromJson(
  Map<String, dynamic> json,
) => XrayInboundSniffing(
  json['enabled'] as bool?,
  json['routeOnly'] as bool?,
  (json['destOverride'] as List<dynamic>?)?.map((e) => e as String).toList(),
  (json['domainsExcluded'] as List<dynamic>?)?.map((e) => e as String).toList(),
  (json['ipsExcluded'] as List<dynamic>?)?.map((e) => e as String).toList(),
  json['metadataOnly'] as bool?,
);

Map<String, dynamic> _$XrayInboundSniffingToJson(
  XrayInboundSniffing instance,
) => <String, dynamic>{
  'enabled': ?instance.enabled,
  'routeOnly': ?instance.routeOnly,
  'destOverride': ?instance.destOverride,
  'domainsExcluded': ?instance.domainsExcluded,
  'ipsExcluded': ?instance.ipsExcluded,
  'metadataOnly': ?instance.metadataOnly,
};

XrayInboundTun _$XrayInboundTunFromJson(Map<String, dynamic> json) =>
    XrayInboundTun(
      json['name'] as String?,
      (json['mtu'] as num?)?.toInt(),
      (json['gateway'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['dns'] as List<dynamic>?)?.map((e) => e as String).toList(),
      (json['autoSystemRoutingTable'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      json['autoOutboundsInterface'] as String?,
    );

Map<String, dynamic> _$XrayInboundTunToJson(XrayInboundTun instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'mtu': ?instance.mtu,
      'gateway': ?instance.gateway,
      'dns': ?instance.dns,
      'autoSystemRoutingTable': ?instance.autoSystemRoutingTable,
      'autoOutboundsInterface': ?instance.autoOutboundsInterface,
    };

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
  json['targetStrategy'] as String?,
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
      'targetStrategy': ?instance.targetStrategy,
    };

XrayOutboundShadowsocks _$XrayOutboundShadowsocksFromJson(
  Map<String, dynamic> json,
) => XrayOutboundShadowsocks(
  json['address'] as String?,
  (json['port'] as num?)?.toInt(),
  json['method'] as String?,
  json['password'] as String?,
);

Map<String, dynamic> _$XrayOutboundShadowsocksToJson(
  XrayOutboundShadowsocks instance,
) => <String, dynamic>{
  'address': ?instance.address,
  'port': ?instance.port,
  'method': ?instance.method,
  'password': ?instance.password,
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

XrayOutboundHttp _$XrayOutboundHttpFromJson(Map<String, dynamic> json) =>
    XrayOutboundHttp(
      json['address'] as String?,
      (json['port'] as num?)?.toInt(),
      json['user'] as String?,
      json['pass'] as String?,
      (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$XrayOutboundHttpToJson(XrayOutboundHttp instance) =>
    <String, dynamic>{
      'address': ?instance.address,
      'port': ?instance.port,
      'user': ?instance.user,
      'pass': ?instance.pass,
      'headers': ?instance.headers,
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
      (json['rules'] as List<dynamic>?)
          ?.map((e) => XrayOutboundDnsRule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$XrayOutboundDnsToJson(XrayOutboundDns instance) =>
    <String, dynamic>{
      'network': ?instance.network,
      'address': ?instance.address,
      'port': ?instance.port,
      'rules': ?instance.rules?.map((e) => e.toJson()).toList(),
    };

XrayOutboundDnsRule _$XrayOutboundDnsRuleFromJson(Map<String, dynamic> json) =>
    XrayOutboundDnsRule(
      json['action'] as String?,
      json['qType'] as String?,
      json['domain'],
      (json['rCode'] as num?)?.toInt(),
    );

Map<String, dynamic> _$XrayOutboundDnsRuleToJson(
  XrayOutboundDnsRule instance,
) => <String, dynamic>{
  'action': ?instance.action,
  'qType': ?instance.qType,
  'domain': ?instance.domain,
  'rCode': ?instance.rCode,
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
    );

Map<String, dynamic> _$XrayTlsSettingsToJson(XrayTlsSettings instance) =>
    <String, dynamic>{
      'serverName': ?instance.serverName,
      'alpn': ?instance.alpn,
      'fingerprint': ?instance.fingerprint,
      'pinnedPeerCertSha256': ?instance.pinnedPeerCertSha256,
      'verifyPeerCertByName': ?instance.verifyPeerCertByName,
      'echConfigList': ?instance.echConfigList,
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
    XrayKcpSettings();

Map<String, dynamic> _$XrayKcpSettingsToJson(XrayKcpSettings instance) =>
    <String, dynamic>{};

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
      json['extra'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$XrayXhttpSettingsToJson(XrayXhttpSettings instance) =>
    <String, dynamic>{
      'host': ?instance.host,
      'path': ?instance.path,
      'mode': ?instance.mode,
      'extra': ?instance.extra,
    };

XrayHysteriaSettings _$XrayHysteriaSettingsFromJson(
  Map<String, dynamic> json,
) => XrayHysteriaSettings(
  (json['version'] as num?)?.toInt(),
  json['auth'] as String?,
);

Map<String, dynamic> _$XrayHysteriaSettingsToJson(
  XrayHysteriaSettings instance,
) => <String, dynamic>{'version': ?instance.version, 'auth': ?instance.auth};

XrayHysteriaSettingsUdphop _$XrayHysteriaSettingsUdphopFromJson(
  Map<String, dynamic> json,
) => XrayHysteriaSettingsUdphop(
  json['ports'] as String?,
  (json['interval'] as num?)?.toInt(),
);

Map<String, dynamic> _$XrayHysteriaSettingsUdphopToJson(
  XrayHysteriaSettingsUdphop instance,
) => <String, dynamic>{
  'ports': ?instance.ports,
  'interval': ?instance.interval,
};

XraySockopt _$XraySockoptFromJson(Map<String, dynamic> json) => XraySockopt(
  json['dialerProxy'] as String?,
  json['tcpFastOpen'] as bool?,
  json['domainStrategy'] as String?,
  json['v6only'] as bool?,
  json['interface'] as String?,
  json['tcpMptcp'] as bool?,
  json['addressPortStrategy'] as String?,
  json['happyEyeballs'] == null
      ? null
      : XrayHappyEyeballs.fromJson(
          json['happyEyeballs'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$XraySockoptToJson(XraySockopt instance) =>
    <String, dynamic>{
      'dialerProxy': ?instance.dialerProxy,
      'tcpFastOpen': ?instance.tcpFastOpen,
      'domainStrategy': ?instance.domainStrategy,
      'v6only': ?instance.v6only,
      'interface': ?instance.interface,
      'tcpMptcp': ?instance.tcpMptcp,
      'addressPortStrategy': ?instance.addressPortStrategy,
      'happyEyeballs': ?instance.happyEyeballs?.toJson(),
    };

XrayHappyEyeballs _$XrayHappyEyeballsFromJson(Map<String, dynamic> json) =>
    XrayHappyEyeballs(
      json['prioritizeIPv6'] as bool?,
      (json['tryDelayMs'] as num?)?.toInt(),
      (json['interleave'] as num?)?.toInt(),
      (json['maxConcurrentTry'] as num?)?.toInt(),
    );

Map<String, dynamic> _$XrayHappyEyeballsToJson(XrayHappyEyeballs instance) =>
    <String, dynamic>{
      'prioritizeIPv6': ?instance.prioritizeIPv6,
      'tryDelayMs': ?instance.tryDelayMs,
      'interleave': ?instance.interleave,
      'maxConcurrentTry': ?instance.maxConcurrentTry,
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

XrayFakeDns _$XrayFakeDnsFromJson(Map<String, dynamic> json) =>
    XrayFakeDns(json['ipPool'] as String?, (json['poolSize'] as num?)?.toInt());

Map<String, dynamic> _$XrayFakeDnsToJson(XrayFakeDns instance) =>
    <String, dynamic>{
      'ipPool': ?instance.ipPool,
      'poolSize': ?instance.poolSize,
    };
