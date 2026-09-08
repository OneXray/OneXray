import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/shared/share/configuration_transfer.dart';

/// Shared transaction/reconnect boundary for Raw, custom-route and node editors.
/// Each editor still owns its format, semantic comparison and stale-row check.
extension ConnectionAssetEditing on ConnectionCoordinator {
  Future<ConnectionConfiguration> readForEditing() async {
    await initialize();
    await refresh();
    return configuration;
  }

  /// False means the user declined reconnection; no validation or write ran.
  Future<bool> saveEditedAsset(
    ConnectionConfiguration configuration, {
    required bool affectsRuntime,
    required Future<bool> Function() confirmReconnect,
    required Future<void> Function() writeAssets,
    Future<void> Function()? validateAssets,
    ConfigurationImportDraft? imported,
    PrepareConnection? prepare,
  }) async {
    final reconnect =
        affectsRuntime && state.value.phase == ConnectionPhase.connected;
    if (reconnect && !await confirmReconnect()) return false;
    await apply(
      configuration,
      expectedConfiguration: configuration.encode(),
      affectsRuntime: affectsRuntime,
      allowReconnect: reconnect,
      imported: imported,
      validateAssets: validateAssets,
      prepare: prepare,
      writeAssets: writeAssets,
    );
    return true;
  }
}
