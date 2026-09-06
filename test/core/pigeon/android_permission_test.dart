import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const queryChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.onexray.BridgeHostApi.queryPlatformPermission',
    BridgeHostApi.pigeonChannelCodec,
  );
  const requestChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.onexray.BridgeHostApi.requestPlatformPermission',
    BridgeHostApi.pigeonChannelCodec,
  );
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final missing = PlatformPermissionResult(
    kind: PlatformPermissionKind.androidLocalNetwork,
    state: PlatformPermissionState.notDetermined,
  );
  final granted = PlatformPermissionResult(
    kind: PlatformPermissionKind.androidVpn,
    state: PlatformPermissionState.granted,
  );

  test('Android startup queries include the API 37 local network grant', () {
    final native = File(
      'android/app/src/main/kotlin/net/yuandev/onexray/pigeon/HostApi.kt',
    ).readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android.permission.ACCESS_LOCAL_NETWORK'));
    expect(
      native,
      contains('Build.VERSION.SDK_INT >= Build.VERSION_CODES.CINNAMON_BUN'),
    );
    expect(
      native,
      contains(
        'context.checkSelfPermission(Manifest.permission.ACCESS_LOCAL_NETWORK)',
      ),
    );
    expect(native, contains('PlatformPermissionKind.ANDROID_LOCAL_NETWORK'));
    expect(native, contains('callback?.invoke(queryPermissionNow())'));
  });

  group('Android permission bridge', () {
    late List<String> calls;
    late PlatformPermissionResult current;
    late int status;
    late int requestedStatus;

    setUp(() {
      calls = [];
      current = missing;
      status = 0;
      requestedStatus = 1;
      messenger.setMockDecodedMessageHandler(queryChannel, (_) async {
        calls.add('query');
        return [current];
      });
      messenger.setMockDecodedMessageHandler(requestChannel, (_) async {
        calls.add('vpn');
        return [current];
      });
      messenger.setMockMethodCallHandler(permissions, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'checkPermissionStatus':
            expect(call.arguments, 40);
            return status;
          case 'requestPermissions':
            expect(call.arguments, [40]);
            if (requestedStatus == 1) current = granted;
            return {40: requestedStatus};
          case 'openAppSettings':
            return true;
          default:
            fail('Unexpected permission call: ${call.method}');
        }
      });
    });

    tearDown(() {
      messenger.setMockDecodedMessageHandler(queryChannel, null);
      messenger.setMockDecodedMessageHandler(requestChannel, null);
      messenger.setMockMethodCallHandler(permissions, null);
    });

    test('startup only checks and never requests permission', () async {
      final result = await AppHostApi().queryPlatformPermission();
      expect(result.kind, PlatformPermissionKind.androidLocalNetwork);
      expect(result.state, PlatformPermissionState.notDetermined);
      expect(calls, ['query']);
    });

    test(
      'VPN authorization is followed by local network authorization',
      () async {
        final result = await AppHostApi().requestPlatformPermission();
        expect(result.state, PlatformPermissionState.granted);
        expect(calls, [
          'vpn',
          'checkPermissionStatus',
          'requestPermissions',
          'query',
        ]);
      },
    );

    test('denial retains the local network permission requirement', () async {
      requestedStatus = 0;
      final result = await AppHostApi().requestPlatformPermission();
      expect(result.kind, PlatformPermissionKind.androidLocalNetwork);
      expect(result.state, PlatformPermissionState.denied);
      expect(calls, ['vpn', 'checkPermissionStatus', 'requestPermissions']);
    });

    test(
      'permanent denial opens settings without another permission prompt',
      () async {
        status = 4;
        final result = await AppHostApi().requestPlatformPermission();
        expect(result.kind, PlatformPermissionKind.androidLocalNetwork);
        expect(result.state, PlatformPermissionState.notDetermined);
        expect(calls, ['vpn', 'checkPermissionStatus', 'openAppSettings']);
      },
    );

    test(
      'a ready platform does not request local network permission',
      () async {
        current = granted;
        final result = await AppHostApi().requestPlatformPermission();
        expect(result.state, PlatformPermissionState.granted);
        expect(calls, ['vpn']);
      },
    );
  }, skip: Platform.isLinux || Platform.isWindows);
}
