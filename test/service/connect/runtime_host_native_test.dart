import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/connect/runtime_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native status can wait for a core operation without losing its event',
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
        AppFlutterApi().vpnStatusChanged(VpnStatus.disconnected);
        return [
          NativeVpnCommandResult(
            state: NativeVpnCommandState.success,
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
