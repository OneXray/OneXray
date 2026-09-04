import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/preparation.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/ping/state.dart';
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

class RawTestResult {
  final int delay;
  final String url;
  final int timeout;
  const RawTestResult(this.delay, this.url, this.timeout);
}

class RawEditorService {
  final AppDatabase db;
  final ConnectionCoordinator coordinator;
  final Future<bool> Function(String)? _validate;
  final Future<ConnectionPlan> Function(
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
    final text = namedText(draft.name, draft.text);
    if (!await validate(text, geodata: geodata)) {
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
    var allowReconnect = false;
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
                  prepareAssets: geodata?.copyFilesTo,
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
          final current = await db.coreConfigDao.searchRow(original.id);
          if (current == null ||
              current.type != 'raw' ||
              current.data != original.data ||
              current.name != original.name) {
            throw const RawEditorException('changed');
          }
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

  Future<bool> validate(String text, {GeoDataImportDraft? geodata}) async {
    if (_validate != null) return _validate(text);
    final directory = Directory(
      p.join(VpnConstants.runDir, 'drafts', newPlanId()),
    );
    await directory.create(recursive: true);
    try {
      await GeoDataService().copyPublishedTo(directory.path);
      await geodata?.copyFilesTo(directory.path);
      return (await XrayRawValidator.validate(
        text,
        assetDirectory: directory.path,
      )).isValid;
    } finally {
      await directory.delete(recursive: true);
    }
  }

  /// Test the draft's actual routing/DNS path to the configured test URL in an
  /// isolated native instance. Never publish the draft or start the VPN host.
  Future<RawTestResult> test(
    RawEditorDraft draft, {
    GeoDataImportDraft? geodata,
  }) async {
    final text = draft.text;
    final configuration = await coordinator.configuration;
    final input = ConnectionConfiguration(
      connection: ConnectionSettings.fromJson({
        ...configuration.connection.toJson(),
        'expert': true,
        'rawId': draft.original?.id,
      }),
      policy: configuration.policy,
    );
    final plan = await ConnectionPreparation(db: db)
        .prepare(input, rawDraft: text, prepareAssets: geodata?.copyFilesTo);
    try {
      final settings = PingState();
      await settings.readFromPreferences();
      final timeout = settings.timeout.toInt();
      final delay = await AppHostApi().probeXray(
        plan.xrayJson,
        url: settings.realUrl,
        timeout: timeout,
      );
      return RawTestResult(delay, settings.realUrl, timeout);
    } finally {
      await Directory(p.join(VpnConstants.runDir, 'plans', plan.id))
          .delete(recursive: true);
    }
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
