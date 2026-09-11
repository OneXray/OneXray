import 'package:collection/collection.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/asset_edit.dart';
import 'package:onexray/service/connect/preparation.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/shared/share/configuration_transfer.dart';
import 'package:onexray/service/connect/routing/custom/service.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';

class CustomRoutingEditorException extends AppFailure {
  final String reason;
  const CustomRoutingEditorException(this.reason)
    : super(
        reason == 'changed' || reason == 'missing'
            ? FailureCategory.conflict
            : FailureCategory.input,
        reason,
      );
}

class CustomRoutingEditorDraft {
  final RoutingProfileData? original;
  final RoutingProfileState state;
  const CustomRoutingEditorDraft({this.original, required this.state});
}

/// Draft editing never resolves servers. Only applying an active semantic change
/// asks the coordinator to prepare/start; its transaction owns the asset write.
class CustomRoutingEditorService {
  final AppDatabase db;
  final ConnectionCoordinator coordinator;
  final Future<String> Function(String)? testXray;
  final Future<ConnectionRuntime> Function(
    ConnectionConfiguration,
    Future<void>,
    RoutingProfileState,
  )?
  prepare;

  CustomRoutingEditorService({
    AppDatabase? database,
    ConnectionCoordinator? coordinator,
    this.testXray,
    this.prepare,
  }) : db = database ?? AppDatabase(),
       coordinator = coordinator ?? ConnectionCoordinator.instance;

  Future<CustomRoutingEditorDraft> load(int? id) async {
    if (id == null) {
      return CustomRoutingEditorDraft(state: RoutingProfileState(name: ''));
    }
    final row = await db.routingProfileDao.searchRow(id);
    if (row == null) throw const CustomRoutingEditorException('missing');
    return CustomRoutingEditorDraft(
      original: row,
      state: CustomRoutingService.read(row),
    );
  }

  Future<List<RoutingProfileData>> get rows => db.routingProfileDao.allRows;

  Future<int?> save(
    CustomRoutingEditorDraft draft, {
    required Future<bool> Function() confirmReconnect,
    ConfigurationImportDraft? imported,
  }) async {
    final name = draft.state.name.trim();
    if (name.isEmpty || name.runes.length > 32) {
      throw const CustomRoutingEditorException('name');
    }
    final original = draft.original;
    final state = draft.state.copyWith(
      id: original?.id,
      clearId: original == null,
      name: name,
    );
    state.validate();
    await _checkName(name, original?.id);
    if (original != null) await _checkOriginal(original);
    if (original == null && (await rows).length >= 3) {
      throw const CustomRoutingEditorException('limit');
    }
    final configuration = await coordinator.readForEditing();
    final connection = configuration.connection;
    final selected = original != null && _selects(connection, original.id);
    final running = coordinator.state.value.runtime?.configuration.connection;
    if (original != null &&
        running != null &&
        !running.expert &&
        _selects(running, original.id) &&
        (!selected || connection.expert)) {
      throw const CustomRoutingEditorException('changed');
    }
    final affectsRuntime =
        selected &&
        !connection.expert &&
        !sameRouting(CustomRoutingService.read(original), state);
    int? savedId = original?.id;
    final saved = await coordinator.saveEditedAsset(
      configuration,
      confirmReconnect: confirmReconnect,
      imported: imported,
      validateAssets: () =>
          CustomRoutingService.validate(state, testXray: testXray),
      affectsRuntime: affectsRuntime,
      prepare: affectsRuntime
          ? (next, cancelled) =>
                prepare?.call(next, cancelled, state) ??
                ConnectionPreparation(db: db).prepare(
                  next,
                  cancelled: cancelled,
                  customDraft: state,
                  onResolved: coordinator.reportResolvedNodes,
                )
          : null,
      writeAssets: () async {
        await _checkName(name, original?.id);
        if (original != null) await _checkOriginal(original);
        savedId = await CustomRoutingService(db).save(state);
      },
    );
    return saved ? savedId : null;
  }

  Future<bool> delete(
    RoutingProfileData original, {
    required Future<bool> Function(bool selected, bool reconnect) confirm,
  }) async {
    await _checkOriginal(original);
    final configuration = await coordinator.readForEditing();
    final connection = configuration.connection;
    final selected = _selects(connection, original.id);
    final running = coordinator.state.value.runtime?.configuration.connection;
    if (running != null &&
        !running.expert &&
        _selects(running, original.id) &&
        (!selected || connection.expert)) {
      throw const CustomRoutingEditorException('changed');
    }
    final affectsRuntime = selected && !connection.expert;
    final reconnect =
        affectsRuntime &&
        coordinator.state.value.phase == ConnectionPhase.connected;
    if (!await confirm(selected, reconnect)) return false;
    final next = selected
        ? ConnectionConfiguration(
            connection: ConnectionSettings.fromJson({
              ...connection.toJson(),
              'trafficMode': TrafficMode.smart.name,
              'customId': null,
            }),
            policy: configuration.policy,
          )
        : configuration;
    await coordinator.apply(
      next,
      affectsRuntime: affectsRuntime,
      allowReconnect: reconnect,
      expectedConfiguration: configuration.encode(),
      writeAssets: () async {
        await _checkOriginal(original);
        if (await db.routingProfileDao.deleteRow(original.id) != 1) {
          throw const CustomRoutingEditorException('missing');
        }
      },
    );
    return true;
  }

  Future<void> _checkOriginal(RoutingProfileData original) async {
    final current = await db.routingProfileDao.searchRow(original.id);
    if (current == null ||
        current.data != original.data ||
        current.name != original.name) {
      throw const CustomRoutingEditorException('changed');
    }
  }

  Future<void> _checkName(String name, int? id) async {
    if ((await rows).any(
      (row) =>
          row.id != id && row.name.trim().toLowerCase() == name.toLowerCase(),
    )) {
      throw const CustomRoutingEditorException('duplicate');
    }
  }

  static bool _selects(ConnectionSettings value, int id) =>
      value.trafficMode == TrafficMode.custom && value.customId == id;

  static bool sameRouting(
    RoutingProfileState before,
    RoutingProfileState after,
  ) {
    Object semantic(RoutingProfileState state) => {
      'entries': state.entryCount,
      'directDnsAddress': state.directDnsAddress.trim(),
      'rules': [
        for (final rule in state.rules) {...rule.toJson()}..remove('ruleTag'),
      ],
    };
    return const DeepCollectionEquality().equals(
      semantic(before),
      semantic(after),
    );
  }
}
