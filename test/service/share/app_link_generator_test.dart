import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/share/app_link_generator.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/app_link_parser.dart';
import 'package:onexray/service/share/app_link_share_service.dart';

void main() {
  group('config links', () {
    for (final entry in const <CoreConfigType, OneXrayConfigLinkType>{
      CoreConfigType.outbound: OneXrayConfigLinkType.outbound,
      CoreConfigType.profile: OneXrayConfigLinkType.profile,
      CoreConfigType.full: OneXrayConfigLinkType.full,
      CoreConfigType.raw: OneXrayConfigLinkType.raw,
    }.entries) {
      test('generates and parses ${entry.value.name}', () {
        const xrayJson = '{"name":"Example"}';
        final uri = OneXrayAppLinkGenerator.config(
          _config(
            type: entry.key.name,
            data: base64Encode(utf8.encode(xrayJson)),
          ),
        );

        expect(uri, isNotNull);
        final link = OneXrayAppLinkParser.parse(uri!)! as OneXrayConfigLink;
        expect(link.type, entry.value);
        expect(link.xrayJson, xrayJson);
        expect(link.name, 'Shared Config');
      });
    }

    test('rejects unsupported types and invalid data', () {
      expect(
        OneXrayAppLinkGenerator.config(_config(type: 'unsupported')),
        isNull,
      );
      expect(
        OneXrayAppLinkGenerator.config(
          _config(type: CoreConfigType.raw.name, data: 'not-base64'),
        ),
        isNull,
      );
    });

    test('finds custom GeoData references in routing and DNS', () {
      final data = base64Encode(
        utf8.encode(
          jsonEncode({
            'routing': {
              'rules': [
                {
                  'domain': [
                    'geosite:google',
                    'ext:community-domain.dat:streaming',
                  ],
                  'ip': ['geoip:private', 'ext:community-ip.dat:private'],
                },
              ],
            },
            'dns': {
              'servers': [
                '8.8.8.8',
                {
                  'address': '1.1.1.1',
                  'domains': ['ext:community-domain.dat:search'],
                  'expectedIPs': ['ext:dns-ip.dat:cloudflare'],
                },
              ],
            },
          }),
        ),
      );

      final names = OneXrayAppLinkGenerator.referencedGeoDataNames(
        _config(type: CoreConfigType.profile.name, data: data),
      );

      expect(names, {'community-domain', 'community-ip', 'dns-ip'});
    });

    test('places referenced GeoData links before the config link', () async {
      final data = base64Encode(
        utf8.encode(
          jsonEncode({
            'routing': {
              'rules': [
                {
                  'domain': ['ext:z-domain.dat:all', 'ext:a-domain.dat:all'],
                },
              ],
            },
          }),
        ),
      );
      final geoData = {
        'a-domain': _geoData('a-domain'),
        'z-domain': _geoData('z-domain'),
      };
      final service = OneXrayAppLinkShareService(
        geoDataLookup: (name) async => geoData[name],
      );

      final text = await service.config(
        _config(type: CoreConfigType.profile.name, data: data),
      );

      expect(text, isNotNull);
      final links = OneXrayAppLinkParser.parseText(text!);
      expect(links, hasLength(3));
      expect(links[0], isA<OneXrayGeoDataLink>());
      expect(links[0].name, 'a-domain');
      expect(links[1], isA<OneXrayGeoDataLink>());
      expect(links[1].name, 'z-domain');
      expect(links[2], isA<OneXrayConfigLink>());
    });
  });

  group('subscription links', () {
    test('normalizes a plain subscription URL', () {
      final uri = OneXrayAppLinkGenerator.subscription(
        _subscription(url: 'https://example.com/sub#provider-fragment'),
      );

      expect(uri, isNotNull);
      final link = OneXrayAppLinkParser.parse(uri!)! as OneXraySubscriptionLink;
      expect(link.url, 'https://example.com/sub');
      expect(link.name, 'Provider');
      expect(link.ageKeyType, isNull);
    });

    test('exports only the X25519 age type', () {
      const secretKey = 'AGE-SECRET-KEY-1PRIVATE';
      const publicKey = 'age1public';
      final uri = OneXrayAppLinkGenerator.subscription(
        _subscription(ageSecretKey: secretKey, agePublicKey: publicKey),
      );

      expect(uri, isNotNull);
      final text = uri.toString();
      expect(text, isNot(contains(secretKey)));
      expect(text, isNot(contains(publicKey)));
      final link = OneXrayAppLinkParser.parse(uri!)! as OneXraySubscriptionLink;
      expect(link.ageKeyType, AgeKeyType.x25519);
    });

    test('exports only the hybrid age type', () {
      final uri = OneXrayAppLinkGenerator.subscription(
        _subscription(
          ageSecretKey: 'AGE-SECRET-KEY-PQ-1PRIVATE',
          agePublicKey: 'age1pq1public',
        ),
      );

      expect(uri, isNotNull);
      final link = OneXrayAppLinkParser.parse(uri!)! as OneXraySubscriptionLink;
      expect(link.ageKeyType, AgeKeyType.hybrid);
    });

    test('rejects incomplete or unsupported age key pairs', () {
      expect(
        OneXrayAppLinkGenerator.subscription(
          _subscription(ageSecretKey: 'AGE-SECRET-KEY-1PRIVATE'),
        ),
        isNull,
      );
      expect(
        OneXrayAppLinkGenerator.subscription(
          _subscription(
            ageSecretKey: 'unsupported',
            agePublicKey: 'age1public',
          ),
        ),
        isNull,
      );
    });
  });

  test('generates and parses a GeoData link', () {
    final uri = OneXrayAppLinkGenerator.geoData(
      _geoData('Community Domain', url: 'https://example.com/community.dat'),
    );

    expect(uri, isNotNull);
    final link = OneXrayAppLinkParser.parse(uri!)! as OneXrayGeoDataLink;
    expect(link.name, 'Community Domain');
    expect(link.type, GeoDataType.domain);
    expect(link.url, 'https://example.com/community.dat');
  });
}

GeoDataData _geoData(String name, {String? url}) {
  return GeoDataData(
    id: 3,
    name: name,
    type: GeoDataType.domain.name,
    url: url ?? 'https://example.com/$name.dat',
    timestamp: DateTime(2026),
    categoryCount: 10,
    ruleCount: 100,
  );
}

CoreConfigData _config({required String type, String data = 'e30='}) {
  return CoreConfigData(
    id: 1,
    name: 'Shared Config',
    type: type,
    tags: '',
    data: data,
    delay: 0,
    subId: 0,
  );
}

SubscriptionData _subscription({
  String url = 'https://example.com/sub',
  String? ageSecretKey,
  String? agePublicKey,
}) {
  return SubscriptionData(
    id: 2,
    name: 'Provider',
    url: url,
    ageSecretKey: ageSecretKey,
    agePublicKey: agePublicKey,
    timestamp: DateTime(2026),
    count: 1,
    expanded: true,
  );
}
