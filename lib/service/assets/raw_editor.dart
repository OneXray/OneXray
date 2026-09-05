import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/preparation.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/xray/raw/db.dart';
import 'package:onexray/service/xray/raw/validator.dart';

class RawEditorException implements Exception {
  final String reason;
  const RawEditorException(this.reason);
}

class RawEditorDraft {
  final CoreConfigData? original;
  final String name;
  final String text;
  const RawEditorDraft({this.original, required this.name, required this.text});
}

class RawEditorService {
  final AppDatabase db;
  final ConnectionCoordinator coordinator;
  final Future<bool> Function(String)? _validate;
  final Future<ConnectionRuntime> Function(
    ConnectionConfiguration,
    Future<void>,
    String,
  )?
  prepare;

  RawEditorService({
    AppDatabase? database,
    ConnectionCoordinator? coordinator,
    this._validate,
    this.prepare,
  }) : db = database ?? AppDatabase(),
       coordinator = coordinator ?? ConnectionCoordinator.instance;

  Future<RawEditorDraft> load(int? id) async {
    if (id == null) {
      return const RawEditorDraft(name: '', text: '{\n  "outbounds": []\n}');
    }
    final row = await db.coreConfigDao.searchRow(id);
    if (row == null || row.type != 'raw') {
      throw const RawEditorException('missing');
    }
    return RawEditorDraft(
      original: row,
      name: row.name,
      text: XrayRawDb.readFromDbData(row),
    );
  }

  /// Null means the user declined reconnection. No asset is written before it.
  Future<int?> save(
    RawEditorDraft draft, {
    required Future<bool> Function() confirmReconnect,
    GeoDataImportDraft? geodata,
  }) async {
    await geodata?.publish();
    try {
      final result = await _save(
        draft,
        confirmReconnect: confirmReconnect,
        geodata: geodata,
      );
      if (result == null) {
        await geodata?.rollback();
      } else {
        await geodata?.complete();
      }
      return result;
    } catch (error, stackTrace) {
      await geodata?.rollback();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<int?> _save(
    RawEditorDraft draft, {
    required Future<bool> Function() confirmReconnect,
    GeoDataImportDraft? geodata,
  }) async {
    final text = namedText(draft.name, draft.text);
    if (!await validate(text)) {
      throw const RawEditorException('invalid');
    }
    final original = draft.original;
    if (original == null &&
        (await db.coreConfigDao.allRawRowsWithData).length >= 3) {
      throw const RawEditorException('limit');
    }
    await coordinator.initialize();
    await coordinator.refresh();
    final configuration = await coordinator.configuration;
    final runtime = coordinator.state.value.runtime;
    if (original != null) _checkRunningRaw(original, configuration);
    final selected =
        original != null &&
        configuration.connection.expert &&
        configuration.connection.rawId == original.id;
    var affectsRuntime = false;
    var allowReconnect = false;
    if (selected) {
      final options = _comparisonOptions(configuration, runtime);
      try {
        affectsRuntime = !const DeepCollectionEquality().equals(
          ConnectionCompiler.rawSemanticJson(
            XrayRawDb.readFromDbData(original),
            options,
          ),
          ConnectionCompiler.rawSemanticJson(text, options),
        );
      } on FormatException {
        // A repaired old configuration cannot be classified as metadata-only.
        affectsRuntime = true;
      }
      if (affectsRuntime &&
          coordinator.state.value.phase == ConnectionPhase.connected) {
        allowReconnect = await confirmReconnect();
        if (!allowReconnect) return null;
      }
    }
    var savedId = original?.id;
    await coordinator.apply(
      configuration,
      expectedConfiguration: configuration.encode(),
      allowReconnect: allowReconnect,
      affectsRuntime: affectsRuntime,
      prepare: affectsRuntime
          ? (next, cancelled) =>
                prepare?.call(next, cancelled, text) ??
                ConnectionPreparation(db: db).prepare(
                  next,
                  cancelled: cancelled,
                  rawDraft: text,
                  onResolved: coordinator.reportResolvedNodes,
                )
          : null,
      writeAssets: () async {
        await geodata?.commit();
        if (original == null) {
          savedId = await db.coreConfigDao.insertAssetRow(
            XrayRawDb.configCompanion(draft.name.trim(), text),
          );
        } else {
          final current = await _checkOriginal(original);
          final saved = current.copyWith(
            name: draft.name.trim(),
            data: Value(base64Encode(utf8.encode(text))),
          );
          if (!await db.coreConfigDao.updateRow(saved)) {
            throw const RawEditorException('missing');
          }
        }
      },
    );
    return savedId;
  }

  Future<bool> delete(
    CoreConfigData original, {
    required Future<bool> Function(
      bool selected,
      bool reconnect,
      bool disconnect,
    )
    confirm,
  }) async {
    await _checkOriginal(original);
    await coordinator.initialize();
    await coordinator.refresh();
    final configuration = await coordinator.configuration;
    _checkRunningRaw(original, configuration);
    final connection = configuration.connection;
    final selected = connection.expert && connection.rawId == original.id;
    final connected =
        coordinator.state.value.phase == ConnectionPhase.connected;
    final servers =
        await (db.select(db.coreConfig)
              ..where((row) => row.type.equals('outbound'))
              ..limit(1))
            .get();
    final disconnect = selected && connected && servers.isEmpty;
    final reconnect = selected && connected && !disconnect;
    if (!await confirm(selected, reconnect, disconnect)) return false;
    await coordinator.apply(
      ConnectionConfiguration(
        connection: ConnectionSettings.fromJson({
          ...connection.toJson(),
          if (connection.rawId == original.id) ...{
            'expert': false,
            'rawId': null,
          },
        }),
        policy: configuration.policy,
      ),
      affectsRuntime: selected && !disconnect,
      disconnect: disconnect,
      allowReconnect: connected,
      expectedConfiguration: configuration.encode(),
      writeAssets: () async {
        _checkRunningRaw(original, configuration);
        await _checkOriginal(original);
        if (await db.coreConfigDao.deleteRow(original) != 1) {
          throw const RawEditorException('missing');
        }
      },
    );
    return true;
  }

  void _checkRunningRaw(
    CoreConfigData original,
    ConnectionConfiguration configuration,
  ) {
    final running = coordinator.state.value.runtime?.configuration.connection;
    if (running?.expert == true &&
        running?.rawId == original.id &&
        (!configuration.connection.expert ||
            configuration.connection.rawId != original.id)) {
      throw const RawEditorException('changed');
    }
  }

  Future<CoreConfigData> _checkOriginal(CoreConfigData original) async {
    final current = await db.coreConfigDao.searchRow(original.id);
    if (current == null ||
        current.type != 'raw' ||
        current.data != original.data ||
        current.name != original.name) {
      throw const RawEditorException('changed');
    }
    return current;
  }

  static String namedText(String name, String text) {
    name = name.trim();
    if (name.isEmpty || name.runes.length > 32) {
      throw const RawEditorException('name');
    }
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) {
      throw const RawEditorException('invalid');
    }
    if (json['name'] == name) {
      return text;
    }
    json['name'] = name;
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  Future<bool> validate(String text) => DataMaintenance.run(() async {
    if (_validate != null) return _validate(text);
    return (await XrayRawValidator.validate(text)).isValid;
  });

  RuntimeOptions _comparisonOptions(
    ConnectionConfiguration configuration,
    ConnectionRuntime? runtime,
  ) {
    final policy = configuration.policy;
    final request = runtime?.request;
    return RuntimeOptions(
      platform: runtime?.platform ?? connectionPlatform,
      sessionDirectory: VpnConstants.runDir,
      metricsPort: int.tryParse(request?.metricsPort ?? '') ?? 65534,
      socksPort: int.tryParse(request?.socksPort ?? '') ?? 65535,
      ipv6: policy.ipv6Enabled,
      interfaceName: policy.xrayOutboundInterfaceName,
      logEnabled: policy.logEnabled,
      logLevel: policy.logLevel,
      dnsLog: policy.recordDns,
      maskAddress: policy.maskAddress,
    );
  }
}
