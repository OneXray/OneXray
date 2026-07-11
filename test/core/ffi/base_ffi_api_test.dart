import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';

void main() {
  test('reports disconnected only after Core stops successfully', () async {
    final api = _TestFfiApi(stopResult: true);
    addTearDown(api.stopSharedIsolate);

    final result = await api.stopVpn();

    expect(result.state, NativeVpnCommandState.success);
    expect(api.statuses, [VpnStatus.disconnecting, VpnStatus.disconnected]);
  });

  test('restores connected state when Core stop fails', () async {
    final api = _TestFfiApi(stopResult: false);
    addTearDown(api.stopSharedIsolate);

    final result = await api.stopVpn();

    expect(result.state, NativeVpnCommandState.failed);
    expect(api.statuses, [VpnStatus.disconnecting, VpnStatus.connected]);
  });
}

final class _TestFfiApi extends BaseFfiApi {
  final bool stopResult;
  final List<VpnStatus> statuses = [];

  _TestFfiApi({required this.stopResult});

  @override
  Future<bool> stopCore() async => stopResult;

  @override
  Future<void> updateVpnStatus(VpnStatus status) async {
    statuses.add(status);
  }
}
