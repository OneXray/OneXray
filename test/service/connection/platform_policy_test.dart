import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/settings.dart';

void main() {
  test(
    'defaults contain no demo selections and compile fixed runtime values',
    () {
      final policy = PlatformPolicy.defaults();
      expect(policy.ipv6Enabled, true);
      expect(policy.xrayOutboundInterfaceName, '');
      expect(policy.logEnabled, false);
      expect(policy.logLevel, 'warning');
      expect(policy.recordDns, true);
      expect(policy.maskAddress, 'full');
      expect(policy.toJson()['android'], {
        'appScope': 'all',
        'includedAppPackageNames': [],
        'excludedAppPackageNames': [],
      });
      final apple = policy.toJson()['apple'];
      expect(apple['connectWifiSsids'], isEmpty);
      expect(apple['disconnectWifiSsids'], isEmpty);
      expect(apple['cellularAction'], 'connect');
      expect(apple['ethernetAction'], 'connect');
      final tun = policy.toTun(ConnectionPlatform.ios);
      expect(tun.tunIPv4, '198.18.0.1');
      expect(tun.tunIPv6, 'fc00::1');
      expect(tun.tunDnsIPv4, '8.8.8.8');
      expect(tun.tunDnsIPv6, '2001:4860:4860::8888');
      expect(tun.dnsServerName, 'dns.google');
      expect(tun.enableIPv6, true);
      expect(tun.metricsEnabled, true);
      expect(tun.includeAllNetworks, false);
      expect(tun.excludeLocalNetworks, true);
      expect(tun.excludeCellularServices, true);
      expect(tun.excludeAPNs, true);
      expect(tun.excludeDeviceCommunication, true);
      expect(tun.enableDot, false);
      expect(tun.onDemandEnabled, false);
      expect(tun.onDemandRules, isEmpty);
      expect(policy.toWindowsPolicy().toJson(), {
        'alwaysOn': false,
        'allowLocalNetwork': true,
        'excludedCidrs': [],
      });
    },
  );

  test(
    'policy and converted native values cannot mutate the stored snapshot',
    () {
      final input = {
        'android': {
          'appScope': 'included',
          'includedAppPackageNames': ['com.example.included'],
          'excludedAppPackageNames': ['com.example.excluded'],
        },
      };
      final policy = PlatformPolicy.fromJson(input);
      input['android']!['includedAppPackageNames'] = ['com.example.changed'];
      final json = policy.toJson();
      json['android']['includedAppPackageNames'].clear();
      final tun = policy.toTun(ConnectionPlatform.android);
      tun.allowAppList!.clear();
      expect(policy.toTun(ConnectionPlatform.android).allowAppList, [
        'com.example.included',
      ]);
      expect(
        PlatformPolicy.fromJson(policy.toJson()).toJson(),
        policy.toJson(),
      );
    },
  );

  test(
    'Android scopes preserve both lists but compile only the active selection',
    () {
      final value = PlatformPolicy.defaults().toJson();
      value['android']['includedAppPackageNames'] = ['com.example.included'];
      value['android']['excludedAppPackageNames'] = ['com.example.excluded'];
      for (final scope in ['all', 'included', 'excluded']) {
        value['android']['appScope'] = scope;
        final policy = PlatformPolicy.fromJson(value);
        final tun = policy.toTun(ConnectionPlatform.android);
        expect(tun.perAppVPNMode, scope == 'included' ? 'allow' : 'disallow');
        expect(
          tun.allowAppList,
          scope == 'included' ? ['com.example.included'] : [],
        );
        expect(
          tun.disallowAppList,
          scope == 'excluded' ? ['com.example.excluded'] : [],
        );
        expect(policy.toJson()['android']['includedAppPackageNames'], [
          'com.example.included',
        ]);
        expect(policy.toJson()['android']['excludedAppPackageNames'], [
          'com.example.excluded',
        ]);
      }
      final emptyIncluded = PlatformPolicy.fromJson({
        'android': {'appScope': 'included'},
      });
      expect(
        emptyIncluded.toJson()['android']['includedAppPackageNames'],
        isEmpty,
      );
      expect(
        () => emptyIncluded.toTun(ConnectionPlatform.android),
        throwsFormatException,
      );
      expect(
        () => emptyIncluded.toTun(ConnectionPlatform.ios),
        returnsNormally,
      );
      expect(
        PlatformPolicy.fromJson({
          'android': {'appScope': 'excluded'},
        }).toTun(ConnectionPlatform.android).disallowAppList,
        isEmpty,
      );
    },
  );

  test(
    'Apple On Demand compiles platform rules in order without changing SSIDs',
    () {
      final policy = PlatformPolicy.fromJson({
        'apple': {
          'onDemandEnabled': true,
          'connectWifiSsids': [' Home Wi-Fi ', 'office', ' \t'],
          'disconnectWifiSsids': ['Office'],
          'cellularAction': 'disconnect',
          'ethernetAction': 'connect',
        },
      });
      for (final platform in [
        ConnectionPlatform.ios,
        ConnectionPlatform.macos,
      ]) {
        final rules = policy.toTun(platform).onDemandRules!;
        expect(rules.map((rule) => rule.toJson()).toList(), [
          {
            'mode': 'disconnect',
            'interfaceType': 'wifi',
            'ssid': ['Office'],
          },
          {
            'mode': 'connect',
            'interfaceType': 'wifi',
            'ssid': [' Home Wi-Fi ', 'office'],
          },
          {
            'mode': platform == ConnectionPlatform.ios
                ? 'disconnect'
                : 'connect',
            'interfaceType': platform == ConnectionPlatform.ios
                ? 'cellular'
                : 'ethernet',
          },
          {'mode': 'ignore', 'interfaceType': 'any'},
        ]);
      }
      final withoutWifi = PlatformPolicy.fromJson({
        'apple': {'onDemandEnabled': true},
      });
      expect(
        withoutWifi.toTun(ConnectionPlatform.ios).onDemandRules!.length,
        2,
      );
      expect(
        () => PlatformPolicy.fromJson({
          'apple': {
            'connectWifiSsids': ['Same'],
            'disconnectWifiSsids': ['Same'],
          },
        }),
        throwsFormatException,
      );
    },
  );

  test('Apple master switches hide runtime rules but retain stored drafts', () {
    final value = PlatformPolicy.defaults().toJson();
    value['apple'].addAll({
      'captureAllTraffic': false,
      'allowLocalNetwork': false,
      'alwaysOn': true,
      'onDemandEnabled': true,
      'connectWifiSsids': ['Saved'],
      'ethernetAction': 'disconnect',
    });
    var policy = PlatformPolicy.fromJson(value);
    expect(
      policy
          .toTun(ConnectionPlatform.macos)
          .onDemandRules!
          .map((rule) => rule.toJson())
          .toList(),
      [
        {'mode': 'connect', 'interfaceType': 'any'},
      ],
    );
    expect(policy.toTun(ConnectionPlatform.macos).excludeLocalNetworks, false);
    expect(policy.toJson()['apple']['connectWifiSsids'], ['Saved']);
    expect(policy.toJson()['apple']['onDemandEnabled'], true);
    value['apple']['alwaysOn'] = false;
    value['apple']['onDemandEnabled'] = false;
    policy = PlatformPolicy.fromJson(value);
    expect(policy.toTun(ConnectionPlatform.macos).onDemandRules, isEmpty);
    expect(policy.toJson()['apple']['connectWifiSsids'], ['Saved']);
    value['apple']['onDemandEnabled'] = true;
    expect(
      PlatformPolicy.fromJson(value)
          .toTun(ConnectionPlatform.macos)
          .onDemandRules![1]
          .mode,
      'disconnect',
    );
  });

  test(
    'desktop interface selection and Windows policy are explicit and isolated',
    () {
      final defaults = PlatformPolicy.defaults();
      for (final platform in [
        ConnectionPlatform.windows,
        ConnectionPlatform.linux,
      ]) {
        expect(() => defaults.toTun(platform), throwsFormatException);
      }
      final policy = PlatformPolicy.fromJson({
        'xrayOutboundInterfaceName': 'Ethernet 2',
        'windows': {
          'alwaysOn': true,
          'allowLocalNetwork': false,
          'excludedCidrs': ['192.0.2.0/24', '2001:db8::/64'],
        },
      });
      expect(
        policy.toTun(ConnectionPlatform.windows).autoOutboundsInterface,
        'Ethernet 2',
      );
      expect(
        policy.toTun(ConnectionPlatform.linux).autoOutboundsInterface,
        'Ethernet 2',
      );
      for (final platform in [
        ConnectionPlatform.ios,
        ConnectionPlatform.macos,
        ConnectionPlatform.android,
      ]) {
        expect(policy.toTun(platform).autoOutboundsInterface, isNull);
      }
      expect(policy.toTun(ConnectionPlatform.windows).onDemandEnabled, isNull);
      expect(policy.toWindowsPolicy().toJson(), policy.toJson()['windows']);
      final ipv4 = policy.toJson()..['ipv6Enabled'] = false;
      final ipv4Policy = PlatformPolicy.fromJson(ipv4);
      expect(() => ipv4Policy.toWindowsPolicy(), throwsFormatException);
      expect(
        () => ipv4Policy.toTun(ConnectionPlatform.windows),
        throwsFormatException,
      );
      expect(() => ipv4Policy.toTun(ConnectionPlatform.ios), returnsNormally);
      expect(ipv4Policy.toJson()['windows']['excludedCidrs'], [
        '192.0.2.0/24',
        '2001:db8::/64',
      ]);
    },
  );

  test(
    'Windows CIDRs reject broad, duplicate, host-bit and DNS exclusions',
    () {
      for (final cidrs in <List<String>>[
        ['0.0.0.0/0'],
        ['::/0'],
        ['192.0.2.1/24'],
        ['2001:db8::1/64'],
        ['192.0.2.0/33'],
        ['2001:db8::/129'],
        ['192.0.2.0'],
        ['192.0.2.0/24\n'],
        ['192.0.002.0/24'],
        ['[2001:db8::]/64'],
        ['fe80::%en0/64'],
        ['192.0.2.0/24', '192.0.2.0/24'],
        ['2001:0DB8:0:0::/64', '2001:db8::/64'],
        ['8.8.8.8/32'],
        ['8.8.0.0/16'],
        ['2001:4860::/32'],
        List.generate(65, (i) => '192.0.2.$i/32'),
      ]) {
        expect(
          () => PlatformPolicy.fromJson({
            'windows': {'excludedCidrs': cidrs},
          }),
          throwsFormatException,
        );
      }
      expect(
        PlatformPolicy.fromJson({
          'windows': {
            'excludedCidrs': ['192.0.2.1/32', '2001:db8::1/128'],
          },
        }).toWindowsPolicy().excludedCidrs.length,
        2,
      );
    },
  );

  test('JSON shape and controlled choices reject invalid values', () {
    for (final value in <Map<String, dynamic>>[
      {'unknown': true},
      {'ipv6Enabled': 1},
      {'apple': null},
      {
        'android': {'appScope': 'allow'},
      },
      {
        'android': {
          'includedAppPackageNames': [1],
        },
      },
      {
        'android': {
          'includedAppPackageNames': ['not a package'],
        },
      },
      {
        'apple': {'cellularAction': 'ignore'},
      },
      {
        'apple': {'extra': true},
      },
      {
        'log': {'level': 'none'},
      },
      {
        'windows': {'alwaysOn': 'false'},
      },
    ]) {
      expect(() => PlatformPolicy.fromJson(value), throwsFormatException);
    }
    final policy = PlatformPolicy.fromJson({
      'log': {
        'enabled': true,
        'level': 'debug',
        'recordDns': false,
        'maskIp': false,
      },
    });
    expect(policy.logEnabled, true);
    expect(policy.logLevel, 'debug');
    expect(policy.recordDns, false);
    expect(policy.maskAddress, '');
  });
}
