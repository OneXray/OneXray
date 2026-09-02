import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android tile uses the App shortcut instead of a saved plan', () {
    const native = 'android/app/src/main/kotlin/net/yuandev/onexray';
    final controller = File('$native/vpn/VpnController.kt').readAsStringSync();
    final tile = File(
      '$native/tile/OneQuickSettingsTileService.kt',
    ).readAsStringSync();
    final shortcut = File(
      'lib/service/menu/short_cut/service.dart',
    ).readAsStringSync();

    expect(controller, contains('getSystemService(ShortcutManager::class.java)'));
    expect(
      controller,
      contains('?.dynamicShortcuts?.firstOrNull { it.id == "startVpn" }'),
    );
    expect(controller, contains('?.intent?.let { Intent(it) }'));
    expect(
      controller,
      contains('shortcutIntent ?: Intent(context, MainActivity::class.java)'),
    );
    expect(controller, isNot(contains('EXTRA_ACTION')));
    expect(controller, isNot(contains('run/start.json')));
    expect(controller, isNot(contains('startVpnWithLastProfile')));
    expect(tile, contains('VpnController.buildShortcutStartIntent(this)'));
    expect(tile, isNot(contains('VpnController.startVpn(')));
    expect(tile, isNot(contains('hasStartSnapshot')));
    expect(shortcut, contains('type: _ShortCutKey.startVpn.name'));
    expect(shortcut, contains('ConnectionCoordinator.instance.connect()'));

    // The native stop path and Android 14 PendingIntent requirement stay intact.
    expect(tile, contains('VpnController.stopVpn(this)'));
    expect(tile, contains('startActivityAndCollapse(pendingIntent)'));
    expect(tile, contains('startActivityAndCollapse(intent)'));
  });
}
