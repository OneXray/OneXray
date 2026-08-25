import 'package:json_annotation/json_annotation.dart';

part 'xray_json.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayJson {
  String? name;
  XrayEnv? env;
  XrayLog? log;
  XrayDns? dns;
  XrayRouting? routing;
  List<XrayInbound>? inbounds;
  List<Map<String, dynamic>>? outbounds;
  XrayPolicy? policy;
  XrayStats? stats;
  XrayMetrics? metrics;
  List<XrayFakeDns>? fakeDns;

  XrayJson(
    this.name,
    this.env,
    this.log,
    this.dns,
    this.routing,
    this.inbounds,
    this.outbounds,
    this.policy,
    this.stats,
    this.metrics,
    this.fakeDns,
  );

  factory XrayJson.fromJson(Map<String, dynamic> json) =>
      _$XrayJsonFromJson(json);

  Map<String, dynamic> toJson() => _$XrayJsonToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayEnv {
  @JsonKey(name: "xray.location.asset")
  String? assetLocation;
  @JsonKey(name: "xray.location.cert")
  String? certLocation;
  @JsonKey(name: "xray.tun.fd")
  String? tunFd;

  XrayEnv({this.assetLocation, this.certLocation, this.tunFd});

  factory XrayEnv.fromJson(Map<String, dynamic> json) =>
      _$XrayEnvFromJson(json);

  Map<String, dynamic> toJson() => _$XrayEnvToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayLog {
  String? access;
  String? error;
  @JsonKey(name: "loglevel")
  String? logLevel;
  bool? dnsLog;
  String? maskAddress;

  XrayLog(
    this.access,
    this.error,
    this.logLevel,
    this.dnsLog,
    this.maskAddress,
  );

  factory XrayLog.fromJson(Map<String, dynamic> json) =>
      _$XrayLogFromJson(json);

  Map<String, dynamic> toJson() => _$XrayLogToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayPolicy {
  Map<String, XrayPolicyLevel>? levels;
  XrayPolicySystem? system;

  XrayPolicy(this.levels, this.system);

  factory XrayPolicy.fromJson(Map<String, dynamic> json) =>
      _$XrayPolicyFromJson(json);

  Map<String, dynamic> toJson() => _$XrayPolicyToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayPolicyLevel {
  int? handshake;
  int? connIdle;
  int? uplinkOnly;
  int? downlinkOnly;
  bool? statsUserUplink;
  bool? statsUserDownlink;
  bool? statsUserOnline;
  int? bufferSize;

  XrayPolicyLevel(
    this.handshake,
    this.connIdle,
    this.uplinkOnly,
    this.downlinkOnly,
    this.statsUserUplink,
    this.statsUserDownlink,
    this.statsUserOnline,
    this.bufferSize,
  );

  factory XrayPolicyLevel.fromJson(Map<String, dynamic> json) =>
      _$XrayPolicyLevelFromJson(json);

  Map<String, dynamic> toJson() => _$XrayPolicyLevelToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayPolicySystem {
  bool? statsInboundUplink;
  bool? statsInboundDownlink;
  bool? statsOutboundUplink;
  bool? statsOutboundDownlink;

  XrayPolicySystem(
    this.statsInboundUplink,
    this.statsInboundDownlink,
    this.statsOutboundUplink,
    this.statsOutboundDownlink,
  );

  factory XrayPolicySystem.fromJson(Map<String, dynamic> json) =>
      _$XrayPolicySystemFromJson(json);

  Map<String, dynamic> toJson() => _$XrayPolicySystemToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayStats {
  XrayStats();

  factory XrayStats.fromJson(Map<String, dynamic> json) =>
      _$XrayStatsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayStatsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayMetrics {
  String? listen;

  XrayMetrics(this.listen);

  factory XrayMetrics.fromJson(Map<String, dynamic> json) =>
      _$XrayMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayMetricsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayDns {
  Map<String, List<String>>? hosts;
  List<XrayDnsServer>? servers;
  String? clientIp;
  String? tag;
  String? queryStrategy;
  bool? disableCache;
  bool? serveStale;
  int? serveExpiredTTL;
  bool? disableFallback;
  bool? disableFallbackIfMatch;
  bool? enableParallelQuery;
  bool? useSystemHosts;

  XrayDns(
    this.hosts,
    this.servers,
    this.clientIp,
    this.tag,
    this.queryStrategy,
    this.disableCache,
    this.serveStale,
    this.serveExpiredTTL,
    this.disableFallback,
    this.disableFallbackIfMatch,
    this.enableParallelQuery,
    this.useSystemHosts,
  );

  factory XrayDns.fromJson(Map<String, dynamic> json) =>
      _$XrayDnsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayDnsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayDnsServer {
  String? address;
  String? clientIp;
  int? port;
  bool? skipFallback;
  List<String>? domains;
  List<String>? expectedIPs;
  List<String>? unexpectedIPs;
  String? queryStrategy;
  String? tag;
  int? timeoutMs;
  bool? disableCache;
  bool? serveStale;
  int? serveExpiredTTL;
  bool? finalQuery;

  XrayDnsServer(
    this.address,
    this.clientIp,
    this.skipFallback,
    this.port,
    this.domains,
    this.expectedIPs,
    this.unexpectedIPs,
    this.queryStrategy,
    this.tag,
    this.timeoutMs,
    this.disableCache,
    this.serveStale,
    this.serveExpiredTTL,
    this.finalQuery,
  );

  factory XrayDnsServer.fromJson(Map<String, dynamic> json) =>
      _$XrayDnsServerFromJson(json);

  Map<String, dynamic> toJson() => _$XrayDnsServerToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayRouting {
  String? domainStrategy;
  List<XrayRoutingRule>? rules;

  XrayRouting(this.domainStrategy, this.rules);

  factory XrayRouting.fromJson(Map<String, dynamic> json) =>
      _$XrayRoutingFromJson(json);

  Map<String, dynamic> toJson() => _$XrayRoutingToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayRoutingRule {
  List<String>? domain;
  List<String>? ip;
  String? port;
  String? sourcePort;
  String? localPort;
  String? network;
  List<String>? sourceIP;
  List<String>? localIP;
  List<String>? user;
  List<String>? inboundTag;
  List<String>? protocol;
  Map<String, String>? attrs;
  List<String>? process;
  String? outboundTag;
  String? ruleTag;

  XrayRoutingRule(
    this.domain,
    this.ip,
    this.port,
    this.sourcePort,
    this.localPort,
    this.network,
    this.sourceIP,
    this.localIP,
    this.user,
    this.inboundTag,
    this.protocol,
    this.attrs,
    this.process,
    this.outboundTag,
    this.ruleTag,
  );

  factory XrayRoutingRule.fromJson(Map<String, dynamic> json) =>
      _$XrayRoutingRuleFromJson(json);

  Map<String, dynamic> toJson() => _$XrayRoutingRuleToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayInbound {
  String? listen;
  String? port;
  String? protocol;
  Map<String, dynamic>? settings;
  String? tag;
  XrayInboundSniffing? sniffing;

  XrayInbound(
    this.listen,
    this.port,
    this.protocol,
    this.settings,
    this.tag,
    this.sniffing,
  );

  factory XrayInbound.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundFromJson(json);

  Map<String, dynamic> toJson() => _$XrayInboundToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayInboundAccount {
  String? user;
  String? pass;

  XrayInboundAccount(this.user, this.pass);

  factory XrayInboundAccount.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundAccountFromJson(json);

  Map<String, dynamic> toJson() => _$XrayInboundAccountToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayInboundSocksSettings {
  String? auth;
  bool? udp;
  List<XrayInboundAccount>? users;

  XrayInboundSocksSettings(this.auth, this.udp, this.users);

  factory XrayInboundSocksSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundSocksSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayInboundSocksSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayInboundHttpSettings {
  bool? allowTransparent;
  List<XrayInboundAccount>? users;

  XrayInboundHttpSettings(this.allowTransparent, this.users);

  factory XrayInboundHttpSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundHttpSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayInboundHttpSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayInboundDokodemoDoorSettings {
  String? address;
  int? port;
  String? network;

  XrayInboundDokodemoDoorSettings(this.address, this.port, this.network);

  factory XrayInboundDokodemoDoorSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundDokodemoDoorSettingsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$XrayInboundDokodemoDoorSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayInboundSniffing {
  bool? enabled;
  bool? routeOnly;
  List<String>? destOverride;
  List<String>? domainsExcluded;
  List<String>? ipsExcluded;
  bool? metadataOnly;

  XrayInboundSniffing(
    this.enabled,
    this.routeOnly,
    this.destOverride,
    this.domainsExcluded,
    this.ipsExcluded,
    this.metadataOnly,
  );

  factory XrayInboundSniffing.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundSniffingFromJson(json);

  Map<String, dynamic> toJson() => _$XrayInboundSniffingToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayInboundTun {
  String? name;
  int? mtu;
  List<String>? gateway;
  List<String>? dns;
  List<String>? autoSystemRoutingTable;
  String? autoOutboundsInterface;

  XrayInboundTun(
    this.name,
    this.mtu,
    this.gateway,
    this.dns,
    this.autoSystemRoutingTable,
    this.autoOutboundsInterface,
  );

  factory XrayInboundTun.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundTunFromJson(json);

  Map<String, dynamic> toJson() => _$XrayInboundTunToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutbound {
  String? protocol;
  Map<String, dynamic>? settings;
  String? tag;
  XrayStreamSettings? streamSettings;

  XrayOutbound(this.protocol, this.settings, this.tag, this.streamSettings);

  factory XrayOutbound.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundFreedom {
  XrayOutboundFreedomFragment? fragment;

  XrayOutboundFreedom(this.fragment);

  factory XrayOutboundFreedom.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundFreedomFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundFreedomToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundFreedomFragment {
  String? packets;
  String? length;
  String? interval;

  XrayOutboundFreedomFragment(this.packets, this.length, this.interval);

  factory XrayOutboundFreedomFragment.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundFreedomFragmentFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundFreedomFragmentToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundDns {
  String? network;
  String? address;
  int? port;
  List<XrayOutboundDnsRule>? rules;

  XrayOutboundDns(this.network, this.address, this.port, this.rules);

  factory XrayOutboundDns.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundDnsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundDnsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundDnsRule {
  String? action;
  String? qType;
  Object? domain;
  int? rCode;

  XrayOutboundDnsRule(this.action, this.qType, this.domain, this.rCode);

  factory XrayOutboundDnsRule.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundDnsRuleFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundDnsRuleToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayStreamSettings {
  XraySockopt? sockopt;

  XrayStreamSettings(this.sockopt);

  factory XrayStreamSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayStreamSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayStreamSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XraySockopt {
  String? dialerProxy;
  String? interface;

  XraySockopt(this.dialerProxy, this.interface);

  factory XraySockopt.fromJson(Map<String, dynamic> json) =>
      _$XraySockoptFromJson(json);

  Map<String, dynamic> toJson() => _$XraySockoptToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayFakeDns {
  String? ipPool;
  int? poolSize;

  XrayFakeDns(this.ipPool, this.poolSize);

  factory XrayFakeDns.fromJson(Map<String, dynamic> json) =>
      _$XrayFakeDnsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayFakeDnsToJson(this);
}
