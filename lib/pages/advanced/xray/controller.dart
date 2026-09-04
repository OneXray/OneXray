import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/controller.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/runtime_files.dart';
import 'package:onexray/service/xray/runtime_settings.dart';

class XrayRuntimeController extends ChangeNotifier {
  XrayRuntimeController({ConnectionCoordinator? coordinator})
    : coordinator = coordinator ?? ConnectionCoordinator.instance {
    reader = AdvancedController(coordinator: this.coordinator);
    _subscription = reader.stream.listen((_) {
      if (reader.state.runtime.runtime != null) {
        runtime = reader.state.runtime.runtime;
      }
      _changed();
    });
    load();
  }
  final ConnectionCoordinator coordinator;
  late final AdvancedController reader;
  late final StreamSubscription<AdvancedPageState> _subscription;
  ConnectionConfiguration? base;
  ConnectionRuntime? runtime;
  Map<String, dynamic> log = {};
  PingState ping = PingState();
  bool loading = true;
  bool failed = false;
  bool saving = false;
  bool _systemExtension = false;
  bool _disposed = false;
  bool get busy => saving;
  bool get runtimeBusy => reader.state.runtime.busy;
  bool get dirty =>
      base != null &&
      jsonEncode(log) != jsonEncode(base!.policy.toJson()['log']);
  bool get logsEnabled => log['enabled'] == true;
  bool get recordDns => log['recordDns'] == true;
  bool get maskIp => log['maskIp'] == true;
  String get level => log['level'] as String? ?? 'warning';
  bool get connected => reader.state.runtime.phase == ConnectionPhase.connected;
  String speedSummary(AppLocalizations l) =>
      '${l.prototypeSeconds(ping.timeout.round())} · ${ping.url == PingUrl.custom ? l.prototypeCustomUrl : ping.url.name}';
  String? logPath(bool access) =>
      RuntimeDiagnosticFiles.logPath(runtime, access: access);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool showLoading = true}) async {
    loading = showLoading;
    failed = false;
    _changed();
    try {
      final configuration = await coordinator.configuration;
      final currentRuntime = await coordinator.readCurrentRuntime();
      final systemExtension = await AppHostApi().useSystemExtension();
      final preferences = PingState();
      await preferences.readFromPreferences();
      if (_disposed) return;
      base = configuration;
      log = Map<String, dynamic>.from(
        configuration.policy.toJson()['log'] as Map,
      );
      _systemExtension = systemExtension;
      ping = preferences;
      runtime = reader.state.runtime.runtime ?? currentRuntime;
    } catch (_) {
      failed = true;
    } finally {
      loading = false;
      _changed();
    }
  }

  void setLog(String key, Object value) {
    if (busy) return;
    log = {...log, key: value};
    _changed();
  }

  void setLevel(String? value) {
    if (value != null) setLog('level', value);
  }

  void restoreDefaults() {
    if (busy) return;
    log = Map<String, dynamic>.from(
      PlatformPolicy.defaults().toJson()['log'] as Map,
    );
    _changed();
  }

  Future<void> save(BuildContext context) async {
    if (busy || runtimeBusy || !dirty || base == null) return;
    final l = AppLocalizations.of(context)!;
    saving = true;
    failed = false;
    _changed();
    try {
      final saved = await saveRuntimeLogPolicy(
        coordinator: coordinator,
        base: base!,
        log: log,
        confirmReconnect: () async =>
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l.prototypeSaveAndReconnect),
                content: Text(l.prototypeReconnectNotice),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.prototypeCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.prototypeSaveAndReconnect),
                  ),
                ],
              ),
            ) ==
            true,
      );
      if (saved && !_disposed) {
        await load(showLoading: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.prototypeSettingsSaved)));
        }
      }
    } catch (_) {
      failed = true;
    } finally {
      saving = false;
      _changed();
    }
  }

  void openLog(
    BuildContext context,
    bool access,
    void Function(BuildContext, LogFileViewerParams) open,
  ) {
    final path = logPath(access);
    if (path == null) return;
    final l = AppLocalizations.of(context)!;
    open(
      context,
      LogFileViewerParams(
        title: access ? l.prototypeAccessLog : l.prototypeErrorLog,
        path: path,
        systemExtension: _systemExtension,
        access: access,
      ),
    );
  }

  void openConfig(
    BuildContext context,
    void Function(BuildContext, ConfigFileViewerParams) open,
  ) {
    final current = runtime;
    if (current == null) return;
    open(
      context,
      ConfigFileViewerParams(
        AppLocalizations.of(context)!.prototypeRecentXrayConfiguration,
        '',
        text: current.xrayJson,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    unawaited(reader.close());
    super.dispose();
  }
}
