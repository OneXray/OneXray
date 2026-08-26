import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_db.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_reader.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_validator.dart';

void main() {
  late AppEventBus eventBus;

  setUpAll(() => eventBus = AppEventBus());
  tearDownAll(() => eventBus.close());

  test('Multi-node Outbound DB boundary preserves its supported roots', () {
    final source = <String, dynamic>{
      'name': '  Multi-node Outbound Name  ',
      'routing': {
        'rules': [
          {
            'type': 'field',
            'future': {'keep': true},
          },
        ],
      },
      'dns': {
        'servers': ['1.1.1.1'],
        'text': 'keep  inner\nwhitespace',
      },
      'outbounds': [
        {
          'tag': 'proxy',
          'protocol': 'future-protocol',
          'future': {'keep': true},
        },
      ],
    };

    final companion = multiNodeOutboundCompanion(source);
    final stored = _row(companion.data.value!);
    final decoded = readMultiNodeOutboundFromDbData(stored);
    ((decoded['dns'] as Map<String, dynamic>)['servers'] as List<dynamic>)
        .clear();

    expect(companion.name.value, '  Multi-node Outbound Name  ');
    expect(companion.type.value, CoreConfigType.multiNodeOutbound.name);
    expect(
      readMultiNodeOutboundFromText(JsonTool.encoder.convert(source)),
      source,
    );
    expect(readMultiNodeOutboundFromDbData(stored), source);
    expect(
      ((source['dns'] as Map<String, dynamic>)['servers'] as List<dynamic>),
      ['1.1.1.1'],
    );
  });

  test(
    'Multi-node Outbound reader and DB boundary reject unsupported roots',
    () {
      expect(() => readMultiNodeOutboundFromText('{}'), throwsFormatException);
      expect(
        () => multiNodeOutboundName({'name': null}),
        throwsFormatException,
      );
      final base = <String, dynamic>{
        'name': 'Multi-node Outbound',
        'outbounds': [
          {'tag': 'proxy', 'protocol': 'freedom'},
        ],
      };
      for (final entry in <String, dynamic>{
        'log': <String, dynamic>{},
        'inbounds': <dynamic>[],
        'policy': <String, dynamic>{},
        'metrics': <String, dynamic>{},
        'stats': <String, dynamic>{},
        'fakeDns': <String, dynamic>{},
        'observatory': <String, dynamic>{},
        'burstObservatory': <String, dynamic>{},
        'version': <String, dynamic>{},
        'geodata': <String, dynamic>{},
        'env': <String, dynamic>{},
      }.entries) {
        final source = <String, dynamic>{...base, entry.key: entry.value};
        expect(
          () => readMultiNodeOutboundFromText(JsonTool.encoder.convert(source)),
          throwsFormatException,
          reason: entry.key,
        );
        expect(
          () => multiNodeOutboundCompanion(source),
          throwsFormatException,
          reason: entry.key,
        );
      }
      expect(
        () => readMultiNodeOutboundFromDbData(_row('')),
        throwsFormatException,
      );
      expect(
        () => multiNodeOutboundCompanion({'name': 'Multi-node Outbound'}),
        throwsFormatException,
      );
    },
  );

  test('App Link name is applied before Multi-node Outbound validation', () {
    final config = readMultiNodeOutboundFromText(
      JsonTool.encoder.convert({
        'outbounds': [
          {'tag': 'proxy', 'protocol': 'freedom'},
        ],
      }),
      nameOverride: 'Link Name',
    );

    expect(config['name'], 'Link Name');
  });

  test('Multi-node Outbound rejects whitespace-only names', () {
    final config = <String, dynamic>{
      'name': '   ',
      'outbounds': [
        {'tag': 'proxy', 'protocol': 'freedom'},
      ],
    };

    expect(validateMultiNodeOutboundFields(config).item1, isFalse);
    expect(() => validateMultiNodeOutboundMap(config), throwsFormatException);
    expect(() => multiNodeOutboundName(config), throwsFormatException);
    expect(() => multiNodeOutboundCompanion(config), throwsFormatException);
  });

  test('Multi-node Outbound field validation requires its own proxy', () {
    expect(
      validateMultiNodeOutboundFields({'name': 'Multi-node Outbound'}).item1,
      isFalse,
    );
    expect(
      validateMultiNodeOutboundFields({'name': '  Multi-node Outbound  '})
          .item1,
      isFalse,
    );
    expect(
      validateMultiNodeOutboundFields({
        'name': 'Multi-node Outbound',
        'env': null,
      }).item1,
      isFalse,
    );
    expect(
      validateMultiNodeOutboundFields({
        'name': 'Multi-node Outbound',
        'outbounds': <String, dynamic>{},
      }).item1,
      isFalse,
    );
  });

  test('Multi-node Outbound validates Maps, tags, and canonicals', () {
    final valid = <String, dynamic>{
      'name': 'Multi-node Outbound',
      'outbounds': [
        {'tag': 'proxy', 'protocol': 'future-protocol'},
        {
          'tag': 'vmess',
          'protocol': 'vmess',
          'settings': {'security': 'auto'},
        },
      ],
    };
    expect(validateMultiNodeOutboundFields(valid).item1, isTrue);

    for (final outbounds in <List<dynamic>>[
      [1],
      [
        {'protocol': 'vless'},
      ],
      [
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
      [
        {'tag': 'same', 'protocol': 'vless'},
        {'tag': 'same', 'protocol': 'vless'},
      ],
      [
        {
          'tag': 'proxy',
          'protocol': 'shadowsocks',
          'settings': {'method': 'plain'},
        },
      ],
    ]) {
      expect(
        validateMultiNodeOutboundFields({
          'name': 'Multi-node Outbound',
          'outbounds': outbounds,
        }).item1,
        isFalse,
      );
    }
  });

  test('Multi-node Outbound protects reserved outbound protocols', () {
    expect(
      validateMultiNodeOutboundFields({
        'name': 'Multi-node Outbound',
        'outbounds': [
          {'tag': 'proxy', 'protocol': 'freedom'},
          {'tag': 'direct', 'protocol': 'freedom'},
          {'tag': 'fragment', 'protocol': 'freedom'},
          {'tag': 'block', 'protocol': 'blackhole'},
          {'tag': 'dnsOut', 'protocol': 'dns'},
        ],
      }).item1,
      isTrue,
    );

    for (final outbound in <Map<String, dynamic>>[
      {'tag': 'direct', 'protocol': 'socks'},
      {'tag': 'fragment', 'protocol': 'vless'},
      {'tag': 'block', 'protocol': 'freedom'},
      {'tag': 'dnsOut', 'protocol': 'freedom'},
    ]) {
      final validation = validateMultiNodeOutboundFields({
        'name': 'Multi-node Outbound',
        'outbounds': [
          {'tag': 'proxy', 'protocol': 'freedom'},
          outbound,
        ],
      });
      expect(validation.item1, isFalse);
      expect(validation.item2, startsWith('Reserved outbound'));
    }
  });

  test('Multi-node Outbound checks every outbound dependency', () {
    final valid = <String, dynamic>{
      'name': 'Multi-node Outbound',
      'outbounds': <dynamic>[
        {
          'tag': 'proxy',
          'protocol': 'vless',
          'streamSettings': {
            'sockopt': {'dialerProxy': 'chain'},
          },
        },
        {'tag': 'chain', 'protocol': 'socks'},
      ],
    };
    expect(validateMultiNodeOutboundFields(valid).item1, isTrue);

    final missing = copyXrayConfigMap(valid);
    (missing['outbounds']! as List<dynamic>).removeLast();
    expect(validateMultiNodeOutboundFields(missing).item1, isFalse);

    final conflict = copyXrayConfigMap(valid);
    final conflictProxy =
        (conflict['outbounds']! as List<dynamic>).first as Map<String, dynamic>;
    conflictProxy['proxySettings'] = {'tag': 'chain'};
    expect(validateMultiNodeOutboundFields(conflict).item1, isFalse);

    final cycle = copyXrayConfigMap(valid);
    final cycleChain =
        (cycle['outbounds']! as List<dynamic>).last as Map<String, dynamic>;
    cycleChain['proxySettings'] = {'tag': 'proxy'};
    expect(validateMultiNodeOutboundFields(cycle).item1, isFalse);
  });
}

CoreConfigData _row(String data) => CoreConfigData(
  id: 1,
  name: 'Database Name',
  type: CoreConfigType.multiNodeOutbound.name,
  tags: '',
  data: data,
  delay: 0,
  subId: 0,
);
