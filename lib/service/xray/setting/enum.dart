import 'package:collection/collection.dart';

enum XrayInboundProtocol {
  tun("tun"),
  socks("socks"),
  http("http");

  const XrayInboundProtocol(this.name);

  final String name;

  @override
  String toString() => name;

  static XrayInboundProtocol? fromString(String name) => XrayInboundProtocol
      .values
      .firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return XrayInboundProtocol.values.map((e) => e.name).toList();
  }
}

enum RoutingDomainStrategy {
  asIs("AsIs"),
  ipIfNonMatch("IpIfNonMatch"),
  ipOnDemand("IpOnDemand");

  const RoutingDomainStrategy(this.name);

  final String name;

  @override
  String toString() => name;

  static RoutingDomainStrategy? fromString(String name) => RoutingDomainStrategy
      .values
      .firstWhereOrNull((value) => value.name == name);

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
  direct("direct"),
  fragment("fragment"),
  block("block"),
  dnsOut("dnsOut");

  const RoutingOutboundTag(this.name);

  final String name;

  @override
  String toString() => name;

  static RoutingOutboundTag? fromString(String name) =>
      RoutingOutboundTag.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return RoutingOutboundTag.values.map((e) => e.name).toList();
  }
}

enum RoutingInboundTag {
  tunIn("tunIn"),
  pingIn("pingIn");

  const RoutingInboundTag(this.name);

  final String name;

  @override
  String toString() => name;

  static RoutingInboundTag? fromString(String name) =>
      RoutingInboundTag.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return RoutingInboundTag.values.map((e) => e.name).toList();
  }
}

enum DnsNetwork {
  none(""),
  tcp("tcp"),
  udp("udp");

  const DnsNetwork(this.name);

  final String name;

  @override
  String toString() => name;

  static DnsNetwork? fromString(String name) =>
      DnsNetwork.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return DnsNetwork.values.map((e) => e.name).toList();
  }
}

enum DnsNonIPQuery {
  skip("skip"),
  drop("drop"),
  reject("reject");

  const DnsNonIPQuery(this.name);

  final String name;

  @override
  String toString() => name;

  static DnsNonIPQuery? fromString(String name) =>
      DnsNonIPQuery.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return DnsNonIPQuery.values.map((e) => e.name).toList();
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

  static DnsQueryStrategy? fromString(String name) =>
      DnsQueryStrategy.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return DnsQueryStrategy.values.map((e) => e.name).toList();
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
