import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// The host owns session counters; device totals exist only in the App ledger.
class RuntimeSnapshot {
  final String sessionId;
  final String planId;
  final int startedAtMs;
  final int endedAtMs;
  final int uplink;
  final int downlink;
  final int totalUplink;
  final int totalDownlink;
  final int resetGeneration;
  final bool available;
  final int sampledAtMs;
  final int savedAtMs;
  final String error;

  const RuntimeSnapshot({
    required this.sessionId,
    required this.planId,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.uplink,
    required this.downlink,
    this.totalUplink = 0,
    this.totalDownlink = 0,
    this.resetGeneration = 0,
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
        session['planId'] is! String ||
        (session['planId'] as String).isEmpty ||
        json['available'] is! bool ||
        json['error'] is! String) {
      throw const FormatException('Invalid runtime snapshot');
    }
    return RuntimeSnapshot(
      sessionId: session['id'] as String,
      planId: session['planId'] as String,
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
      'planId': planId,
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

  RuntimeSnapshot withTotals({
    required int uplink,
    required int downlink,
    required int resetGeneration,
  }) => RuntimeSnapshot(
    sessionId: sessionId,
    planId: planId,
    startedAtMs: startedAtMs,
    endedAtMs: endedAtMs,
    uplink: this.uplink,
    downlink: this.downlink,
    totalUplink: uplink,
    totalDownlink: downlink,
    resetGeneration: resetGeneration,
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
    planId: planId,
    startedAtMs: startedAtMs,
    endedAtMs: endedAtMs,
    uplink: uplink,
    downlink: downlink,
    totalUplink: totalUplink,
    totalDownlink: totalDownlink,
    resetGeneration: resetGeneration,
    available: available ?? this.available,
    sampledAtMs: sampledAtMs,
    savedAtMs: savedAtMs,
    error: error ?? this.error,
  );
}

class RuntimeState {
  final RuntimeSnapshot? current;
  final List<RuntimeSnapshot> archived;

  const RuntimeState({this.current, this.archived = const []});

  factory RuntimeState.fromJson(Map<String, dynamic> json) {
    if ((json['current'] != null && json['current'] is! Map<String, dynamic>) ||
        json['archived'] is! List ||
        (json['archived'] as List).any(
          (snapshot) => snapshot is! Map<String, dynamic>,
        )) {
      throw const FormatException('Invalid runtime state');
    }
    return RuntimeState(
      current: json['current'] == null
          ? null
          : RuntimeSnapshot.fromJson(json['current'] as Map<String, dynamic>),
      archived: [
        for (final snapshot in json['archived'] as List)
          RuntimeSnapshot.fromJson(snapshot as Map<String, dynamic>),
      ],
    );
  }
}

/// Reads host snapshots after acknowledging the requested settled archives.
/// It must never remove the current session, and must retain failed deletions.
typedef RuntimeStateReader = Future<RuntimeState> Function(
  List<String> removeSessionIds,
);

class TrafficAccounting {
  final String path;
  final RuntimeStateReader readRuntimeState;
  final Future<void> Function(String text)? _write;

  // Multiple runtime-host instances still have exactly one App ledger writer.
  static final Map<String, Future<void>> _queues = {};

  TrafficAccounting({
    required String path,
    required this.readRuntimeState,
    this._write,
  }) : path = p.normalize(p.absolute(path));

  Future<RuntimeSnapshot?> read({RuntimeSnapshot? live, bool reset = false}) {
    final previous = _queues[path] ?? Future<void>.value();
    final result = previous.then((_) => _read(live: live, reset: reset));
    final completed = result.then<void>((_) {}, onError: (Object _) {});
    _queues[path] = completed;
    unawaited(
      completed.then((_) {
        if (identical(_queues[path], completed)) {
          _queues.remove(path);
        }
      }),
    );
    return result;
  }

  Future<RuntimeSnapshot?> _read({
    RuntimeSnapshot? live,
    required bool reset,
  }) async {
    // Read inside the same queue as archive deletion/watermark pruning. Otherwise
    // a previously captured archive could be counted again after its removal.
    RuntimeState files;
    try {
      files = await readRuntimeState(const []);
    } on Exception {
      if (live != null) {
        rethrow;
      }
      // The HTTP endpoint closes with the core. Offline display/reset uses only
      // the App ledger; the next connection reconciles remaining host snapshots.
      files = const RuntimeState();
    }
    final current = files.current;
    if (live != null &&
        (current == null ||
            current.sessionId != live.sessionId ||
            current.planId != live.planId ||
            current.endedAtMs != 0)) {
      throw const FormatException('Runtime session changed');
    }
    final file = File(path);
    final ledger = await file.exists()
        ? _TrafficLedger.decode(await file.readAsString())
        : _TrafficLedger();
    final before = ledger.encode();
    for (final snapshot in [...files.archived, ?current, ?live]) {
      ledger.merge(snapshot);
    }
    if (reset) {
      ledger.uplink = 0;
      ledger.downlink = 0;
      ledger.resetGeneration++;
    }

    RuntimeSnapshot? display = current;
    for (final snapshot in files.archived) {
      if (display == null ||
          (current == null && snapshot.savedAtMs > display.savedAtMs)) {
        display = snapshot;
      }
    }
    display ??= ledger.last?.withCounters(
      uplink: ledger.last!.uplink,
      downlink: ledger.last!.downlink,
      sampledAtMs: ledger.last!.sampledAtMs,
      available: false,
      error: 'runtimeStateUnavailable',
    );
    if (display != null) {
      final watermark = ledger.watermarks[display.sessionId];
      if (watermark != null) {
        display = display.withCounters(
          uplink: math.max(display.uplink, watermark.uplink),
          downlink: math.max(display.downlink, watermark.downlink),
          sampledAtMs: math.max(display.sampledAtMs, watermark.time),
          available: live?.available ?? display.available,
          error: live?.error ?? display.error,
        );
      }
      ledger.last = display;
    }
    if (before != ledger.encode()) {
      await _save(ledger);
    }

    final removable = files.archived
        .map((snapshot) => snapshot.sessionId)
        .where((id) => id != current?.sessionId && _sessionId.hasMatch(id))
        .toSet();
    if (removable.isNotEmpty) {
      try {
        // The first save is durable before any archive is removed. If deletion
        // fails, retain its watermark. If pruning fails, extra watermarks are safe.
        final remaining = await readRuntimeState(removable.toList());
        final retained = {
          for (final snapshot in remaining.archived) snapshot.sessionId,
          ?remaining.current?.sessionId,
        };
        final removed = removable.difference(retained);
        if (removed.isNotEmpty) {
          for (final id in removed) {
            ledger.watermarks.remove(id);
          }
          await _save(ledger);
        }
      } on Exception {
        // Cleanup is optional; the first committed ledger remains sufficient.
      }
    }

    if (display == null) {
      return null;
    }
    return display.withTotals(
      uplink: ledger.uplink,
      downlink: ledger.downlink,
      resetGeneration: ledger.resetGeneration,
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
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}

final _sessionId = RegExp(r'^[a-f0-9]{32}$');

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
  int resetGeneration = 0;
  RuntimeSnapshot? last;
  final Map<String, _Watermark> watermarks = {};

  _TrafficLedger();

  factory _TrafficLedger.decode(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> ||
        json['version'] != 1 ||
        json['sessions'] is! Map) {
      throw const FormatException('Invalid traffic totals');
    }
    final result = _TrafficLedger()
      ..uplink = _number(json, 'uplink')
      ..downlink = _number(json, 'downlink')
      ..resetGeneration = _number(json, 'resetGeneration');
    if (json['last'] != null) {
      result.last = RuntimeSnapshot.fromJson(
        json['last'] as Map<String, dynamic>,
      );
    }
    for (final entry in (json['sessions'] as Map).entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('Invalid traffic watermark');
      }
      result.watermarks[entry.key as String] = _Watermark(
        _number(entry.value as Map, 'uplink'),
        _number(entry.value as Map, 'downlink'),
        _number(entry.value as Map, 'time'),
      );
    }
    return result;
  }

  void merge(RuntimeSnapshot snapshot) {
    final previous = watermarks[snapshot.sessionId] ?? _Watermark(0, 0, 0);
    final next = _Watermark(
      math.max(snapshot.uplink, previous.uplink),
      math.max(snapshot.downlink, previous.downlink),
      math.max(snapshot.sampledAtMs, previous.time),
    );
    uplink += next.uplink - previous.uplink;
    downlink += next.downlink - previous.downlink;
    watermarks[snapshot.sessionId] = next;
  }

  String encode() => jsonEncode({
    'version': 1,
    'uplink': uplink,
    'downlink': downlink,
    'resetGeneration': resetGeneration,
    'last': ?last?.toJson(),
    'sessions': {
      for (final entry in watermarks.entries)
        entry.key: {
          'uplink': entry.value.uplink,
          'downlink': entry.value.downlink,
          'time': entry.value.time,
        },
    },
  });
}

class _Watermark {
  final int uplink;
  final int downlink;
  final int time;
  const _Watermark(this.uplink, this.downlink, this.time);
}
