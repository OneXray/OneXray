import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/routing/document.dart';
import 'package:onexray/service/routing/state.dart';

void main() {
  test('projects the supported Xray routing fields into editable state', () {
    final source = _document(2);
    source['name'] = '  My routes  ';
    final first = <String, dynamic>{
      'ruleTag': '  Duplicate label  ',
      'domain': ['domain:example.com', 'geosite:cn'],
      'ip': ['192.0.2.0/24', 'geoip:cn'],
      'port': '80,443,8000-8080',
      'network': 'tcp,udp',
      'balancerTag': 'proxy',
    };
    final second = <String, dynamic>{
      'ruleTag': '  Duplicate label  ',
      'domain': ['ext:other.dat:private'],
      'outboundTag': 'direct',
    };
    final third = <String, dynamic>{
      'port': 53,
      'network': ['tcp', 'udp'],
      'outboundTag': 'block',
    };
    (source['routing'] as Map)['rules'] = [first, second, third];
    (source['routing'] as Map)['domainStrategy'] = 'IPIfNonMatch';

    final state = RoutingProfileDocument.parse(jsonEncode(source)).state;

    expect(state.name, '  My routes  ');
    expect(state.entryCount, 2);
    expect(state.domainStrategy, 'IPIfNonMatch');
    expect(state.rules.map((rule) => rule.toJson()), [first, second, third]);
    expect(jsonDecode(state.encode()), {
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [first, second, third],
      },
      'outbounds': [
        {},
        {},
        {'tag': 'direct', 'protocol': 'freedom'},
        {'tag': 'block', 'protocol': 'blackhole'},
      ],
    });
  });

  test('state owns immutable rule values and writes a minimal XrayJson', () {
    final domain = ['domain:example.com'];
    final rule = RoutingRuleState(domain: domain);
    final state = RoutingProfileState(name: 'Route', rules: [rule]);
    domain.clear();

    expect(state.rules.single.domain, ['domain:example.com']);
    expect(() => state.rules.add(rule), throwsUnsupportedError);
    expect(XrayJson.fromJson(jsonDecode(state.encode())).toJson(), {
      'routing': {
        'rules': [
          {
            'domain': ['domain:example.com'],
            'balancerTag': 'proxy',
          },
        ],
      },
      'outbounds': [
        {},
        {'tag': 'direct', 'protocol': 'freedom'},
        {'tag': 'block', 'protocol': 'blackhole'},
      ],
    });
  });

  test('supports one to three entry slots and only supported actions', () {
    for (final count in [1, 2, 3]) {
      final state = RoutingProfileDocument.parse(
        jsonEncode(_document(count)..remove('name')),
      ).state;
      expect(state.entryCount, count);
      expect(state.name, isEmpty);
      expect(state.domainStrategy, 'AsIs');
      expect(state.rules, isEmpty);
    }
    for (final action in RoutingRuleAction.values) {
      final rule = RoutingRuleState(
        domain: const ['domain:example.com'],
        action: action,
      );
      expect(RoutingRuleState.fromXrayJson(rule.xrayJson).action, action);
    }
  });

  test('uses typed geodata only as separated import metadata', () {
    final source = _document();
    source['geodata'] = {
      'assets': [
        {'file': 'other.dat', 'url': 'https://example.com/other.dat?version=2'},
      ],
    };
    (source['routing'] as Map)['rules'] = [
      {
        ..._rule(),
        'domain': ['ext:other.dat:cn'],
      },
    ];

    final document = RoutingProfileDocument.parse(jsonEncode(source));

    expect(document.assets, [
      {'file': 'other.dat', 'url': 'https://example.com/other.dat?version=2'},
    ]);
    expect(document.state.xrayJson.geodata, isNull);
    expect(
      (jsonDecode(document.state.encode()) as Map).containsKey('geodata'),
      false,
    );
  });

  test(
    'rejects unknown roots, routing fields and rule fields before XrayJson',
    () {
      for (final root in [
        'dns',
        'inbounds',
        'policy',
        'version',
        'entryCount',
      ]) {
        _reject({..._document(), root: {}});
      }
      for (final field in ['balancers', 'domainMatcher', 'rulesEnabled']) {
        _reject({
          ..._document(),
          'routing': {'rules': [], field: []},
        });
      }
      for (final field in [
        'source',
        'sourcePort',
        'inboundTag',
        'protocol',
        'attrs',
        'enabled',
        'disabled',
        'name',
        'id',
        'uuid',
        'type',
      ]) {
        _rejectRule({..._rule(), field: 'hidden'});
      }
      _rejectRule({
        'domain': ['example.com'],
      });
      _rejectRule({..._rule(), 'balancerTag': 'custom'});
      _rejectRule({..._rule(), 'outboundTag': 'direct'});
      expect(
        () => RoutingProfileState.fromXrayJson(
          name: 'Route',
          xrayJson: XrayJson(
            outbounds: const [{}],
            routing: XrayRouting(
              rules: [
                XrayRoutingRule(
                  domain: const ['domain:example.com'],
                  inboundTag: const ['hidden'],
                  balancerTag: 'proxy',
                ),
              ],
            ),
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test('rejects invalid names, slots, conditions and functional outbounds', () {
    for (final name in [null, '', '   ', 12, List.filled(33, 'a').join()]) {
      _reject({..._document(), 'name': name});
    }
    for (final count in [0, 4]) {
      _reject(_document(count));
    }
    for (final outbound in [
      {'tag': 'node', 'protocol': 'socks'},
      {'tag': 'direct', 'protocol': 'blackhole'},
      {'tag': 'direct', 'protocol': 'freedom', 'settings': null},
      {
        'tag': 'direct',
        'protocol': 'freedom',
        'settings': {'redirect': 'example.com:80'},
      },
    ]) {
      _reject({
        ..._document(),
        'outbounds': [{}, outbound],
      });
    }
    for (final key in ['domain', 'ip']) {
      for (final value in [
        null,
        'example.com',
        [1],
        [''],
        ['  '],
      ]) {
        _rejectRule({..._rule(), key: value});
      }
    }
    for (final port in [null, [], '', 'abc', '3-2', 0, 65536, 1.5]) {
      _rejectRule({..._rule(), 'port': port});
    }
    for (final network in [
      null,
      '',
      [],
      [1],
      'unix',
      'TCP',
      'tcp,other',
    ]) {
      _rejectRule({..._rule(), 'network': network});
    }
  });

  test('rejects unsafe geodata assets', () {
    for (final file in [
      '../other.dat',
      r'..\other.dat',
      '/other.dat',
      r'C:\other.dat',
      'geosite.dat',
      'GEOIP.DAT',
      '.dat',
      'other.json',
      ' other.dat',
      'CON.dat',
    ]) {
      _rejectAssets([
        {'file': file, 'url': 'https://example.com/other.dat'},
      ]);
    }
    for (final url in [
      'http://example.com/other.dat',
      'file:///other.dat',
      'https:///other.dat',
      'https://user:secret@example.com/other.dat',
      'https://example.com/other.dat#fragment',
      null,
    ]) {
      _rejectAssets([
        {'file': 'other.dat', 'url': url},
      ]);
    }
  });
}

Map<String, dynamic> _document([int count = 1]) => {
  'name': 'Custom',
  'outbounds': [
    ...List.generate(count, (_) => <String, dynamic>{}),
    {'tag': 'direct', 'protocol': 'freedom'},
    {'tag': 'block', 'protocol': 'blackhole'},
  ],
  'routing': <String, dynamic>{'rules': <dynamic>[]},
};

Map<String, dynamic> _rule() => {
  'ruleTag': 'A rule',
  'domain': ['domain:example.com'],
  'balancerTag': 'proxy',
};

void _reject(Map<String, dynamic> document) {
  expect(
    () => RoutingProfileDocument.parse(jsonEncode(document)),
    throwsFormatException,
    reason: jsonEncode(document),
  );
}

void _rejectRule(Map<String, dynamic> rule) {
  final document = _document();
  (document['routing'] as Map)['rules'] = [rule];
  _reject(document);
}

void _rejectAssets(Object? assets) => _reject({
  ..._document(),
  'geodata': {'assets': assets},
});
