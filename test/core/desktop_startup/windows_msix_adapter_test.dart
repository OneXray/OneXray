import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/desktop_startup/windows_msix_adapter.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';

void main() {
  test('maps the packaged StartupTask state', () async {
    final adapter = WindowsMsixLaunchAtLoginAdapter(
      native: WindowsNativeApi.forTest((_) async {
        return jsonEncode({
          'success': true,
          'data': {'state': 'enabled'},
          'error': '',
        });
      }),
    );

    expect((await adapter.query()).state, LaunchAtLoginState.enabled);
  });

  test('preserves Windows user approval requirements', () async {
    String? request;
    final adapter = WindowsMsixLaunchAtLoginAdapter(
      native: WindowsNativeApi.forTest((value) async {
        request = value;
        return jsonEncode({
          'success': true,
          'data': {'state': 'requiresApproval'},
          'error': '',
        });
      }),
    );

    expect(
      (await adapter.setEnabled(true)).state,
      LaunchAtLoginState.requiresApproval,
    );
    expect((jsonDecode(request!)['payload'] as Map)['enabled'], isTrue);
  });

  test('preserves the native unavailable state', () async {
    final adapter = WindowsMsixLaunchAtLoginAdapter(
      native: WindowsNativeApi.forTest((_) async {
        return jsonEncode({
          'success': true,
          'data': {'state': 'unavailable'},
          'error': '',
        });
      }),
    );

    expect((await adapter.query()).state, LaunchAtLoginState.unavailable);
  });
}
