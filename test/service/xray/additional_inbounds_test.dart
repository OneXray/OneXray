import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/profile/additional_inbound_state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/profile/state_writer.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    eventBus = AppEventBus();
  });

  tearDown(() => eventBus.close());

  test('additional inbounds round-trip through Xray JSON models', () {
    final original = InboundsState()
      ..additional = <AdditionalInboundState>[
        InboundSocksState(
          listen: '',
          port: '12080',
          tag: 'socksOffice',
          user: 'alice',
          pass: 'secret',
        ),
        InboundHttpState(port: '12081', tag: 'httpLocal'),
        InboundDokodemoDoorState(
          port: '12082',
          tag: 'jellyfinForward',
          targetAddress: '127.0.0.1',
          targetPort: '8888',
          network: DokodemoDoorNetwork.tcp,
        ),
      ];
    final json = XrayJsonStandard.standard..inbounds = original.xrayJson;

    final decoded = XrayJson.fromJson(json.toJson());
    final restored = InboundsState()..readFromXrayJson(decoded);

    expect(restored.additional, hasLength(3));
    final socks = restored.additional[0] as InboundSocksState;
    expect(socks.listen, '');
    expect(socks.port, '12080');
    expect(socks.user, 'alice');
    expect(socks.pass, 'secret');
    expect(socks.udp, isTrue);

    final http = restored.additional[1] as InboundHttpState;
    expect(http.port, '12081');
    expect(http.tag, 'httpLocal');

    final forward = restored.additional[2] as InboundDokodemoDoorState;
    expect(forward.targetAddress, '127.0.0.1');
    expect(forward.targetPort, '8888');
    expect(forward.network, DokodemoDoorNetwork.tcp);
  });

  test('additional inbound validation rejects unsafe and duplicate values', () {
    final state = InboundsState()
      ..additional = <AdditionalInboundState>[
        InboundSocksState(listen: '', port: '12080', tag: 'localProxy'),
      ];

    expect(state.validate(const <String>{}), isNotNull);

    state.additional[0] = InboundSocksState(
      listen: '',
      port: '12080',
      tag: 'localProxy',
      user: 'alice',
      pass: 'secret',
    );
    state.additional.add(InboundHttpState(port: '12080', tag: 'localProxy'));

    expect(state.validate(const <String>{}), isNotNull);
  });

  test('additional inbound normalization preserves credentials', () {
    final inbound = InboundSocksState(
      listen: ' 127.0.0.1 ',
      port: ' 12080 ',
      tag: ' localProxy ',
      user: 'user name',
      pass: ' pass phrase ',
    );

    inbound.removeWhitespace();

    expect(inbound.listen, '127.0.0.1');
    expect(inbound.port, '12080');
    expect(inbound.tag, 'localProxy');
    expect(inbound.user, 'user name');
    expect(inbound.pass, ' pass phrase ');
  });

  test('new additional inbound names and ports stay unique', () {
    final state = InboundsState();
    final first = state.createAdditional(AdditionalInboundType.socks);
    state.additional.add(first);
    final second = state.createAdditional(AdditionalInboundType.socks);

    expect(first.tag, 'socksIn1');
    expect(second.tag, 'socksIn2');
    expect(first.port, '11024');
    expect(second.port, '11025');
  });

  test('Profile validation config removes only the TUN inbound', () {
    final profile = XrayProfileState()
      ..inbounds.additional = <AdditionalInboundState>[
        InboundSocksState(tag: 'localSocks'),
        InboundDokodemoDoorState(tag: 'dokodemoDoor1', targetPort: '8888'),
      ];
    final xrayJson = profile.xrayJson;

    profile.removeTunInbound(xrayJson);

    expect(xrayJson.inbounds!.map((inbound) => inbound.tag), <String>[
      'localSocks',
      'dokodemoDoor1',
      RoutingInboundTag.pingIn.name,
    ]);
  });
}
