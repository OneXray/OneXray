import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/settings/traffic_widget.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  for (final supported in [true, false]) {
    test('widget pin request respects launcher support: $supported', () async {
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'isRequestPinWidgetSupported' ? supported : null;
      });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      expect(await TrafficWidgetService().requestPin(), supported);
      expect(calls.map((call) => call.method), [
        'isRequestPinWidgetSupported',
        if (supported) 'requestPinWidget',
      ]);
      if (supported) {
        expect(
          calls.last.arguments['qualifiedAndroidName'],
          TrafficWidgetService.provider,
        );
      }
    });
  }
}
