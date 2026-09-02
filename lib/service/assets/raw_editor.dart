import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/preparation.dart';
import 'package:onexray/service/xray/raw/db.dart';
import 'package:onexray/service/xray/raw/validator.dart';
import 'package:path/path.dart' as p;

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
  final Future<bool> Function(String) _validate;
  final Future<ConnectionPlan> Function(
    ConnectionConfiguration,
    Future<void>,
    String,
  )?
  prepare;

  RawEditorService({
    AppDatabase? database,
    ConnectionCoordinator? coordinator,
    Future<bool> Function(String)? validate,
    this.prepare,
  }) : db = database ?? AppDatabase(),
       coordinator = coordinator ?? ConnectionCoordinator.instance,
       _validate =
           validate ??
           ((text) async => (await XrayRawValidator.validate(text)).isValid);

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
  }) async {
    final text = namedText(draft.name, draft.text);
    if (!await _validate(text)) {
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
    final plan = coordinator.state.value.plan;
    final running = plan?.configuration.connection;
    if (original != null &&
        running?.expert == true &&
        running?.rawId == original.id &&
        (!configuration.connection.expert ||
            configuration.connection.rawId != original.id)) {
      throw const RawEditorException('changed');
    }
    final selected =
        original != null &&
        configuration.connection.expert &&
        configuration.connection.rawId == original.id;
    var affectsRuntime = false;
    if (selected) {
      final options = _comparisonOptions(configuration, plan);
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
          coordinator.state.value.phase == ConnectionPhase.connected &&
          !await confirmReconnect()) {
        return null;
      }
    }
    var savedId = original?.id;
    await coordinator.apply(
      configuration,
      affectsRuntime: affectsRuntime,
      prepare: affectsRuntime
          ? (next, cancelled) =>
                prepare?.call(next, cancelled, text) ??
                ConnectionPreparation(db: db)
                    .prepare(next, cancelled: cancelled, rawDraft: text)
          : null,
      writeAssets: () async {
        if (original == null) {
          savedId = await db.coreConfigDao.insertAssetRow(
            XrayRawDb.configCompanion(draft.name, text),
          );
        } else {
          final current = await db.coreConfigDao.searchRow(original.id);
          if (current == null ||
              current.type != 'raw' ||
              current.data != original.data ||
              current.name != original.name) {
            throw const RawEditorException('changed');
          }
          final saved = current.copyWith(
            name: draft.name,
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

  static String namedText(String name, String text) {
    if (name.trim().isEmpty || name.length > 32) {
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

  RuntimeOptions _comparisonOptions(
    ConnectionConfiguration configuration,
    ConnectionPlan? plan,
  ) {
    final policy = configuration.policy;
    final request = plan?.request;
    return RuntimeOptions(
      platform: plan?.platform ?? connectionPlatform,
      assetDirectory: plan?.assetDirectory ?? VpnConstants.datDir,
      sessionDirectory: plan == null
          ? VpnConstants.runDir
          : p.dirname(plan.runtime.statePath),
      pingPort: int.tryParse(request?.pingPort ?? '') ?? 65533,
      metricsPort: int.tryParse(request?.metricsPort ?? '') ?? 65534,
      socksPort: int.tryParse(request?.socksPort ?? '') ?? 65535,
      pingAuth: request?.pingAuth ?? XrayInboundAccount('editor', 'editor'),
      ipv6: policy.ipv6Enabled,
      interfaceName: policy.xrayOutboundInterfaceName,
      logEnabled: policy.logEnabled,
      logLevel: policy.logLevel,
      dnsLog: policy.recordDns,
      maskAddress: policy.maskAddress,
    );
  }
}
