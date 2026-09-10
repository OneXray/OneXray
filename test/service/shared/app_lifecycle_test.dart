import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/app_lifecycle.dart';

void main() {
  const cases = <AppLifecycleState?, bool>{
    null: true,
    AppLifecycleState.resumed: true,
    AppLifecycleState.inactive: true,
    AppLifecycleState.hidden: false,
    AppLifecycleState.paused: false,
    AppLifecycleState.detached: false,
  };
  for (final entry in cases.entries) {
    test('app visibility for ${entry.key}', () {
      expect(isAppVisible(entry.key), entry.value);
    });
  }
}
