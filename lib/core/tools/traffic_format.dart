String formatTraffic(int bytes, {bool connection = false}) {
  // Match the connection page's approved labels; other consumers use IEC units.
  final units = connection
      ? const ['B', 'KB', 'MB', 'GB', 'TB']
      : const ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  var number = value.toStringAsFixed(
    unit == 0
        ? 0
        : connection
        ? 2
        : 1,
  );
  if (connection && number.contains('.')) {
    number = number.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return '$number ${units[unit]}';
}
