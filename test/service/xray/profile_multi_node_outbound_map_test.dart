import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_validator.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_validator.dart';

void main() {
  late AppEventBus eventBus;

  setUpAll(() => eventBus = AppEventBus());
  tearDownAll(() => eventBus.close());

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
    'Profile and Multi-node Outbound reject non-canonical Maps before writing',
    () {
      final invalid = <String, dynamic>{
        'tag': 'proxy',
        'protocol': 'shadowsocks',
        'settings': {'method': 'plain'},
      };
      expect(
        validateProfileFields({
          'name': 'Profile',
          'outbounds': [copyOutboundMap(invalid)],
        }).item1,
        isFalse,
      );
      expect(
        validateMultiNodeOutboundFields({
          'name': 'Multi-node Outbound',
          'outbounds': [invalid],
        }).item1,
        isFalse,
      );
    },
  );

  test('Multi-node Outbound validator rejects a missing custom tag', () {
    final multiNodeOutbound = <String, dynamic>{
      'name': 'Multi-node Outbound',
      'outbounds': [
        {
          'tag': 'proxy',
          'protocol': 'vless',
          'settings': {'encryption': 'none'},
        },
        {
          'protocol': 'vless',
          'settings': {'encryption': 'none'},
        },
      ],
    };

    expect(validateMultiNodeOutboundFields(multiNodeOutbound).item1, isFalse);
  });
}
