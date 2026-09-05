import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/routing/region_catalog.dart';
import 'package:onexray/service/routing/state.dart';

final catalog = RegionCatalog.fromJson(
  {
    'geosite': {
      'CN': ['CN'],
      'RU': ['CATEGORY-RU'],
    },
    'geoip': {
      'CN': ['CN'],
      'RU': ['RU'],
      'US': ['US'],
    },
  },
  geositeCodes: ['CN', 'CATEGORY-RU'],
  geoipCodes: ['CN', 'RU', 'US'],
);

RuntimeOptions options({
  ConnectionPlatform platform = ConnectionPlatform.android,
  bool ipv6 = true,
  String interfaceName = '',
}) => RuntimeOptions(
  platform: platform,
  sessionDirectory: '/unused-session',
  metricsPort: 18186,
  socksPort: 18187,
  ipv6: ipv6,
  interfaceName: interfaceName,
);

ResolvedServer node(int id, {String? address}) => ResolvedServer(
  id: id,
  sourceId: 1,
  outbound: {
    'tag': 'Same user tag',
    'protocol': address == null ? 'freedom' : 'socks',
    if (address != null) 'settings': {'address': address, 'port': 12345},
  },
);

void main() {
  test(
    'normal 1/2/3 nodes always use full selectors and immutable mappings',
    () {
      for (var count = 1; count <= 3; count++) {
        final settings = ConnectionSettings(
          smart: SmartRoutingSettings(entryCount: count),
        );
        final entries = List.generate(count, (index) => node(index + 1));
        final plan = ConnectionCompiler.compile(
          settings: settings,
          entries: entries,
          regions: catalog,
          options: options(),
        );
        final config = plan.config;
        final balancer = config['routing']['balancers'].single as Map;
        expect(balancer['tag'], 'proxy');
        expect(
          balancer['selector'],
          List.generate(count, (i) => 'app-entry-$i'),
        );
        expect(balancer['fallbackTag'], 'direct');
        expect(config['observatory']['subjectSelector'], isEmpty);
        final outbounds = (config['outbounds'] as List).cast<Map>();
        expect(
          outbounds.take(count).map((outbound) => outbound['tag']),
          List.generate(count, (index) => 'app-entry-$index'),
        );
        expect(outbounds.skip(count).map((outbound) => outbound['tag']), [
          'direct',
          'block',
          'dnsOut',
        ]);
        expect(
          outbounds.last['streamSettings']['sockopt']['dialerProxy'],
          'direct',
        );
        expect(
          outbounds.any((outbound) => outbound['protocol'] == 'loopback'),
          false,
        );
        expect(jsonEncode(outbounds), isNot(contains('domainStrategy')));
        expect(
          (config['routing']['rules'] as List).any(
            (rule) => (rule as Map).containsKey('type'),
          ),
          false,
        );
        final directRules = (config['routing']['rules'] as List)
            .cast<Map>()
            .where((rule) => rule['outboundTag'] == 'direct');
        final domainRule = directRules.singleWhere(
          (rule) => rule.containsKey('domain'),
        );
        final ipRule = directRules.singleWhere(
          (rule) => rule.containsKey('ip'),
        );
        expect(domainRule['domain'], [
          'geosite:PRIVATE',
          'geosite:APPLE',
          'geosite:CN',
        ]);
        expect(domainRule.containsKey('ip'), false);
        expect(ipRule['ip'], ['geoip:PRIVATE', 'geoip:CN']);
        expect(ipRule.containsKey('domain'), false);
        expect(config['dns']['servers'].last['domains'], domainRule['domain']);
        expect(plan.nodeTags.values, entries.map((entry) => entry.id));
        expect(entries.first.outbound['tag'], 'Same user tag');
        expect(XrayJson.fromJson(config).toJson(), config);
        final inbounds = (config['inbounds'] as List).cast<Map>();
        expect(
          inbounds.singleWhere(
            (inbound) => inbound['tag'] == 'tunIn',
          )['settings'],
          {'name': 'OneXrayTun', 'mtu': 1500},
        );
        expect(inbounds, hasLength(1));
        config['outbounds'].clear();
        expect(plan.config['outbounds'], isNotEmpty);
        _fixture('normal-$count', plan);
      }
    },
  );

  test(
    'each final exit clone depends on its own entry, with no asset rewrite',
    () {
      for (var count = 1; count <= 3; count++) {
        final entries = List.generate(count, (i) => node(i + 1));
        final finalExit = ResolvedServer(
          id: 9,
          sourceId: 1,
          outbound: {
            'tag': 'Same user tag',
            'protocol': 'freedom',
            'streamSettings': {
              'sockopt': {'tcpFastOpen': true},
            },
          },
        );
        final finalExitBeforeCompile =
            jsonDecode(jsonEncode(finalExit.outbound)) as Map<String, dynamic>;
        final plan = ConnectionCompiler.compile(
          settings: ConnectionSettings(
            smart: SmartRoutingSettings(entryCount: count, finalExitId: 9),
          ),
          entries: entries,
          finalExit: finalExit,
          regions: catalog,
          options: options(),
        );
        final outbounds = (plan.config['outbounds'] as List).cast<Map>();
        final selector = List.generate(count, (i) => 'app-exit-$i');
        expect(
          plan.config['routing']['balancers'].single['selector'],
          selector,
        );
        expect(outbounds.map((outbound) => outbound['tag']), [
          ...selector,
          ...List.generate(count, (i) => 'app-entry-$i'),
          'direct',
          'block',
          'dnsOut',
        ]);
        expect(
          outbounds.take(count).map((outbound) => outbound['tag']),
          selector,
        );
        expect(
          outbounds.skip(count).take(count).map((outbound) => outbound['tag']),
          List.generate(count, (index) => 'app-entry-$index'),
        );
        for (var i = 0; i < count; i++) {
          final exit = outbounds.singleWhere(
            (item) => item['tag'] == 'app-exit-$i',
          );
          expect(
            exit['streamSettings']['sockopt']['dialerProxy'],
            'app-entry-$i',
          );
          expect(exit['streamSettings']['sockopt']['tcpFastOpen'], true);
          expect(plan.nodeTags['app-exit-$i'], 9);
          expect(plan.nodeTags['app-entry-$i'], i + 1);
        }
        expect(
          outbounds.map((outbound) => outbound['tag']).toSet(),
          hasLength(outbounds.length),
        );
        expect(
          entries.every((entry) => entry.outbound['tag'] == 'Same user tag'),
          true,
        );
        expect(finalExit.outbound, finalExitBeforeCompile);
        _fixture('chain-$count', plan);
      }
    },
  );

  test('All VPN/fixed server use one node, excluding Smart final exit', () {
    final settings = ConnectionSettings(
      trafficMode: TrafficMode.allVpn,
      smart: SmartRoutingSettings(entryCount: 3, finalExitId: 9),
    );
    final plan = ConnectionCompiler.compile(
      settings: settings,
      entries: [node(1)],
      regions: catalog,
      options: options(),
    );
    expect(plan.finalExit, isNull);
    expect(plan.config['routing']['domainStrategy'], 'AsIs');
    expect(
      ConnectionSettings(
        selection: const ServerSelection.server(1),
        smart: SmartRoutingSettings(entryCount: 3),
      ).requiredEntries(),
      1,
    );
    expect(
      () => ConnectionCompiler.compile(
        settings: settings,
        entries: [node(1)],
        finalExit: node(9),
        regions: catalog,
        options: options(),
      ),
      throwsFormatException,
    );
    _fixture('all-vpn', plan);
  });

  test(
    'missing/duplicate entries and self chains are rejected before runtime',
    () {
      final settings = ConnectionSettings(
        smart: SmartRoutingSettings(entryCount: 2),
      );
      for (final entries in [
        <ResolvedServer>[],
        [node(1)],
        [node(1), node(1)],
      ]) {
        expect(
          () => ConnectionCompiler.compile(
            settings: settings,
            entries: entries,
            regions: catalog,
            options: options(),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => ConnectionCompiler.compile(
          settings: ConnectionSettings(
            smart: SmartRoutingSettings(finalExitId: 1),
          ),
          entries: [node(1)],
          finalExit: node(1),
          regions: catalog,
          options: options(),
        ),
        throwsFormatException,
      );
    },
  );

  test('Custom keeps native AND rules/order, maps duplicate names, derives DNS domains only', () {
    final template = RoutingProfileState(
      name: 'Custom',
      entryCount: 2,
      domainStrategy: 'IPIfNonMatch',
      rules: [
        RoutingRuleState(
          ruleTag: 'Same',
          domain: const ['domain:example.test'],
          port: '443',
          network: 'tcp',
          action: RoutingRuleAction.direct,
        ),
        RoutingRuleState(
          ruleTag: 'Same',
          ip: const ['192.0.2.1/32'],
          action: RoutingRuleAction.block,
        ),
      ],
    );
    final original = template.encode();
    final plan = ConnectionCompiler.compile(
      settings: ConnectionSettings(
        trafficMode: TrafficMode.custom,
        customId: 4,
        smart: SmartRoutingSettings(finalExitId: 9),
      ),
      entries: [node(1), node(2)],
      custom: template,
      regions: catalog,
      options: options(),
    );
    final first = (plan.config['routing']['rules'] as List).singleWhere(
      (rule) => rule['ruleTag'] == 'app-custom-0',
    );
    expect(first['domain'], ['domain:example.test']);
    expect(first['port'], '443');
    expect(first['network'], 'tcp');
    final servers = plan.config['dns']['servers'] as List;
    expect(servers.map((server) => server['address']), ['8.8.8.8', '8.8.8.8']);
    expect(servers.last['domains'], ['domain:example.test']);
    expect(servers.last['skipFallback'], true);
    expect(template.encode(), original);
    _fixture('custom', plan);
  });

  test('Smart omits empty direct rule types', () {
    for (final (smart, expected) in [
      (
        SmartRoutingSettings(
          directPrivate: false,
          directApple: false,
          directRegions: [],
        ),
        <Map<String, dynamic>>[],
      ),
      (
        SmartRoutingSettings(directPrivate: false, directRegions: []),
        [
          {
            'ruleTag': 'app-smart-direct-domain',
            'domain': ['geosite:APPLE'],
            'outboundTag': 'direct',
          },
        ],
      ),
      (
        SmartRoutingSettings(
          directPrivate: false,
          directApple: false,
          directRegions: ['US', 'US'],
        ),
        [
          {
            'ruleTag': 'app-smart-direct-ip',
            'ip': ['geoip:US'],
            'outboundTag': 'direct',
          },
        ],
      ),
    ]) {
      expect(
        ConnectionCompiler.smartRules(
          smart,
          catalog,
        ).map((rule) => rule.toJson()),
        expected,
      );
    }
  });

  test('Smart IP strategy does not add a first-pass catch-all', () {
    for (final resolve in [true, false]) {
      final plan = ConnectionCompiler.compile(
        settings: ConnectionSettings(
          smart: SmartRoutingSettings(
            resolveIpOnNoMatch: resolve,
            directDns: false,
          ),
        ),
        entries: [node(1)],
        regions: catalog,
        options: options(),
      );
      expect(
        plan.config['routing']['domainStrategy'],
        resolve ? 'IPIfNonMatch' : 'AsIs',
      );
      expect(plan.config['dns']['servers'].last['domains'], isEmpty);
      expect(
        (plan.config['routing']['rules'] as List).any(
          (rule) => ![
            'domain',
            'ip',
            'inboundTag',
            'port',
            'network',
          ].any(rule.containsKey),
        ),
        false,
      );
    }
  });

  test('Raw keeps source/additional inbound/policy/DNS/routing but overrides runtime fields', () {
    const source = ''' {"inbounds":[{"tag":"tunIn","protocol":"tun","settings":{"name":"ignored"}},
      {"tag":"extra","protocol":"socks","listen":"127.0.0.1","port":18185}],
      "outbounds":[{"tag":"custom-direct","protocol":"freedom","streamSettings":{"sockopt":{"domainStrategy":"UseIPv4"}}}],
      "routing":{"rules":[{"type":"field","domain":["full:example.test"],"outboundTag":"custom-direct","futureRule":{"keep":true}}]},
      "dns":{"hosts":{"example.test":"127.0.0.1"},"servers":["localhost"],"futureDns":{"keep":true}},
      "policy":{"levels":{"0":{"handshake":7,"statsUserUplink":true}},"system":{"statsOutboundUplink":true}},
      "log":{"error":"user-file","loglevel":"debug"},"metrics":{"listen":"0.0.0.0:8080"},
      "fakeDns":[{"ipPool":"198.18.0.0/15","poolSize":1024,"futureFakeDns":true}],
      "api":{"tag":"user-api"},"geodata":{"assets":[]},
      "futureRoot":{"nested":{"keep":true}},
      "env":{"xray.location.asset":"bad"}}
    ''';
    final raw = jsonDecode(source) as Map<String, dynamic>;
    final rawBeforeCompile =
        jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
    final plan = ConnectionCompiler.compile(
      settings: ConnectionSettings(expert: true, rawId: 8),
      entries: [],
      raw: raw,
      regions: catalog,
      options: options(),
    );
    final runtime = plan.config;
    expect(runtime['inbounds'][1]['tag'], 'extra');
    expect(runtime['inbounds'].first['settings']['name'], 'OneXrayTun');
    expect(runtime['policy']['levels']['0']['handshake'], 7);
    expect(runtime['policy']['levels']['0']['statsUserUplink'], false);
    expect(runtime['policy']['system']['statsOutboundUplink'], false);
    expect(runtime['dns']['servers'], ['localhost']);
    expect(runtime['fakeDns'], jsonDecode(source)['fakeDns']);
    expect(runtime['api'], jsonDecode(source)['api']);
    expect(runtime['futureRoot'], jsonDecode(source)['futureRoot']);
    expect(runtime['dns']['futureDns'], jsonDecode(source)['dns']['futureDns']);
    expect(runtime.containsKey('geodata'), false);
    expect(
      runtime['outbounds'].first['streamSettings']['sockopt']['domainStrategy'],
      'UseIPv4',
    );
    expect(
      runtime['routing']['rules'].last,
      jsonDecode(source)['routing']['rules'].single,
    );
    expect(runtime['log']['error'], 'none');
    expect(runtime['metrics']['listen'], '127.0.0.1:18186');
    expect(
      jsonDecode(source)['policy']['levels']['0']['statsUserUplink'],
      true,
    );
    expect(raw, rawBeforeCompile);
    expect(raw['geodata'], jsonDecode(source)['geodata']);
    expect(plan.nodeTags, isEmpty);
    _fixture('raw', plan);
  });

  test('Raw semantic comparison includes fields unknown to the App', () {
    Map<String, dynamic> semantic(String value) =>
        ConnectionCompiler.rawSemanticJson(
          jsonEncode({
            'name': 'Ignored display name',
            'outbounds': [
              {'tag': 'direct', 'protocol': 'freedom'},
            ],
            'futureRoot': {'value': value},
          }),
          options(),
        );

    expect(semantic('one').containsKey('name'), false);
    expect(semantic('one')['futureRoot'], {'value': 'one'});
    expect(semantic('one'), isNot(semantic('two')));
  });

  test('Raw keeps the default outbound and routing untouched', () {
    final plan = ConnectionCompiler.compile(
      settings: ConnectionSettings(expert: true),
      entries: [],
      raw: {
        'outbounds': [
          {'protocol': 'freedom'},
        ],
      },
      regions: catalog,
      options: options(),
    );

    expect(plan.config['outbounds'].first.containsKey('tag'), false);
    expect(plan.config['routing']['rules'], isEmpty);
  });

  test('Raw reserved tags/ports conflict clearly, rather than renaming user references', () {
    for (final inbound in [
      {'tag': 'extra', 'protocol': 'socks', 'port': '18186-18187'},
      {'tag': 'extra-tun', 'protocol': 'tun'},
    ]) {
      expect(
        () => ConnectionCompiler.compile(
          settings: ConnectionSettings(expert: true),
          entries: [],
          raw: {
            'inbounds': [inbound],
            'outbounds': [
              {'protocol': 'freedom'},
            ],
          },
          regions: catalog,
          options: options(),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'normal runtime models retain platform, DNS, logging and statistics policy',
    () {
      for (final platform in ConnectionPlatform.values) {
        for (final ipv6 in [false, true]) {
          for (final (enabled, supported, dnsLog) in [
            (false, true, true),
            (true, false, true),
            (true, true, false),
            (true, true, true),
          ]) {
            final desktop =
                platform == ConnectionPlatform.windows ||
                platform == ConnectionPlatform.linux;
            final config = ConnectionCompiler.compile(
              settings: ConnectionSettings(trafficMode: TrafficMode.allVpn),
              entries: [node(1, address: '192.0.2.1')],
              regions: catalog,
              options: RuntimeOptions(
                platform: platform,
                sessionDirectory: '/unused-session',
                metricsPort: 18186,
                socksPort: 18187,
                ipv6: ipv6,
                interfaceName: 'selected-interface',
                logEnabled: enabled,
                logFilesSupported: supported,
                logLevel: 'debug',
                dnsLog: dnsLog,
                maskAddress: 'half',
              ),
            ).config;
            final logging = enabled && supported;
            expect(config['log'], {
              'access': logging ? '/unused-session/access.log' : 'none',
              'error': logging ? '/unused-session/error.log' : 'none',
              'loglevel': logging ? 'debug' : 'none',
              'dnsLog': logging && dnsLog,
              'maskAddress': 'half',
            });
            expect(config['env'], {
              'xray.location.asset': VpnConstants.datDir,
              'xray.location.cert': VpnConstants.datDir,
            });
            expect(config['stats'], isEmpty);
            expect(config['metrics'], {'listen': '127.0.0.1:18186'});
            expect(config['policy'], {
              'system': {
                'statsInboundUplink': true,
                'statsInboundDownlink': true,
                'statsOutboundUplink': false,
                'statsOutboundDownlink': false,
              },
            });
            expect(config['dns']['servers'], [
              {
                'address': '8.8.8.8',
                'tag': ConnectionCompiler.dnsProxy,
                'queryStrategy': ipv6 ? 'UseIP' : 'UseIPv4',
              },
              {
                'address': '8.8.8.8',
                'tag': ConnectionCompiler.dnsDirect,
                'domains': <String>[],
                'skipFallback': true,
                'queryStrategy': ipv6 ? 'UseIP' : 'UseIPv4',
              },
            ]);
            final direct = (config['outbounds'] as List).singleWhere(
              (outbound) => outbound['tag'] == 'direct',
            );
            expect(direct, {
              'tag': 'direct',
              'protocol': 'freedom',
              if (desktop)
                'streamSettings': {
                  'sockopt': {'interface': 'selected-interface'},
                },
            });
            if (platform == ConnectionPlatform.linux) {
              expect(config['inbounds'].single['settings'], {
                'name': 'OneXrayTun',
                'mtu': VpnConstants.tunMtu,
                'gateway': ['198.18.0.1/15', if (ipv6) 'fc00::1/64'],
                'dns': ['8.8.8.8', if (ipv6) '2001:4860:4860::8888'],
                'autoSystemRoutingTable': ['0.0.0.0/0', if (ipv6) '::/0'],
                'autoOutboundsInterface': 'selected-interface',
              });
            }
          }
        }
      }
    },
  );

  test('Windows/Linux require an interface and stay within XrayJson', () {
    expect(
      () => options(platform: ConnectionPlatform.windows),
      throwsFormatException,
    );
    for (final platform in [
      ConnectionPlatform.windows,
      ConnectionPlatform.linux,
    ]) {
      final plan = ConnectionCompiler.compile(
        settings: ConnectionSettings(trafficMode: TrafficMode.allVpn),
        entries: [node(1, address: 'node.test')],
        regions: catalog,
        options: options(
          platform: platform,
          ipv6: false,
          interfaceName: 'selected-interface',
        ),
      );
      final entry = (plan.config['outbounds'] as List).singleWhere(
        (node) => node['tag'] == 'app-entry-0',
      );
      expect(
        entry['streamSettings']['sockopt']['interface'],
        'selected-interface',
      );
      expect(
        entry['streamSettings']['sockopt'].containsKey('domainStrategy'),
        false,
      );
      expect(
        (plan.config['outbounds'] as List).map((outbound) => outbound['tag']),
        ['app-entry-0', 'direct', 'block', 'dnsOut'],
      );
      expect(
        (plan.config['routing']['rules'] as List).first['outboundTag'],
        'block',
      );
      expect(plan.config['dns'].containsKey('hosts'), false);
      expect(plan.config['dns'].containsKey('queryStrategy'), false);
      expect(
        (plan.config['dns']['servers'] as List).every(
          (server) => server['queryStrategy'] == 'UseIPv4',
        ),
        true,
      );
      expect(
        plan.config['inbounds'].first['protocol'],
        platform == ConnectionPlatform.windows ? 'socks' : 'tun',
      );
      final settings = plan.config['inbounds'].first['settings'];
      if (platform == ConnectionPlatform.windows) {
        expect(settings, {'auth': 'noauth', 'udp': true});
      } else {
        expect(settings['autoOutboundsInterface'], 'selected-interface');
        expect(settings['autoSystemRoutingTable'], ['0.0.0.0/0']);
      }
      expect(XrayJson.fromJson(plan.config).toJson(), plan.config);
    }
  });
}

void _fixture(String name, CompiledConnection plan) {
  const target = String.fromEnvironment('P2_FIXTURES');
  if (target.isEmpty) return;
  Directory(target).createSync(recursive: true);
  File('$target/$name.json').writeAsStringSync(plan.xrayJson);
}
