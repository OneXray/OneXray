import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
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
      type: 'profile',
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

  test(
    'selected Simple Profile is exposed through the same Map seam',
    () async {
      final tunSettings = TunSettingsState()..tunDnsIPv4 = '9.9.9.9';

      final profile = await loadSelectedProfileMap(tunSettings);

      expect(profile['name'], XrayProfileSimple.simpleName);
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
