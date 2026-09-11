import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/desktop_core_exit.dart';
import 'package:onexray/core/ffi/linux_core_exit.dart';
import 'package:onexray/core/model/tun_json.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as p;
import 'package:process/process.dart';

class LinuxFfiApi extends BaseFfiApi {
  static final LinuxFfiApi _singleton = LinuxFfiApi._internal();

  factory LinuxFfiApi() => _singleton;

  LinuxFfiApi._internal()
    : _filesDirectory = null,
      _executablePath = null,
      _procDirectory = '/proc',
      _signalProcess = Process.killPid,
      _watchExit = watchLinuxCoreExit,
      _notify = AppFlutterApi().vpnStatusChanged,
      _notifyError = AppFlutterApi().vpnStatusController.addError;

  @visibleForTesting
  LinuxFfiApi.forTesting({
    required String this._filesDirectory,
    required this._executablePath,
    required this._procDirectory,
    required this._signalProcess,
    required this._watchExit,
    Future<void> Function(VpnStatus)? notify,
    void Function(Object)? notifyError,
  }) : _notify = notify ?? AppFlutterApi().vpnStatusChanged,
       _notifyError =
           notifyError ?? AppFlutterApi().vpnStatusController.addError;

  static const _coreBin = 'OneXrayCore';
  final _processManager = LocalProcessManager();
  final String? _filesDirectory;
  final String? _executablePath;
  final String _procDirectory;
  final bool Function(int, ProcessSignal) _signalProcess;
  final DesktopCoreExitWatch Function(int) _watchExit;
  final Future<void> Function(VpnStatus) _notify;
  final void Function(Object) _notifyError;
  final _exitWatches = <int, DesktopCoreExitWatch>{};
  Process? _coreProcess;
  VpnStatus? _transition;
  bool _observing = false;
  bool _stopping = false;
  String? _lastCoreError;

  @override
  Future<NativeVpnCommandResult> readVpnStatus() async {
    final running = await queryCoreRunning();
    if (running == null) {
      return commandFailed('Unable to read Linux Core process state.');
    }
    return commandSuccess(
      status:
          _transition ??
          (running ? VpnStatus.connected : VpnStatus.disconnected),
    );
  }

  @override
  Future<NativeVpnCommandResult> startVpn() async {
    _transition = VpnStatus.connecting;
    try {
      await _notify(VpnStatus.connecting);
      final request = await StartVpnRequestReader.readFromStartFile();
      if (!await startCore(readRunXrayRequest(request), request.tun)) {
        final error = _lastCoreError;
        await stopVpn();
        return commandFailed(error);
      }
      await _notify(VpnStatus.connected);
      return commandSuccess(status: VpnStatus.connected);
    } catch (error) {
      return commandFailed(failureDetails(error));
    } finally {
      _transition = null;
    }
  }

  @override
  Future<NativeVpnCommandResult> stopVpn() async {
    _transition = VpnStatus.disconnecting;
    try {
      await _notify(VpnStatus.disconnecting);
      if (!await stopCore()) {
        return commandFailed('Unable to stop the current Core process.');
      }
      await _notify(VpnStatus.disconnected);
      return commandSuccess(status: VpnStatus.disconnected);
    } finally {
      _transition = null;
    }
  }

  @override
  Future<String> getTunFilesDir() async =>
      _filesDirectory ?? await super.getTunFilesDir();

  @override
  Future<void> observeVpnStatus() async {
    _observing = true;
    try {
      _syncExitWatches(await _findCorePids());
    } catch (_) {
      disposeVpnStatus();
      rethrow;
    }
  }

  @override
  void disposeVpnStatus() {
    _observing = false;
    _clearExitWatches();
  }

  void _clearExitWatches() {
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
      _observeProcess(pid);
    }
  }

  DesktopCoreExitWatch _observeProcess(int pid) =>
      _exitWatches.putIfAbsent(pid, () {
        final process = _coreProcess;
        final watch = process?.pid == pid
            ? DesktopCoreExitWatch(process!.exitCode.then((_) => true), () {})
            : _watchExit(pid);
        unawaited(
          watch.exited
              .then((exited) async {
                if (!identical(_exitWatches[pid], watch)) return;
                _exitWatches.remove(pid);
                if (_coreProcess?.pid == pid) _coreProcess = null;
                if (!exited || !_observing || _stopping) return;
                final running = await queryCoreRunning();
                if (running == null) {
                  throw StateError('Unable to read Linux Core process state.');
                }
                await _notify(
                  running ? VpnStatus.connected : VpnStatus.disconnected,
                );
              })
              .catchError((Object error) {
                if (_observing && !_stopping) _notifyError(error);
              }),
        );
        return watch;
      });

  Future<bool> startCore(LibXrayRunConfig request, TunJson? tun) async {
    _lastCoreError = null;
    try {
      if (!await _stopCoreProcess()) {
        _lastCoreError = 'The previous Core process is still running.';
        return false;
      }
      final inputs = await materializeRunXrayConfig(request);
      if (inputs == null) {
        _lastCoreError = 'The Xray configuration is empty.';
        return false;
      }
      final process = await _processManager.start([
        corePath,
        ...desktopCoreRunArguments(
          dns: tun?.tunDnsIPv4 ?? '',
          interfaceName: tun?.autoOutboundsInterface ?? '',
          configPath: inputs,
        ),
      ]);
      _coreProcess = process;
      _bindProcess(process);
      _observeProcess(process.pid);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!await _isCoreProcess(process.pid)) {
        _lastCoreError = 'The Core process exited during startup.';
        return false;
      }
      return true;
    } catch (error) {
      _lastCoreError = failureDetails(error);
      ygLogger('start core failed: $_lastCoreError');
      await _stopCoreProcess();
      return false;
    }
  }

  // Existing named processes are discovered directly; old PID files are unused.
  Future<bool> cleanupStaleCore() async => await queryCoreRunning() != null;

  Future<bool> stopCore() => _stopCoreProcess();

  Future<bool> _stopCoreProcess() async {
    _stopping = true;
    try {
      for (final (signal, timeout) in const [
        (ProcessSignal.sigterm, Duration(seconds: 3)),
        (ProcessSignal.sigkill, Duration(seconds: 2)),
      ]) {
        final pids = await _findCorePids();
        if (pids.isEmpty) {
          _coreProcess = null;
          _clearExitWatches();
          return true;
        }
        final exits = [for (final pid in pids) _observeProcess(pid).exited];
        for (final pid in pids) {
          // Only the exact process name matters, including before escalation.
          if (await _isCoreProcess(pid) &&
              !_signalProcess(pid, signal) &&
              await _isCoreProcess(pid)) {
            return false;
          }
        }
        if ((await _findCorePids()).isEmpty) {
          _coreProcess = null;
          _clearExitWatches();
          return true;
        }
        await Future.wait(exits).timeout(timeout, onTimeout: () => []);
      }
      final stopped = (await _findCorePids()).isEmpty;
      if (stopped) {
        _coreProcess = null;
        _clearExitWatches();
      }
      return stopped;
    } catch (error) {
      ygLogger('stop desktop Core failed (${error.runtimeType})');
      return false;
    } finally {
      _stopping = false;
    }
  }

  Future<bool?> queryCoreRunning() async {
    try {
      final pids = await _findCorePids();
      if (_observing) _syncExitWatches(pids);
      return pids.isNotEmpty;
    } catch (_) {
      return null;
    }
  }

  Future<Set<int>> _findCorePids() async {
    final pids = <int>{};
    await for (final entry in Directory(
      _procDirectory,
    ).list(followLinks: false)) {
      final pid = int.tryParse(p.basename(entry.path));
      if (entry is Directory &&
          pid != null &&
          pid > 0 &&
          await _isCoreProcess(pid)) {
        pids.add(pid);
      }
    }
    return pids;
  }

  Future<bool> _isCoreProcess(int pid) async {
    try {
      // File capabilities can block /proc/<pid>/exe, but name/state remain
      // readable in stat. Do not require paths, start ticks or saved records.
      final text = await File(p.join(_procDirectory, '$pid', 'stat'))
          .readAsString();
      final opening = text.indexOf('(');
      final closing = text.lastIndexOf(')');
      if (opening < 0 || closing <= opening) return false;
      final state = text.substring(closing + 1).trimLeft();
      return text.substring(opening + 1, closing) == _coreBin &&
          state.isNotEmpty &&
          state[0] != 'Z' &&
          state[0] != 'X';
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2 || error.osError?.errorCode == 3) {
        return false;
      }
      rethrow;
    }
  }

  String get corePath {
    if (_executablePath != null) return _executablePath;
    if (kReleaseMode) {
      return p.join(p.dirname(Platform.resolvedExecutable), _coreBin);
    }
    final homeDir = Platform.environment['HOME'];
    return homeDir == null
        ? _coreBin
        : p.join(homeDir, 'work', 'vpn', _coreBin);
  }

  void _bindProcess(Process process) {
    process.stdout.listen((data) {
      if (!kReleaseMode) ygLogger(utf8.decode(data));
    });
    process.stderr.listen((data) {
      if (!kReleaseMode) ygLogger(utf8.decode(data));
    });
  }
}
