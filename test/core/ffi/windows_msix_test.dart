import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/windows/msix_ffi_api.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';

void main() {
  final token = 'vcore-session-v2:${'a' * 64}';
  String response(String status) => jsonEncode({
    'success': true,
    'error': '',
    'data': {
      'status': status,
      'snapshotToken': status == 'disconnected' ? null : token,
    },
  });

  test('status reads are pure and never return the last successful status on error', () async {
    var failQuery = false;
    final calls = <String>[];
    final api = WindowsMsixFfiApi(
      native: WindowsNativeApi.forTest((request) async {
        calls.add(jsonDecode(request)['method'] as String);
        if (failQuery) throw StateError('System query failed');
        return response('connected');
      }),
      readRequest: () async => throw StateError('No matching token'),
    );
    expect((await api.readVpnStatus()).status, VpnStatus.connected);
    failQuery = true;
    final failed = await api.readVpnStatus();
    expect(failed.state, NativeVpnCommandState.failed);
    expect(failed.status, isNull);
    expect(calls, ['getVpnStatus', 'getVpnStatus']);
  });

  test(
    'MSIX owns periodic notifications and cancels them on disposal',
    () async {
      var status = 'connected';
      var reads = 0;
      final disconnected = Completer<void>();
      final events = <VpnStatus>[];
      final api = WindowsMsixFfiApi(
        native: WindowsNativeApi.forTest((request) async {
          expect(jsonDecode(request)['method'], 'getVpnStatus');
          reads++;
          return response(status);
        }),
        readRequest: () async =>
            StartVpnRequest(null, null, null, null)..snapshotToken = token,
        notify: (value) async {
          events.add(value);
          if (value == VpnStatus.disconnected) disconnected.complete();
        },
        monitorInterval: const Duration(milliseconds: 10),
      );
      addTearDown(api.disposeVpnStatus);
      await api.observeVpnStatus();
      expect(events, [VpnStatus.connected]);
      status = 'disconnected';
      await disconnected.future.timeout(const Duration(seconds: 2));
      api.disposeVpnStatus();
      final stoppedReads = reads;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(reads, stoppedReads);
      expect(events, [VpnStatus.connected, VpnStatus.disconnected]);
    },
  );

  test(
    'restored stale sessions are stopped by monitoring, not by a read',
    () async {
      final calls = <String>[];
      final events = <VpnStatus>[];
      final api = WindowsMsixFfiApi(
        native: WindowsNativeApi.forTest((request) async {
          final method = jsonDecode(request)['method'] as String;
          calls.add(method);
          return response(method == 'stopVpn' ? 'disconnected' : 'connected');
        }),
        readRequest: () async => StartVpnRequest(null, null, null, null),
        notify: (status) async => events.add(status),
      );
      addTearDown(api.disposeVpnStatus);
      await api.readVpnStatus();
      expect(calls, ['getVpnStatus']);
      await api.observeVpnStatus();
      expect(calls, ['getVpnStatus', 'getVpnStatus', 'stopVpn']);
      expect(events, [VpnStatus.disconnecting, VpnStatus.disconnected]);
    },
  );

  test(
    'stop is confirmed internally and times out without inventing success',
    () async {
      var status = 'disconnecting';
      var reads = 0;
      final api = WindowsMsixFfiApi(
        native: WindowsNativeApi.forTest((request) async {
          if (jsonDecode(request)['method'] == 'getVpnStatus') reads++;
          return response(status);
        }),
        notify: (_) async {},
        confirmInterval: const Duration(milliseconds: 1),
        stopTimeout: const Duration(milliseconds: 5),
      );
      expect((await api.stopVpn()).state, NativeVpnCommandState.failed);
      expect(reads, greaterThan(0));
      status = 'disconnected';
      final result = await api.stopVpn();
      expect(result.state, NativeVpnCommandState.success);
      expect(result.status, VpnStatus.disconnected);
    },
  );
}
