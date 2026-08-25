import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';

void main() {
  test('new outbound contains only the required UI defaults', () {
    expect(newOutboundMap(tag: 'custom'), {
      'name': 'xray',
      'protocol': 'vless',
      'settings': {'encryption': 'none'},
      'tag': 'custom',
      'streamSettings': {'network': 'raw', 'security': 'none'},
    });
  });

  test('single outbound wrapper round-trips without shared references', () {
    final source = <String, dynamic>{
      'protocol': 'vless',
      'settings': {
        'address': 'example.com',
        'editorOnly': {'enabled': true},
      },
    };

    final decoded = decodeSingleOutbound(encodeSingleOutbound(source));
    (decoded['settings'] as Map<String, dynamic>)['address'] = 'changed';

    expect(decoded['protocol'], 'vless');
    expect(
      (source['settings'] as Map<String, dynamic>)['address'],
      'example.com',
    );
    expect((decoded['settings'] as Map<String, dynamic>)['editorOnly'], {
      'enabled': true,
    });
  });

  test('single outbound wrapper rejects invalid shapes', () {
    expect(() => decodeSingleOutbound('[]'), throwsFormatException);
    expect(
      () => decodeSingleOutbound('{"outbounds":[]}'),
      throwsFormatException,
    );
    expect(
      () => decodeSingleOutbound('{"outbounds":[{},{}]}'),
      throwsFormatException,
    );
    expect(
      () => decodeSingleOutbound('{"outbounds":[1]}'),
      throwsFormatException,
    );
  });

  test('runtime tag and dialer helpers preserve siblings', () {
    final outbound = <String, dynamic>{
      'protocol': 'vless',
      'editorOnly': {'keep': true},
      'streamSettings': {
        'network': 'xhttp',
        'sockopt': {'interface': 'utun9', 'dialerProxy': 'old'},
      },
    };

    setOutboundTag(outbound, 'proxy');
    setOutboundDialerProxy(outbound, 'chainProxy');
    expect(outboundDialerProxy(outbound), 'chainProxy');
    removeOutboundDialerProxy(outbound);

    expect(outbound['tag'], 'proxy');
    expect(outbound['editorOnly'], {'keep': true});
    expect(
      ((outbound['streamSettings'] as Map<String, dynamic>)['sockopt']
          as Map<String, dynamic>)['interface'],
      'utun9',
    );
    expect(outboundDialerProxy(outbound), isNull);
  });

  test('canonical gate only rejects VMess and Shadowsocks mismatches', () {
    for (final outbound in <Map<String, dynamic>>[
      {
        'protocol': 'vmess',
        'settings': {'security': 'auto'},
      },
      {
        'protocol': 'shadowsocks',
        'settings': {'method': 'aes-256-gcm'},
      },
      {'protocol': 'vless'},
    ]) {
      expect(() => requireCanonicalOutbound(outbound), returnsNormally);
    }

    expect(
      () => requireCanonicalOutbound({
        'protocol': 'vmess',
        'settings': {'security': 'none'},
      }),
      throwsFormatException,
    );
    expect(
      () => requireCanonicalOutbound({
        'protocol': 'shadowsocks',
        'settings': {'method': 'plain'},
      }),
      throwsFormatException,
    );
  });

  test('DB save prefers object name and fills fallback only in its copy', () {
    final named = <String, dynamic>{
      'name': 'Object Name',
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {'editorOnly': true},
    };
    final namedCompanion = outboundCompanion(
      named,
      databaseName: 'Link Fragment',
    );

    expect(namedCompanion.name.value, 'Object Name');
    expect(_savedOutbound(namedCompanion.data.value!), named);

    final unnamed = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {'editorOnly': true},
    };
    final fallbackCompanion = outboundCompanion(
      unnamed,
      databaseName: 'Link Fragment',
    );

    expect(fallbackCompanion.name.value, 'Link Fragment');
    expect(
      _savedOutbound(fallbackCompanion.data.value!)['name'],
      'Link Fragment',
    );
    expect(unnamed, isNot(contains('name')));
  });
}

Map<String, dynamic> _savedOutbound(String data) =>
    decodeSingleOutbound(utf8.decode(base64Decode(data)));
