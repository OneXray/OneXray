import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/failure.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';

Future<bool> runConnectionAction(
  BuildContext context,
  ConnectionCoordinator coordinator,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    if (connectionFailureReason(error) != 'cancelled' &&
        coordinator.state.value.issue != 'cancelled' &&
        context.mounted) {
      final l = AppLocalizations.of(context)!;
      ContextAlert.showToast(
        context,
        connectionFailureMessage(l, error: error),
      );
    }
    return false;
  }
}

Future<ConnectionConfiguration?> applyConnectionChange(
  BuildContext context,
  ConnectionCoordinator coordinator,
  Map<String, dynamic> values, {
  required String Function(ConnectionSettings) label,
  Future<void> Function()? writeAssets,
}) async {
  final current = await coordinator.configuration;
  final next = ConnectionConfiguration(
    connection: ConnectionSettings.fromJson({
      ...current.connection.toJson(),
      ...values,
    }),
    policy: current.policy,
  );
  if (next.encode() == current.encode() && writeAssets == null) return current;
  if (!context.mounted) return null;
  final reconnect = coordinator.state.value.phase == ConnectionPhase.connected;
  if (reconnect &&
      !await showApplyAndReconnectDialog(
        context,
        label: label(next.connection),
      )) {
    return null;
  }
  if (!context.mounted) return null;
  ConnectionConfiguration? saved;
  await runConnectionAction(context, coordinator, () async {
    await coordinator.apply(
      next,
      writeAssets: writeAssets,
      expectedConfiguration: current.encode(),
      allowReconnect: reconnect,
    );
    saved = await coordinator.configuration;
  });
  return saved;
}
