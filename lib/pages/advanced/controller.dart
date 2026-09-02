import 'dart:async';
import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/platform_policy.dart';

class AdvancedPageState {
  final PlatformPolicy? policy;
  final ConnectionView runtime;
  final String xrayVersion;
  final String uptime;
  final bool failed;

  const AdvancedPageState({
    this.policy,
    this.runtime = const ConnectionView(),
    this.xrayVersion = '—',
    this.uptime = '—',
    this.failed = false,
  });
}

/// P4 reads the new connection value only. Platform editing follows in P7.
class AdvancedController extends PageCubit<AdvancedPageState> {
  final ConnectionCoordinator coordinator;
  StreamSubscription<ConnectionStateData>? _subscription;
  PlatformPolicy? _policy;
  String _version = '—';
  bool _failed = false;

  AdvancedController({ConnectionCoordinator? coordinator})
    : coordinator = coordinator ?? ConnectionCoordinator.instance,
      super(const AdvancedPageState()) {
    this.coordinator.state.addListener(_publish);
    reload();
    _readVersion();
  }

  bool get showInterface => AppPlatform.isWindows || AppPlatform.isLinux;

  Future<void> reload() async {
    await _subscription?.cancel();
    if (!isPageActive) return;
    _subscription = coordinator.db.connectionStateDao.watch().listen(
      (row) {
        try {
          _policy = ConnectionConfiguration.fromJson(
            jsonDecode(row.settingsJson) as Map<String, dynamic>,
          ).policy;
          _failed = false;
        } catch (_) {
          _policy = null;
          _failed = true;
        }
        _publish();
      },
      onError: (Object _) {
        _policy = null;
        _failed = true;
        _publish();
      },
    );
  }

  Future<void> _readVersion() async {
    try {
      final version = await AppHostApi().xrayVersion();
      if (version.isNotEmpty) _version = version;
    } catch (_) {
      // Version lookup is optional; never display a fabricated version.
    }
    _publish();
  }

  void _publish() {
    final runtime = coordinator.state.value;
    final started = runtime.traffic?.startedAtMs;
    var uptime = '—';
    if (runtime.phase == ConnectionPhase.connected &&
        started != null &&
        started > 0) {
      final seconds =
          ((DateTime.now().millisecondsSinceEpoch - started) ~/ 1000).clamp(
            0,
            1 << 53,
          );
      uptime =
          '${seconds ~/ 3600}:'
          '${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:'
          '${(seconds % 60).toString().padLeft(2, '0')}';
    }
    emit(
      AdvancedPageState(
        policy: _policy,
        runtime: runtime,
        xrayVersion: _version,
        uptime: uptime,
        failed: _failed,
      ),
    );
  }

  String statusLabel(AppLocalizations l10n) => switch (state.runtime.phase) {
    ConnectionPhase.disconnected => l10n.prototypeDisconnected,
    ConnectionPhase.preparing ||
    ConnectionPhase.connecting => l10n.prototypeConnecting,
    ConnectionPhase.connected => l10n.prototypeConnected,
    ConnectionPhase.disconnecting => l10n.prototypeDisconnecting,
    ConnectionPhase.recovering => l10n.prototypeReconnecting,
    ConnectionPhase.failed => l10n.prototypeConnectionFailed,
  };

  @override
  Future<void> disposePageResources() async {
    coordinator.state.removeListener(_publish);
    await _subscription?.cancel();
  }
}
