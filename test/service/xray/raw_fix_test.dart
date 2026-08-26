import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/raw/fix.dart';
import 'package:onexray/service/xray/raw/validator.dart';

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

  test('Raw normalization applies an imported name override', () {
    final result = XrayRawValidator.normalize('''
      {
        "name": "Original",
        "inbounds": [{"tag": "tunIn", "protocol": "tun"}],
        "outbounds": [{"tag": "direct", "protocol": "freedom"}]
      }
      ''', nameOverride: 'Imported');

    expect(result.isValid, isTrue);
    expect(result.name, 'Imported');
    final normalized = JsonTool.decoder.convert(
      result.normalizedText!,
    ) as Map<String, dynamic>;
    expect(normalized['name'], 'Imported');
    final inbounds = normalized['inbounds']! as List<dynamic>;
    expect(inbounds.single, containsPair('tag', 'pingIn'));
  });

  test(
    'Profile runtime patch preserves user roots and custom inbounds',
    () async {
      final jsonMap = <String, dynamic>{
        'name': 'Multi-node Outbound',
        'policy': <String, dynamic>{'user': true},
        'stats': <String, dynamic>{'user': true},
        'metrics': <String, dynamic>{'listen': '127.0.0.1:1000'},
        'observatory': <String, dynamic>{'subjectSelector': <dynamic>[]},
        'inbounds': <dynamic>[
          <String, dynamic>{
            'tag': 'tunIn',
            'protocol': 'tun',
            'settings': <String, dynamic>{'user': true},
            'user': true,
          },
          <String, dynamic>{'tag': 'customIn', 'protocol': 'socks'},
          <String, dynamic>{'tag': 'pingIn', 'protocol': 'http'},
        ],
        'outbounds': <dynamic>[
          <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
        ],
      };
      final ports = XrayPorts(
        '23456',
        '23457',
        XrayInboundAccount('ping-user', 'ping-pass'),
      );

      await XrayRawFix.fixProfileConfig(
        jsonMap,
        XrayProfileState(),
        CoreRunMode.tun,
        TunSettingsState(),
        ports,
        false,
        disableLog: false,
      );

      expect(jsonMap['policy'], <String, dynamic>{'user': true});
      expect(jsonMap['stats'], <String, dynamic>{'user': true});
      expect(jsonMap['metrics'], <String, dynamic>{'listen': '127.0.0.1:1000'});
      expect(jsonMap['observatory'], isNotNull);
      expect(jsonMap['env'], isNotNull);
      final inbounds = jsonMap['inbounds']! as List<dynamic>;
      expect(inbounds.map((inbound) => (inbound as Map)['tag']), <String>[
        'tunIn',
        'customIn',
        'pingIn',
      ]);
      final tun = inbounds.first as Map;
      expect(tun['user'], true);
      expect(tun['listen'], NetConstants.proxyHost);
      expect(tun['protocol'], 'tun');
      final tunSettings = tun['settings']! as Map;
      expect(tunSettings['user'], true);
      expect(tunSettings['name'], 'OneXrayTun');
      expect(tunSettings['mtu'], 1500);
      expect((inbounds.last as Map)['port'], '23456');
      expect(ports.metricsPort, isEmpty);
    },
  );

  test(
    'Profile validation keeps custom inbounds and adds runtime inbounds',
    () {
      final customInbound = <String, dynamic>{
        'tag': 'customIn',
        'protocol': 'socks',
        'settings': <String, dynamic>{'auth': 'noauth'},
        'future': <String, dynamic>{'keep': true},
      };
      final jsonMap = <String, dynamic>{
        'inbounds': <dynamic>[customInbound],
        'outbounds': <dynamic>[
          <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
        ],
      };

      XrayRawFix.prepareProfileValidationConfig(jsonMap);

      final inbounds = jsonMap['inbounds']! as List<dynamic>;
      expect(inbounds.map((inbound) => (inbound as Map)['tag']), <String>[
        'tunIn',
        'customIn',
        'pingIn',
      ]);
      expect(inbounds[1], customInbound);
      expect(jsonMap['env'], isNotNull);
    },
  );

  test('Profile validation rejects a conflicting ping routing rule', () {
    final jsonMap = <String, dynamic>{
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
      ],
      'routing': <String, dynamic>{
        'rules': <dynamic>[
          <String, dynamic>{
            'inboundTag': <String>['pingIn'],
            'outboundTag': 'direct',
          },
        ],
      },
    };

    expect(
      () => XrayRawFix.prepareProfileValidationConfig(jsonMap),
      throwsFormatException,
    );
  });

  test('Profile proxy runtime keeps custom inbounds', () async {
    final jsonMap = <String, dynamic>{
      'inbounds': <dynamic>[
        <String, dynamic>{'tag': 'tunIn', 'protocol': 'tun'},
        <String, dynamic>{'tag': 'customIn', 'protocol': 'socks', 'port': 1080},
      ],
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
      ],
    };
    final ports = XrayPorts(
      '23456',
      '23457',
      XrayInboundAccount('ping-user', 'ping-pass'),
    );

    await XrayRawFix.fixProfileConfig(
      jsonMap,
      XrayProfileState(),
      CoreRunMode.proxy,
      TunSettingsState(),
      ports,
      false,
      disableLog: false,
    );

    final inbounds = jsonMap['inbounds']! as List<dynamic>;
    expect(inbounds.map((inbound) => (inbound as Map)['tag']), <String>[
      'customIn',
      'pingIn',
    ]);
  });

  test(
    'Multi-node Outbound runtime patch does not mutate stored Maps',
    () async {
      final profile = <String, dynamic>{
        'name': 'Profile',
        'inbounds': <dynamic>[
          <String, dynamic>{
            'tag': 'customIn',
            'protocol': 'socks',
            'port': 1080,
          },
        ],
        'outbounds': <dynamic>[
          <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
        ],
      };
      final multiNodeOutbound = <String, dynamic>{
        'name': 'Multi-node Outbound',
        'routing': <String, dynamic>{'domainStrategy': 'AsIs', 'future': true},
        'outbounds': <dynamic>[
          <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
        ],
      };
      final expectedProfile = copyXrayConfigMap(profile);
      final expectedMultiNodeOutbound = copyXrayConfigMap(multiNodeOutbound);
      final runtime = applyMultiNodeOutboundOverlay(profile, multiNodeOutbound);
      final ports = XrayPorts(
        '23456',
        '23457',
        XrayInboundAccount('ping-user', 'ping-pass'),
      );

      await XrayRawFix.fixProfileConfig(
        runtime,
        XrayProfileState(),
        CoreRunMode.proxy,
        TunSettingsState(),
        ports,
        false,
        disableLog: false,
      );

      expect(profile, expectedProfile);
      expect(multiNodeOutbound, expectedMultiNodeOutbound);
      expect(runtime, isNot(expectedProfile));
    },
  );

  test('Profile runtime patch rejects an incompatible reserved inbound', () {
    final jsonMap = <String, dynamic>{
      'inbounds': <dynamic>[
        <String, dynamic>{'tag': 'tunIn', 'protocol': 'socks'},
      ],
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
      ],
    };
    final ports = XrayPorts(
      '23456',
      '23457',
      XrayInboundAccount('ping-user', 'ping-pass'),
    );

    expect(
      () => XrayRawFix.fixProfileConfig(
        jsonMap,
        XrayProfileState(),
        CoreRunMode.tun,
        TunSettingsState(),
        ports,
        false,
        disableLog: false,
      ),
      throwsFormatException,
    );
  });

  test('Profile runtime metrics patch preserves user siblings', () async {
    final jsonMap = <String, dynamic>{
      'policy': <String, dynamic>{
        'levels': <String, dynamic>{
          '0': <String, dynamic>{'handshake': 5},
        },
        'system': <String, dynamic>{'user': true},
      },
      'stats': <String, dynamic>{'user': true},
      'metrics': <String, dynamic>{'user': true},
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
      ],
    };
    final ports = XrayPorts(
      '23456',
      '23457',
      XrayInboundAccount('ping-user', 'ping-pass'),
    );

    await XrayRawFix.fixProfileConfig(
      jsonMap,
      XrayProfileState(),
      CoreRunMode.proxy,
      TunSettingsState(),
      ports,
      true,
      disableLog: false,
    );

    final policy = jsonMap['policy']! as Map<String, dynamic>;
    expect(policy['levels'], isNotNull);
    expect((policy['system'] as Map)['user'], true);
    expect(jsonMap['stats'], containsPair('user', true));
    final metrics = jsonMap['metrics']! as Map<String, dynamic>;
    expect(metrics['user'], true);
    expect(metrics['listen'], endsWith(':23457'));
  });
}
