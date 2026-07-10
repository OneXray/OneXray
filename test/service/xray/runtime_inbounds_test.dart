import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/runtime_inbounds.dart';

void main() {
  test('TUN mode keeps TUN and ping inbounds and maps proxy tags', () {
    final xray = _configWithInboundTags(['socksIn', 'httpIn']);

    XrayRuntimeInbounds.applyToXrayJson(xray, InboundsState(), CoreRunMode.tun);

    expect(xray.inbounds!.map((item) => item.tag), ['tunIn', 'pingIn']);
    expect(xray.routing!.rules!.single.inboundTag, ['tunIn']);
  });

  test('Proxy mode keeps local proxy inbounds and expands the TUN tag', () {
    final xray = _configWithInboundTags(['tunIn']);

    XrayRuntimeInbounds.applyToXrayJson(
      xray,
      InboundsState(),
      CoreRunMode.proxy,
    );

    expect(xray.inbounds!.map((item) => item.tag), [
      'socksIn',
      'httpIn',
      'pingIn',
    ]);
    expect(xray.routing!.rules!.single.inboundTag, ['socksIn', 'httpIn']);
  });
}

XrayJson _configWithInboundTags(List<String> tags) {
  final rule = XrayRoutingRuleStandard.standard..inboundTag = tags;
  final routing = XrayRoutingStandard.standard..rules = [rule];
  return XrayJsonStandard.standard..routing = routing;
}
