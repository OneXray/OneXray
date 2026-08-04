import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/app_link_parser.dart';

void main() {
  group('config links', () {
    for (final entry in const <String, OneXrayConfigLinkType>{
      'outbound': OneXrayConfigLinkType.outbound,
      'profile': OneXrayConfigLinkType.profile,
      'full': OneXrayConfigLinkType.full,
      'raw': OneXrayConfigLinkType.raw,
    }.entries) {
      test('parses ${entry.key}', () {
        const json = '{"name":"Example"}';
        final uri = Uri(
          scheme: 'onexray',
          host: 'onexray.com',
          path: '/config/add',
          queryParameters: {
            'type': entry.key,
            'data': base64Encode(utf8.encode(json)),
          },
          fragment: 'Imported Profile',
        );

        final result = OneXrayAppLinkParser.parse(uri);

        expect(result, isA<OneXrayConfigLink>());
        final link = result! as OneXrayConfigLink;
        expect(link.type, entry.value);
        expect(link.xrayJson, json);
        expect(link.name, 'Imported Profile');
      });
    }

    test('does not accept the legacy setting type', () {
      final uri = _configUri(type: 'setting');

      expect(OneXrayAppLinkParser.parse(uri), isNull);
    });

    test('rejects duplicate and unknown query parameters', () {
      final data = Uri.encodeQueryComponent(
        base64Encode(utf8.encode('{"name":"Example"}')),
      );
      final duplicate = Uri.parse(
        'onexray://onexray.com/config/add?type=raw&type=full&data=$data',
      );
      final unknown = _configUri(extra: const {'backup': 'true'});

      expect(OneXrayAppLinkParser.parse(duplicate), isNull);
      expect(OneXrayAppLinkParser.parse(unknown), isNull);
    });
  });

  group('subscription links', () {
    test('parses a plain HTTPS subscription and removes its fragment', () {
      final uri = _subscriptionUri(
        url: 'https://example.com/subscription#provider-fragment',
        name: 'Provider',
      );

      final result = OneXrayAppLinkParser.parse(uri);

      expect(result, isA<OneXraySubscriptionLink>());
      final link = result! as OneXraySubscriptionLink;
      expect(link.url, 'https://example.com/subscription');
      expect(link.name, 'Provider');
      expect(link.ageKeyType, isNull);
    });

    test('parses X25519 and hybrid age modes', () {
      final x25519 = OneXrayAppLinkParser.parse(
        _subscriptionUri(url: 'https://example.com/sub', age: 'x25519'),
      );
      final hybrid = OneXrayAppLinkParser.parse(
        _subscriptionUri(url: 'https://example.com/sub', age: 'hybrid'),
      );

      expect(
        (x25519! as OneXraySubscriptionLink).ageKeyType,
        AgeKeyType.x25519,
      );
      expect(
        (hybrid! as OneXraySubscriptionLink).ageKeyType,
        AgeKeyType.hybrid,
      );
    });

    test('rejects unknown age modes and non-HTTPS URLs', () {
      final unknownAge = _subscriptionUri(
        url: 'https://example.com/sub',
        age: 'future',
      );
      final insecure = _subscriptionUri(url: 'http://example.com/sub');

      expect(OneXrayAppLinkParser.parse(unknownAge), isNull);
      expect(OneXrayAppLinkParser.parse(insecure), isNull);
    });
  });

  group('GeoData links', () {
    test('parses domain and IP GeoData', () {
      final domain = OneXrayAppLinkParser.parse(
        _geoDataUri(type: 'domain', name: 'community-domain'),
      );
      final ip = OneXrayAppLinkParser.parse(
        _geoDataUri(type: 'ip', name: 'community-ip'),
      );

      expect((domain! as OneXrayGeoDataLink).type, GeoDataType.domain);
      expect(domain.name, 'community-domain');
      expect((ip! as OneXrayGeoDataLink).type, GeoDataType.ip);
    });

    test('rejects unsupported types and non-HTTPS URLs', () {
      expect(OneXrayAppLinkParser.parse(_geoDataUri(type: 'other')), isNull);
      expect(
        OneXrayAppLinkParser.parse(
          _geoDataUri(type: 'domain', url: 'file:///tmp/geosite.dat'),
        ),
        isNull,
      );
    });
  });

  test('requires the exact scheme, host, and supported path', () {
    final wrongScheme = _configUri(scheme: 'https');
    final wrongHost = _configUri(host: 'example.com');
    final spoofedHost = _configUri(host: 'onexray.com.example.com');
    final wrongPath = _configUri(path: '/backup/add');

    expect(OneXrayAppLinkParser.parse(wrongScheme), isNull);
    expect(OneXrayAppLinkParser.parse(wrongHost), isNull);
    expect(OneXrayAppLinkParser.parse(spoofedHost), isNull);
    expect(OneXrayAppLinkParser.parse(wrongPath), isNull);
  });

  test('parses supported links from multi-line share text', () {
    final raw = _configUri(type: 'raw').toString();
    final geoData = _geoDataUri(type: 'domain').toString();

    final links = OneXrayAppLinkParser.parseText(
      '$raw\r\nnot-a-link\n$geoData\n',
    );

    expect(links, hasLength(2));
    expect(links.first, isA<OneXrayConfigLink>());
    expect(links.last, isA<OneXrayGeoDataLink>());
  });
}

Uri _configUri({
  String scheme = 'onexray',
  String host = 'onexray.com',
  String path = '/config/add',
  String type = 'raw',
  Map<String, String> extra = const {},
}) {
  return Uri(
    scheme: scheme,
    host: host,
    path: path,
    queryParameters: {
      'type': type,
      'data': base64Encode(utf8.encode('{"name":"Example"}')),
      ...extra,
    },
  );
}

Uri _subscriptionUri({required String url, String? age, String name = ''}) {
  return Uri(
    scheme: 'onexray',
    host: 'onexray.com',
    path: '/sub/add',
    queryParameters: {'url': url, 'age': ?age},
    fragment: name,
  );
}

Uri _geoDataUri({
  required String type,
  String url = 'https://example.com/geodata.dat',
  String name = '',
}) {
  return Uri(
    scheme: 'onexray',
    host: 'onexray.com',
    path: '/dat/add',
    queryParameters: {'type': type, 'url': url},
    fragment: name,
  );
}
