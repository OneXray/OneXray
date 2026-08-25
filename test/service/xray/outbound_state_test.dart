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

  test('new outbound defaults to aes-256-gcm', () {
    final state = OutboundState()..protocol = XrayOutboundProtocol.shadowsocks;

    expect(state.shadowsocksMethod, ShadowsocksMethod.aes256gcm);
    expect(state.xrayJson.settings?['method'], 'aes-256-gcm');
  });

  group('Shadowsocks outbound reader', () {
    test('reads every canonical method', () {
      for (final method in canonicalMethods) {
        final state = OutboundState();

        expect(state.readFromText(_shadowsocksJson(method)), isTrue);
        expect(state.shadowsocksMethod.name, method);
        expect(state.address, 'example.com');
        expect(state.port, '8388');
        expect(state.shadowsocksPassword, 'password');
        expect(state.xrayJson.settings, {
          'address': 'example.com',
          'port': 8388,
          'method': method,
          'password': 'password',
        });
      }
    });

    test('returns failure for non-canonical methods', () {
      for (final method in nonCanonicalMethods) {
        final state = OutboundState();

        expect(
          state.readFromText(_shadowsocksJson(method)),
          isFalse,
          reason: method,
        );
      }
    });

    test('returns failure for an empty or missing method', () {
      expect(OutboundState().readFromText(_shadowsocksJson('')), isFalse);
      expect(OutboundState().readFromText(_shadowsocksJson(null)), isFalse);
    });

    test('propagates failure through profile and full config readers', () {
      for (final tag in ['proxy', 'chainProxy']) {
        final xrayJson = XrayJson.fromJson(
          jsonDecode(_shadowsocksJson('aead_aes_256_gcm', tag: tag)),
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

    test('does not propagate failures from other Shadowsocks fields', () {
      final json = jsonDecode(_shadowsocksJson('aes-256-gcm'));
      final outbound = (json['outbounds'] as List<dynamic>).single;
      outbound['mux'] = {'enabled': true, 'xudpProxyUDP443': 'unsupported'};
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
