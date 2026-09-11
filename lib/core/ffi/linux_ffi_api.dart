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
      _runCommand = Process.run,
      _watchExit = watchLinuxCoreExit,
      _notify = AppFlutterApi().vpnStatusChanged,
      _notifyError = AppFlutterApi().vpnStatusController.addError;

  @visibleForTesting
  LinuxFfiApi.forTesting({
    required String this._filesDirectory,
    required this._executablePath,
    required this._runCommand,
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
  final Future<ProcessResult> Function(String, List<String>) _runCommand;
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
      if (!(await _findCorePids()).contains(process.pid)) {
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
      var pids = await _findCorePids();
      for (final (signal, timeout) in const [
        ('-TERM', Duration(seconds: 3)),
        ('-KILL', Duration(seconds: 2)),
      ]) {
        if (pids.isEmpty) break;
        final exits = [for (final pid in pids) _observeProcess(pid).exited];
        final arguments = [signal, '-x', _coreBin];
        final result = await _runCommand('pkill', arguments);
        if (result.exitCode != 0 && result.exitCode != 1) {
          throw ProcessException(
            'pkill',
            arguments,
            'Core stop command failed',
            result.exitCode,
          );
        }
        if (result.exitCode == 0) {
          await Future.wait(exits).timeout(timeout, onTimeout: () => []);
        }
        // pkill 0 means at least one signal was sent, not that every Core exited.
        // Exit 1 can mean either no matches or a permission failure.
        pids = await _findCorePids();
        if (result.exitCode == 1 && pids.isNotEmpty) return false;
      }
      final stopped = pids.isEmpty;
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
    // procps does the name/state scan natively. Do not match full command lines
    // or include zombies/dead processes when reporting a running VPN.
    const arguments = ['-x', '-r', 'R,S,D,T,t,I', _coreBin];
    final result = await _runCommand('pgrep', arguments);
    if (result.exitCode == 1) return {};
    if (result.exitCode != 0) {
      throw ProcessException(
        'pgrep',
        arguments,
        'Core process query failed',
        result.exitCode,
      );
    }
    final pids = {
      for (final value in '${result.stdout}'.trim().split(RegExp(r'\s+')))
        int.parse(value),
    };
    if (pids.any((pid) => pid <= 0)) {
      throw const FormatException('Invalid Core PID returned by pgrep');
    }
    return pids;
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
