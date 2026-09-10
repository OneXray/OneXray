import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/service/shared/menu/tray/service.dart')
      .readAsStringSync();
  final compact = source.replaceAll(RegExp(r'\s+'), ' ');

  test('independent quit is limited to macOS and Windows MSIX', () {
    expect(
      compact,
      contains(
        'bool get _canQuitWithoutStoppingVpn => AppPlatform.isMacOS || '
        '(AppPlatform.isWindows && windowsBuildMode == WindowsMode.msix);',
      ),
    );
    expect(
      compact,
      contains(
        'if (_canQuitWithoutStoppingVpn) { items.add( MenuItem( '
        'key: _TrayMenuKey.quitAndStopVpn.name, '
        'label: appLocalizationsNoContext().menuBarQuitAndStopVpn,',
      ),
    );
  });

  test('plain Quit stops only standalone Core before exiting', () {
    final action = compact
        .split('case _TrayMenuKey.quitApp:')[1]
        .split('case _TrayMenuKey.quitAndStopVpn:')[0];
    expect(
      action,
      contains(
        'if (!_canQuitWithoutStoppingVpn) { '
        'await ConnectionCoordinator.instance.disconnect(); } '
        'await ServicesBinding.instance.exitApplication(',
      ),
    );
  });

  test('Quit and Stop VPN waits for disconnect and keeps the failure path', () {
    final action = compact.split('case _TrayMenuKey.quitAndStopVpn:')[1];
    expect(
      action,
      contains(
        'await ConnectionCoordinator.instance.disconnect(); '
        'await ServicesBinding.instance.exitApplication(',
      ),
    );
    expect(action, contains('await _showMainWindow();'));
  });
}
