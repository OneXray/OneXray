import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/service/ping/state.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('custom ping URL is selectable and resolved', () {
    final state = PingState()
      ..url = PingUrl.custom
      ..customUrl = 'https://example.com/ping';

    expect(PingUrl.names, contains('Custom'));
    expect(state.realUrl, 'https://example.com/ping');
  });

  test('ping URL validation accepts only absolute HTTP URLs', () {
    expect(PingUrl.isValidCustomUrl('https://example.com/ping'), isTrue);
    expect(PingUrl.isValidCustomUrl('HTTP://127.0.0.1:8080/ping'), isTrue);
    expect(PingUrl.isValidCustomUrl(''), isFalse);
    expect(PingUrl.isValidCustomUrl('example.com/ping'), isFalse);
    expect(PingUrl.isValidCustomUrl('ftp://example.com/ping'), isFalse);
  });

  test('custom URL and automatic ping setting round trip', () async {
    final original = PingState()
      ..timeout = 8
      ..url = PingUrl.custom
      ..customUrl = 'https://example.com/ping'
      ..autoPingNewConfigs = true;

    await original.saveToPreferences();

    final restored = PingState();
    await restored.readFromPreferences();

    expect(restored.timeout, 8);
    expect(restored.url, PingUrl.custom);
    expect(restored.customUrl, 'https://example.com/ping');
    expect(restored.realUrl, 'https://example.com/ping');
    expect(restored.autoPingNewConfigs, isTrue);
  });

  test(
    'legacy custom URL is restored without an automatic ping field',
    () async {
      await PreferencesKey().savePingState({
        'timeout': 5,
        'url': 'Custom',
        'customUrl': 'https://legacy.example.com/ping',
      });

      final restored = PingState();
      await restored.readFromPreferences();

      expect(restored.url, PingUrl.custom);
      expect(restored.customUrl, 'https://legacy.example.com/ping');
      expect(restored.autoPingNewConfigs, isFalse);
    },
  );

  test('invalid legacy custom URLs are retained but not activated', () async {
    for (final customUrl in [
      'example.com/ping',
      'ftp://legacy.example.com/ping',
    ]) {
      await PreferencesKey().savePingState({
        'timeout': 5,
        'url': 'Custom',
        'customUrl': customUrl,
      });

      final restored = PingState();
      await restored.readFromPreferences();

      expect(restored.url, PingUrl.cloudflare, reason: customUrl);
      expect(restored.customUrl, customUrl, reason: customUrl);
      expect(restored.realUrl, PingUrl.cloudflare.url, reason: customUrl);
      expect(restored.autoPingNewConfigs, isFalse, reason: customUrl);
    }
  });
}
