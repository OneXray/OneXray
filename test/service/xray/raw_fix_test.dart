import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_inbound_account.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
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
      final source = <String, dynamic>{
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
          <String, dynamic>{
            'tag': 'proxy',
            'protocol': 'freedom',
            'streamSettings': <String, dynamic>{
              'sockopt': <String, dynamic>{
                'interface': ' user interface ',
                'future': ' keep  spaces ',
              },
            },
          },
          <String, dynamic>{
            'tag': 'direct',
            'protocol': 'freedom',
            'streamSettings': <String, dynamic>{
              'sockopt': <String, dynamic>{
                'interface': 'app-owned-interface',
                'future': true,
              },
            },
          },
        ],
      };
      final jsonMap = copyXrayConfigMap(source);
      final ports = XrayPorts(
        '23456',
        '23457',
        XrayInboundAccount('ping-user', 'ping-pass'),
      );

      await XrayRawFix.fixProfileConfig(
        jsonMap,
        CoreRunMode.tun,
        TunSettingsState(),
        ports,
        false,
        disableLog: false,
        runtimePlatform: XrayRuntimePlatform.other,
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
      final outbounds = jsonMap['outbounds']! as List<dynamic>;
      final proxy = outbounds.first as Map<String, dynamic>;
      final proxySockopt =
          (proxy['streamSettings'] as Map<String, dynamic>)['sockopt']
              as Map<String, dynamic>;
      expect(proxySockopt['interface'], ' user interface ');
      expect(proxySockopt['future'], ' keep  spaces ');
      final direct = outbounds.last as Map<String, dynamic>;
      final directSockopt =
          (direct['streamSettings'] as Map<String, dynamic>)['sockopt']
              as Map<String, dynamic>;
      expect(directSockopt, isNot(contains('interface')));
      expect(directSockopt['future'], isTrue);
      expect(source['env'], isNull);
      expect(
        (((source['outbounds'] as List<dynamic>).first
                as Map<String, dynamic>)['streamSettings']
            as Map<String, dynamic>)['sockopt'],
        containsPair('interface', ' user interface '),
      );
    },
  );

  test('Raw runtime inbounds come from the Profile Map copy', () async {
    final profile = <String, dynamic>{
      'name': 'Profile',
      'fakeDns': <String, dynamic>{'ipPool': '198.18.0.0/15'},
      'inbounds': <dynamic>[
        <String, dynamic>{
          'tag': 'tunIn',
          'protocol': 'tun',
          'settings': <String, dynamic>{'future': ' keep  spaces '},
          'sniffing': <String, dynamic>{
            'future': <dynamic>[1, 2],
          },
        },
        <String, dynamic>{
          'tag': 'customIn',
          'protocol': 'socks',
          'future': <String, dynamic>{'keep': true},
        },
      ],
    };
    final expectedProfile = copyXrayConfigMap(profile);
    final raw = <String, dynamic>{
      'inbounds': <dynamic>[
        <String, dynamic>{'tag': 'rawIn', 'protocol': 'http'},
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

    await XrayRawFix.fixConfig(
      raw,
      profile,
      CoreRunMode.tun,
      TunSettingsState(),
      ports,
      false,
      disableLog: false,
      runtimePlatform: XrayRuntimePlatform.other,
    );

    expect(profile, expectedProfile);
    final inbounds = raw['inbounds']! as List<dynamic>;
    expect(inbounds.map((inbound) => (inbound as Map)['tag']), <String>[
      'tunIn',
      'customIn',
      'pingIn',
    ]);
    final tun = inbounds.first as Map<String, dynamic>;
    expect(tun['sniffing'], <String, dynamic>{
      'future': <dynamic>[1, 2],
    });
    expect(
      (tun['settings'] as Map<String, dynamic>)['future'],
      ' keep  spaces ',
    );
    expect((inbounds[1] as Map)['future'], <String, dynamic>{'keep': true});

    final proxyRaw = <String, dynamic>{
      'inbounds': <dynamic>[
        <String, dynamic>{'tag': 'rawIn', 'protocol': 'http'},
      ],
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'proxy', 'protocol': 'freedom'},
      ],
    };
    await XrayRawFix.fixConfig(
      proxyRaw,
      profile,
      CoreRunMode.proxy,
      TunSettingsState(),
      XrayPorts('23458', '23459', XrayInboundAccount('ping-user', 'ping-pass')),
      false,
      disableLog: false,
      runtimePlatform: XrayRuntimePlatform.other,
    );
    expect(
      (proxyRaw['inbounds'] as List<dynamic>).map(
        (inbound) => (inbound as Map)['tag'],
      ),
      <String>['pingIn'],
    );
    expect(profile, expectedProfile);
  });

  test('Profile selected and final outbounds materialize on a Map copy', () {
    final storedProfile = <String, dynamic>{
      'name': 'Profile  name',
      'observatory': <String, dynamic>{'future': ' keep  spaces '},
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'direct', 'protocol': 'freedom'},
        <String, dynamic>{
          'tag': 'proxy',
          'protocol': 'vless',
          'future': 'old-runtime-proxy',
        },
        <String, dynamic>{
          'name': 'Final  name',
          'tag': 'chainProxy',
          'protocol': 'vless',
          'settings': <String, dynamic>{'future': 'final'},
        },
        <String, dynamic>{
          'tag': 'custom',
          'protocol': 'socks',
          'future': <String, dynamic>{'keep': true},
        },
      ],
    };
    final selected = <String, dynamic>{
      'name': 'Selected  name',
      'tag': 'stored-tag',
      'protocol': 'vless',
      'streamSettings': <String, dynamic>{
        'sockopt': <String, dynamic>{
          'dialerProxy': 'stored-upstream',
          'interface': ' selected interface ',
        },
      },
    };
    final expectedProfile = copyXrayConfigMap(storedProfile);
    final expectedSelected = JsonTool.decoder.convert(
      JsonTool.encoder.convert(selected),
    );
    final runtime = copyXrayConfigMap(storedProfile);
    final currentOutbounds = runtime['outbounds']! as List<dynamic>;
    final finalOutbound = currentOutbounds[2] as Map<String, dynamic>;

    XrayRawFix.applySelectedOutbound(
      runtime,
      selected,
      finalOutbound: finalOutbound,
    );

    expect(storedProfile, expectedProfile);
    expect(selected, expectedSelected);
    expect(runtime['name'], 'Profile  name');
    expect(runtime['observatory'], storedProfile['observatory']);
    final outbounds = runtime['outbounds']! as List<dynamic>;
    expect(outbounds.map((outbound) => (outbound as Map)['tag']), <String>[
      'proxy',
      'chainProxy',
      'direct',
      'custom',
    ]);
    final materializedFinal = outbounds[0] as Map<String, dynamic>;
    expect(materializedFinal, isNot(contains('name')));
    expect(
      ((materializedFinal['streamSettings'] as Map)['sockopt']
          as Map)['dialerProxy'],
      'chainProxy',
    );
    final materializedSelected = outbounds[1] as Map<String, dynamic>;
    expect(materializedSelected, isNot(contains('name')));
    final selectedSockopt =
        (materializedSelected['streamSettings'] as Map)['sockopt'] as Map;
    expect(selectedSockopt, isNot(contains('dialerProxy')));
    expect(selectedSockopt['interface'], ' selected interface ');
    expect((outbounds.last as Map)['future'], <String, dynamic>{'keep': true});
    expect(
      outbounds.where(
        (outbound) =>
            outbound is Map && outbound['future'] == 'old-runtime-proxy',
      ),
      isEmpty,
    );

    final withoutFinal = <String, dynamic>{
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'direct', 'protocol': 'freedom'},
      ],
    };
    XrayRawFix.applySelectedOutbound(withoutFinal, selected);
    final directSelected =
        (withoutFinal['outbounds'] as List<dynamic>).first as Map;
    expect(directSelected['tag'], 'proxy');
    expect(
      ((directSelected['streamSettings'] as Map)['sockopt']
          as Map)['dialerProxy'],
      'stored-upstream',
    );
    expect(selected, expectedSelected);

    final duplicateFinals = <String, dynamic>{
      'name': 'Profile',
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'chainProxy', 'protocol': 'vless'},
        <String, dynamic>{'tag': 'chainProxy', 'protocol': 'trojan'},
      ],
    };
    final expectedDuplicateFinals = copyXrayConfigMap(duplicateFinals);
    final duplicateOutbounds = duplicateFinals['outbounds']! as List<dynamic>;
    final duplicateFinal = duplicateOutbounds.first as Map<String, dynamic>;
    expect(
      () => XrayRawFix.applySelectedOutbound(
        duplicateFinals,
        selected,
        finalOutbound: duplicateFinal,
      ),
      throwsFormatException,
    );
    expect(duplicateFinals, expectedDuplicateFinals);
  });

  test('Profile disabled logging preserves unknown log siblings', () {
    final jsonMap = <String, dynamic>{
      'log': <String, dynamic>{
        'access': '/user/access.log',
        'error': '/user/error.log',
        'loglevel': 'debug',
        'dnsLog': true,
        'maskAddress': 'full',
        'future': <String, dynamic>{'keep': ' value '},
      },
    };

    XrayRawFix.fixLog(jsonMap, disableLog: true);

    final log = jsonMap['log']! as Map<String, dynamic>;
    expect(log['loglevel'], 'none');
    expect(log['dnsLog'], isFalse);
    expect(log, isNot(contains('access')));
    expect(log, isNot(contains('error')));
    expect(log, isNot(contains('maskAddress')));
    expect(log['future'], <String, dynamic>{'keep': ' value '});
  });

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
    expect(
      () => XrayRawFix.prepareProfileValidationConfig(<String, dynamic>{
        'routing': <String, dynamic>{'rules': <String, dynamic>{}},
      }),
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
      CoreRunMode.proxy,
      TunSettingsState(),
      ports,
      false,
      disableLog: false,
      runtimePlatform: XrayRuntimePlatform.other,
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
        CoreRunMode.proxy,
        TunSettingsState(),
        ports,
        false,
        disableLog: false,
        runtimePlatform: XrayRuntimePlatform.other,
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
        CoreRunMode.tun,
        TunSettingsState(),
        ports,
        false,
        disableLog: false,
        runtimePlatform: XrayRuntimePlatform.other,
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
      CoreRunMode.proxy,
      TunSettingsState(),
      ports,
      true,
      disableLog: false,
      runtimePlatform: XrayRuntimePlatform.other,
    );

    final policy = jsonMap['policy']! as Map<String, dynamic>;
    expect(policy['levels'], isNotNull);
    expect((policy['system'] as Map)['user'], true);
    expect(jsonMap['stats'], containsPair('user', true));
    final metrics = jsonMap['metrics']! as Map<String, dynamic>;
    expect(metrics['user'], true);
    expect(metrics['listen'], endsWith(':23457'));
  });

  test('XrayPorts allocates separate SOCKS, ping, and metrics ports', () async {
    var calls = 0;
    final ports = await XrayPorts.getPorts(
      excludedPorts: const <int>{10000},
      portProvider: (count) async {
        expect(count, 3);
        calls += 1;
        return calls == 1
            ? <int>[10000, 10001, 10002]
            : <int>[11000, 11001, 11002];
      },
    );

    expect(calls, 2);
    expect(ports?.socksPort, '11000');
    expect(ports?.pingPort, '11001');
    expect(ports?.metricsPort, '11002');
  });

  test('Windows uses SOCKS on tunIn and binds every outbound', () async {
    final jsonMap = <String, dynamic>{
      'inbounds': <dynamic>[
        <String, dynamic>{
          'tag': 'tunIn',
          'protocol': 'tun',
          'sniffing': <String, dynamic>{'enabled': true, 'user': true},
        },
      ],
      'outbounds': <dynamic>[
        <String, dynamic>{'tag': 'proxy', 'protocol': 'vless'},
        <String, dynamic>{
          'tag': 'direct',
          'protocol': 'freedom',
          'streamSettings': <String, dynamic>{
            'sockopt': <String, dynamic>{'tcpFastOpen': true},
          },
        },
        <String, dynamic>{'tag': 'block', 'protocol': 'blackhole'},
      ],
    };
    final tunSettings = TunSettingsState()..outboundsInterface = 'Ethernet 2';
    final ports = XrayPorts(
      '23456',
      '23457',
      XrayInboundAccount('ping-user', 'ping-pass'),
      socksPort: '23455',
    );

    await XrayRawFix.fixProfileConfig(
      jsonMap,
      CoreRunMode.tun,
      tunSettings,
      ports,
      false,
      disableLog: false,
      runtimePlatform: XrayRuntimePlatform.windows,
    );

    final inbounds = (jsonMap['inbounds'] as List<dynamic>).cast<Map>();
    final inbound = inbounds.first;
    expect(inbound['tag'], 'tunIn');
    expect(inbound['protocol'], 'socks');
    expect(inbound['listen'], NetConstants.proxyHost);
    expect(inbound['port'], '23455');
    expect(inbound['settings'], <String, dynamic>{
      'auth': 'noauth',
      'udp': true,
    });
    expect(inbound['sniffing'], containsPair('user', true));
    for (final outbound
        in (jsonMap['outbounds'] as List<dynamic>).cast<Map>()) {
      final streamSettings = outbound['streamSettings'] as Map;
      final sockopt = streamSettings['sockopt'] as Map;
      expect(sockopt['interface'], 'Ethernet 2');
    }
  });

  test('Linux binds the interface only in the TUN inbound', () async {
    final jsonMap = <String, dynamic>{
      'outbounds': <dynamic>[
        <String, dynamic>{
          'tag': 'proxy',
          'protocol': 'vless',
          'streamSettings': <String, dynamic>{
            'sockopt': <String, dynamic>{'interface': 'old0'},
          },
        },
        <String, dynamic>{
          'tag': 'direct',
          'protocol': 'freedom',
          'streamSettings': <String, dynamic>{
            'sockopt': <String, dynamic>{'interface': 'old1'},
          },
        },
      ],
    };
    final tunSettings = TunSettingsState()..outboundsInterface = 'eth0';

    await XrayRawFix.fixProfileConfig(
      jsonMap,
      CoreRunMode.tun,
      tunSettings,
      XrayPorts('23456', '23457', XrayInboundAccount('ping-user', 'ping-pass')),
      false,
      disableLog: false,
      runtimePlatform: XrayRuntimePlatform.linux,
    );

    final inbounds = (jsonMap['inbounds'] as List<dynamic>).cast<Map>();
    final tun = inbounds.first;
    expect(tun['protocol'], 'tun');
    final settings = tun['settings'] as Map;
    expect(settings['autoOutboundsInterface'], 'eth0');
    expect(settings['autoSystemRoutingTable'], isNotEmpty);
    for (final outbound
        in (jsonMap['outbounds'] as List<dynamic>).cast<Map>()) {
      final streamSettings = outbound['streamSettings'] as Map;
      final sockopt = streamSettings['sockopt'] as Map;
      expect(sockopt, isNot(contains('interface')));
    }
  });
}
