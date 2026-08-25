// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xray_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

XrayJson _$XrayJsonFromJson(Map<String, dynamic> json) => XrayJson(
  json['name'] as String?,
  json['env'] == null
      ? null
      : XrayEnv.fromJson(json['env'] as Map<String, dynamic>),
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
      ?.map((e) => e as Map<String, dynamic>)
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
  'env': ?instance.env?.toJson(),
  'log': ?instance.log?.toJson(),
  'dns': ?instance.dns?.toJson(),
  'routing': ?instance.routing?.toJson(),
  'inbounds': ?instance.inbounds?.map((e) => e.toJson()).toList(),
  'outbounds': ?instance.outbounds,
  'policy': ?instance.policy?.toJson(),
  'stats': ?instance.stats?.toJson(),
  'metrics': ?instance.metrics?.toJson(),
  'fakeDns': ?instance.fakeDns?.map((e) => e.toJson()).toList(),
};

XrayEnv _$XrayEnvFromJson(Map<String, dynamic> json) => XrayEnv(
  assetLocation: json['xray.location.asset'] as String?,
  certLocation: json['xray.location.cert'] as String?,
  tunFd: json['xray.tun.fd'] as String?,
);

Map<String, dynamic> _$XrayEnvToJson(XrayEnv instance) => <String, dynamic>{
  'xray.location.asset': ?instance.assetLocation,
  'xray.location.cert': ?instance.certLocation,
  'xray.tun.fd': ?instance.tunFd,
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

XrayInboundDokodemoDoorSettings _$XrayInboundDokodemoDoorSettingsFromJson(
  Map<String, dynamic> json,
) => XrayInboundDokodemoDoorSettings(
  json['address'] as String?,
  (json['port'] as num?)?.toInt(),
  json['network'] as String?,
);

Map<String, dynamic> _$XrayInboundDokodemoDoorSettingsToJson(
  XrayInboundDokodemoDoorSettings instance,
) => <String, dynamic>{
  'address': ?instance.address,
  'port': ?instance.port,
  'network': ?instance.network,
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
  json['protocol'] as String?,
  json['settings'] as Map<String, dynamic>?,
  json['tag'] as String?,
  json['streamSettings'] == null
      ? null
      : XrayStreamSettings.fromJson(
          json['streamSettings'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$XrayOutboundToJson(XrayOutbound instance) =>
    <String, dynamic>{
      'protocol': ?instance.protocol,
      'settings': ?instance.settings,
      'tag': ?instance.tag,
      'streamSettings': ?instance.streamSettings?.toJson(),
    };

XrayOutboundFreedom _$XrayOutboundFreedomFromJson(Map<String, dynamic> json) =>
    XrayOutboundFreedom(
      json['fragment'] == null
          ? null
          : XrayOutboundFreedomFragment.fromJson(
              json['fragment'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$XrayOutboundFreedomToJson(
  XrayOutboundFreedom instance,
) => <String, dynamic>{'fragment': ?instance.fragment?.toJson()};

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

XrayStreamSettings _$XrayStreamSettingsFromJson(Map<String, dynamic> json) =>
    XrayStreamSettings(
      json['sockopt'] == null
          ? null
          : XraySockopt.fromJson(json['sockopt'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$XrayStreamSettingsToJson(XrayStreamSettings instance) =>
    <String, dynamic>{'sockopt': ?instance.sockopt?.toJson()};

XraySockopt _$XraySockoptFromJson(Map<String, dynamic> json) =>
    XraySockopt(json['dialerProxy'] as String?, json['interface'] as String?);

Map<String, dynamic> _$XraySockoptToJson(XraySockopt instance) =>
    <String, dynamic>{
      'dialerProxy': ?instance.dialerProxy,
      'interface': ?instance.interface,
    };

XrayFakeDns _$XrayFakeDnsFromJson(Map<String, dynamic> json) =>
    XrayFakeDns(json['ipPool'] as String?, (json['poolSize'] as num?)?.toInt());

Map<String, dynamic> _$XrayFakeDnsToJson(XrayFakeDns instance) =>
    <String, dynamic>{
      'ipPool': ?instance.ipPool,
      'poolSize': ?instance.poolSize,
    };
