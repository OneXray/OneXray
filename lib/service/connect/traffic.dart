/// One in-memory sample from the active Xray metrics endpoint.
class ConnectionTraffic {
  final int uplink;
  final int downlink;
  final int sampledAtMs;

  const ConnectionTraffic({
    required this.uplink,
    required this.downlink,
    required this.sampledAtMs,
  });
}
