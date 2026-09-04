import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/routing/custom_template.dart';

void main() {
  test(
    'native four-condition rules round-trip with names and order intact',
    () {
      final document = _template(2);
      document['name'] = '  My routes  ';
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
      (document['routing'] as Map)['rules'] = [first, second, third];
      (document['routing'] as Map)['domainStrategy'] = 'IPIfNonMatch';
      final template = CustomRoutingTemplate.parse(jsonEncode(document));

      expect(template.entryCount, 2);
      expect(template.name, '  My routes  ');
      expect(template.domainStrategy, 'IPIfNonMatch');
      expect(template.rules, [first, second, third]);
      expect(template.toJson(), document);
      expect(jsonDecode(template.encode()), document);
    },
  );

  test(
    'one to three slots and empty rules need no names or duplicated count',
    () {
      for (final count in [1, 2, 3]) {
        final document = _template(count);
        document.remove('name');
        final template = CustomRoutingTemplate.parse(jsonEncode(document));
        expect(template.entryCount, count);
        expect(template.name, isNull);
        expect(template.domainStrategy, 'AsIs');
        expect(template.rules, isEmpty);
        expect(template.toJson(), document);
      }
    },
  );

  test('returned maps and lists cannot mutate the validated template', () {
    final document = _template();
    (document['routing'] as Map)['rules'] = [_rule()];
    final template = CustomRoutingTemplate.parse(jsonEncode(document));
    final output = template.toJson();
    ((output['outbounds'] as List).first as Map)['protocol'] = 'socks';
    ((output['routing'] as Map)['rules'] as List).clear();
    final rules = template.rules;
    (rules.single['domain'] as List).clear();
    rules.single['outboundTag'] = 'block';
    rules.clear();
    expect(template.toJson(), document);
    expect(template.rules, [_rule()]);
  });

  test('import assets stay explicit while storage and runtime omit geodata', () {
    final document = _template();
    final assets = [
      {'file': 'other.dat', 'url': 'https://example.com/other.dat?version=2'},
    ];
    document['geodata'] = {'assets': assets};
    (document['routing'] as Map)['rules'] = [
      {
        ..._rule(),
        'domain': ['ext:other.dat:cn'],
      },
    ];
    final template = CustomRoutingTemplate.parse(jsonEncode(document));
    expect(template.assets, assets);
    expect(template.toJson().containsKey('geodata'), isFalse);
    expect(
      (jsonDecode(template.encode()) as Map).containsKey('geodata'),
      isFalse,
    );
    expect(template.rules.single['domain'], ['ext:other.dat:cn']);
    final returned = template.assets;
    returned.single['file'] = 'changed.dat';
    returned.clear();
    expect(template.assets, assets);
    // A storage round-trip intentionally has no import manifest. Its caller
    // must prepare the separately retained assets before committing this JSON.
    expect(CustomRoutingTemplate.parse(template.encode()).assets, isEmpty);
  });

  test(
    'rejects non-object input, invalid roots, metadata and routing shapes',
    () {
      for (final text in ['[]', 'null', '{']) {
        expect(() => CustomRoutingTemplate.parse(text), throwsFormatException);
      }
      for (final root in [
        'dns',
        'inbounds',
        'policy',
        'version',
        'entryCount',
      ]) {
        _reject({..._template(), root: {}});
      }
      for (final name in [null, '', '   ', 12, List.filled(33, 'a').join()]) {
        _reject({..._template(), 'name': name});
      }
      final maxName = List.filled(32, 'a').join();
      expect(
        CustomRoutingTemplate.parse(
          jsonEncode({..._template(), 'name': maxName}),
        ).name,
        maxName,
      );
      for (final routing in [
        null,
        [],
        {'rules': {}},
        {'rules': null},
      ]) {
        _reject({..._template(), 'routing': routing});
      }
      for (final strategy in [null, '', 'IPOnDemand', true]) {
        _reject({
          ..._template(),
          'routing': {'rules': [], 'domainStrategy': strategy},
        });
      }
      for (final field in ['balancers', 'domainMatcher', 'rulesEnabled']) {
        _reject({
          ..._template(),
          'routing': {'rules': [], field: []},
        });
      }
    },
  );

  test('preserves native defaults for an empty template', () {
    for (final text in [
      '{"outbounds":[{}]}',
      '{"outbounds":[{}],"routing":{}}',
    ]) {
      final template = CustomRoutingTemplate.parse(text);
      expect(template.rules, isEmpty);
      expect(jsonDecode(template.encode()), jsonDecode(text));
    }
  });

  test(
    'only literal slots and unmodified direct/block functional outbounds pass',
    () {
      for (final count in [0, 4]) {
        _reject(_template(count));
      }
      for (final outbound in [
        null,
        [],
        {'tag': ''},
        {'tag': 'node', 'protocol': 'socks'},
        {'tag': 'direct', 'protocol': 'blackhole'},
        {'tag': 'direct', 'protocol': 'freedom', 'settings': null},
        {
          'tag': 'direct',
          'protocol': 'freedom',
          'settings': {'redirect': 'example.com:80'},
        },
        {
          'tag': 'block',
          'protocol': 'blackhole',
          'settings': {
            'response': {'type': 'http'},
          },
        },
        {'tag': 'direct', 'protocol': 'freedom', 'streamSettings': {}},
      ]) {
        _reject({
          ..._template(),
          'outbounds': [{}, outbound],
        });
      }
      _reject({
        ..._template(),
        'outbounds': [
          {},
          {},
          {},
          {'tag': ''},
        ],
      });
      _reject({
        ..._template(),
        'outbounds': [
          {},
          {'tag': 'direct', 'protocol': 'freedom'},
          {'tag': 'direct', 'protocol': 'freedom'},
        ],
      });
      final document = _template();
      (document['outbounds'] as List)[1] = <String, dynamic>{
        ...(document['outbounds'] as List)[1] as Map<String, dynamic>,
        'settings': <String, dynamic>{},
      };
      expect(
        CustomRoutingTemplate.parse(jsonEncode(document)).toJson(),
        document,
      );
    },
  );

  test(
    'rules reject hidden conditions, private fields and unsupported actions',
    () {
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
      ]) {
        _rejectRule({..._rule(), field: 'hidden'});
      }
      for (final type in [null, 'other']) {
        _rejectRule({..._rule(), 'type': type});
      }
      for (final tag in [null, '', '  ', 3]) {
        _rejectRule({..._rule(), 'ruleTag': tag});
      }
      _rejectRule({
        'domain': ['example.com'],
      });
      _rejectRule({..._rule(), 'outboundTag': 'direct'});
      _rejectRule({..._rule(), 'balancerTag': 'custom'});
      _rejectRule({
        'domain': ['example.com'],
        'outboundTag': 'proxy',
      });
      _rejectRule({
        'domain': ['example.com'],
        'outboundTag': null,
      });
      final document = _template();
      (document['routing'] as Map)['rules'] = [null];
      _reject(document);
    },
  );

  test(
    'four conditions require valid native shapes and at least one value',
    () {
      _rejectRule({..._rule(), 'type': 'field'});
      _rejectRule({'domain': [], 'ip': [], 'balancerTag': 'proxy'});
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
      for (final port in [
        null,
        [],
        '',
        'abc',
        '1-',
        '3-2',
        '-1',
        '+443',
        0,
        65536,
        '80,',
        '1-2-3',
        1.5,
      ]) {
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
    },
  );

  test(
    'manifest rejects unsafe names, duplicate files, URLs and extra metadata',
    () {
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
        'other.dat ',
        'bad\u0000.dat',
        'bad:stream.dat',
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
        'https://example.com/white space.dat',
        null,
      ]) {
        _rejectAssets([
          {'file': 'other.dat', 'url': url},
        ]);
      }
      _rejectAssets([
        {'file': 'other.dat', 'url': 'https://example.com/other.dat'},
        {'file': 'Other.dat', 'url': 'https://example.com/other.dat'},
      ]);
      _rejectAssets([
        {'file': 'other.dat'},
      ]);
      _rejectAssets([
        {
          'file': 'other.dat',
          'url': 'https://example.com/other.dat',
          'type': 'domain',
        },
      ]);
      _rejectAssets([null]);
      _rejectAssets({});
      _reject({
        ..._template(),
        'geodata': {'assets': [], 'cron': 'daily'},
      });
      _reject({..._template(), 'geodata': null});
      expect(
        CustomRoutingTemplate.parse(
          jsonEncode({
            ..._template(),
            'geodata': {'assets': []},
          }),
        ).assets,
        isEmpty,
      );
    },
  );
}

Map<String, dynamic> _template([int count = 1]) => {
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
    () => CustomRoutingTemplate.parse(jsonEncode(document)),
    throwsFormatException,
    reason: jsonEncode(document),
  );
}

void _rejectRule(Map<String, dynamic> rule) {
  final document = _template();
  (document['routing'] as Map)['rules'] = [rule];
  _reject(document);
}

void _rejectAssets(Object? assets) => _reject({
  ..._template(),
  'geodata': {'assets': assets},
});
