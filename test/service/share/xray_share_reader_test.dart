import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/share/xray_share_reader.dart';

void main() {
  test(
    'preserves libXray outbound maps without app-side schema validation',
    () async {
      final json = jsonDecode('''
{
  "outbounds": [
    {
      "name": "Valid",
      "protocol": "vless",
      "editorOnly": {"keep": true},
      "settings": {
        "address": "example.com",
        "port": 443,
        "id": "00000000-0000-0000-0000-000000000000",
        "encryption": "none",
        "advanced": {"keep": true}
      }
    },
    {
      "name": "Incomplete",
      "protocol": "vless",
      "settings": {
        "port": 443,
        "id": "00000000-0000-0000-0000-000000000000",
        "encryption": "none"
      }
    },
    {
      "name": "Unsupported",
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
''') as Map<String, dynamic>;
      final rows = await XrayShareReader().readXrayJsonOutbounds(json);

      expect(rows, hasLength(3));
      expect(
        rows.map((row) => row.name.value),
        containsAll(<String>['Valid', 'Incomplete', 'Unsupported']),
      );
      final valid = rows.firstWhere((row) => row.name.value == 'Valid');
      final wrapper = jsonDecode(
        utf8.decode(base64Decode(valid.data.value!)),
      ) as Map<String, dynamic>;
      final stored =
          (wrapper['outbounds'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(stored['tag'], 'Valid');
      expect(stored, isNot(contains('name')));
      expect(stored['editorOnly'], {'keep': true});
      expect((stored['settings'] as Map<String, dynamic>)['advanced'], {
        'keep': true,
      });
    },
  );

  test('skips Shadowsocks outbounds with non-canonical methods', () async {
    final json = jsonDecode('''
{
  "outbounds": [
    {
      "name": "Canonical",
      "protocol": "shadowsocks",
      "settings": {
        "address": "example.com",
        "port": 8388,
        "method": "aes-256-gcm",
        "password": "password"
      }
    },
    {
      "name": "Alias",
      "protocol": "shadowsocks",
      "settings": {
        "address": "example.com",
        "port": 8388,
        "method": "aead_aes_256_gcm",
        "password": "password"
      }
    }
  ]
}
''') as Map<String, dynamic>;
    final rows = await XrayShareReader().readXrayJsonOutbounds(json);

    expect(rows, hasLength(1));
    expect(rows.single.name.value, 'Canonical');
  });

  test('skips VMess outbounds with non-canonical securities', () async {
    final json = jsonDecode('''
{
  "outbounds": [
    {
      "name": "Canonical",
      "protocol": "vmess",
      "settings": {
        "address": "example.com",
        "port": 443,
        "id": "00000000-0000-0000-0000-000000000000",
        "security": "auto"
      }
    },
    {
      "name": "Legacy",
      "protocol": "vmess",
      "settings": {
        "address": "example.com",
        "port": 443,
        "id": "00000000-0000-0000-0000-000000000000",
        "security": "none"
      }
    }
  ]
}
''') as Map<String, dynamic>;
    final rows = await XrayShareReader().readXrayJsonOutbounds(json);

    expect(rows, hasLength(1));
    expect(rows.single.name.value, 'Canonical');
  });

  test('uses libXray tag metadata without borrowing sendThrough', () async {
    final xrayJson = <String, dynamic>{
      'outbounds': [
        {
          'protocol': 'vless',
          'tag': 'Imported Node',
          'sendThrough': '127.0.0.1',
          'settings': {
            'address': 'example.com',
            'port': 443,
            'id': '00000000-0000-0000-0000-000000000000',
            'encryption': 'none',
          },
        },
      ],
    };

    final rows = await XrayShareReader().readXrayJsonOutbounds(xrayJson);

    expect(rows.single.name.value, 'Imported Node');
    final wrapper = jsonDecode(
      utf8.decode(base64Decode(rows.single.data.value!)),
    ) as Map<String, dynamic>;
    final stored =
        (wrapper['outbounds'] as List<dynamic>).single as Map<String, dynamic>;
    expect(stored['tag'], 'Imported Node');
    expect(stored['sendThrough'], '127.0.0.1');
    expect(stored, isNot(contains('name')));
  });

  test('uses protocol as the tag when a share has no node name', () async {
    final rows = await XrayShareReader().readXrayJsonOutbounds({
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'address': 'example.com',
            'port': 443,
            'id': '00000000-0000-0000-0000-000000000000',
            'encryption': 'none',
          },
        },
      ],
    });

    expect(rows.single.name.value, 'vless');
    final wrapper = jsonDecode(
      utf8.decode(base64Decode(rows.single.data.value!)),
    ) as Map<String, dynamic>;
    final stored =
        (wrapper['outbounds'] as List<dynamic>).single as Map<String, dynamic>;
    expect(stored['tag'], 'vless');
    expect(stored, isNot(contains('name')));
  });
}
