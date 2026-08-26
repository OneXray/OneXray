import 'package:collection/collection.dart';
import 'package:onexray/service/tun_settings/state.dart';

enum XrayInboundProtocol {
  tun("tun"),
  socks("socks"),
  http("http"),
  dokodemoDoor("dokodemo-door");

  const XrayInboundProtocol(this.name);

  final String name;

  @override
  String toString() => name;
}

enum RoutingDomainStrategy {
  asIs("AsIs"),
  ipIfNonMatch("IPIfNonMatch"),
  ipOnDemand("IPOnDemand");

  const RoutingDomainStrategy(this.name);

  final String name;

  @override
  String toString() => name;

  static RoutingDomainStrategy? fromString(String name) {
    final normalized = name.toLowerCase();
    return RoutingDomainStrategy.values.firstWhereOrNull(
      (value) => value.name.toLowerCase() == normalized,
    );
  }

  static List<String> get names {
    return RoutingDomainStrategy.values.map((e) => e.name).toList();
  }

  static List<String> simpleStrategy = [
    RoutingDomainStrategy.asIs.name,
    RoutingDomainStrategy.ipIfNonMatch.name,
  ];
}

enum RoutingOutboundTag {
  proxy("proxy"),
  chainProxy("chainProxy"),
  direct("direct"),
  fragment("fragment"),
  block("block"),
  dnsOut("dnsOut");

  const RoutingOutboundTag(this.name);

  final String name;

  @override
  String toString() => name;
}

enum RoutingInboundTag {
  tunIn("tunIn"),
  pingIn("pingIn");

  const RoutingInboundTag(this.name);

  final String name;

  @override
  String toString() => name;
}

enum XrayLogLevel {
  debug("debug"),
  info("info"),
  warning("warning"),
  error("error"),
  none("none");

  const XrayLogLevel(this.name);

  final String name;

  @override
  String toString() => name;

  static XrayLogLevel? fromString(String name) =>
      XrayLogLevel.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return XrayLogLevel.values.map((e) => e.name).toList();
  }
}

enum XrayLogMaskAddress {
  none(""),
  quarter("quarter"),
  half("half"),
  full("full");

  const XrayLogMaskAddress(this.name);

  final String name;

  @override
  String toString() => name;

  static XrayLogMaskAddress? fromString(String name) =>
      XrayLogMaskAddress.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return XrayLogMaskAddress.values.map((e) => e.name).toList();
  }
}

enum DnsQueryStrategy {
  useIP("UseIP"),
  useIPv4("UseIPv4"),
  useIPv6("UseIPv6");

  const DnsQueryStrategy(this.name);

  final String name;

  @override
  String toString() => name;

  static DnsQueryStrategy fromTunSettings(TunSettingsState tunSettings) {
    return tunSettings.enableIPv6
        ? DnsQueryStrategy.useIP
        : DnsQueryStrategy.useIPv4;
  }
}

enum SimpleCountry {
  cn("CN"),
  ir("IR"),
  ru("RU"),
  other("Other");

  const SimpleCountry(this.name);

  final String name;

  @override
  String toString() => name;

  static SimpleCountry? fromString(String name) =>
      SimpleCountry.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return SimpleCountry.values.map((e) => e.name).toList();
  }
}
