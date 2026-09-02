import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/raw/validator.dart';

const source = '''
  {
    "name": "Expert",
    "inbounds": [{"tag":"custom","protocol":"socks","port":12345}],
    "outbounds": [{"tag":"direct","protocol":"freedom"}],
    "routing": {"rules":[{"inboundTag":["custom"],"outboundTag":"direct"}]},
    "policy": {"levels":{"0":{"connIdle":123}},"system":{"statsOutboundUplink":true}},
    "metrics": {"listen":"127.0.0.1:12346"},
    "stats": {},
    "env": {"xray.location.asset":"/user/assets","xray.location.cert":"/user/certs","other":"retained"},
    "log": {"access":"/user/access.log","error":"/user/error.log","loglevel":"debug"},
    "customRoot": {"value":true}
  }

''';

void main() {
  test('ordinary normalization preserves every byte and expert field', () {
    final result = XrayRawValidator.normalize(source);
    expect(result.isValid, isTrue);
    expect(result.name, 'Expert');
    expect(result.normalizedText, source);
    expect(
      XrayRawValidator.normalize(source, nameOverride: ' ').normalizedText,
      source,
    );
  });

  test('explicit name override only changes the root name', () {
    final result = XrayRawValidator.normalize(
      source,
      nameOverride: ' Renamed ',
    );
    final expected = jsonDecode(source) as Map<String, dynamic>;
    expected['name'] = 'Renamed';
    expect(result.isValid, isTrue);
    expect(result.name, 'Renamed');
    expect(jsonDecode(result.normalizedText!), expected);
  });

  test(
    'full-core validation gets a safe copy and returns the original source',
    () async {
      var calls = 0;
      final result = await XrayRawValidator.validate(
        source,
        testXray: (text) async {
          calls++;
          final actual = jsonDecode(text) as Map<String, dynamic>;
          final expected = jsonDecode(source) as Map<String, dynamic>;
          expected['env'] = {
            'xray.location.asset': VpnConstants.datDir,
            'xray.location.cert': VpnConstants.datDir,
            'other': 'retained',
          };
          expected['log'] = {
            'access': 'none',
            'error': 'none',
            'loglevel': 'none',
            'dnsLog': false,
          };
          expect(
            actual,
            expected,
          ); // Includes the original inbounds/policy/metrics/rules.
          return '';
        },
      );
      expect(calls, 1);
      expect(result.isValid, isTrue);
      expect(result.normalizedText, source);
    },
  );

  test(
    'full-core build errors reject save without returning a patched copy',
    () async {
      final result = await XrayRawValidator.validate(
        source,
        testXray: (_) async => 'Invalid inbound settings',
      );
      expect(result.isValid, isFalse);
      expect(result.error, 'Invalid inbound settings');
      expect(result.normalizedText, isNull);
    },
  );
}
