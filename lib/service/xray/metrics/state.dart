class TrafficMetricsState {
  final bool available;
  final int uploadTotal;
  final int downloadTotal;
  final int uploadSpeed;
  final int downloadSpeed;

  const TrafficMetricsState({
    required this.available,
    required this.uploadTotal,
    required this.downloadTotal,
    required this.uploadSpeed,
    required this.downloadSpeed,
  });

  const TrafficMetricsState.unavailable()
    : available = false,
      uploadTotal = 0,
      downloadTotal = 0,
      uploadSpeed = 0,
      downloadSpeed = 0;

  const TrafficMetricsState.zero()
    : available = true,
      uploadTotal = 0,
      downloadTotal = 0,
      uploadSpeed = 0,
      downloadSpeed = 0;
}
