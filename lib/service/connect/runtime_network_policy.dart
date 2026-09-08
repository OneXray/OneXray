/// Local DNS URLs dial outside Xray routing and do not receive outbound
/// sockopt.interface. Reject them when an outbound interface is required;
/// never silently change the user's transport or address.
void validateLocalDnsNetworkPolicy(
  Map<String, dynamic> config, {
  required bool requiresInterface,
}) {
  if (!requiresInterface) return;
  final dns = config['dns'];
  if (dns is! Map) return;
  final servers = dns['servers'];
  if (servers is! List) return;
  for (final server in servers) {
    final address = server is Map ? server['address'] : server;
    if (address is! String) continue;
    if (Uri.tryParse(address)?.scheme.toLowerCase().endsWith('+local') ==
        true) {
      throw const FormatException(
        'Local DNS URLs cannot use the required network interface',
      );
    }
  }
}
