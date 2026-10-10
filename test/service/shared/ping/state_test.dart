import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/service/shared/ping/state.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesKey().clearUserDataPreferences();
  });

  test('location probes are disabled without preferences', () async {
    final state = PingState();

    await state.readFromPreferences();

    expect(state.locationEnabled, isFalse);
    expect(state.timeout, PingTimeout.defaultValue);
    expect(state.url, PingUrl.cloudflare);
  });

  test('custom ping URL is selectable and resolved', () {
    final state = PingState()
      ..url = PingUrl.custom
      ..customUrl = 'https://example.com/ping';

    expect(state.realUrl, 'https://example.com/ping');
  });

  test('ping URL validation accepts only absolute HTTP URLs', () {
    expect(PingUrl.isValidCustomUrl('https://example.com/ping'), isTrue);
    expect(PingUrl.isValidCustomUrl('HTTP://127.0.0.1:8080/ping'), isTrue);
    expect(PingUrl.isValidCustomUrl(''), isFalse);
    expect(PingUrl.isValidCustomUrl('example.com/ping'), isFalse);
    expect(PingUrl.isValidCustomUrl('ftp://example.com/ping'), isFalse);
  });

  test('custom URL round trips', () async {
    final original = PingState()
      ..timeout = 8
      ..url = PingUrl.custom
      ..customUrl = 'https://example.com/ping'
      ..locationEnabled = true;

    await original.saveToPreferences();

    final restored = PingState();
    await restored.readFromPreferences();

    expect(restored.timeout, 8);
    expect(restored.url, PingUrl.custom);
    expect(restored.customUrl, 'https://example.com/ping');
    expect(restored.realUrl, 'https://example.com/ping');
    expect(restored.locationEnabled, isTrue);

    restored.locationEnabled = false;
    await restored.saveToPreferences();
    final disabled = PingState();
    await disabled.readFromPreferences();
    expect(disabled.locationEnabled, isFalse);
    expect(disabled.realUrl, 'https://example.com/ping');
    expect(
      (await PreferencesKey().readPingState())!['locationEnabled'],
      isFalse,
    );
  });

  test(
    'legacy preferences retain the custom URL and disable location probes',
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
      expect(restored.locationEnabled, isFalse);
    },
  );

  test('null location preference restores as disabled', () async {
    await PreferencesKey().savePingState({
      'timeout': 8,
      'url': 'Google',
      'locationEnabled': null,
    });
    final restored = PingState()..locationEnabled = true;

    await restored.readFromPreferences();

    expect(restored.locationEnabled, isFalse);
    expect(restored.timeout, 8);
    expect(restored.url, PingUrl.google);
  });

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
    }
  });
}
