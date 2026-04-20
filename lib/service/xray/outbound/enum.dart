import 'package:collection/collection.dart';

enum XrayOutboundProtocol {
  blackhole("blackhole"),
  dns("dns"),
  freedom("freedom"),
  vless("vless"),
  vmess("vmess"),
  socks("socks"),
  shadowsocks("shadowsocks"),
  trojan("trojan"),
  hysteria("hysteria");

  const XrayOutboundProtocol(this.name);

  final String name;

  @override
  String toString() => name;

  static XrayOutboundProtocol? fromString(String name) => XrayOutboundProtocol
      .values
      .firstWhereOrNull((value) => value.name == name);

  static List<XrayOutboundProtocol> outbounds = [
    XrayOutboundProtocol.vless,
    XrayOutboundProtocol.vmess,
    XrayOutboundProtocol.shadowsocks,
    XrayOutboundProtocol.trojan,
    XrayOutboundProtocol.hysteria,
    XrayOutboundProtocol.socks,
  ];
}

enum VLESSFlow {
  none("none"),
  xtlsRprxVision("xtls-rprx-vision"),
  xtlsRprxVisionUdp443("xtls-rprx-vision-udp443");

  const VLESSFlow(this.name);

  final String name;

  @override
  String toString() => name;

  static VLESSFlow? fromString(String name) =>
      VLESSFlow.values.firstWhereOrNull((value) => value.name == name);
}

enum VMessSecurity {
  aes128gcm("aes-128-gcm"),
  chacha20poly1305("chacha20-poly1305"),
  auto("auto"),
  none("none"),
  zero("zero");

  const VMessSecurity(this.name);

  final String name;

  @override
  String toString() => name;

  static VMessSecurity? fromString(String name) =>
      VMessSecurity.values.firstWhereOrNull((value) => value.name == name);
}

enum ShadowsocksMethod {
  blake3aes128gcm2022("2022-blake3-aes-128-gcm"),
  blake3aes256gcm2022("2022-blake3-aes-256-gcm"),
  blake3chacha20poly13052022("2022-blake3-chacha20-poly1305"),
  aes128gcm("aes-128-gcm"),
  aes256gcm("aes-256-gcm"),
  chacha20poly1305("chacha20-poly1305"),
  xchacha20poly1305("xchacha20-poly1305"),
  none("none");

  const ShadowsocksMethod(this.name);

  final String name;

  @override
  String toString() => name;

  static ShadowsocksMethod? fromString(String name) {
    final clean = name.toLowerCase().replaceAll("_", "-");
    switch (clean) {
      case "aead-aes-128-gcm":
        return ShadowsocksMethod.aes128gcm;
      case "aead-aes-256-gcm":
        return ShadowsocksMethod.aes256gcm;
      case "aead-chacha20-poly1305":
      case "chacha20-ietf-poly1305":
        return ShadowsocksMethod.chacha20poly1305;
      case "xchacha20-ietf-poly1305":
        return ShadowsocksMethod.xchacha20poly1305;
      case "plain":
        return ShadowsocksMethod.none;
      default:
        return ShadowsocksMethod.values.firstWhereOrNull(
          (value) => value.name == name,
        );
    }
  }
}

enum ShadowsocksUoTVersion {
  none(""),
  one("1"),
  two("2");

  const ShadowsocksUoTVersion(this.name);

  final String name;

  @override
  String toString() => name;

  static ShadowsocksUoTVersion? fromString(String name) {
    return ShadowsocksUoTVersion.values.firstWhereOrNull(
      (value) => value.name == name,
    );
  }
}

enum StreamSettingsNetwork {
  raw("raw"),
  xhttp("xhttp"),
  kcp("kcp"),
  grpc("grpc"),
  ws("ws"),
  httpupgrade("httpupgrade"),
  hysteria("hysteria");

  const StreamSettingsNetwork(this.name);

  final String name;

  @override
  String toString() => name;

  static StreamSettingsNetwork? fromString(String name) {
    switch (name) {
      case "tcp":
        return StreamSettingsNetwork.raw;
      case "mkcp":
        return StreamSettingsNetwork.kcp;
      case "gun":
        return StreamSettingsNetwork.grpc;
      default:
        return StreamSettingsNetwork.values.firstWhereOrNull(
          (value) => value.name == name,
        );
    }
  }
}

enum RawHeaderType {
  none("none"),
  http("http");

  const RawHeaderType(this.name);

  final String name;

  @override
  String toString() => name;

  static RawHeaderType? fromString(String name) =>
      RawHeaderType.values.firstWhereOrNull((value) => value.name == name);
}

enum KcpHeaderType {
  none("none"),
  srtp("srtp"),
  utp("utp"),
  wechatVideo("wechat-video"),
  dtls("dtls"),
  wireguard("wireguard"),
  dns("dns");

  const KcpHeaderType(this.name);

  final String name;

  @override
  String toString() => name;

  static KcpHeaderType? fromString(String name) =>
      KcpHeaderType.values.firstWhereOrNull((value) => value.name == name);
}

enum XhttpMode {
  auto("auto"),
  packetUp("packet-up"),
  streamUp("stream-up"),
  streamOne("stream-one");

  const XhttpMode(this.name);

  final String name;

  @override
  String toString() => name;

  static XhttpMode? fromString(String name) =>
      XhttpMode.values.firstWhereOrNull((value) => value.name == name);
}

enum StreamSettingsSecurity {
  none("none"),
  tls("tls"),
  reality("reality");

  const StreamSettingsSecurity(this.name);

  final String name;

  @override
  String toString() => name;

  static StreamSettingsSecurity? fromString(String name) =>
      StreamSettingsSecurity.values.firstWhereOrNull(
        (value) => value.name == name,
      );

  static List<StreamSettingsSecurity> xhttpDownloadSettingsSecurity = [
    StreamSettingsSecurity.tls,
    StreamSettingsSecurity.reality,
  ];
}

enum StreamSettingsSecurityFingerprint {
  none(""),
  chrome("chrome"),
  firefox("firefox"),
  safari("safari"),
  ios("ios"),
  android("android"),
  edge("edge"),
  browser360("360"),
  qq("qq"),
  random("random"),
  randomized("randomized");

  const StreamSettingsSecurityFingerprint(this.name);

  final String name;

  @override
  String toString() => name;

  static StreamSettingsSecurityFingerprint? fromString(String name) =>
      StreamSettingsSecurityFingerprint.values.firstWhereOrNull(
        (value) => value.name == name,
      );
}

enum StreamSettingsEchForceQuery {
  none("none"),
  half("half"),
  full("full");

  const StreamSettingsEchForceQuery(this.name);

  final String name;

  @override
  String toString() => name;

  static StreamSettingsEchForceQuery? fromString(String name) =>
      StreamSettingsEchForceQuery.values.firstWhereOrNull(
        (value) => value.name == name,
      );
}

enum MuxXudpProxyUDP443 {
  reject("reject"),
  allow("allow"),
  skip("skip");

  const MuxXudpProxyUDP443(this.name);

  final String name;

  @override
  String toString() => name;

  static MuxXudpProxyUDP443? fromString(String name) =>
      MuxXudpProxyUDP443.values.firstWhereOrNull((value) => value.name == name);
}

enum StreamSettingsSecurityALPN {
  h3("h3"),
  h2("h2"),
  http1_1("http/1.1");

  const StreamSettingsSecurityALPN(this.name);

  final String name;

  @override
  String toString() => name;

  static StreamSettingsSecurityALPN? fromString(String name) =>
      StreamSettingsSecurityALPN.values.firstWhereOrNull(
        (value) => value.name == name,
      );

  static Set<StreamSettingsSecurityALPN> fromStrings(List<String> strings) {
    final values = <StreamSettingsSecurityALPN>{};
    for (final string in strings) {
      final value = StreamSettingsSecurityALPN.fromString(string);
      if (value != null) {
        values.add(value);
      }
    }
    return values;
  }

  static List<String> toStrings(Set<StreamSettingsSecurityALPN> values) {
    return values.map((value) => value.name).toList();
  }
}

enum FinalMaskType {
  headerDns("header-dns"),
  headerDtls("header-dtls"),
  headerSrtp("header-srtp"),
  headerUtp("header-utp"),
  headerWechat("header-wechat"),
  headerWireguard("header-wireguard"),
  mkcpOriginal("mkcp-original"),
  mkcpAes128gcm("mkcp-aes128gcm"),
  salamander("salamander"),
  xdns("xdns"),
  xicmp("xicmp");

  const FinalMaskType(this.name);

  final String name;

  @override
  String toString() => name;

  static FinalMaskType? fromString(String name) =>
      FinalMaskType.values.firstWhereOrNull((value) => value.name == name);
}
