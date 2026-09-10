import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/errors/failure.dart';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/desktop_core_process.dart';
import 'package:onexray/core/ffi/desktop_core_exit.dart';
import 'package:onexray/core/ffi/linux_core_exit.dart';
import 'package:onexray/core/model/tun_json.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/pigeon/model.dart';
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
      _notifyError = AppFlutterApi().vpnStatusController.addError,
      _processStore = DesktopCoreProcessStore();

  @visibleForTesting
  LinuxFfiApi.forTesting({
    required String filesDirectory,
    required String this._executablePath,
    required this._procDirectory,
    required this._signalProcess,
    required this._watchExit,
    Future<void> Function(VpnStatus)? notify,
    void Function(Object)? notifyError,
  }) : _filesDirectory = filesDirectory,
       _notify = notify ?? AppFlutterApi().vpnStatusChanged,
       _notifyError =
           notifyError ?? AppFlutterApi().vpnStatusController.addError,
       _processStore = DesktopCoreProcessStore(directory: filesDirectory);

  VpnStatus? _transition;

  @override
  Future<NativeVpnCommandResult> readVpnStatus() async {
    final running = await queryCoreRunning();
    if (running == null) {
      return commandFailed(
        'Unable to verify the current Core process identity.',
      );
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

  //===================================
  static const _coreBin = "OneXrayCore";
  final _processManager = LocalProcessManager();
  final DesktopCoreProcessStore _processStore;
  final String? _filesDirectory;
  final String? _executablePath;
  final String _procDirectory;
  final bool Function(int, ProcessSignal) _signalProcess;
  final DesktopCoreExitWatch Function(int) _watchExit;
  final Future<void> Function(VpnStatus) _notify;
  final void Function(Object) _notifyError;
  DesktopCoreExitWatch? _exitWatch;
  DesktopCoreProcessRecord? _watchedRecord;
  Process? _coreProcess;
  DesktopCoreProcessRecord? _currentRecord;
  bool _stopping = false;
  String? _lastCoreError;

  @override
  Future<void> observeVpnStatus() async {
    final running = await queryCoreRunning();
    if (running == null) {
      throw StateError('Could not identify the current Linux Core');
    }
    if (running && _coreProcess == null) {
      await _observeRestored(_currentRecord!);
    }
  }

  @override
  void disposeVpnStatus() {
    _exitWatch?.cancel();
    _exitWatch = null;
    _watchedRecord = null;
  }

  Future<DesktopCoreExitWatch> _observeRestored(
    DesktopCoreProcessRecord record, {
    bool v2684 = false,
  }) async {
    if (identical(_watchedRecord, record) && _exitWatch != null) {
      return _exitWatch!;
    }
    disposeVpnStatus();
    final watch = _watchExit(record.pid);
    _exitWatch = watch;
    _watchedRecord = record;
    unawaited(
      watch.exited
          .then((exited) async {
            if (!exited || !identical(_exitWatch, watch)) return;
            _exitWatch = null;
            _watchedRecord = null;
            if (identical(_currentRecord, record)) _currentRecord = null;
            if (!_stopping) await _notify(VpnStatus.disconnected);
          })
          .catchError((Object error) {
            if (identical(_exitWatch, watch)) _notifyError(error);
          }),
    );
    // A pidfd pins a process, not a PID. Verify again after opening it so PID
    // reuse between the initial /proc check and pidfd_open cannot be adopted.
    if (await _coreProcessIsRunning(record, v2684: v2684) == null) {
      disposeVpnStatus();
      throw StateError('Linux Core identity changed while subscribing');
    }
    return watch;
  }

  @override
  Future<String> getTunFilesDir() async =>
      _filesDirectory ?? await super.getTunFilesDir();

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

      final command = <String>[
        corePath,
        ...desktopCoreRunArguments(
          dns: tun?.tunDnsIPv4 ?? '',
          interfaceName: tun?.autoOutboundsInterface ?? '',
          configPath: inputs,
        ),
      ];
      final process = await _processManager.start(command);
      _bindProcess(process);
      _coreProcess = process;
      _trackProcess(process);
      final identity = await _readStat(process.pid);
      if (identity == null || identity.stopped) {
        throw StateError(
          'Desktop Core exited before its identity was recorded',
        );
      }
      final record = DesktopCoreProcessRecord(
        pid: process.pid,
        configPath: inputs,
        startTicks: identity.startTicks,
      );
      _currentRecord = record;
      if (await _coreProcessIsRunning(record) != true) {
        throw StateError('Desktop Core process identity could not be verified');
      }
      await _processStore.write(record);
    } catch (e) {
      _lastCoreError = failureDetails(e);
      ygLogger('start core failed: $_lastCoreError');
      await _stopCoreProcess();
      return false;
    }

    await Future.delayed(Duration(seconds: 1));

    final running = await queryCoreRunning() ?? false;
    if (!running) _lastCoreError = 'The Core process exited during startup.';
    return running;
  }

  Future<bool> cleanupStaleCore() async {
    try {
      final record = _currentRecord ?? await _processStore.read();
      if (record == null) return _coreProcess == null;
      if (_isV2684Record(record)) {
        final processDirectory = Directory(
          p.join(_procDirectory, '${record.pid}'),
        );
        if (!await processDirectory.exists()) {
          await _processStore.clear(pid: record.pid);
          return true;
        }
        final legacyRecord = await _verifyV2684Core(record);
        if (legacyRecord == null) return false;
        return await _stopRecordedCore(legacyRecord, v2684: true);
      }
      // An active Core belongs to the restored coordinator, not stale cleanup.
      if (await _coreProcessIsRunning(record) == true) {
        return true;
      }
      return await _stopRecordedCore(record);
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopCore() => _stopCoreProcess();

  Future<bool> _stopCoreProcess() async {
    try {
      final record = _currentRecord ?? await _processStore.read();
      if (record == null) return _coreProcess == null;
      return await _stopRecordedCore(record);
    } catch (error) {
      ygLogger(
        'stop desktop Core identity check failed (${error.runtimeType})',
      );
      return false;
    }
  }

  Future<bool> _stopRecordedCore(
    DesktopCoreProcessRecord record, {
    bool v2684 = false,
  }) async {
    Future<bool?> running() => _coreProcessIsRunning(record, v2684: v2684);

    final isRunning = await running();
    if (isRunning == null) return false;
    if (!isRunning) {
      if (_coreProcess?.pid == record.pid) _coreProcess = null;
      if (_currentRecord?.pid == record.pid) _currentRecord = null;
      await _processStore.clear(pid: record.pid);
      return true;
    }
    _stopping = true;
    try {
      final ownedProcess = _coreProcess;
      final exited = ownedProcess?.pid == record.pid
          ? ownedProcess!.exitCode.then((_) => true)
          : (await _observeRestored(record, v2684: v2684)).exited;
      if (!_signalProcess(record.pid, ProcessSignal.sigterm) &&
          await running() != false) {
        return false;
      }
      if (!await _waitForCoreExit(
        record,
        exited,
        const Duration(seconds: 3),
        v2684: v2684,
      )) {
        // Re-check the complete identity before escalating; never signal a PID
        // which was reused while waiting for the previous process to terminate.
        if (await running() != true) return false;
        if (!_signalProcess(record.pid, ProcessSignal.sigkill) &&
            await running() != false) {
          return false;
        }
        if (!await _waitForCoreExit(
          record,
          exited,
          const Duration(seconds: 2),
          v2684: v2684,
        )) {
          return false;
        }
      }
      if (_coreProcess?.pid == record.pid) _coreProcess = null;
      if (_currentRecord?.pid == record.pid) _currentRecord = null;
      await _processStore.clear(pid: record.pid);
      disposeVpnStatus();
      return true;
    } finally {
      _stopping = false;
    }
  }

  Future<bool?> queryCoreRunning() async {
    try {
      final record = _currentRecord ?? await _processStore.read();
      if (record == null) return _coreProcess == null ? false : null;
      final running = await _coreProcessIsRunning(record);
      if (running == true) {
        _currentRecord = record;
      } else if (running == false && _coreProcess == null) {
        _currentRecord = null;
      }
      return running;
    } catch (_) {
      return null;
    }
  }

  /// false means exited; null means ownership is unknown and must not be killed.
  Future<bool?> _coreProcessIsRunning(
    DesktopCoreProcessRecord record, {
    bool v2684 = false,
  }) async {
    if (record.pid <= 0) return null;
    final processDirectory = Directory(p.join(_procDirectory, '${record.pid}'));
    if (!await processDirectory.exists()) return false;
    final configPath = record.configPath;
    if (configPath == null || record.startTicks == null) return null;
    try {
      String? legacyExecutablePath;
      final identity = await _readStat(record.pid);
      if (identity == null || identity.startTicks != record.startTicks) {
        return null;
      }
      if (identity.stopped) return false;
      if (v2684) {
        final executableTarget = await Link(
          p.join(processDirectory.path, 'exe'),
        ).target();
        const deletedSuffix = ' (deleted)';
        legacyExecutablePath = executableTarget.endsWith(deletedSuffix)
            ? executableTarget.substring(
                0,
                executableTarget.length - deletedSuffix.length,
              )
            : executableTarget;
        if (!p.isAbsolute(legacyExecutablePath) ||
            p.basename(legacyExecutablePath) != _coreBin ||
            p.basename(p.dirname(legacyExecutablePath)) != 'bin') {
          return null;
        }
        final processUid = await _effectiveUid(processDirectory.path);
        final appUid = await _effectiveUid(p.join(_procDirectory, 'self'));
        if (processUid == null || appUid == null || processUid != appUid) {
          return null;
        }
        if (configPath != p.join(await getTunFilesDir(), 'run', 'xray.json')) {
          return null;
        }
      } else {
        final actualExecutable = await File(
          p.join(processDirectory.path, 'exe'),
        ).resolveSymbolicLinks();
        final expectedExecutable = await File(corePath).resolveSymbolicLinks();
        if (actualExecutable != expectedExecutable) return null;
        final inputDirectory = await Directory(
          p.join(await getTunFilesDir(), 'run', 'core-inputs'),
        ).resolveSymbolicLinks();
        final resolvedConfig = await File(configPath).resolveSymbolicLinks();
        if (!p.isAbsolute(configPath) ||
            !p.isWithin(inputDirectory, resolvedConfig)) {
          return null;
        }
      }
      final arguments = utf8
          .decode(
            await File(p.join(processDirectory.path, 'cmdline')).readAsBytes(),
          )
          .split('\x00');
      if (v2684) {
        while (arguments.isNotEmpty && arguments.last.isEmpty) {
          arguments.removeLast();
        }
        if (arguments.length != 4 ||
            arguments[0] != legacyExecutablePath ||
            arguments[1] != 'run' ||
            arguments[2] != '-config' ||
            arguments[3] != configPath) {
          return null;
        }
      } else if (arguments.length < 2 ||
          arguments[1] != 'run' ||
          !_matchesArgument(arguments, '-config', configPath)) {
        return null;
      }
      // stat is re-read after the other /proc reads to catch an intervening reuse.
      final current = await _readStat(record.pid);
      if (current == null || current.startTicks != record.startTicks) {
        return null;
      }
      return !current.stopped;
    } catch (_) {
      return await processDirectory.exists() ? null : false;
    }
  }

  static bool _isV2684Record(DesktopCoreProcessRecord record) =>
      record.configPath == null && record.startTicks == null;

  Future<DesktopCoreProcessRecord?> _verifyV2684Core(
    DesktopCoreProcessRecord record,
  ) async {
    if (record.pid <= 0 || !_isV2684Record(record)) return null;
    final identity = await _readStat(record.pid);
    if (identity == null) return null;
    final verified = DesktopCoreProcessRecord(
      pid: record.pid,
      configPath: p.join(await getTunFilesDir(), 'run', 'xray.json'),
      startTicks: identity.startTicks,
    );
    return await _coreProcessIsRunning(verified, v2684: true) == null
        ? null
        : verified;
  }

  Future<int?> _effectiveUid(String processDirectory) async {
    final lines = await File(p.join(processDirectory, 'status')).readAsLines();
    for (final line in lines) {
      if (!line.startsWith('Uid:')) continue;
      final fields = line.substring(4).trim().split(RegExp(r'\s+'));
      return fields.length < 2 ? null : int.tryParse(fields[1]);
    }
    return null;
  }

  static bool _matchesArgument(
    List<String> arguments,
    String flag,
    String? expected,
  ) {
    final positions = [
      for (var i = 0; i < arguments.length; i++)
        if (arguments[i] == flag) i,
    ];
    if (expected == null) return positions.isEmpty;
    return positions.length == 1 &&
        positions.single + 1 < arguments.length &&
        arguments[positions.single + 1] == expected;
  }

  Future<({int startTicks, bool stopped})?> _readStat(int pid) async {
    try {
      final text = await File(p.join(_procDirectory, '$pid', 'stat'))
          .readAsString();
      final opening = text.indexOf('(');
      final closing = text.lastIndexOf(')');
      if (opening < 0 ||
          closing < opening ||
          int.tryParse(text.substring(0, opening).trim()) != pid) {
        return null;
      }
      final fields = text.substring(closing + 1).trim().split(RegExp(r'\s+'));
      if (fields.length < 20) return null;
      final ticks = int.tryParse(fields[19]); // Linux proc_pid_stat field 22.
      return ticks == null
          ? null
          : (startTicks: ticks, stopped: fields[0] == 'Z' || fields[0] == 'X');
    } catch (_) {
      return null;
    }
  }

  Future<bool> _waitForCoreExit(
    DesktopCoreProcessRecord record,
    Future<bool> exited,
    Duration timeout, {
    bool v2684 = false,
  }) async {
    if (await _coreProcessIsRunning(record, v2684: v2684) == false) return true;
    await exited.timeout(timeout, onTimeout: () => false);
    return await _coreProcessIsRunning(record, v2684: v2684) == false;
  }

  String get corePath {
    if (_executablePath != null) return _executablePath;
    if (kReleaseMode) {
      final bundleDir = p.dirname(Platform.resolvedExecutable);
      final corePath = p.join(bundleDir, _coreBin);
      return corePath;
    } else {
      final homeDir = Platform.environment["HOME"];
      if (homeDir == null) {
        return _coreBin;
      }
      return p.join(homeDir, "work", "vpn", _coreBin);
    }
  }

  void _bindProcess(Process process) {
    process.stdout.listen((data) {
      if (!kReleaseMode) {
        ygLogger(utf8.decode(data));
      }
    });
    process.stderr.listen((data) {
      if (!kReleaseMode) {
        ygLogger(utf8.decode(data));
      }
    });
  }

  void _trackProcess(Process process) {
    process.exitCode.then((_) {
      if (identical(_coreProcess, process)) {
        _coreProcess = null;
        _currentRecord = null;
        // Leave the exited identity until the next verified stop/start. An async
        // exit callback must not erase a newer process record after PID reuse.
        if (!_stopping) {
          unawaited(_notify(VpnStatus.disconnected));
        }
      }
    });
  }
}
