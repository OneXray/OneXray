import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/share/xray_share_reader.dart';

void main() {
  test(
    'converts supported outbounds without app-side Xray validation',
    () async {
      final json =
          jsonDecode('''
{
  "outbounds": [
    {
      "name": "Valid",
      "protocol": "vless",
      "settings": {
        "address": "example.com",
        "port": 443,
        "id": "00000000-0000-0000-0000-000000000000",
        "encryption": "none"
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
''')
              as Map<String, dynamic>;
      final xrayJson = XrayJson.fromJson(json);

      final rows = await XrayShareReader().readXrayJsonOutbounds(xrayJson);

      expect(rows, hasLength(2));
      expect(
        rows.map((row) => row.name.value),
        containsAll(<String>['Valid', 'Incomplete']),
      );
    },
  );
}
