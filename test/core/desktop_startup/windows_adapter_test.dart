import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/desktop_startup/windows_adapter.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';

void main() {
  test('maps the packaged StartupTask state', () async {
    final adapter = WindowsLaunchAtLoginAdapter(
      packageAvailable: true,
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
    final adapter = WindowsLaunchAtLoginAdapter(
      packageAvailable: true,
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

  test('is unavailable without package identity', () async {
    var invoked = false;
    final adapter = WindowsLaunchAtLoginAdapter(
      packageAvailable: false,
      native: WindowsNativeApi.forTest((_) async {
        invoked = true;
        throw StateError('must not invoke');
      }),
    );

    expect((await adapter.query()).state, LaunchAtLoginState.unavailable);
    expect(invoked, isFalse);
  });
}
