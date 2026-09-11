import 'dart:async';
import 'dart:io';

import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/desktop_core_exit.dart';
import 'package:onexray/core/ffi/windows/core_process.dart';
import 'package:onexray/core/ffi/windows/ffi_api.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as p;

class WindowsExeFfiApi extends WindowsFfiApi {
  final WindowsCoreProcess _process;
  final String? _filesDirectory;
  final String _corePath;
  final Future<StartVpnRequest> Function() _readRequest;
  final Future<void> Function(VpnStatus) _notify;
  final void Function(Object) _notifyError;
  final _exitWatches = <int, DesktopCoreExitWatch>{};
  // Cancelling waits also invalidates the reads already triggered by their exits.
  int _watchGeneration = 0;
  int _queryGeneration = 0;
  bool _observing = false;
  VpnStatus? _transition;

  WindowsExeFfiApi({
    WindowsCoreProcess? process,
    this._filesDirectory,
    String? executable,
    Future<StartVpnRequest> Function()? readRequest,
    Future<void> Function(VpnStatus)? notify,
    void Function(Object)? notifyError,
  }) : _process = process ?? WindowsCoreProcess(),
       _corePath =
           executable ??
           p.join(p.dirname(Platform.resolvedExecutable), 'OneXrayCore.exe'),
       _readRequest = readRequest ?? StartVpnRequestReader.readFromStartFile,
       _notify = notify ?? AppFlutterApi().vpnStatusChanged,
       _notifyError =
           notifyError ?? AppFlutterApi().vpnStatusController.addError,
       super.base();

  @override
  Future<String> getTunFilesDir() async =>
      _filesDirectory ?? await super.getTunFilesDir();

  @override
  Future<void> ensureRuntime() =>
      checkRuntimeFiles(const ['libXray.dll', 'OneXrayCore.exe', 'wintun.dll']);

  @override
  Future<void> observeVpnStatus() async {
    _observing = true;
    final query = _findCorePids();
    final generation = _queryGeneration;
    try {
      await query;
    } catch (_) {
      if (generation == _queryGeneration) disposeVpnStatus();
      rethrow;
    }
  }

  @override
  void disposeVpnStatus() {
    _observing = false;
    _clearExitWatches();
  }

  void _clearExitWatches() {
    _watchGeneration++;
    _queryGeneration++;
    for (final watch in _exitWatches.values) {
      watch.cancel();
    }
    _exitWatches.clear();
  }

  void _syncExitWatches(Set<int> pids) {
    for (final pid in _exitWatches.keys.toList()) {
      if (!pids.contains(pid)) _exitWatches.remove(pid)?.cancel();
    }
    for (final pid in pids) {
      if (_exitWatches.containsKey(pid)) continue;
      final watch = _process.watchExit(pid);
      final generation = _watchGeneration;
      int? queryGeneration;
      _exitWatches[pid] = watch;
      unawaited(
        watch.exited
            .then((exited) async {
              if (!identical(_exitWatches[pid], watch)) return;
              _exitWatches.remove(pid);
              if (!exited || !_observing || _transition != null) return;
              final query = _findCorePids();
              queryGeneration = _queryGeneration;
              final pids = await query;
              if (_observing &&
                  _transition == null &&
                  generation == _watchGeneration &&
                  queryGeneration == _queryGeneration) {
                await _notify(
                  pids.isNotEmpty
                      ? VpnStatus.connected
                      : VpnStatus.disconnected,
                );
              }
            })
            .catchError((Object error) {
              if (identical(_exitWatches[pid], watch)) {
                _exitWatches.remove(pid)?.cancel();
              }
              if (_observing &&
                  _transition == null &&
                  generation == _watchGeneration &&
                  (queryGeneration == null ||
                      queryGeneration == _queryGeneration)) {
                _notifyError(error);
              }
            }),
      );
    }
  }

  Future<Set<int>> _findCorePids() async {
    // Claim the query revision before awaiting, including one-shot status reads.
    final generation = ++_queryGeneration;
    final pids = await _process.findPids();
    if (_observing && generation == _queryGeneration) _syncExitWatches(pids);
    return pids;
  }

  Future<bool> _running() async => (await _findCorePids()).isNotEmpty;

  @override
  Future<NativeVpnCommandResult> readVpnStatus() async {
    try {
      final running = await _running();
      return commandSuccess(
        status:
            _transition ??
            (running ? VpnStatus.connected : VpnStatus.disconnected),
      );
    } catch (error, stackTrace) {
      return _failed('read', error, stackTrace);
    }
  }

  @override
  Future<bool?> cleanupStaleCore() async {
    // Discover existing named processes; legacy PID files are not consulted.
    final status = await readVpnStatus();
    return status.state == NativeVpnCommandState.success;
  }

  @override
  Future<NativeVpnCommandResult> startVpn({
    String? configYaml,
    WindowsVpnNetworkSettings? networkSettings,
    WindowsVpnPolicy policy = const WindowsVpnPolicy(
      alwaysOn: false,
      allowLocalNetwork: true,
      excludedCidrs: [],
    ),
  }) async {
    _transition = VpnStatus.connecting;
    var launchAttempted = false;
    try {
      await _notify(VpnStatus.connecting);
      await _stop();
      final request = await _readRequest();
      final config = await materializeRunXrayConfig(
        readRunXrayRequest(request),
      );
      if (config == null) {
        throw const FormatException('xrayJson is empty');
      }
      // Create as the App user before Windows starts an elevated Core.
      final errorFile = desktopCoreErrorFile(config);
      await errorFile.writeAsString('', flush: true);
      launchAttempted = true;
      final pid = await _process.start(
        _corePath,
        desktopCoreRunArguments(
          dns: request.tun?.tunDnsIPv4 ?? '',
          interfaceName: request.tun?.autoOutboundsInterface ?? '',
          configPath: config,
          errorFile: errorFile.path,
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!(await _findCorePids()).contains(pid)) {
        throw StateError(
          await readDesktopCoreStartError(
            config,
            'Windows Core exited during start',
          ),
        );
      }
      await _notify(VpnStatus.connected);
      return commandSuccess(status: VpnStatus.connected);
    } catch (error, stackTrace) {
      try {
        if (launchAttempted) await _stop();
        if (!await _running()) await _notify(VpnStatus.disconnected);
      } catch (cleanupError) {
        ygLogger('clean up failed Windows Core start: $cleanupError');
      }
      return _failed('start', error, stackTrace);
    } finally {
      _transition = null;
    }
  }

  @override
  Future<NativeVpnCommandResult> stopVpn() async {
    _transition = VpnStatus.disconnecting;
    try {
      await _notify(VpnStatus.disconnecting);
      await _stop();
      await _notify(VpnStatus.disconnected);
      return commandSuccess(status: VpnStatus.disconnected);
    } catch (error, stackTrace) {
      return _failed('stop', error, stackTrace);
    } finally {
      _transition = null;
    }
  }

  Future<void> _stop() async {
    // A denied stop must still retire older queries, but keep live exit watches.
    _queryGeneration++;
    await _process.stopAll();
    _clearExitWatches();
  }

  NativeVpnCommandResult _failed(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    ygLogger('$operation Windows Core failed: $error\n$stackTrace');
    return commandFailed(error.toString());
  }
}
