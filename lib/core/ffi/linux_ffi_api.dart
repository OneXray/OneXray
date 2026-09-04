import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/desktop_core_process.dart';
import 'package:onexray/core/model/tun_json.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
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
      _processStore = DesktopCoreProcessStore();

  @visibleForTesting
  LinuxFfiApi.forTesting({
    required String filesDirectory,
    required String this._executablePath,
    required this._procDirectory,
    required this._signalProcess,
  }) : _filesDirectory = filesDirectory,
       _processStore = DesktopCoreProcessStore(directory: filesDirectory);

  //===================================
  static const _coreBin = "OneXrayCore";
  final _processManager = LocalProcessManager();
  final DesktopCoreProcessStore _processStore;
  final String? _filesDirectory;
  final String? _executablePath;
  final String _procDirectory;
  final bool Function(int, ProcessSignal) _signalProcess;
  Process? _coreProcess;
  DesktopCoreProcessRecord? _currentRecord;
  bool _stopping = false;

  // App-owned processes already report exitCode; restored PIDs cannot do so.
  bool get needsVpnStatusPolling =>
      _coreProcess == null && _currentRecord != null;

  @override
  Future<String> getTunFilesDir() async =>
      _filesDirectory ?? await super.getTunFilesDir();

  @override
  Future<bool> startCore(LibXrayRunConfig request, TunJson? tun) async {
    try {
      if (!await _stopCoreProcess()) {
        ygLogger("start core failed: previous core is still running");
        return false;
      }

      final inputs = await materializeRunXrayConfig(request);
      if (inputs == null) {
        ygLogger("start core failed: xrayJson is empty");
        return false;
      }

      final command = <String>[
        corePath,
        ...desktopCoreRunArguments(
          dns: tun?.tunDnsIPv4 ?? '',
          interfaceName: tun?.autoOutboundsInterface ?? '',
          configPath: inputs.configPath,
          runtimePath: inputs.runtimePath,
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
        configPath: inputs.configPath,
        runtimePath: inputs.runtimePath,
        startTicks: identity.startTicks,
      );
      _currentRecord = record;
      if (await _coreProcessIsRunning(record) != true) {
        throw StateError('Desktop Core process identity could not be verified');
      }
      await _processStore.write(record);
    } catch (e) {
      ygLogger('start core failed (${e.runtimeType})');
      await _stopCoreProcess();
      return false;
    }

    await Future.delayed(Duration(seconds: 1));

    return await queryCoreRunning() ?? false;
  }

  Future<bool> cleanupStaleCore() async {
    try {
      final record = _currentRecord ?? await _processStore.read();
      if (record == null) return _coreProcess == null;
      // A managed session belongs to the restored coordinator, not stale cleanup.
      if (record.runtimePath != null &&
          await _coreProcessIsRunning(record) == true) {
        return true;
      }
      return await _stopRecordedCore(record);
    } catch (_) {
      return false;
    }
  }

  @override
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

  Future<bool> _stopRecordedCore(DesktopCoreProcessRecord record) async {
    final running = await _coreProcessIsRunning(record);
    if (running == null) return false;
    if (!running) {
      if (_coreProcess?.pid == record.pid) _coreProcess = null;
      if (_currentRecord?.pid == record.pid) _currentRecord = null;
      await _processStore.clear(pid: record.pid);
      return true;
    }
    _stopping = true;
    try {
      if (!_signalProcess(record.pid, ProcessSignal.sigterm) &&
          await _coreProcessIsRunning(record) != false) {
        return false;
      }
      if (!await _waitForCoreExit(record, const Duration(seconds: 3))) {
        // Re-check the complete identity before escalating; never signal a PID
        // which was reused while waiting for the previous process to terminate.
        if (await _coreProcessIsRunning(record) != true) return false;
        if (!_signalProcess(record.pid, ProcessSignal.sigkill) &&
            await _coreProcessIsRunning(record) != false) {
          return false;
        }
        if (!await _waitForCoreExit(record, const Duration(seconds: 2))) {
          return false;
        }
      }
      if (_coreProcess?.pid == record.pid) _coreProcess = null;
      if (_currentRecord?.pid == record.pid) _currentRecord = null;
      await _processStore.clear(pid: record.pid);
      return true;
    } finally {
      _stopping = false;
    }
  }

  @override
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
  Future<bool?> _coreProcessIsRunning(DesktopCoreProcessRecord record) async {
    if (record.pid <= 0) return null;
    final processDirectory = Directory(p.join(_procDirectory, '${record.pid}'));
    if (!await processDirectory.exists()) return false;
    final configPath = record.configPath;
    if (configPath == null || record.startTicks == null) return null;
    try {
      final identity = await _readStat(record.pid);
      if (identity == null || identity.startTicks != record.startTicks) {
        return null;
      }
      if (identity.stopped) return false;
      final actualExecutable = await File(p.join(processDirectory.path, 'exe'))
          .resolveSymbolicLinks();
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
      final runtimePath = record.runtimePath;
      if (runtimePath != null) {
        final resolvedRuntime = await File(runtimePath).resolveSymbolicLinks();
        if (!p.isWithin(inputDirectory, resolvedRuntime) ||
            p.dirname(resolvedRuntime) != p.dirname(resolvedConfig)) {
          return null;
        }
      }
      final arguments = utf8
          .decode(
            await File(p.join(processDirectory.path, 'cmdline')).readAsBytes(),
          )
          .split('\x00');
      if (arguments.length < 2 ||
          arguments[1] != 'run' ||
          !_matchesArgument(arguments, '-config', configPath) ||
          !_matchesArgument(arguments, '-runtime', runtimePath)) {
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
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final running = await _coreProcessIsRunning(record);
      if (running == false) return true;
      if (running == null || DateTime.now().isAfter(deadline)) return false;
      await Future.delayed(const Duration(milliseconds: 100));
    }
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
          unawaited(updateVpnStatus(VpnStatus.disconnected));
        }
      }
    });
  }
}
