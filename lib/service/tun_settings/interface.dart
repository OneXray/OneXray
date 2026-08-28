import 'dart:io';

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
