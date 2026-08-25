import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_reader.dart';
import 'package:onexray/service/xray/full_config/state_validator.dart';
import 'package:onexray/service/xray/full_config/state_writer.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_validator.dart';
import 'package:onexray/service/xray/profile/state_writer.dart';

void main() {
  late AppEventBus eventBus;

  setUpAll(() => eventBus = AppEventBus());
  tearDownAll(() => eventBus.close());

  test('Profile and Full preserve App-unprojected user outbound Maps', () {
    final outbound = <String, dynamic>{
      'name': '  node  ',
      'tag': 'proxy',
      'protocol': 'future-protocol',
      'settings': <dynamic>['core', 'owned', 'shape'],
      'streamSettings': {
        'network': 'tcp',
        'security': 'future-security',
        'sockopt': {'interface': ' en0 ', 'appUnprojected': true},
      },
      'appUnprojected': {
        'nested': [1, 2],
      },
    };
    final xrayJson = XrayJson.fromJson({
      'outbounds': [outbound],
    });

    final profile = XrayProfileState();
    expect(profile.readFromXrayJson(xrayJson), isTrue);
    profile.removeWhitespace();
    expect(profile.outbounds.outbounds, [outbound]);
    expect(profile.xrayJson.outbounds!.first, outbound);

    final full = XrayFullConfigState();
    expect(full.readFromXrayJson(xrayJson), isTrue);
    expect(full.validateFields().item1, isTrue);
    expect(full.xrayJson.outbounds!.first, outbound);
  });

  test('System Outbounds stay typed and final patches use a Map copy', () {
    final direct = <String, dynamic>{
      'protocol': 'freedom',
      'tag': 'direct',
      'streamSettings': {
        'sockopt': {'interface': 'en0'},
      },
      'appUnprojected': true,
    };
    final finalOutbound = <String, dynamic>{
      'name': 'final',
      'tag': 'chainProxy',
      'protocol': 'future-protocol',
      'streamSettings': {
        'sockopt': {'dialerProxy': 'upstream', 'interface': 'en1'},
      },
      'appUnprojected': true,
    };
    final profile = XrayProfileState();

    expect(
      profile.readFromXrayJson(
        XrayJson.fromJson({
          'outbounds': [direct, finalOutbound],
        }),
      ),
      isTrue,
    );

    expect(profile.outbounds.outbounds, isEmpty);
    expect(profile.outbounds.finalOutbound, finalOutbound);
    final written = profile.xrayJson.outbounds!;
    final writtenFinal = written.first;
    final writtenDirect = written.singleWhere(
      (outbound) => outboundString(outbound, 'tag') == 'direct',
    );
    expect(outboundDialerProxy(writtenFinal), isNull);
    expect(
      ((writtenFinal['streamSettings'] as Map)['sockopt'] as Map)['interface'],
      'en1',
    );
    expect(writtenDirect.containsKey('appUnprojected'), isFalse);
    expect(outboundDialerProxy(profile.outbounds.finalOutbound!), 'upstream');
  });

  test('Full reader canonical failure is atomic', () {
    final existing = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {'encryption': 'none'},
    };
    final full = XrayFullConfigState()
      ..name = 'existing'
      ..outbounds.outbounds.add(copyOutboundMap(existing));
    final replacement = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'future-protocol',
    };
    final invalid = <String, dynamic>{
      'tag': 'custom',
      'protocol': 'vmess',
      'settings': {'security': 'none'},
    };

    expect(
      full.readFromXrayJson(
        XrayJson.fromJson({
          'name': 'replacement',
          'outbounds': [replacement, invalid],
        }),
      ),
      isFalse,
    );

    expect(full.name, 'existing');
    expect(full.outbounds.outbounds, [existing]);
  });

  test('Profile and Full reject non-canonical Maps before writing', () {
    final invalid = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'shadowsocks',
      'settings': {'method': 'plain'},
    };
    final profile = XrayProfileState()
      ..outbounds.outbounds.add(copyOutboundMap(invalid));
    final full = XrayFullConfigState()
      ..outbounds.outbounds.add(copyOutboundMap(invalid));

    expect(profile.validateFields().item1, isFalse);
    expect(() => profile.xrayJson, throwsFormatException);
    expect(full.validateFields().item1, isFalse);
    expect(() => full.xrayJson, throwsFormatException);
  });

  test('Full validator rejects a missing custom tag', () {
    final full = XrayFullConfigState()
      ..outbounds.outbounds.add({
        'tag': 'proxy',
        'protocol': 'vless',
        'settings': {'encryption': 'none'},
      })
      ..outbounds.outbounds.add({
        'protocol': 'vless',
        'settings': {'encryption': 'none'},
      });

    expect(full.validateFields().item1, isFalse);
  });
}
