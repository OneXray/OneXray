import 'dart:convert';

import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/runtime_host.dart';

/// Only log policy is replaced; concurrently saved platform settings survive.
/// The coordinator owns validation, reconnect/rollback and the atomic commit.
Future<bool> saveRuntimeLogPolicy({
  required ConnectionCoordinator coordinator,
  required ConnectionConfiguration base,
  required Map<String, dynamic> log,
  required Future<bool> Function() confirmReconnect,
}) async {
  final current = await coordinator.configuration;
  if (jsonEncode(current.policy.toJson()['log']) !=
      jsonEncode(base.policy.toJson()['log'])) {
    throw const ConnectionHostException('configurationChanged');
  }
  if (jsonEncode(log) == jsonEncode(current.policy.toJson()['log'])) {
    return true;
  }
  final reconnect = coordinator.state.value.phase == ConnectionPhase.connected;
  if (reconnect && !await confirmReconnect()) return false;
  await coordinator.apply(
    ConnectionConfiguration(
      connection: current.connection,
      policy: PlatformPolicy.fromJson({...current.policy.toJson(), 'log': log}),
    ),
    expectedConfiguration: current.encode(),
    allowReconnect: reconnect,
  );
  return true;
}
