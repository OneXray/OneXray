import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/preparation.dart';
import 'package:onexray/service/connection/resolver.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';

class ServerEditDraft {
  final CoreConfigData original;
  final String text;
  const ServerEditDraft(this.original, this.text);
}

class ServerRemoval {
  final Set<int> ids;
  final int? sourceId;
  final ConnectionConfiguration configuration;
  final String expectedConfiguration;
  final bool affectsRuntime;
  final bool disconnect;
  const ServerRemoval({
    required this.ids,
    this.sourceId,
    required this.configuration,
    required this.expectedConfiguration,
    required this.affectsRuntime,
    required this.disconnect,
  });
}

/// Asset changes use the same commit/rollback boundary as connection changes.
/// Candidate measurements and favorites never mutate the active runtime.
class ServerAssetService {
  final AppDatabase db;
  final ConnectionCoordinator coordinator;
  final Future<String> Function(String) _validate;
  final void Function(List<int>) _schedule;
  final Future<ConnectionRuntime> Function(
    ConnectionConfiguration,
    Future<void>,
    Map<int, ResolvedServer>,
    Set<int>,
  )?
  prepare;

  ServerAssetService({
    AppDatabase? database,
    ConnectionCoordinator? coordinator,
    Future<String> Function(String)? validate,
    void Function(List<int>)? schedule,
    this.prepare,
  }) : db = database ?? AppDatabase(),
       coordinator = coordinator ?? ConnectionCoordinator.instance,
       _validate = validate ?? AppHostApi().testXray,
       _schedule = schedule ?? PingService().schedulePingConfigIds;

  Stream<List<CoreConfigData>> watch() => (db.select(
    db.coreConfig,
  )..where((row) => row.type.equals('outbound'))).watch();

  Future<List<CoreConfigData>> rows() => (db.select(
    db.coreConfig,
  )..where((row) => row.type.equals('outbound'))).get();

  static bool measured(CoreConfigData row) =>
      row.delay != PingDelayConstants.unknown;

  static bool healthy(CoreConfigData row) =>
      PingDelayConstants.isSuccessful(row.delay);

  static bool selectable(CoreConfigData row) {
    if (measured(row) && !healthy(row)) return false;
    try {
      final outbound = ResolvedServer.fromRow(row).outbound;
      if (outboundString(outbound, 'protocol')?.isNotEmpty != true) {
        return false;
      }
      requireCanonicalOutbound(outbound);
      return true;
    } on FormatException {
      return false;
    }
  }

  static String protocolLabel(CoreConfigData row) {
    try {
      return outboundTags(readOutboundFromDbData(row))
          .split(',')
          .map((value) => value.trim().toUpperCase())
          .where((value) => value.isNotEmpty && value != 'NONE')
          .join(' | ');
    } on FormatException {
      return '';
    }
  }

  Future<ServerEditDraft> load(int id) async {
    final row = await db.coreConfigDao.searchRow(id);
    if (row == null || row.type != 'outbound') {
      throw const FormatException('Server no longer exists');
    }
    String text;
    try {
      text = const JsonEncoder.withIndent('  ')
          .convert(readOutboundFromDbData(row));
    } on FormatException {
      text = row.data == null ? '{}' : utf8.decode(base64Decode(row.data!));
    }
    return ServerEditDraft(row, text);
  }

  Future<bool> save(
    ServerEditDraft draft, {
    required Future<bool> Function() confirmReconnect,
  }) async {
    if (utf8.encode(draft.text).length > 16 * 1024 * 1024) {
      throw const FormatException('Server configuration is too large');
    }
    final outbound = jsonDecode(draft.text);
    if (outbound is! Map<String, dynamic>) {
      throw const FormatException('An outbound object is required');
    }
    requireCanonicalOutbound(outbound);
    if (outbound['tag'] is! String ||
        (outbound['tag'] as String).trim().isEmpty) {
      throw const FormatException('A server tag is required');
    }
    if ((await _validate(encodeSingleOutbound(outbound))).isNotEmpty) {
      throw const FormatException('Invalid server configuration');
    }
    await coordinator.initialize();
    await coordinator.refresh();
    final configuration = await coordinator.configuration;
    final original = draft.original;
    var semanticChange = true;
    try {
      semanticChange = !const DeepCollectionEquality().equals(
        {...readOutboundFromDbData(original)}..remove('tag'),
        {...outbound}..remove('tag'),
      );
    } on FormatException {
      // A repaired legacy row is not a metadata-only edit.
    }
    final active =
        coordinator.state.value.runtime?.nodeIds.contains(original.id) == true;
    final reconnect = active && semanticChange;
    final affectsRuntime = semanticChange && active;
    var allowReconnect = false;
    if (reconnect &&
        coordinator.state.value.phase == ConnectionPhase.connected) {
      allowReconnect = await confirmReconnect();
      if (!allowReconnect) return false;
    }
    final companion = outboundCompanion(outbound);
    final drafts = {
      original.id: ResolvedServer(
        id: original.id,
        sourceId: original.subId,
        outbound: outbound,
      ),
    };
    await coordinator.apply(
      configuration,
      expectedConfiguration: configuration.encode(),
      allowReconnect: allowReconnect,
      affectsRuntime: affectsRuntime,
      prepare: reconnect
          ? (next, cancelled) => _prepare(next, cancelled, drafts, const {})
          : null,
      writeAssets: () async {
        if (semanticChange &&
            !reconnect &&
            coordinator.state.value.runtime?.nodeIds.contains(original.id) ==
                true) {
          throw const FormatException('Server became active while editing');
        }
        final current = await db.coreConfigDao.searchRow(original.id);
        if (current == null ||
            current.type != 'outbound' ||
            current.data != original.data) {
          throw const FormatException('Server changed while editing');
        }
        await db.coreConfigDao.updateRow(
          current.copyWith(
            name: companion.name.value,
            tags: companion.tags.value,
            data: companion.data,
            delay: semanticChange ? PingDelayConstants.unknown : current.delay,
            countryCode: semanticChange
                ? const Value(null)
                : const Value.absent(),
          ),
        );
      },
    );
    if (semanticChange) _schedule([original.id]);
    return true;
  }

  Future<void> favorite(int id, bool value) => DataMaintenance.run(() async {
    await (db.update(db.coreConfig)
          ..where((row) => row.id.equals(id) & row.type.equals('outbound')))
        .write(CoreConfigCompanion(favorite: Value(value)));
  });

  Future<int> copyLocal(CoreConfigData row, String suffix) =>
      DataMaintenance.run(() async {
        final current = await db.coreConfigDao.searchRow(row.id);
        if (current == null || current.type != 'outbound') {
          throw const FormatException('Server no longer exists');
        }
        final outbound = readOutboundFromDbData(current);
        outbound['tag'] = '${outboundDisplayName(outbound)} · $suffix';
        final id = await db.coreConfigDao.insertAssetRow(
          outboundCompanion(outbound).copyWith(
            countryCode: Value(current.countryCode),
            favorite: const Value(false),
          ),
        );
        _schedule([id]);
        return id;
      });

  Future<ServerRemoval> previewRemoval({
    Set<int> ids = const {},
    int? sourceId,
  }) async {
    await coordinator.initialize();
    await coordinator.refresh();
    final all = await rows();
    final removed = sourceId == null
        ? ids
        : all
              .where((row) => row.subId == sourceId)
              .map((row) => row.id)
              .toSet();
    final remaining = all.where((row) => !removed.contains(row.id)).toList();
    final current = await coordinator.configuration;
    final selection = current.connection.selection;
    final invalidSelection = switch (selection.kind) {
      SelectionKind.automatic => false,
      SelectionKind.server => removed.contains(selection.id),
      SelectionKind.source =>
        selection.id == sourceId ||
            !remaining.any((row) => row.subId == selection.id),
      SelectionKind.region => !remaining.any(
        (row) =>
            row.countryCode?.toUpperCase() == selection.region?.toUpperCase(),
      ),
    };
    final next = ConnectionConfiguration(
      policy: current.policy,
      connection: ConnectionSettings.fromJson({
        ...current.connection.toJson(),
        if (invalidSelection)
          'selection': const ServerSelection.automatic().toJson(),
        'smart': {
          ...current.connection.smart.toJson(),
          if (removed.contains(current.connection.smart.finalExitId))
            'finalExitId': null,
        },
      }),
    );
    final active =
        coordinator.state.value.phase == ConnectionPhase.connected &&
        coordinator.state.value.runtime?.nodeIds.any(removed.contains) == true;
    return ServerRemoval(
      ids: Set.unmodifiable(removed),
      sourceId: sourceId,
      configuration: next,
      expectedConfiguration: current.encode(),
      affectsRuntime: active,
      disconnect:
          active &&
          !remaining.any(
            (row) => selectable(row) && row.id != next.connection.finalExitId,
          ),
    );
  }

  /// The UI confirms this preview before calling. A changed source aborts instead
  /// of removing servers not included in the confirmation.
  Future<void> remove(ServerRemoval preview) async {
    final refreshed = await previewRemoval(
      ids: preview.ids,
      sourceId: preview.sourceId,
    );
    if (!const SetEquality<int>().equals(preview.ids, refreshed.ids) ||
        refreshed.configuration.encode() != preview.configuration.encode() ||
        refreshed.expectedConfiguration != preview.expectedConfiguration ||
        refreshed.affectsRuntime != preview.affectsRuntime ||
        refreshed.disconnect != preview.disconnect) {
      throw const FormatException('Deletion preview changed');
    }
    await coordinator.apply(
      preview.configuration,
      expectedConfiguration: preview.expectedConfiguration,
      disconnect: preview.disconnect,
      allowReconnect: preview.affectsRuntime,
      affectsRuntime: preview.affectsRuntime && !preview.disconnect,
      prepare: preview.affectsRuntime && !preview.disconnect
          ? (next, cancelled) =>
                _prepare(next, cancelled, const {}, preview.ids)
          : null,
      writeAssets: () async {
        if (!preview.affectsRuntime &&
            coordinator.state.value.runtime?.nodeIds.any(
                  preview.ids.contains,
                ) ==
                true) {
          throw const FormatException('Server became active before deletion');
        }
        if (preview.sourceId case final id?) {
          final currentIds = (await rows())
              .where((row) => row.subId == id)
              .map((row) => row.id)
              .toSet();
          if (!const SetEquality<int>().equals(currentIds, preview.ids)) {
            throw const FormatException('Subscription changed before deletion');
          }
          await SubscriptionService().deleteSubscription(
            id,
            prepareDeletion: (_) async => true,
          );
        } else {
          await (db.delete(db.coreConfig)..where(
                (row) => row.id.isIn(preview.ids) & row.type.equals('outbound'),
              ))
              .go();
        }
      },
    );
  }

  Future<ConnectionRuntime> _prepare(
    ConnectionConfiguration next,
    Future<void> cancelled,
    Map<int, ResolvedServer> drafts,
    Set<int> removed,
  ) =>
      prepare?.call(next, cancelled, drafts, removed) ??
      ConnectionPreparation(
        db: db,
        resolver: ConnectionResolver(
          rows: () => watch().map(
            (rows) => rows.where((row) => !removed.contains(row.id)).toList(),
          ),
        ),
      ).prepare(
        next,
        cancelled: cancelled,
        serverDrafts: drafts,
        onResolved: coordinator.reportResolvedNodes,
      );
}
