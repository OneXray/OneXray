import 'dart:io';

import 'package:onexray/service/connection/platform_policy.dart';

class OutboundInterfaceOption {
  final String name;
  final List<String> addresses;
  final bool currentInternet;

  const OutboundInterfaceOption(
    this.name,
    this.addresses,
    this.currentInternet,
  );
}

Future<List<NetworkInterface>> queryInterfaceList() async {
  final interfaces = await NetworkInterface.list();
  final filterInterfaces = interfaces.where((e) {
    return e.addresses.any(
      (address) =>
          !address.isLinkLocal &&
          !address.isLoopback &&
          !address.isMulticast &&
          (address.type == InternetAddressType.IPv4 ||
              address.type == InternetAddressType.IPv6),
    );
  }).toList();
  return filterInterfaces;
}

Future<List<NetworkInterface>> queryXrayOutboundInterfaceList() async => [
  for (final row in await queryInterfaceList())
    if (row.name != 'OneXrayTun' &&
        !row.addresses.any(
          (address) =>
              address.address == PlatformPolicy.tunIpv4Address ||
              address.address == PlatformPolicy.tunIpv6Address,
        ))
      row,
];

Future<List<OutboundInterfaceOption>> queryXrayOutboundInterfaces() async {
  final rows = await queryXrayOutboundInterfaceList();
  final current = await _currentInternetInterface();
  return [
    for (final row in rows)
      OutboundInterfaceOption(
        row.name,
        row.addresses.map((address) => address.address).toList(),
        row.name == current,
      ),
  ];
}

Future<String?> _currentInternetInterface() async {
  try {
    if (Platform.isLinux) {
      final routes =
          (await File('/proc/net/route').readAsLines())
              .skip(1)
              .map((line) => line.trim().split(RegExp(r'\s+')))
              .where((parts) => parts.length > 7 && parts[1] == '00000000')
              .toList()
            ..sort(
              (a, b) =>
                  (int.tryParse(a[6]) ?? 0).compareTo(int.tryParse(b[6]) ?? 0),
            );
      return routes.isEmpty ? null : routes.first.first;
    }
    if (Platform.isWindows) {
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '(Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -First 1).InterfaceAlias',
      ]).timeout(const Duration(seconds: 5));
      return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
    }
  } on Exception {
    // This is only a reference hint and never selects an interface.
  }
  return null;
}
