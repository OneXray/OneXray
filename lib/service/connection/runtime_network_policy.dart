import 'dart:io';

/// Local DNS URLs dial outside Xray routing and do not receive outbound
/// sockopt.interface or DNS-host bootstrap overrides. Reject what cannot obey
/// the global policy; never silently change the user's transport or address.
void validateLocalDnsNetworkPolicy(
  Map<String, dynamic> config, {
  required bool ipv6,
  required bool requiresInterface,
}) {
  final dns = config['dns'];
  if (dns == null) return;
  if (dns is! Map) throw const FormatException('dns must be an object');
  final servers = dns['servers'];
  if (servers == null) return;
  if (servers is! List) {
    throw const FormatException('dns.servers must be an array');
  }
  for (final server in servers) {
    final address = server is Map ? server['address'] : server;
    if (address is! String || address.isEmpty || address.trim() != address) {
      throw const FormatException(
        'DNS server address must be a nonempty string',
      );
    }
    // Desktop's ordinary system resolver is already bound to the App-selected
    // interface / 8.8.8.8. FakeDNS has no remote DNS transport.
    if (address.toLowerCase() == 'localhost' ||
        address.toLowerCase() == 'fakedns') {
      continue;
    }

    var host = address;
    var local = false;
    if (address.contains('://')) {
      final uri = Uri.tryParse(address);
      if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
        throw const FormatException('Invalid DNS server URL');
      }
      host = uri.host;
      local = uri.scheme.toLowerCase().endsWith('+local');
    }
    if (host.startsWith('[')) {
      final closing = host.indexOf(']');
      if (closing < 0) throw const FormatException('Invalid DNS IPv6 endpoint');
      host = host.substring(1, closing);
    }
    final ip = InternetAddress.tryParse(host);
    if (!ipv6 && ip?.type == InternetAddressType.IPv6) {
      throw const FormatException(
        'IPv6 DNS endpoints are unavailable while IPv6 is disabled',
      );
    }
    // ponytail: fail closed for +local until P3 can enforce interface and IP
    // family in the global dialer; a routing rule cannot protect this path.
    if (local && requiresInterface) {
      throw const FormatException(
        'Local DNS URLs cannot use the required network interface',
      );
    }
    if (local && !ipv6 && ip?.type != InternetAddressType.IPv4) {
      throw const FormatException(
        'Local DNS hostnames cannot guarantee IPv4-only resolution',
      );
    }
  }
}
