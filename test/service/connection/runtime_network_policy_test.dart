import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/runtime_network_policy.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/routing/region_catalog.dart';

Map<String, dynamic> wireguard(List<Object?> endpoints) => {
  'tag': 'wg',
  'protocol': 'wireguard',
  'settings': {
    'peers': [
      for (final endpoint in endpoints) {'endpoint': endpoint},
    ],
  },
};

CompiledConnection compileRaw(
  Map<String, dynamic> source, {
  Map<String, List<String>> hosts = const {},
}) => ConnectionCompiler.compile(
  settings: ConnectionSettings(expert: true),
  entries: [],
  raw: source,
  regions: RegionCatalog.fromJson(
    {'geosite': <String, dynamic>{}, 'geoip': <String, dynamic>{}},
    geositeCodes: [],
    geoipCodes: [],
  ),
  options: RuntimeOptions(
    platform: ConnectionPlatform.android,
    sessionDirectory: '/fixture/session',
    metricsPort: 18002,
    socksPort: 18003,
    ipv6: false,
    bootstrapAddresses: hosts,
  ),
);

void main() {
  test('IPv6 block precedes Raw user rules', () {
    final plan = compileRaw({
      'outbounds': [
        {'tag': 'direct', 'protocol': 'freedom'},
      ],
      'routing': {
        'rules': [
          {'network': 'tcp,udp', 'outboundTag': 'direct'},
        ],
      },
    });
    final rules = plan.config['routing']['rules'] as List;
    expect(rules[0]['ruleTag'], ConnectionCompiler.ipv6Block);
    expect(rules[0]['ip'], ['::/0']);
    expect(rules[1]['outboundTag'], 'direct');
  });

  test('WireGuard extraction preserves standard endpoints and rejects malformed ones', () {
    final source = wireguard([
      'node.test:51820',
      '192.0.2.1:51820',
      '[2001:db8::1]:51820',
    ]);
    final original = jsonEncode(source);
    expect(outboundAddresses(source), [
      'node.test',
      '192.0.2.1',
      '2001:db8::1',
    ]);
    expect(jsonEncode(source), original);
    for (final bad in [
      'node.test',
      'node.test:abc',
      'node.test:0',
      'node.test:65536',
      ':51820',
      '2001:db8::1:51820',
      '[node.test]:51820',
      '[::1]',
      'node.test:443/path',
      'node.test:443\n',
      null,
    ]) {
      expect(
        () => outboundAddresses(wireguard([bad])).toList(),
        throwsFormatException,
      );
    }
    expect(
      () => outboundAddresses(wireguard([])).toList(),
      throwsFormatException,
    );
    expect(
      () => outboundAddresses({'protocol': 'wireguard'}).toList(),
      throwsFormatException,
    );
  });

  test('WireGuard IPv6 is rejected and hostnames require bootstrap without rewriting peers', () {
    expect(
      () => compileRaw({
        'outbounds': [
          wireguard(['[2001:db8::1]:51820']),
        ],
      }),
      throwsFormatException,
    );
    final source = {
      'outbounds': [
        wireguard(['node.test:51820']),
      ],
    };
    expect(() => compileRaw(source), throwsFormatException);
    final plan = compileRaw(
      source,
      hosts: {
        'node.test': ['192.0.2.1'],
      },
    );
    expect(
      plan.config['outbounds'][0]['settings'],
      source['outbounds']![0]['settings'],
    );
    expect(plan.config['dns']['hosts']['node.test'], ['192.0.2.1']);
  });

  test(
    'IPv4-only DNS rejects explicit IPv6 in string, object and URL forms',
    () {
      for (final address in [
        '2001:4860:4860::8888',
        '[2001:db8::1]',
        'https://[2001:db8::1]/dns-query',
        'tcp://[2001:db8::1]:53',
        'https+local://[2001:db8::1]/dns-query',
      ]) {
        for (final entry in [
          address,
          {'address': address},
        ]) {
          expect(
            () => validateLocalDnsNetworkPolicy(
              {
                'dns': {
                  'servers': [entry],
                },
              },
              ipv6: false,
              requiresInterface: false,
            ),
            throwsFormatException,
          );
        }
      }
    },
  );

  test(
    'local DNS fails closed for interface binding and uncontrolled IPv4 lookup',
    () {
      for (final scheme in [
        'https+local',
        'h2c+local',
        'tcp+local',
        'quic+local',
      ]) {
        for (final host in ['192.0.2.1', 'dns.example.test']) {
          final config = {
            'dns': {
              'servers': ['$scheme://$host:443'],
            },
          };
          expect(
            () => validateLocalDnsNetworkPolicy(
              config,
              ipv6: true,
              requiresInterface: true,
            ),
            throwsFormatException,
          );
        }
        expect(
          () => validateLocalDnsNetworkPolicy(
            {
              'dns': {
                'servers': ['$scheme://dns.example.test:443'],
              },
            },
            ipv6: false,
            requiresInterface: false,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('permitted DNS modes remain untouched including ordinary localhost', () {
    final config = {
      'dns': {
        'servers': [
          'localhost',
          'fakedns',
          '8.8.8.8',
          'https://dns.google/dns-query',
        ],
      },
    };
    final source = jsonEncode(config);
    validateLocalDnsNetworkPolicy(config, ipv6: false, requiresInterface: true);
    expect(jsonEncode(config), source);
    validateLocalDnsNetworkPolicy(
      {
        'dns': {
          'servers': ['https+local://192.0.2.1/dns-query'],
        },
      },
      ipv6: false,
      requiresInterface: false,
    );
    validateLocalDnsNetworkPolicy(
      {
        'dns': {
          'servers': ['https+local://dns.google/dns-query'],
        },
      },
      ipv6: true,
      requiresInterface: false,
    );
  });
}
