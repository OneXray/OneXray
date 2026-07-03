import 'dart:io';

Future<List<NetworkInterface>> queryInterfaceList() async {
  final interfaces = await NetworkInterface.list();
  final filterInterfaces = interfaces.where((e) {
    for (final address in e.addresses) {
      if (address.isLinkLocal) {
        return false;
      }
      if (address.isLoopback) {
        return false;
      }
      if (address.isMulticast) {
        return false;
      }
      if (!(address.type == InternetAddressType.IPv4 ||
          address.type == InternetAddressType.IPv6)) {
        return false;
      }
    }
    return true;
  }).toList();
  return filterInterfaces;
}
