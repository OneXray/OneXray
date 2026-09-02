import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/model/tun_json.dart';
import 'package:onexray/service/connection/settings.dart';

/// User policy is a value snapshot, not the mutable native TunJson or old prefs.
final class PlatformPolicy {
  final String _json;

  PlatformPolicy._(Map<String, dynamic> value) : _json = jsonEncode(value);

  factory PlatformPolicy.defaults() => PlatformPolicy.fromJson({});

  factory PlatformPolicy.fromJson(Map<String, dynamic> value) {
    final policy = _readPolicyObject(_defaults, value);
    final android = policy['android'] as Map<String, dynamic>;
    if (!{'all', 'included', 'excluded'}.contains(android['appScope'])) {
      throw const FormatException('Invalid Android app scope');
    }
    for (final key in ['includedAppPackageNames', 'excludedAppPackageNames']) {
      if ((android[key] as List<String>).any(
        (name) => name.isEmpty || RegExp(r'[\s\x00]').hasMatch(name),
      )) {
        throw const FormatException('Invalid Android app package name');
      }
    }

    final apple = policy['apple'] as Map<String, dynamic>;
    for (final key in ['cellularAction', 'ethernetAction']) {
      if (!{'connect', 'disconnect'}.contains(apple[key])) {
        throw const FormatException('Invalid Apple network action');
      }
    }
    for (final key in ['connectWifiSsids', 'disconnectWifiSsids']) {
      // SSIDs are exact names; trimming nonblank values would change the match.
      apple[key] = (apple[key] as List<String>)
          .where((name) => name.trim().isNotEmpty)
          .toList();
    }
    if ((apple['connectWifiSsids'] as List<String>).any(
      (name) => (apple['disconnectWifiSsids'] as List<String>).contains(name),
    )) {
      throw const FormatException('A Wi-Fi name cannot have both actions');
    }

    final log = policy['log'] as Map<String, dynamic>;
    if (!{'error', 'warning', 'info', 'debug'}.contains(log['level'])) {
      throw const FormatException('Invalid Xray log level');
    }
    _validateExclusions(policy['windows']['excludedCidrs'] as List<String>);
    return PlatformPolicy._(policy);
  }

  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;

  bool get ipv6Enabled => toJson()['ipv6Enabled'] as bool;
  String get xrayOutboundInterfaceName =>
      toJson()['xrayOutboundInterfaceName'] as String;
  bool get logEnabled => toJson()['log']['enabled'] as bool;
  String get logLevel => toJson()['log']['level'] as String;
  bool get recordDns => toJson()['log']['recordDns'] as bool;
  String get maskAddress => toJson()['log']['maskIp'] == true ? 'full' : '';

  static const tunIpv4Address = '198.18.0.1';
  static const tunIpv6Address = 'fc00::1';
  static const dnsIpv4Address = '8.8.8.8';
  static const dnsIpv6Address = '2001:4860:4860::8888';
  static const dnsServerName = 'dns.google';

  /// Compiles for a real start. Inactive platform drafts remain in [toJson].
  TunJson toTun(ConnectionPlatform platform) {
    final policy = toJson();
    final tun = <String, dynamic>{
      'tunIPv4': tunIpv4Address,
      'tunIPv6': tunIpv6Address,
      'tunDnsIPv4': dnsIpv4Address,
      'tunDnsIPv6': dnsIpv6Address,
      'dnsServerName': dnsServerName,
      'enableIPv6': policy['ipv6Enabled'],
      'metricsEnabled': true,
      'tunName': 'OneXrayTun',
    };

    if (platform == ConnectionPlatform.windows ||
        platform == ConnectionPlatform.linux) {
      final interfaceName = policy['xrayOutboundInterfaceName'] as String;
      if (interfaceName.trim().isEmpty || interfaceName.contains('\u0000')) {
        throw const FormatException('Network interface is required');
      }
      tun['autoOutboundsInterface'] = interfaceName;
    }

    if (platform == ConnectionPlatform.windows) {
      toWindowsPolicy();
    } else if (platform == ConnectionPlatform.android) {
      final android = policy['android'] as Map<String, dynamic>;
      final scope = android['appScope'];
      final included = (android['includedAppPackageNames'] as List)
          .cast<String>();
      if (scope == 'included' && included.isEmpty) {
        throw const FormatException(
          'Select at least one app before connecting',
        );
      }
      tun.addAll({
        'perAppVPNMode': scope == 'included' ? 'allow' : 'disallow',
        'allowAppList': scope == 'included' ? included : <String>[],
        'disallowAppList': scope == 'excluded'
            ? android['excludedAppPackageNames']
            : <String>[],
      });
    } else if (platform == ConnectionPlatform.ios ||
        platform == ConnectionPlatform.macos) {
      final apple = policy['apple'] as Map<String, dynamic>;
      final alwaysOn = apple['alwaysOn'] as bool;
      final onDemand = alwaysOn || apple['onDemandEnabled'] == true;
      final rules = <Map<String, dynamic>>[];
      if (alwaysOn) {
        rules.add({'mode': 'connect', 'interfaceType': 'any'});
      } else if (onDemand) {
        for (final action in ['disconnect', 'connect']) {
          final ssids = (apple['${action}WifiSsids'] as List).cast<String>();
          if (ssids.isNotEmpty) {
            rules.add({'mode': action, 'interfaceType': 'wifi', 'ssid': ssids});
          }
        }
        final network = platform == ConnectionPlatform.ios
            ? 'cellular'
            : 'ethernet';
        rules.add({
          'mode': apple['${network}Action'],
          'interfaceType': network,
        });
        rules.add({'mode': 'ignore', 'interfaceType': 'any'});
      }
      tun.addAll({
        'includeAllNetworks': apple['captureAllTraffic'],
        'excludeLocalNetworks': apple['allowLocalNetwork'],
        'excludeCellularServices': apple['bypassCellularServices'],
        'excludeAPNs': apple['bypassApplePushNotifications'],
        'excludeDeviceCommunication': apple['allowDeviceCommunication'],
        'enableDot': apple['dnsOverTls'],
        'onDemandEnabled': onDemand,
        'onDemandRules': rules,
      });
    }
    return TunJson.fromJson(tun);
  }

  WindowsVpnPolicy toWindowsPolicy() {
    final policy = toJson();
    final windows = policy['windows'] as Map<String, dynamic>;
    final cidrs = (windows['excludedCidrs'] as List).cast<String>();
    _validateExclusions(cidrs, ipv6: policy['ipv6Enabled'] as bool);
    return WindowsVpnPolicy(
      alwaysOn: windows['alwaysOn'] as bool,
      allowLocalNetwork: windows['allowLocalNetwork'] as bool,
      excludedCidrs: List.unmodifiable(cidrs),
    );
  }
}

const _defaults = <String, dynamic>{
  'ipv6Enabled': true,
  'xrayOutboundInterfaceName': '',
  'android': {
    'appScope': 'all',
    'includedAppPackageNames': <String>[],
    'excludedAppPackageNames': <String>[],
  },
  'apple': {
    'captureAllTraffic': false,
    'allowLocalNetwork': true,
    'bypassCellularServices': true,
    'bypassApplePushNotifications': true,
    'allowDeviceCommunication': true,
    'dnsOverTls': false,
    'alwaysOn': false,
    'onDemandEnabled': false,
    'connectWifiSsids': <String>[],
    'disconnectWifiSsids': <String>[],
    'cellularAction': 'connect',
    'ethernetAction': 'connect',
  },
  'windows': {
    'alwaysOn': false,
    'allowLocalNetwork': true,
    'excludedCidrs': <String>[],
  },
  'log': {
    'enabled': false,
    'level': 'warning',
    'recordDns': true,
    'maskIp': true,
  },
};

Map<String, dynamic> _readPolicyObject(
  Map<String, dynamic> defaults,
  Map value,
) {
  if (value.keys.any((key) => !defaults.containsKey(key))) {
    throw const FormatException('Unknown platform policy field');
  }
  return defaults.map<String, dynamic>((key, fallback) {
    final item = value.containsKey(key) ? value[key] : fallback;
    if (fallback is Map<String, dynamic> && item is Map) {
      return MapEntry(key, _readPolicyObject(fallback, item));
    }
    if (fallback is List && item is List && item.every((v) => v is String)) {
      return MapEntry(key, List<String>.from(item));
    }
    if (fallback is bool && item is bool ||
        fallback is String && item is String) {
      return MapEntry(key, item);
    }
    throw FormatException('Invalid platform policy field: $key');
  });
}

void _validateExclusions(List<String> values, {bool ipv6 = true}) {
  if (values.length > 64) {
    throw const FormatException('Windows VPN allows at most 64 exclusions');
  }
  final seen = <String>{};
  final dns = [
    InternetAddress(PlatformPolicy.dnsIpv4Address).rawAddress,
    InternetAddress(PlatformPolicy.dnsIpv6Address).rawAddress,
  ];
  for (final value in values) {
    final parts = value.split('/');
    final address =
        parts.length == 2 && !RegExp(r'[\[\]%\s]').hasMatch(parts[0])
        ? InternetAddress.tryParse(parts[0])
        : null;
    final prefix =
        parts.length == 2 &&
            RegExp(r'^[1-9][0-9]*$').stringMatch(parts[1]) == parts[1]
        ? int.tryParse(parts[1])
        : null;
    if (address == null ||
        prefix == null ||
        prefix > address.rawAddress.length * 8) {
      throw const FormatException('Invalid Windows VPN exclusion CIDR');
    }
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4 &&
        parts[0] != bytes.join('.')) {
      throw const FormatException('Invalid Windows VPN exclusion CIDR');
    }
    if (!ipv6 && address.type == InternetAddressType.IPv6) {
      throw const FormatException('IPv6 exclusions require IPv6 to be enabled');
    }
    for (var i = 0; i < bytes.length; i++) {
      if ((bytes[i] & _mask(prefix, i)) != bytes[i]) {
        throw const FormatException('Windows VPN exclusion must be a network');
      }
    }
    if (!seen.add('${bytes.join(',')}/$prefix')) {
      throw const FormatException('Duplicate Windows VPN exclusion');
    }
    for (final server in dns) {
      if (server.length == bytes.length &&
          bytes.indexed.every(
            (entry) => (server[entry.$1] & _mask(prefix, entry.$1)) == entry.$2,
          )) {
        throw const FormatException(
          'Windows VPN exclusion contains tunnel DNS',
        );
      }
    }
  }
}

int _mask(int prefix, int byteIndex) {
  final bits = prefix - byteIndex * 8;
  return bits >= 8
      ? 255
      : bits <= 0
      ? 0
      : (255 << (8 - bits)) & 255;
}
