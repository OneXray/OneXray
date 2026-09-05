import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/controller.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/runtime_files.dart';
import 'package:onexray/service/xray/runtime_settings.dart';

const _notProvided = Object();

@immutable
class XrayRuntimePageState {
  final ConnectionConfiguration? base;
  final ConnectionRuntime? runtime;
  final ConnectionView connection;
  final Map<String, dynamic> log;
  final double pingTimeout;
  final PingUrl pingUrl;
  final String xrayVersion;
  final String uptime;
  final bool loading;
  final bool failed;
  final bool saving;
  final bool systemExtension;

  XrayRuntimePageState({
    this.base,
    this.runtime,
    this.connection = const ConnectionView(),
    Map<String, dynamic> log = const {},
    this.pingTimeout = PingTimeout.defaultValue,
    this.pingUrl = PingUrl.cloudflare,
    this.xrayVersion = '—',
    this.uptime = '—',
    this.loading = true,
    this.failed = false,
    this.saving = false,
    this.systemExtension = false,
  }) : log = Map<String, dynamic>.unmodifiable(log);

  XrayRuntimePageState copyWith({
    Object? base = _notProvided,
    Object? runtime = _notProvided,
    ConnectionView? connection,
    Map<String, dynamic>? log,
    double? pingTimeout,
    PingUrl? pingUrl,
    String? xrayVersion,
    String? uptime,
    bool? loading,
    bool? failed,
    bool? saving,
    bool? systemExtension,
  }) => XrayRuntimePageState(
    base: identical(base, _notProvided)
        ? this.base
        : base as ConnectionConfiguration?,
    runtime: identical(runtime, _notProvided)
        ? this.runtime
        : runtime as ConnectionRuntime?,
    connection: connection ?? this.connection,
    log: log ?? this.log,
    pingTimeout: pingTimeout ?? this.pingTimeout,
    pingUrl: pingUrl ?? this.pingUrl,
    xrayVersion: xrayVersion ?? this.xrayVersion,
    uptime: uptime ?? this.uptime,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    saving: saving ?? this.saving,
    systemExtension: systemExtension ?? this.systemExtension,
  );
}

class XrayRuntimeController extends PageCubit<XrayRuntimePageState> {
  XrayRuntimeController({ConnectionCoordinator? coordinator})
    : this._(coordinator ?? ConnectionCoordinator.instance);

  XrayRuntimeController._(this.coordinator)
    : reader = AdvancedController(coordinator: coordinator),
      super(XrayRuntimePageState()) {
    _subscription = reader.stream.listen(_advancedChanged);
    _advancedChanged(reader.state);
    load();
  }
  final ConnectionCoordinator coordinator;
  final AdvancedController reader;
  late final StreamSubscription<AdvancedPageState> _subscription;

  ConnectionConfiguration? get base => state.base;
  ConnectionRuntime? get runtime => state.runtime;
  Map<String, dynamic> get log => state.log;
  bool get loading => state.loading;
  bool get failed => state.failed;
  bool get saving => state.saving;
  String get xrayVersion => state.xrayVersion;
  String get uptime => state.uptime;
  bool get busy => state.saving;
  bool get runtimeBusy => state.connection.busy;
  bool get dirty =>
      base != null &&
      jsonEncode(log) != jsonEncode(base!.policy.toJson()['log']);
  bool get logsEnabled => log['enabled'] == true;
  bool get recordDns => log['recordDns'] == true;
  bool get maskIp => log['maskIp'] == true;
  String get level => log['level'] as String? ?? 'warning';
  bool get connected => state.connection.phase == ConnectionPhase.connected;
  String speedSummary(AppLocalizations l) =>
      '${l.prototypeSeconds(state.pingTimeout.round())} · ${state.pingUrl == PingUrl.custom ? l.prototypeCustomUrl : state.pingUrl.name}';
  String statusLabel(AppLocalizations l) => switch (state.connection.phase) {
    ConnectionPhase.disconnected => l.prototypeDisconnected,
    ConnectionPhase.preparing ||
    ConnectionPhase.connecting => l.prototypeConnecting,
    ConnectionPhase.connected => l.prototypeConnected,
    ConnectionPhase.disconnecting => l.prototypeDisconnecting,
    ConnectionPhase.failed => l.prototypeConnectionFailed,
  };
  String? logPath(bool access) => state.systemExtension
      ? null
      : RuntimeDiagnosticFiles.logPath(runtime, access: access);

  void _advancedChanged(AdvancedPageState advanced) {
    emit(
      state.copyWith(
        connection: advanced.runtime,
        runtime: advanced.runtime.runtime ?? state.runtime,
        xrayVersion: advanced.xrayVersion,
        uptime: advanced.uptime,
      ),
    );
  }

  Future<void> load({bool showLoading = true}) async {
    emit(state.copyWith(loading: showLoading, failed: false));
    try {
      final configuration = await coordinator.configuration;
      final currentRuntime = await coordinator.readCurrentRuntime();
      final systemExtension = await AppHostApi().useSystemExtension();
      final preferences = PingState();
      await preferences.readFromPreferences();
      emit(
        state.copyWith(
          base: configuration,
          log: Map<String, dynamic>.from(
            configuration.policy.toJson()['log'] as Map,
          ),
          systemExtension: systemExtension,
          pingTimeout: preferences.timeout,
          pingUrl: preferences.url,
          runtime: reader.state.runtime.runtime ?? currentRuntime,
        ),
      );
    } catch (_) {
      emit(state.copyWith(failed: true));
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  void setLog(String key, Object value) {
    if (busy || state.systemExtension) return;
    emit(state.copyWith(log: {...log, key: value}));
  }

  void setLevel(String? value) {
    if (value != null) setLog('level', value);
  }

  void restoreDefaults() {
    if (busy || state.systemExtension) return;
    emit(
      state.copyWith(
        log: Map<String, dynamic>.from(
          PlatformPolicy.defaults().toJson()['log'] as Map,
        ),
      ),
    );
  }

  Future<void> save(BuildContext context) async {
    if (busy ||
        runtimeBusy ||
        state.systemExtension ||
        !dirty ||
        base == null) {
      return;
    }
    final l = AppLocalizations.of(context)!;
    emit(state.copyWith(saving: true, failed: false));
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
      if (saved && isPageActive) {
        await load(showLoading: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.prototypeSettingsSaved)));
        }
      }
    } catch (_) {
      emit(state.copyWith(failed: true));
    } finally {
      emit(state.copyWith(saving: false));
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
  Future<void> disposePageResources() async {
    await _subscription.cancel();
    await reader.close();
  }
}
