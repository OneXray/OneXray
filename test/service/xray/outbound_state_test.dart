import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_reader.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_validator.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';

void main() {
  const canonicalMethods = [
    '2022-blake3-aes-128-gcm',
    '2022-blake3-aes-256-gcm',
    '2022-blake3-chacha20-poly1305',
    'aes-128-gcm',
    'aes-256-gcm',
    'chacha20-poly1305',
    'xchacha20-poly1305',
  ];
  const nonCanonicalMethods = [
    'none',
    'plain',
    'aead-aes-128-gcm',
    'aead_aes_128_gcm',
    'aead-aes-256-gcm',
    'aead_aes_256_gcm',
    'aead-chacha20-poly1305',
    'aead_chacha20_poly1305',
    'chacha20-ietf-poly1305',
    'aead-xchacha20-poly1305',
    'aead_xchacha20_poly1305',
    'xchacha20-ietf-poly1305',
    'AES-256-GCM',
    ' aes-256-gcm',
    'aes-256-gcm ',
    'unsupported',
  ];

  group('ShadowsocksMethod', () {
    test('contains only Xray-core canonical methods', () {
      expect(
        ShadowsocksMethod.values.map((method) => method.name),
        canonicalMethods,
      );
      for (final method in canonicalMethods) {
        expect(ShadowsocksMethod.fromString(method), isNotNull);
      }
    });

    test('rejects non-canonical methods', () {
      for (final method in nonCanonicalMethods) {
        expect(ShadowsocksMethod.fromString(method), isNull, reason: method);
      }
    });
  });

  test('new Shadowsocks form uses the canonical default', () {
    final state = OutboundState()
      ..changeProtocol(XrayOutboundProtocol.shadowsocks);

    expect(state.shadowsocksMethod, ShadowsocksMethod.aes256gcm);
    expect((state.materialize()['settings'] as Map)['method'], 'aes-256-gcm');
  });

  test('projects every canonical method without rebuilding the Map', () {
    for (final method in canonicalMethods) {
      final outbound = decodeSingleOutbound(_shadowsocksJson(method));
      final state = OutboundState(outbound);

      expect(state.shadowsocksMethodName, method);
      expect(state.address, 'example.com');
      expect(state.port, '8388');
      expect(state.shadowsocksPassword, 'password');
      expect(state.materialize(), outbound);
    }
  });

  test('canonical gate rejects every non-canonical method', () {
    for (final method in <String?>[...nonCanonicalMethods, '', null]) {
      final outbound = decodeSingleOutbound(_shadowsocksJson(method));
      expect(
        () => requireCanonicalOutbound(outbound),
        throwsFormatException,
        reason: '$method',
      );
    }
  });

  test('non-canonical method fails through profile and multi-node outbound readers', () {
    for (final tag in ['proxy', 'chainProxy']) {
      final xrayJson = XrayJson.fromJson(
        jsonDecode(_shadowsocksJson('aead_aes_256_gcm', tag: tag)),
      );

      expect(XrayProfileState().readFromXrayJson(xrayJson), isFalse);
      final multiNodeOutbound = <String, dynamic>{
        'name': 'Multi-node Outbound',
        ...jsonDecode(_shadowsocksJson('aead_aes_256_gcm', tag: tag)),
      };
      expect(validateMultiNodeOutboundFields(multiNodeOutbound).item1, isFalse);
    }
  });

  test(
    'profile and multi-node outbound preserve an App-unprojected sibling',
    () {
      final json = jsonDecode(_shadowsocksJson('aes-256-gcm'));
      final outbound = (json['outbounds'] as List<dynamic>).single;
      outbound['mux'] = {'enabled': true, 'xudpProxyUDP443': 'editorOnly'};
      final xrayJson = XrayJson.fromJson(json);

      final profile = XrayProfileState();
      expect(profile.readFromXrayJson(xrayJson), isTrue);
      expect(profile.outbounds.outbounds, [outbound]);

      final multiNodeOutbound = readMultiNodeOutboundFromText(
        jsonEncode(<String, dynamic>{'name': 'Multi-node Outbound', ...json}),
      );
      expect(multiNodeOutbound['outbounds'], [outbound]);
    },
  );
}

String _shadowsocksJson(String? method, {String tag = 'proxy'}) => jsonEncode({
  'outbounds': [
    {
      'protocol': 'shadowsocks',
      'tag': tag,
      'settings': {
        'address': 'example.com',
        'port': 8388,
        'method': ?method,
        'password': 'password',
      },
    },
  ],
});
