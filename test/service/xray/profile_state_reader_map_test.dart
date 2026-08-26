import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/state_db.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_validator.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AppEventBus eventBus;

  setUpAll(() => eventBus = AppEventBus());
  tearDownAll(() => eventBus.close());

  test(
    'Routing domain strategy writes canonical values and reads legacy case',
    () {
      expect(RoutingDomainStrategy.ipIfNonMatch.name, 'IPIfNonMatch');
      expect(RoutingDomainStrategy.ipOnDemand.name, 'IPOnDemand');
      expect(
        RoutingDomainStrategy.fromString('IpIfNonMatch'),
        RoutingDomainStrategy.ipIfNonMatch,
      );
    },
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('Profile database reader preserves the complete config Map', () {
    final source = <String, dynamic>{
      'name': 'Profile',
      'dns': {
        'servers': [
          {
            'address': 'https://example.com/dns-query',
            'future': {
              'nested': [1, 2, 3],
            },
          },
        ],
      },
      'routing': {
        'rules': [
          {
            'type': 'field',
            'future': {'keep': true},
          },
        ],
      },
      'observatory': {
        'probeInterval': '30s',
        'future': {'keep': true},
      },
    };
    final row = CoreConfigData(
      id: 1,
      name: 'Database name',
      type: CoreConfigType.profile.name,
      tags: '',
      data: base64Encode(utf8.encode(JsonTool.encoder.convert(source))),
      delay: -1,
      subId: -1,
    );

    final first = readProfileMapFromDbData(row);
    final second = readProfileMapFromDbData(row);
    final firstDns = first['dns'] as Map<String, dynamic>;
    final firstServers = firstDns['servers'] as List<dynamic>;
    (firstServers.single as Map<String, dynamic>)['address'] =
        'changed.example';

    expect(second, source);
    final secondRouting = second['routing'] as Map<String, dynamic>;
    final secondRules = secondRouting['rules'] as List<dynamic>;
    final secondRule = secondRules.single as Map<String, dynamic>;
    final future = secondRule['future'] as Map<String, dynamic>;
    expect(future['keep'], isTrue);
  });

  test('Profile preserves App-unprojected user outbound Maps', () {
    final outbound = <String, dynamic>{
      'name': '  node  ',
      'tag': 'proxy',
      'protocol': 'future-protocol',
      'settings': <dynamic>['core', 'owned', 'shape'],
      'streamSettings': {
        'network': 'tcp',
        'security': 'future-security',
        'sockopt': {'interface': ' en0 ', 'appUnprojected': true},
      },
      'appUnprojected': {
        'nested': [1, 2],
      },
    };
    final profile = readProfileMapFromText(
      jsonEncode({
        'name': 'Profile',
        'outbounds': [outbound],
      }),
    );

    expect(profile['outbounds'], [outbound]);
  });

  test(
    'Profile text reader applies the final name without projecting fields',
    () {
      final source = <String, dynamic>{
        'name': '',
        'dns': {
          'servers': [
            '1.1.1.1',
            {
              'address': 'https://example.com/dns-query',
              'future': {'keep': true},
            },
          ],
        },
        'fakeDns': {'ipPool': '198.18.0.0/15', 'future': true},
        'observatory': {
          'probeInterval': '30s',
          'future': {'keep': true},
        },
      };

      final profile = readProfileMapFromText(
        JsonTool.encoder.convert(source),
        nameOverride: 'Shared Profile',
      );

      expect(profileName(profile), 'Shared Profile');
      expect(source['name'], isEmpty);
      expect(profile['dns'], source['dns']);
      expect(profile['fakeDns'], source['fakeDns']);
      expect(profile['observatory'], source['observatory']);
      expect(readProfileMapFromText(encodeProfileMap(profile)), profile);
    },
  );

  test('Profile companion keeps the legacy database type and complete Map', () {
    final source = <String, dynamic>{
      'name': 'Stored Profile',
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'future': {'keep': true},
      },
      'policy': {
        'levels': {
          '0': {'handshake': 5},
        },
      },
      'stats': {'future': true},
      'observatory': {
        'probeInterval': '30s',
        'future': {'keep': true},
      },
    };

    final companion = profileCompanion(source);
    final stored = readProfileMapFromText(
      utf8.decode(base64Decode(companion.data.value!)),
    );

    expect(companion.name.value, 'Stored Profile');
    expect(companion.type.value, CoreConfigType.profile.name);
    expect(companion.type.value, 'setting');
    expect(stored, source);
  });

  test(
    'Profile field validation enforces name, roots, and canonical methods',
    () {
      final valid = <String, dynamic>{
        'name': 'Profile',
        'outbounds': [
          {
            'protocol': 'vmess',
            'settings': {'security': 'auto'},
            'future': {'keep': true},
          },
        ],
      };

      expect(validateProfileFields(valid).item1, isTrue);
      for (final profile in <Map<String, dynamic>>[
        <String, dynamic>{},
        {'name': ''},
        {'name': '  '},
        {'name': 'Profile', 'api': <String, dynamic>{}},
        {'name': 'Profile', 'version': <String, dynamic>{}},
        {'name': 'Profile', 'geodata': <String, dynamic>{}},
        {
          'name': 'Profile',
          'outbounds': ['not-an-object'],
        },
        {
          'name': 'Profile',
          'outbounds': [
            {
              'protocol': 'shadowsocks',
              'settings': {'method': 'plain'},
            },
          ],
        },
      ]) {
        expect(validateProfileFields(profile).item1, isFalse);
      }
      expect(() => profileCompanion(valid), returnsNormally);
      expect(
        () => profileCompanion({
          'name': 'Profile',
          'outbounds': [
            {
              'protocol': 'vmess',
              'settings': {'security': 'none'},
            },
          ],
        }),
        throwsFormatException,
      );
    },
  );

  test('Profile validation failure does not mutate the Map', () async {
    final source = <String, dynamic>{
      'name': 'Profile',
      'routing': {
        'rules': [
          {
            'inboundTag': ['pingIn'],
            'outboundTag': 'direct',
            'future': {'keep': true},
          },
        ],
      },
      'outbounds': [
        {'tag': 'proxy', 'protocol': 'freedom'},
      ],
    };
    final snapshot = copyXrayConfigMap(source);

    final validation = await validateProfile(source);

    expect(validation.item1, isFalse);
    expect(source, snapshot);
  });

  test('new Profile Map uses the requested default DNS server', () {
    final first = newProfileMap('9.9.9.9');
    final second = newProfileMap('9.9.9.9');
    final firstDns = first['dns']! as Map<String, dynamic>;
    final firstServers = firstDns['servers']! as List<dynamic>;
    (firstServers.single as Map<String, dynamic>)['address'] = 'changed';

    final secondDns = second['dns']! as Map<String, dynamic>;
    final secondServers = secondDns['servers']! as List<dynamic>;
    expect(
      (secondServers.single as Map<String, dynamic>)['address'],
      '9.9.9.9',
    );
    expect(second['policy'], {
      'system': {
        'statsInboundUplink': true,
        'statsInboundDownlink': true,
        'statsOutboundUplink': true,
        'statsOutboundDownlink': true,
      },
    });
    expect(second, isNot(contains('metrics')));
    expect(second, isNot(contains('stats')));
    expect(second, isNot(contains('version')));
    expect(second, isNot(contains('geodata')));
    expect(second['fakeDns'], [
      {'ipPool': '198.18.0.0/15', 'poolSize': 32768},
    ]);
    final routing = second['routing'] as Map<String, dynamic>;
    final rules = (routing['rules'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(rules.map((rule) => rule['ruleTag']), <String>[
      RoutingRuleTag.dnsQuery,
      RoutingRuleTag.dnsOut,
      RoutingRuleTag.dnsDoT,
      RoutingRuleTag.ping,
    ]);
    final outbounds = (second['outbounds'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(outbounds.map((outbound) => outbound['tag']), <String>[
      RoutingOutboundTag.direct.name,
      RoutingOutboundTag.fragment.name,
      RoutingOutboundTag.block.name,
      RoutingOutboundTag.dnsOut.name,
    ]);
    expect(() => validateXrayConfigMap(second), returnsNormally);
  });

  test(
    'selected Simple Profile is exposed through the same Map seam',
    () async {
      final tunSettings = TunSettingsState()..tunDnsIPv4 = '9.9.9.9';

      final profile = await loadSelectedProfileMap(tunSettings);

      expect(profile['name'], XrayProfileSimple.simpleName);
      expect(profile, isNot(contains('version')));
      expect(profile, isNot(contains('geodata')));
      expect(() => validateXrayConfigMap(profile), returnsNormally);
      final dns = profile['dns'] as Map<String, dynamic>;
      final servers = dns['servers'] as List<dynamic>;
      expect(
        servers.whereType<Map<String, dynamic>>().any(
          (server) => server['address'] == 'tcp://9.9.9.9',
        ),
        isTrue,
      );
    },
  );
}
