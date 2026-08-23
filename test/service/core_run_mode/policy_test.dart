import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/core_run_mode/state.dart';

void main() {
  test('iOS Debug builds preserve Proxy mode', () {
    expect(
      CoreRunModePolicy.resolveForEnvironment(
        CoreRunMode.proxy,
        debugMode: true,
        isIOS: true,
      ),
      CoreRunMode.proxy,
    );
  });

  test('non-iOS Debug builds resolve Proxy mode to TUN', () {
    expect(
      CoreRunModePolicy.resolveForEnvironment(
        CoreRunMode.proxy,
        debugMode: true,
        isIOS: false,
      ),
      CoreRunMode.tun,
    );
  });

  test('iOS non-Debug builds resolve Proxy mode to TUN', () {
    expect(
      CoreRunModePolicy.resolveForEnvironment(
        CoreRunMode.proxy,
        debugMode: false,
        isIOS: true,
      ),
      CoreRunMode.tun,
    );
  });

  test('non-iOS non-Debug builds resolve Proxy mode to TUN', () {
    expect(
      CoreRunModePolicy.resolveForEnvironment(
        CoreRunMode.proxy,
        debugMode: false,
        isIOS: false,
      ),
      CoreRunMode.tun,
    );
  });

  test('TUN mode remains available in every environment', () {
    for (final debugMode in [true, false]) {
      for (final isIOS in [true, false]) {
        expect(
          CoreRunModePolicy.resolveForEnvironment(
            CoreRunMode.tun,
            debugMode: debugMode,
            isIOS: isIOS,
          ),
          CoreRunMode.tun,
        );
      }
    }
  });
}
