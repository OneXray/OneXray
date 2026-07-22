import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/runtime_inbounds.dart';

void main() {
  test('TUN mode writes TUN and ping inbounds', () {
    final xray = _configWithInboundTags(['tunIn']);

    XrayRuntimeInbounds.applyToXrayJson(xray, InboundsState(), CoreRunMode.tun);

    expect(xray.inbounds!.map((item) => item.tag), ['tunIn', 'pingIn']);
    expect(xray.routing!.rules!.single.inboundTag, ['tunIn']);
  });

  test('Proxy mode writes only the Profile ping inbound', () {
    final inbounds = InboundsState();
    inbounds.ping.port = '23456';
    final xray = _configWithInboundTags(['tunIn']);
    xray.inbounds = <XrayInbound>[
      ...inbounds.xrayJson,
      XrayInbound(
        '127.0.0.1',
        '12000',
        'dokodemo-door',
        null,
        'customIn',
        null,
      ),
    ];
    final routingBefore = xray.routing!.toJson();

    XrayRuntimeInbounds.applyToXrayJson(xray, inbounds, CoreRunMode.proxy);

    expect(xray.inbounds!.map((item) => item.tag), ['pingIn']);
    expect(xray.inbounds!.single.port, '23456');
    expect(xray.routing!.toJson(), routingBefore);
  });

  test(
    'Raw Proxy mode replaces user inbounds with the Profile ping inbound',
    () {
      final inboundsState = InboundsState();
      inboundsState.ping.port = '23456';
      final json = <String, dynamic>{
        'inbounds': <dynamic>[
          <String, dynamic>{'tag': 'tunIn', 'protocol': 'tun'},
          <String, dynamic>{'tag': 'customIn', 'protocol': 'socks'},
          <String, dynamic>{'tag': 'pingIn', 'protocol': 'http'},
        ],
        'routing': <String, dynamic>{
          'rules': <dynamic>[
            <String, dynamic>{
              'inboundTag': <String>['tunIn'],
              'outboundTag': 'proxy',
            },
          ],
        },
        'customRoot': <String, dynamic>{'keep': true},
      };
      XrayRuntimeInbounds.applyToRawJson(
        json,
        inboundsState,
        CoreRunMode.proxy,
      );

      final inbounds = json['inbounds']! as List<dynamic>;
      expect(inbounds, hasLength(1));
      expect(inbounds.single, containsPair('tag', 'pingIn'));
      expect(inbounds.single, containsPair('port', '23456'));
      final routing = json['routing']! as Map<String, dynamic>;
      final rules = routing['rules']! as List<dynamic>;
      expect((rules.single as Map)['inboundTag'], <String>['tunIn']);
      expect(json['customRoot'], <String, dynamic>{'keep': true});
    },
  );
}

XrayJson _configWithInboundTags(List<String> tags) {
  final rule = XrayRoutingRuleStandard.standard..inboundTag = tags;
  final routing = XrayRoutingStandard.standard..rules = [rule];
  return XrayJsonStandard.standard..routing = routing;
}
