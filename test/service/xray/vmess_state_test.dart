import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_reader.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';

void main() {
  const canonicalSecurities = ['aes-128-gcm', 'chacha20-poly1305', 'auto'];
  const nonCanonicalSecurities = [
    'none',
    'zero',
    'plain',
    'AES-128-GCM',
    'AUTO',
    'aes_128_gcm',
    'chacha20-ietf-poly1305',
    ' auto',
    'auto ',
    'unsupported',
  ];

  group('VMessSecurity', () {
    test('contains only Xray-core canonical securities', () {
      expect(
        VMessSecurity.values.map((security) => security.name),
        canonicalSecurities,
      );
      for (final security in canonicalSecurities) {
        expect(VMessSecurity.fromString(security), isNotNull);
      }
    });

    test('rejects non-canonical securities', () {
      for (final security in nonCanonicalSecurities) {
        expect(VMessSecurity.fromString(security), isNull, reason: security);
      }
    });
  });

  test('new VMess form uses the canonical default', () {
    final state = OutboundState()..changeProtocol(XrayOutboundProtocol.vmess);

    expect(state.vmessSecurity, VMessSecurity.auto);
    expect((state.materialize()['settings'] as Map)['security'], 'auto');
  });

  test('projects every canonical security without rebuilding the Map', () {
    for (final security in canonicalSecurities) {
      final outbound = decodeSingleOutbound(_vmessJson(security));
      final state = OutboundState(outbound);

      expect(state.vmessSecurityName, security);
      expect(state.address, 'example.com');
      expect(state.port, '443');
      expect(state.vmessId, '00000000-0000-0000-0000-000000000000');
      expect(state.materialize(), outbound);
    }
  });

  test('canonical gate rejects every non-canonical security', () {
    for (final security in <String?>[...nonCanonicalSecurities, '', null]) {
      final outbound = decodeSingleOutbound(_vmessJson(security));
      expect(
        () => requireCanonicalOutbound(outbound),
        throwsFormatException,
        reason: '$security',
      );
    }
  });

  test(
    'non-canonical security fails through profile and full config readers',
    () {
      for (final tag in ['proxy', 'chainProxy']) {
        final xrayJson = XrayJson.fromJson(
          jsonDecode(_vmessJson('none', tag: tag)),
        );

        expect(XrayProfileState().readFromXrayJson(xrayJson), isFalse);
        expect(XrayFullConfigState().readFromXrayJson(xrayJson), isFalse);
      }
    },
  );

  test('profile and full config preserve an App-unprojected sibling', () {
    final json = jsonDecode(_vmessJson('auto'));
    final outbound = (json['outbounds'] as List<dynamic>).single;
    final settings = outbound['settings'] as Map<String, dynamic>;
    settings['address'] = 123;
    final xrayJson = XrayJson.fromJson(json);

    final profile = XrayProfileState();
    expect(profile.readFromXrayJson(xrayJson), isTrue);
    expect(profile.outbounds.outbounds, [outbound]);

    final fullConfig = XrayFullConfigState();
    expect(fullConfig.readFromXrayJson(xrayJson), isTrue);
    expect(fullConfig.outbounds.outbounds, [outbound]);
  });
}

String _vmessJson(String? security, {String tag = 'proxy'}) => jsonEncode({
  'outbounds': [
    {
      'protocol': 'vmess',
      'tag': tag,
      'settings': {
        'address': 'example.com',
        'port': 443,
        'id': '00000000-0000-0000-0000-000000000000',
        'security': ?security,
      },
    },
  ],
});
