import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/config_map.dart';

void main() {
  test('complete config round-trips and copies without shared references', () {
    final source = <String, dynamic>{
      'name': 'Profile',
      'log': {'loglevel': 'warning'},
      'routing': {
        'rules': [
          {
            'type': 'field',
            'future': {'keep': true},
          },
        ],
      },
      'dns': {
        'servers': [
          '1.1.1.1',
          {
            'address': 'https://example.com/dns-query',
            'future': {'keep': true},
          },
        ],
        'text': 'keep  inner\nwhitespace',
      },
      'inbounds': [
        {'protocol': 'socks'},
      ],
      'outbounds': [
        {'protocol': 'vless'},
      ],
      'policy': <String, dynamic>{},
      'metrics': <String, dynamic>{},
      'stats': <String, dynamic>{},
      'fakeDns': [
        {'ipPool': '198.18.0.0/15'},
      ],
      'observatory': <String, dynamic>{},
      'burstObservatory': <String, dynamic>{},
    };

    final decoded = decodeXrayConfigMap(encodeXrayConfigMap(source));
    final copied = copyXrayConfigMap(source);
    ((copied['dns'] as Map<String, dynamic>)['servers'] as List<dynamic>)
        .clear();

    expect(decoded, source);
    expect(decoded.keys.toSet(), xrayConfigRootNames);
    expect(
      ((source['dns'] as Map<String, dynamic>)['servers'] as List<dynamic>),
      hasLength(2),
    );
  });

  test('config validation rejects unsupported roots and invalid shapes', () {
    expect(() => decodeXrayConfigMap('[]'), throwsFormatException);
    for (final root in [
      'env',
      'api',
      'transport',
      'reverse',
      'version',
      'geodata',
      'typo',
    ]) {
      expect(
        () => decodeXrayConfigMap(JsonTool.encoder.convert({root: null})),
        throwsFormatException,
      );
    }
    for (final config in <Map<String, dynamic>>[
      {'name': ''},
      {'name': '   '},
      {'inbounds': <String, dynamic>{}},
      {'outbounds': <String, dynamic>{}},
      {'fakeDns': '198.18.0.0/15'},
      {'routing': <dynamic>[]},
    ]) {
      expect(() => encodeXrayConfigMap(config), throwsFormatException);
    }
  });

  test('root editor preserves missing, null, value, and sibling roots', () {
    final source = <String, dynamic>{
      'name': 'Profile',
      'dns': {
        'servers': ['1.1.1.1'],
      },
      'routing': {
        'domainStrategy': 'AsIs',
        'future': {'keep': true},
      },
    };

    expect(JsonTool.decoder.convert(encodeXrayRootEditor(source, 'routing')), {
      'routing': source['routing'],
    });
    expect(
      JsonTool.decoder.convert(encodeXrayRootEditor(source, 'metrics')),
      <String, dynamic>{},
    );

    final replaced = applyXrayRootEditor(
      source,
      'routing',
      '{"routing":{"domainStrategy":"IPIfNonMatch"}}',
    );
    final removed = applyXrayRootEditor(source, 'routing', '{}');
    final emptyObject = applyXrayRootEditor(
      source,
      'routing',
      '{"routing":{}}',
    );
    final explicitNull = applyXrayRootEditor(
      source,
      'routing',
      '{"routing":null}',
    );
    ((replaced['dns'] as Map<String, dynamic>)['servers'] as List<dynamic>)
        .clear();

    expect(replaced['routing'], {'domainStrategy': 'IPIfNonMatch'});
    expect(removed, isNot(contains('routing')));
    expect(emptyObject, containsPair('routing', <String, dynamic>{}));
    expect(explicitNull, containsPair('routing', null));
    expect(source['routing'], {
      'domainStrategy': 'AsIs',
      'future': {'keep': true},
    });
    expect(
      ((source['dns'] as Map<String, dynamic>)['servers'] as List<dynamic>),
      ['1.1.1.1'],
    );

    for (final text in [
      '[]',
      '{"dns":{}}',
      '{"routing":{},"dns":{}}',
      '{"routing":[]}',
    ]) {
      expect(
        () => applyXrayRootEditor(source, 'routing', text),
        throwsFormatException,
      );
    }
    expect(() => encodeXrayRootEditor(source, 'name'), throwsFormatException);
  });

  test('Multi-node Outbound overlays only its three configuration roots', () {
    final profile = <String, dynamic>{
      'name': 'Profile',
      'log': {'loglevel': 'warning'},
      'dns': {
        'servers': ['1.1.1.1'],
      },
      'routing': {'domainStrategy': 'AsIs'},
    };
    final multiNodeOutbound = <String, dynamic>{
      'name': 'Multi-node Outbound',
      'dns': null,
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'future': {'keep': true},
      },
    };

    final result = applyMultiNodeOutboundOverlay(profile, multiNodeOutbound);
    (result['log'] as Map<String, dynamic>)['loglevel'] = 'debug';
    ((result['routing'] as Map<String, dynamic>)['future']
            as Map<String, dynamic>)['keep'] =
        false;

    expect(result['name'], 'Profile');
    expect(result, isNot(contains('dns')));
    expect(
      (result['routing'] as Map<String, dynamic>)['domainStrategy'],
      'IPIfNonMatch',
    );
    expect((profile['log'] as Map<String, dynamic>)['loglevel'], 'warning');
    expect(
      ((multiNodeOutbound['routing'] as Map<String, dynamic>)['future']
          as Map<String, dynamic>)['keep'],
      isTrue,
    );
  });
}
