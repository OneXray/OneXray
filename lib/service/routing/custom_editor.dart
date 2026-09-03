import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/preparation.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/routing/custom_service.dart';
import 'package:onexray/service/routing/custom_template.dart';

class CustomRoutingEditorException implements Exception {
  final String reason;
  const CustomRoutingEditorException(this.reason);
}

class CustomRoutingEditorDraft {
  final RoutingProfileData? original;
  final String name;
  final CustomRoutingTemplate template;
  const CustomRoutingEditorDraft({
    this.original,
    required this.name,
    required this.template,
  });
}

/// Draft editing never resolves servers. Only applying an active semantic change
/// asks the coordinator to prepare/start; its transaction owns the asset write.
class CustomRoutingEditorService {
  final AppDatabase db;
  final ConnectionCoordinator coordinator;
  final Future<ConnectionPlan> Function(
    ConnectionConfiguration,
    Future<void>,
    CustomRoutingTemplate,
  )?
  prepare;

  CustomRoutingEditorService({
    AppDatabase? database,
    ConnectionCoordinator? coordinator,
    this.prepare,
  }) : db = database ?? AppDatabase(),
       coordinator = coordinator ?? ConnectionCoordinator.instance;

  Future<CustomRoutingEditorDraft> load(int? id) async {
    if (id == null) {
      return CustomRoutingEditorDraft(
        name: '',
        template: CustomRoutingTemplate.parse(
          '{"outbounds":[{}, {"tag":"direct","protocol":"freedom"},'
          '{"tag":"block","protocol":"blackhole"}],"routing":{"rules":[]}}',
        ),
      );
    }
    final row = await db.routingProfileDao.searchRow(id);
    if (row == null) throw const CustomRoutingEditorException('missing');
    return CustomRoutingEditorDraft(
      original: row,
      name: row.name,
      template: CustomRoutingService.read(row),
    );
  }

  Future<List<RoutingProfileData>> get rows => db.routingProfileDao.allRows;

  Future<int?> save(
    CustomRoutingEditorDraft draft, {
    required Future<bool> Function() confirmReconnect,
    GeoDataImportDraft? geodata,
  }) async {
    final name = draft.name.trim();
    if (name.isEmpty || name.runes.length > 32) {
      throw const CustomRoutingEditorException('name');
    }
    final template = CustomRoutingTemplate.parse(
      jsonEncode({...draft.template.toJson(), 'name': name}),
    );
    if (draft.template.assets.isNotEmpty) {
      throw const CustomRoutingEditorException('assets');
    }
    final original = draft.original;
    await _checkName(name, original?.id);
    if (original != null) await _checkOriginal(original);
    if (original == null && (await rows).length >= 3) {
      throw const CustomRoutingEditorException('limit');
    }
    await coordinator.initialize();
    await coordinator.refresh();
    final configuration = await coordinator.configuration;
    final connection = configuration.connection;
    final selected = original != null && _selects(connection, original.id);
    final running = coordinator.state.value.plan?.configuration.connection;
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
        !sameRouting(CustomRoutingService.read(original), template);
    var allowReconnect = false;
    if (affectsRuntime &&
        coordinator.state.value.phase == ConnectionPhase.connected) {
      allowReconnect = await confirmReconnect();
      if (!allowReconnect) return null;
    }
    await _checkConfiguration(configuration);
    int? savedId = original?.id;
    await coordinator.apply(
      configuration,
      affectsRuntime: affectsRuntime,
      allowReconnect: allowReconnect,
      expectedConfiguration: configuration.encode(),
      prepare: affectsRuntime
          ? (next, cancelled) =>
                prepare?.call(next, cancelled, template) ??
                ConnectionPreparation(db: db).prepare(
                  next,
                  cancelled: cancelled,
                  customDraft: template,
                  prepareAssets: geodata?.copyFilesTo,
                  onResolved: coordinator.reportResolvedNodes,
                )
          : null,
      writeAssets: () async {
        await _checkConfiguration(configuration);
        await _checkName(name, original?.id);
        if (original != null) await _checkOriginal(original);
        await geodata?.commit();
        savedId = await CustomRoutingService(db)
            .save(id: original?.id, name: name, text: template.encode());
      },
    );
    return savedId;
  }

  Future<bool> delete(
    RoutingProfileData original, {
    required Future<bool> Function(bool selected, bool reconnect) confirm,
  }) async {
    await _checkOriginal(original);
    await coordinator.initialize();
    await coordinator.refresh();
    final configuration = await coordinator.configuration;
    final connection = configuration.connection;
    final selected = _selects(connection, original.id);
    final running = coordinator.state.value.plan?.configuration.connection;
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
    await _checkConfiguration(configuration);
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
        await _checkConfiguration(configuration);
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

  Future<void> _checkConfiguration(ConnectionConfiguration expected) async {
    if ((await coordinator.configuration).encode() != expected.encode()) {
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
    CustomRoutingTemplate before,
    CustomRoutingTemplate after,
  ) {
    Object semantic(CustomRoutingTemplate template) => {
      'entries': template.entryCount,
      'strategy': template.domainStrategy,
      'rules': [
        for (final rule in template.rules)
          {...rule}
            ..remove('ruleTag')
            ..remove('type'),
      ],
    };
    return const DeepCollectionEquality().equals(
      semantic(before),
      semantic(after),
    );
  }
}
