import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/core_run_mode/state.dart';

void main() {
  test('Debug builds preserve the requested run mode', () {
    expect(
      CoreRunModePolicy.resolveForBuild(CoreRunMode.proxy, debugMode: true),
      CoreRunMode.proxy,
    );
  });

  test('Non-Debug builds always resolve to TUN mode', () {
    expect(
      CoreRunModePolicy.resolveForBuild(CoreRunMode.proxy, debugMode: false),
      CoreRunMode.tun,
    );
    expect(
      CoreRunModePolicy.resolveForBuild(CoreRunMode.tun, debugMode: false),
      CoreRunMode.tun,
    );
  });
}
