import 'dart:io';

import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/core/model/xray_standard.dart';

enum FakeDnsValidationError {
  ipPoolRequired,
  ipPoolInvalid,
  poolSizeInvalid,
  poolSizeTooLarge,
}

class FakeDnsState {
  final String defaultIpPool;
  final String defaultPoolSize;
  final InternetAddressType addressType;
  var ipPool = "";
  var poolSize = "";

  FakeDnsState({
    required this.defaultIpPool,
    required this.defaultPoolSize,
    required this.addressType,
  }) {
    ipPool = defaultIpPool;
    poolSize = defaultPoolSize;
  }

  void removeWhitespace() {
    ipPool = ipPool.removeWhitespace;
    poolSize = poolSize.removeWhitespace;
  }

  void readFromXrayJson(XrayFakeDns fakeDns) {
    if (EmptyTool.checkString(fakeDns.ipPool)) {
      ipPool = fakeDns.ipPool!;
    }
    if (fakeDns.poolSize != null) {
      poolSize = fakeDns.poolSize!.toString();
    }
  }

  XrayFakeDns get xrayJson {
    final fakeDns = XrayFakeDnsStandard.standard;
    fakeDns.ipPool = ipPool;
    fakeDns.poolSize = int.tryParse(poolSize) ?? int.parse(defaultPoolSize);

    return fakeDns;
  }

  FakeDnsValidationError? validate() {
    final value = ipPool.removeWhitespace;
    if (value.isEmpty) {
      return FakeDnsValidationError.ipPoolRequired;
    }

    final parts = value.split("/");
    if (parts.length != 2) {
      return FakeDnsValidationError.ipPoolInvalid;
    }

    final address = InternetAddress.tryParse(parts[0]);
    final prefix = int.tryParse(parts[1]);
    if (address == null || prefix == null) {
      return FakeDnsValidationError.ipPoolInvalid;
    }
    if (address.type != addressType) {
      return FakeDnsValidationError.ipPoolInvalid;
    }

    final bits = address.type == InternetAddressType.IPv4 ? 32 : 128;
    if (prefix < 0 || prefix > bits) {
      return FakeDnsValidationError.ipPoolInvalid;
    }

    final poolSizeInt = int.tryParse(poolSize.removeWhitespace);
    if (poolSizeInt == null || poolSizeInt <= 0) {
      return FakeDnsValidationError.poolSizeInvalid;
    }

    final capacity = BigInt.one << (bits - prefix);
    if (BigInt.from(poolSizeInt) >= capacity) {
      return FakeDnsValidationError.poolSizeTooLarge;
    }
    return null;
  }
}

class FakeDnsPoolsState {
  static const ipv4IpPool = "198.18.0.0/15";
  static const ipv6IpPool = "fc00::/18";
  static const defaultPoolSize = "32768";

  final ipv4 = FakeDnsState(
    defaultIpPool: ipv4IpPool,
    defaultPoolSize: defaultPoolSize,
    addressType: InternetAddressType.IPv4,
  );
  final ipv6 = FakeDnsState(
    defaultIpPool: ipv6IpPool,
    defaultPoolSize: defaultPoolSize,
    addressType: InternetAddressType.IPv6,
  );

  void removeWhitespace() {
    ipv4.removeWhitespace();
    ipv6.removeWhitespace();
  }

  void readFromXrayJson(XrayJson xrayJson) {
    if (!EmptyTool.checkList(xrayJson.fakeDns)) {
      return;
    }
    for (final fakeDns in xrayJson.fakeDns!) {
      final ipPool = fakeDns.ipPool;
      if (!EmptyTool.checkString(ipPool)) {
        continue;
      }
      final address = InternetAddress.tryParse(ipPool!.split("/").first);
      if (address == null) {
        continue;
      }
      switch (address.type) {
        case InternetAddressType.IPv4:
          ipv4.readFromXrayJson(fakeDns);
          break;
        case InternetAddressType.IPv6:
          ipv6.readFromXrayJson(fakeDns);
          break;
        default:
          break;
      }
    }
  }

  List<XrayFakeDns> xrayJson(DnsQueryStrategy queryStrategy) {
    switch (queryStrategy) {
      case DnsQueryStrategy.useIP:
        return [ipv4.xrayJson, ipv6.xrayJson];
      case DnsQueryStrategy.useIPv4:
        return [ipv4.xrayJson];
      case DnsQueryStrategy.useIPv6:
        return [ipv6.xrayJson];
    }
  }

  FakeDnsValidationError? validateIPv4() => ipv4.validate();

  FakeDnsValidationError? validateIPv6() => ipv6.validate();
}
