import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_reader.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
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

  test('new outbound defaults to auto', () {
    final state = OutboundState()..protocol = XrayOutboundProtocol.vmess;

    expect(state.vmessSecurity, VMessSecurity.auto);
    expect(state.xrayJson.settings?['security'], 'auto');
  });

  group('VMess outbound reader', () {
    test('reads every canonical security', () {
      for (final security in canonicalSecurities) {
        final state = OutboundState();

        expect(state.readFromText(_vmessJson(security)), isTrue);
        expect(state.vmessSecurity.name, security);
        expect(state.address, 'example.com');
        expect(state.port, '443');
        expect(state.vmessId, '00000000-0000-0000-0000-000000000000');
        expect(state.xrayJson.settings, {
          'address': 'example.com',
          'port': 443,
          'id': '00000000-0000-0000-0000-000000000000',
          'security': security,
        });
      }
    });

    test('returns failure for non-canonical securities', () {
      for (final security in nonCanonicalSecurities) {
        expect(
          OutboundState().readFromText(_vmessJson(security)),
          isFalse,
          reason: security,
        );
      }
    });

    test('returns failure for an empty or missing security', () {
      expect(OutboundState().readFromText(_vmessJson('')), isFalse);
      expect(OutboundState().readFromText(_vmessJson(null)), isFalse);
    });

    test('propagates failure through profile and full config readers', () {
      for (final tag in ['proxy', 'chainProxy']) {
        final xrayJson = XrayJson.fromJson(
          jsonDecode(_vmessJson('none', tag: tag)),
        );

        expect(
          XrayProfileState().readFromXrayJson(xrayJson),
          isFalse,
          reason: tag,
        );
        expect(
          XrayFullConfigState().readFromXrayJson(xrayJson),
          isFalse,
          reason: tag,
        );
      }
    });

    test('does not propagate failures from other VMess fields', () {
      final json = jsonDecode(_vmessJson('auto'));
      final outbound = (json['outbounds'] as List<dynamic>).single;
      final settings = outbound['settings'] as Map<String, dynamic>;
      settings['address'] = 123;
      final xrayJson = XrayJson.fromJson(json);

      final profile = XrayProfileState();
      expect(profile.readFromXrayJson(xrayJson), isTrue);
      expect(profile.outbounds.outbounds, isEmpty);

      final fullConfig = XrayFullConfigState();
      expect(fullConfig.readFromXrayJson(xrayJson), isTrue);
      expect(fullConfig.outbounds.outbounds, isEmpty);
    });
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
