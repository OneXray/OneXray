import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/raw/fix.dart';

void main() {
  test('Raw config keeps only the app-managed ping inbound', () {
    final jsonMap = <String, dynamic>{
      'inbounds': <dynamic>[
        <String, dynamic>{'tag': 'tunIn', 'protocol': 'tun'},
        <String, dynamic>{'tag': 'customIn', 'protocol': 'socks'},
        <String, dynamic>{'tag': 'pingIn', 'protocol': 'http', 'port': '12345'},
      ],
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
      ],
      'routing': <String, dynamic>{
        'rules': <dynamic>[
          <String, dynamic>{
            'inboundTag': <String>['tunIn'],
            'outboundTag': 'proxy',
            'ruleTag': 'userRule',
          },
          <String, dynamic>{
            'inboundTag': <String>['pingIn'],
            'outboundTag': 'direct',
            'ruleTag': 'oldPingRule',
          },
        ],
      },
    };

    XrayRawFix.keepOnlyPingInbound(jsonMap);

    final inbounds = jsonMap['inbounds']! as List<dynamic>;
    expect(inbounds, hasLength(1));
    expect(inbounds.single, containsPair('tag', 'pingIn'));
    expect(inbounds.single, containsPair('protocol', 'http'));
    expect(inbounds.single, containsPair('port', '0'));

    final routing = jsonMap['routing']! as Map<String, dynamic>;
    final rules = routing['rules']! as List<dynamic>;
    expect(rules, hasLength(2));
    expect(rules.first, containsPair('ruleTag', 'ping'));
    expect(rules.first, containsPair('outboundTag', 'proxy'));
    expect(rules.last, containsPair('ruleTag', 'userRule'));
  });

  test('Raw ping config uses the allocated port and authentication', () {
    final jsonMap = <String, dynamic>{
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'direct', 'protocol': 'freedom'},
      ],
    };
    final ports = XrayPorts(
      '23456',
      '23457',
      XrayInboundAccount('ping-user', 'ping-pass'),
    );

    XrayRawFix.keepOnlyPingInbound(jsonMap, ports: ports);

    final inbounds = jsonMap['inbounds']! as List<dynamic>;
    final pingInbound = inbounds.single as Map<String, dynamic>;
    expect(pingInbound['port'], '23456');
    final settings = pingInbound['settings']! as Map<String, dynamic>;
    final users = settings['users']! as List<dynamic>;
    expect(users.single, <String, dynamic>{
      'user': 'ping-user',
      'pass': 'ping-pass',
    });

    final routing = jsonMap['routing']! as Map<String, dynamic>;
    final rules = routing['rules']! as List<dynamic>;
    expect(rules.single, containsPair('outboundTag', 'direct'));
  });
}
