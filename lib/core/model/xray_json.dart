import 'package:json_annotation/json_annotation.dart';

part 'xray_json.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayJson {
  String? name;
  XrayLog? log;
  XrayDns? dns;
  XrayRouting? routing;
  List<XrayInbound>? inbounds;
  List<XrayOutbound>? outbounds;

  XrayJson(
    this.name,
    this.log,
    this.dns,
    this.routing,
    this.inbounds,
    this.outbounds,
  );

  factory XrayJson.fromJson(Map<String, dynamic> json) =>
      _$XrayJsonFromJson(json);

  Map<String, dynamic> toJson() => _$XrayJsonToJson(this);
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
class XrayDns {
  Map<String, List<String>>? hosts;
  List<XrayDnsServer>? servers;
  String? tag;
  String? queryStrategy;
  bool? disableCache;
  bool? disableFallback;
  bool? disableFallbackIfMatch;
  bool? useSystemHosts;

  XrayDns(
    this.hosts,
    this.servers,
    this.tag,
    this.queryStrategy,
    this.disableCache,
    this.disableFallback,
    this.disableFallbackIfMatch,
    this.useSystemHosts,
  );

  factory XrayDns.fromJson(Map<String, dynamic> json) =>
      _$XrayDnsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayDnsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayDnsServer {
  String? address;
  int? port;
  bool? skipFallback;
  List<String>? domains;
  List<String>? expectedIPs;
  List<String>? unexpectedIPs;
  String? queryStrategy;
  String? tag;
  bool? disableCache;
  bool? finalQuery;

  XrayDnsServer(
    this.address,
    this.skipFallback,
    this.port,
    this.domains,
    this.expectedIPs,
    this.unexpectedIPs,
    this.queryStrategy,
    this.tag,
    this.disableCache,
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
class XrayInboundSniffing {
  bool? enabled;
  List<String>? destOverride;
  List<String>? domainsExcluded;

  XrayInboundSniffing(this.enabled, this.destOverride, this.domainsExcluded);

  factory XrayInboundSniffing.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundSniffingFromJson(json);

  Map<String, dynamic> toJson() => _$XrayInboundSniffingToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayInboundTun {
  String? name;
  @JsonKey(name: "MTU")
  int? mtu;

  XrayInboundTun(this.name, this.mtu);

  factory XrayInboundTun.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundTunFromJson(json);

  Map<String, dynamic> toJson() => _$XrayInboundTunToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutbound {
  String? name;
  String? sendThrough;
  String? protocol;
  Map<String, dynamic>? settings;
  String? tag;
  XrayStreamSettings? streamSettings;
  XrayMux? mux;

  XrayOutbound(
    this.name,
    this.sendThrough,
    this.protocol,
    this.settings,
    this.tag,
    this.streamSettings,
    this.mux,
  );

  factory XrayOutbound.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundShadowsocks {
  String? address;
  int? port;
  String? method;
  String? password;
  bool? uot;

  @JsonKey(name: "UoTVersion")
  int? uotVersion;

  XrayOutboundShadowsocks(
    this.address,
    this.port,
    this.method,
    this.password,
    this.uot,
    this.uotVersion,
  );

  factory XrayOutboundShadowsocks.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundShadowsocksFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundShadowsocksToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundSocks {
  String? address;
  int? port;
  String? user;
  String? pass;

  XrayOutboundSocks(this.address, this.port, this.user, this.pass);

  factory XrayOutboundSocks.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundSocksFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundSocksToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundTrojan {
  String? address;
  int? port;
  String? password;

  XrayOutboundTrojan(this.address, this.port, this.password);

  factory XrayOutboundTrojan.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundTrojanFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundTrojanToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundVLESS {
  String? address;
  int? port;
  String? id;
  String? flow;
  String? encryption;
  XrayOutboundVLESSReverse? reverse;

  XrayOutboundVLESS(
    this.address,
    this.port,
    this.id,
    this.flow,
    this.encryption,
    this.reverse,
  );

  factory XrayOutboundVLESS.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundVLESSFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundVLESSToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundVLESSReverse {
  String? tag;

  XrayOutboundVLESSReverse(this.tag);

  factory XrayOutboundVLESSReverse.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundVLESSReverseFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundVLESSReverseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundVMess {
  String? address;
  int? port;
  String? id;
  String? security;

  XrayOutboundVMess(this.address, this.port, this.id, this.security);

  factory XrayOutboundVMess.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundVMessFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundVMessToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundHysteria {
  int? version;
  String? address;
  int? port;

  XrayOutboundHysteria(this.version, this.address, this.port);

  factory XrayOutboundHysteria.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundHysteriaFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundHysteriaToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundFreedom {
  XrayOutboundFreedomFragment? fragment;
  List<XrayOutboundFreedomNoises>? noises;

  XrayOutboundFreedom(this.fragment, this.noises);

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
class XrayOutboundFreedomNoises {
  String? type;
  String? packet;
  String? delay;

  XrayOutboundFreedomNoises(this.type, this.packet, this.delay);

  factory XrayOutboundFreedomNoises.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundFreedomNoisesFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundFreedomNoisesToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayOutboundDns {
  String? network;
  String? address;
  int? port;
  String? nonIPQuery;

  XrayOutboundDns(this.network, this.address, this.port, this.nonIPQuery);

  factory XrayOutboundDns.fromJson(Map<String, dynamic> json) =>
      _$XrayOutboundDnsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayOutboundDnsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayStreamSettings {
  String? address;
  int? port;
  String? network;
  String? security;
  XrayTlsSettings? tlsSettings;
  XrayRealitySettings? realitySettings;
  XrayRawSettings? rawSettings;
  XrayKcpSettings? kcpSettings;
  XrayWsSettings? wsSettings;
  XrayGrpcSettings? grpcSettings;
  XrayHttpupgradeSettings? httpupgradeSettings;
  XrayXhttpSettings? xhttpSettings;
  XrayHysteriaSettings? hysteriaSettings;
  Map<String, dynamic>? finalmask;
  XraySockopt? sockopt;

  XrayStreamSettings(
    this.address,
    this.port,
    this.network,
    this.security,
    this.tlsSettings,
    this.realitySettings,
    this.rawSettings,
    this.kcpSettings,
    this.wsSettings,
    this.grpcSettings,
    this.httpupgradeSettings,
    this.xhttpSettings,
    this.hysteriaSettings,
    this.finalmask,
    this.sockopt,
  );

  factory XrayStreamSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayStreamSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayStreamSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayTlsSettings {
  String? serverName;
  List<String>? alpn;
  String? fingerprint;
  String? pinnedPeerCertSha256;
  String? verifyPeerCertByName;
  String? echConfigList;
  String? echForceQuery;

  XrayTlsSettings(
    this.serverName,
    this.alpn,
    this.fingerprint,
    this.pinnedPeerCertSha256,
    this.verifyPeerCertByName,
    this.echConfigList,
    this.echForceQuery,
  );

  factory XrayTlsSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayTlsSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayTlsSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayRealitySettings {
  bool? show;
  String? fingerprint;
  String? serverName;
  String? publicKey;
  String? password;
  String? shortId;
  String? mldsa65Verify;
  String? spiderX;

  XrayRealitySettings(
    this.show,
    this.fingerprint,
    this.serverName,
    this.publicKey,
    this.password,
    this.shortId,
    this.mldsa65Verify,
    this.spiderX,
  );

  factory XrayRealitySettings.fromJson(Map<String, dynamic> json) =>
      _$XrayRealitySettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayRealitySettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayRawSettings {
  XrayRawSettingsHeader? header;

  XrayRawSettings(this.header);

  factory XrayRawSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayRawSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayRawSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayRawSettingsHeader {
  String? type;
  XrayRawSettingsHeaderRequest? request;

  XrayRawSettingsHeader(this.type, this.request);

  factory XrayRawSettingsHeader.fromJson(Map<String, dynamic> json) =>
      _$XrayRawSettingsHeaderFromJson(json);

  Map<String, dynamic> toJson() => _$XrayRawSettingsHeaderToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayRawSettingsHeaderRequest {
  List<String>? path;
  XrayRawSettingsHeaderRequestHeaders? headers;

  XrayRawSettingsHeaderRequest(this.path, this.headers);

  factory XrayRawSettingsHeaderRequest.fromJson(Map<String, dynamic> json) =>
      _$XrayRawSettingsHeaderRequestFromJson(json);

  Map<String, dynamic> toJson() => _$XrayRawSettingsHeaderRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayRawSettingsHeaderRequestHeaders {
  @JsonKey(name: 'Host')
  List<String>? host;

  XrayRawSettingsHeaderRequestHeaders(this.host);

  factory XrayRawSettingsHeaderRequestHeaders.fromJson(
    Map<String, dynamic> json,
  ) => _$XrayRawSettingsHeaderRequestHeadersFromJson(json);

  Map<String, dynamic> toJson() =>
      _$XrayRawSettingsHeaderRequestHeadersToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayKcpSettings {
  XrayKcpHeader? header;
  String? seed;

  XrayKcpSettings(this.header, this.seed);

  factory XrayKcpSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayKcpSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayKcpSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayKcpHeader {
  String? type;
  String? domain;

  XrayKcpHeader(this.type, this.domain);

  factory XrayKcpHeader.fromJson(Map<String, dynamic> json) =>
      _$XrayKcpHeaderFromJson(json);

  Map<String, dynamic> toJson() => _$XrayKcpHeaderToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayWsSettings {
  String? path;
  String? host;

  XrayWsSettings(this.path, this.host);

  factory XrayWsSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayWsSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayWsSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayGrpcSettings {
  String? authority;
  String? serviceName;
  bool? multiMode;

  XrayGrpcSettings(this.authority, this.serviceName, this.multiMode);

  factory XrayGrpcSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayGrpcSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayGrpcSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayHttpupgradeSettings {
  String? host;
  String? path;

  XrayHttpupgradeSettings(this.host, this.path);

  factory XrayHttpupgradeSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayHttpupgradeSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayHttpupgradeSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayXhttpSettings {
  String? host;
  String? path;
  String? mode;
  Map<String, String>? headers;
  String? xPaddingBytes;
  bool? noGRPCHeader;
  String? scMaxEachPostBytes;
  String? scMinPostsIntervalMs;
  XrayXhttpSettingsXmux? xmux;
  XrayStreamSettings? downloadSettings;
  XrayXhttpSettings? extra;

  XrayXhttpSettings(
    this.host,
    this.path,
    this.mode,
    this.headers,
    this.xPaddingBytes,
    this.noGRPCHeader,
    this.scMaxEachPostBytes,
    this.scMinPostsIntervalMs,
    this.xmux,
    this.downloadSettings,
    this.extra,
  );

  factory XrayXhttpSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayXhttpSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayXhttpSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayXhttpSettingsXmux {
  String? maxConcurrency;
  String? maxConnections;
  String? cMaxReuseTimes;
  String? hMaxReusableSecs;
  String? hMaxRequestTimes;
  int? hKeepAlivePeriod;

  XrayXhttpSettingsXmux(
    this.maxConcurrency,
    this.maxConnections,
    this.cMaxReuseTimes,
    this.hMaxReusableSecs,
    this.hMaxRequestTimes,
    this.hKeepAlivePeriod,
  );

  factory XrayXhttpSettingsXmux.fromJson(Map<String, dynamic> json) =>
      _$XrayXhttpSettingsXmuxFromJson(json);

  Map<String, dynamic> toJson() => _$XrayXhttpSettingsXmuxToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayHysteriaSettings {
  int? version;
  String? auth;
  String? up;
  String? down;
  XrayHysteriaSettingsUdphop? udphop;

  XrayHysteriaSettings(
    this.version,
    this.auth,
    this.up,
    this.down,
    this.udphop,
  );

  factory XrayHysteriaSettings.fromJson(Map<String, dynamic> json) =>
      _$XrayHysteriaSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayHysteriaSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayHysteriaSettingsUdphop {
  String? port;
  int? interval;

  XrayHysteriaSettingsUdphop(this.port, this.interval);

  factory XrayHysteriaSettingsUdphop.fromJson(Map<String, dynamic> json) =>
      _$XrayHysteriaSettingsUdphopFromJson(json);
  Map<String, dynamic> toJson() => _$XrayHysteriaSettingsUdphopToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XraySockopt {
  String? dialerProxy;
  bool? tcpFastOpen;
  String? interface;
  bool? tcpMptcp;

  XraySockopt(
    this.dialerProxy,
    this.tcpFastOpen,
    this.interface,
    this.tcpMptcp,
  );

  factory XraySockopt.fromJson(Map<String, dynamic> json) =>
      _$XraySockoptFromJson(json);

  Map<String, dynamic> toJson() => _$XraySockoptToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayMux {
  bool? enabled;
  int? concurrency;
  int? xudpConcurrency;
  String? xudpProxyUDP443;

  XrayMux(
    this.enabled,
    this.concurrency,
    this.xudpConcurrency,
    this.xudpProxyUDP443,
  );

  factory XrayMux.fromJson(Map<String, dynamic> json) =>
      _$XrayMuxFromJson(json);

  Map<String, dynamic> toJson() => _$XrayMuxToJson(this);
}
