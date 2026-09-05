// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// The latest counters for one libXray session plus App-owned totals.
class RuntimeSnapshot {
  final String sessionId;
  final int startedAtMs;
  final int endedAtMs;
  final int uplink;
  final int downlink;
  final int totalUplink;
  final int totalDownlink;
  final bool available;
  final int sampledAtMs;
  final int savedAtMs;
  final String error;

  const RuntimeSnapshot({
    required this.sessionId,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.uplink,
    required this.downlink,
    this.totalUplink = 0,
    this.totalDownlink = 0,
    required this.available,
    required this.sampledAtMs,
    required this.savedAtMs,
    required this.error,
  });

  factory RuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    final session = json['session'];
    if (json['version'] != 1 ||
        session is! Map ||
        session['id'] is! String ||
        (session['id'] as String).isEmpty ||
        json['available'] is! bool ||
        json['error'] is! String) {
      throw const FormatException('Invalid runtime snapshot');
    }
    return RuntimeSnapshot(
      sessionId: session['id'] as String,
      startedAtMs: _number(session, 'startedAtMs'),
      endedAtMs: _number(session, 'endedAtMs'),
      uplink: _number(session, 'uplink'),
      downlink: _number(session, 'downlink'),
      available: json['available'] as bool,
      sampledAtMs: _number(json, 'sampledAtMs'),
      savedAtMs: _number(json, 'savedAtMs'),
      error: json['error'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'session': {
      'id': sessionId,
      'startedAtMs': startedAtMs,
      'endedAtMs': endedAtMs,
      'uplink': uplink,
      'downlink': downlink,
    },
    'available': available,
    'sampledAtMs': sampledAtMs,
    'savedAtMs': savedAtMs,
    'error': error,
  };

  RuntimeSnapshot withTotals({required int uplink, required int downlink}) =>
      RuntimeSnapshot(
        sessionId: sessionId,
        startedAtMs: startedAtMs,
        endedAtMs: endedAtMs,
        uplink: this.uplink,
        downlink: this.downlink,
        totalUplink: uplink,
        totalDownlink: downlink,
        available: available,
        sampledAtMs: sampledAtMs,
        savedAtMs: savedAtMs,
        error: error,
      );

  RuntimeSnapshot withCounters({
    required int uplink,
    required int downlink,
    required int sampledAtMs,
    bool? available,
    String? error,
  }) => RuntimeSnapshot(
    sessionId: sessionId,
    startedAtMs: startedAtMs,
    endedAtMs: endedAtMs,
    uplink: uplink,
    downlink: downlink,
    totalUplink: totalUplink,
    totalDownlink: totalDownlink,
    available: available ?? this.available,
    sampledAtMs: sampledAtMs,
    savedAtMs: savedAtMs,
    error: error ?? this.error,
  );
}

typedef RuntimeSnapshotReader = Future<RuntimeSnapshot?> Function();

class TrafficAccounting {
  final String path;
  final RuntimeSnapshotReader readRuntimeSnapshot;
  final Future<void> Function(String text)? _write;

  static final Map<String, Future<void>> _queues = {};

  TrafficAccounting({
    required String path,
    required this.readRuntimeSnapshot,
    Future<void> Function(String text)? write,
  }) : path = p.normalize(p.absolute(path)),
       _write = write;

  Future<RuntimeSnapshot?> read({RuntimeSnapshot? live, bool reset = false}) {
    final previous = _queues[path] ?? Future<void>.value();
    final result = previous.then((_) => _read(live: live, reset: reset));
    final completed = result.then<void>((_) {}, onError: (Object _) {});
    _queues[path] = completed;
    unawaited(
      completed.then((_) {
        if (identical(_queues[path], completed)) _queues.remove(path);
      }),
    );
    return result;
  }

  Future<RuntimeSnapshot?> _read({
    RuntimeSnapshot? live,
    required bool reset,
  }) async {
    RuntimeSnapshot? current;
    try {
      current = await readRuntimeSnapshot();
    } on Exception {
      if (live != null) rethrow;
    }
    if (live != null &&
        (current == null ||
            current.sessionId != live.sessionId ||
            current.endedAtMs != 0)) {
      throw const FormatException('Runtime session changed');
    }

    final file = File(path);
    late _TrafficLedger ledger;
    var repair = false;
    try {
      ledger = await file.exists()
          ? _TrafficLedger.decode(await file.readAsString())
          : _TrafficLedger();
    } on Exception {
      // Totals are best effort. A stale, corrupt or unreadable ledger must not
      // turn working live metrics into a VPN startup failure.
      ledger = _TrafficLedger();
      repair = true;
    }
    final before = ledger.encode();
    if (current != null) ledger.merge(current);
    if (live != null) ledger.merge(live);
    if (reset) {
      ledger.uplink = 0;
      ledger.downlink = 0;
    }
    var display = live ?? ledger.last;
    if (display != null && live == null && current == null) {
      display = display.withCounters(
        uplink: display.uplink,
        downlink: display.downlink,
        sampledAtMs: display.sampledAtMs,
        available: false,
        error: 'runtimeStateUnavailable',
      );
    }
    if (repair || before != ledger.encode()) {
      try {
        await _save(ledger);
      } on Exception {
        // Live/session counters remain usable when App-owned totals cannot be
        // persisted. A later sample may repair the file.
      }
    }
    return display?.withTotals(
      uplink: ledger.uplink,
      downlink: ledger.downlink,
    );
  }

  Future<void> _save(_TrafficLedger ledger) async {
    final write = _write;
    if (write != null) {
      await write(ledger.encode());
      return;
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    final temporary = File('$path.tmp');
    final temporaryType = await FileSystemEntity.type(
      temporary.path,
      followLinks: false,
    );
    if (temporaryType != FileSystemEntityType.notFound &&
        temporaryType != FileSystemEntityType.file) {
      throw const FormatException('Invalid traffic totals temporary file');
    }
    try {
      await temporary.writeAsString(ledger.encode(), flush: true);
      if (!Platform.isWindows) {
        await temporary.rename(path);
      } else {
        using((arena) {
          final result = MoveFileEx(
            arena.pcwstr(temporary.path),
            arena.pcwstr(path),
            MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
          );
          if (!result.value) {
            throw WindowsException(result.error.toHRESULT());
          }
        });
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

int _number(Map object, String key) {
  final value = object[key];
  if (value is! int || value < 0) {
    throw const FormatException('Invalid runtime counter');
  }
  return value;
}

class _TrafficLedger {
  int uplink = 0;
  int downlink = 0;
  String? sessionId;
  int sessionUplink = 0;
  int sessionDownlink = 0;
  RuntimeSnapshot? last;

  _TrafficLedger();

  factory _TrafficLedger.decode(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> ||
        json['version'] != 1 ||
        !json.containsKey('sessionId') ||
        (json['sessionId'] != null && json['sessionId'] is! String) ||
        (json['last'] != null && json['last'] is! Map<String, dynamic>)) {
      throw const FormatException('Invalid traffic totals');
    }
    return _TrafficLedger()
      ..uplink = _number(json, 'uplink')
      ..downlink = _number(json, 'downlink')
      ..sessionId = json['sessionId'] as String?
      ..sessionUplink = _number(json, 'sessionUplink')
      ..sessionDownlink = _number(json, 'sessionDownlink')
      ..last = json['last'] == null
          ? null
          : RuntimeSnapshot.fromJson(json['last'] as Map<String, dynamic>);
  }

  void merge(RuntimeSnapshot snapshot) {
    if (sessionId != snapshot.sessionId) {
      sessionId = snapshot.sessionId;
      sessionUplink = 0;
      sessionDownlink = 0;
    }
    uplink += math.max(0, snapshot.uplink - sessionUplink);
    downlink += math.max(0, snapshot.downlink - sessionDownlink);
    sessionUplink = math.max(sessionUplink, snapshot.uplink);
    sessionDownlink = math.max(sessionDownlink, snapshot.downlink);
    if (last == null ||
        last!.sessionId != snapshot.sessionId ||
        snapshot.sampledAtMs >= last!.sampledAtMs) {
      last = snapshot;
    }
  }

  String encode() => jsonEncode({
    'version': 1,
    'uplink': uplink,
    'downlink': downlink,
    'sessionId': sessionId,
    'sessionUplink': sessionUplink,
    'sessionDownlink': sessionDownlink,
    'last': last?.toJson(),
  });
}
