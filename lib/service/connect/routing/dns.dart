import 'package:onexray/core/model/xray_json.dart';

abstract final class RoutingDns {
  static const defaultAddress = '8.8.8.8';
  static const proxyTag = 'app-dns-proxy';
  static const directTag = 'app-dns-direct';

  /// DNS only knows the queried domain, not the later connection's conditions.
  static List<String> directDomains(Iterable<XrayRoutingRule> rules) => {
    for (final rule in rules)
      if (rule.outboundTag == 'direct' &&
          (rule.ip?.isEmpty ?? true) &&
          rule.port == null &&
          rule.network == null &&
          (rule.protocol?.isEmpty ?? true) &&
          (rule.localOS?.isEmpty ?? true) &&
          (rule.inboundTag?.isEmpty ?? true))
        ...?rule.domain,
  }.toList();

  static XrayDns compile({
    String? directAddress,
    Iterable<String> directDomains = const [],
    bool ipv6 = true,
  }) {
    final queryStrategy = ipv6 ? 'UseIP' : 'UseIPv4';
    return XrayDns(
      servers: [
        XrayDnsServer(
          address: defaultAddress,
          tag: proxyTag,
          queryStrategy: queryStrategy,
        ),
        if (directAddress != null)
          XrayDnsServer(
            address: directAddress,
            tag: directTag,
            domains: directDomains.toSet().toList(),
            skipFallback: true,
            queryStrategy: queryStrategy,
          ),
      ],
    );
  }
}
