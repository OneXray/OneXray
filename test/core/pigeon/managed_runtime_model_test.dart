import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/model.dart';

void main() {
  test('runXray API 4 preserves the managed traffic endpoint and token', () {
    const runtime = ManagedRuntimeRequest(
      statePath: '/run/runtime.json',
      listen: '127.0.0.1:12003',
      token: 'fedcba9876543210fedcba9876543210',
    );
    final invoke = LibXrayInvokeRequest(
      method: LibXrayMethod.runXray,
      payload: RunXrayRequest('{}', runtime: runtime).toJson(),
    ).toJson();

    expect(invoke['apiVersion'], 4);
    expect(invoke['method'], 'runXray');
    final decoded = RunXrayRequest.fromJson(
      invoke['payload'] as Map<String, dynamic>,
    ).runtime!;
    expect(decoded.toJson(), {
      'statePath': runtime.statePath,
      'inboundTag': 'tunIn',
      'listen': runtime.listen,
      'token': runtime.token,
    });
  });

  test('optional managed endpoint fields are omitted when not supplied', () {
    const runtime = ManagedRuntimeRequest(statePath: '/run/runtime.json');
    expect(runtime.toJson(), {
      'statePath': runtime.statePath,
      'inboundTag': 'tunIn',
    });
  });
}
