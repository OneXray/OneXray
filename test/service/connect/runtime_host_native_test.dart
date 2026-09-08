import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/connect/runtime_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a successful native query must include its status', () async {
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.onexray.BridgeHostApi.readVpnStatus',
      BridgeHostApi.pigeonChannelCodec,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler(
      channel,
      (_) async => [
        NativeVpnCommandResult(state: NativeVpnCommandState.success),
      ],
    );
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    await expectLater(
      ConnectionRuntimeHost().inspect([]),
      throwsA(
        isA<ConnectionHostException>().having(
          (error) => error.reason,
          'reason',
          'nativeStatusFailed',
        ),
      ),
    );
    expect(AppFlutterApi().vpnStatusController.hasListener, false);
  }, skip: !(Platform.isMacOS || Platform.isIOS || Platform.isAndroid));

  test(
    'native status returns permission and state without a callback event',
    () async {
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.onexray.BridgeHostApi.readVpnStatus',
        BridgeHostApi.pigeonChannelCodec,
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final permission = PlatformPermissionResult(
        kind: PlatformPermissionKind.appleVpn,
        state: PlatformPermissionState.notRequired,
      );
      messenger.setMockDecodedMessageHandler(channel, (_) async {
        // A simulator state query can wait behind a libXray ping batch.
        await Future<void>.delayed(const Duration(seconds: 6));
        return [
          NativeVpnCommandResult(
            state: NativeVpnCommandState.success,
            status: VpnStatus.disconnected,
            permission: permission,
          ),
        ];
      });
      addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));

      // A disconnected result never reads a runtime file or database.
      final current = await ConnectionRuntimeHost().inspect([]);
      expect(current.status, VpnStatus.disconnected);
      expect(current.permission?.state, PlatformPermissionState.notRequired);
      expect(AppFlutterApi().vpnStatusController.hasListener, false);
    },
    skip: !(Platform.isMacOS || Platform.isIOS || Platform.isAndroid),
  );
}
