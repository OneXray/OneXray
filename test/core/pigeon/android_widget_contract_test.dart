import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const native = 'android/app/src/main/kotlin/net/yuandev/onexray';
  const resources = 'android/app/src/main/res';

  test('widget shares native saved start and keeps an App fallback', () {
    final provider = File('$native/widget/TrafficWidgetProvider.kt')
        .readAsStringSync();
    expect(
      provider,
      contains('VpnController.buildShortcutStartIntent(context)'),
    );
    expect(provider, contains('PendingIntent.getActivity('));
    expect(provider, contains('PendingIntent.getBroadcast('));
    expect(provider, contains('VpnController.startSavedVpn(context)'));
    expect(provider, contains('openAppForStart(context)'));
    expect(provider, contains('PendingIntent.getService('));
    expect(provider, contains('OneVpnService.ACTION_STOP'));
    expect(provider, isNot(contains('VpnController.startVpn(')));
    expect(provider, isNot(contains('VpnController.readVpnRunning(')));
    expect(provider, isNot(contains('run/start.json')));
    expect(
      provider,
      contains('setPendingIntentCreatorBackgroundActivityStartMode'),
    );
    expect(provider, contains('creationOptions.toBundle()'));
    expect(provider, contains('null, sendOptions.toBundle())'));
    expect(provider, contains('busy -> null'));
    expect(provider, contains('"setEnabled", !busy'));
    expect(provider, contains('R.id.traffic_action_progress'));
    expect(
      provider,
      contains('context.resources.configuration.layoutDirection'),
    );
    for (final direction in ['download', 'upload']) {
      expect(
        provider,
        contains(
          'setTextViewText(R.id.traffic_${direction}_label, '
          'context.getString(R.string.traffic_$direction))',
        ),
      );
    }
  });

  test('service publishes disconnecting before releasing the core', () {
    final service = File('$native/vpn/OneVpnService.kt').readAsStringSync();
    final release = service.substring(
      service.indexOf('private fun releaseTun('),
    );
    final disconnecting = release.indexOf(
      'updateWidget(VpnStatus.DISCONNECTING)',
    );
    final stop = release.indexOf('stopXray()');
    final disconnected = release.indexOf(
      'updateWidget(VpnStatus.DISCONNECTED)',
    );
    expect(disconnecting, greaterThanOrEqualTo(0));
    expect(stop, greaterThan(disconnecting));
    expect(disconnected, greaterThan(stop));
  });

  test('widget has independent rates, session totals and a 48dp action', () {
    final layout = File('$resources/layout/traffic_widget.xml')
        .readAsStringSync();
    for (final id in [
      'traffic_download_speed',
      'traffic_upload_speed',
      'traffic_download_session',
      'traffic_upload_session',
      'traffic_action',
      'traffic_action_progress',
    ]) {
      expect(layout, contains('@+id/$id'));
    }
    expect(layout, contains('@drawable/traffic_app_icon'));
    expect(layout, contains('android:layout_height="48dp"'));
  });

  test('widget text is available in every supported system language', () {
    for (final locale in [
      'values',
      'values-zh',
      'values-b+zh+Hant',
      'values-ru',
      'values-fa',
    ]) {
      final strings = File('$resources/$locale/strings.xml').readAsStringSync();
      for (final key in [
        'notification_vpn_start_failed',
        'traffic_download',
        'traffic_upload',
        'traffic_session_value',
        'traffic_start_vpn',
        'traffic_stop_vpn',
        'traffic_widget_disconnected',
      ]) {
        expect(strings, contains('name="$key"'), reason: '$locale: $key');
      }
    }
  });
}
