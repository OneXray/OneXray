import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/connection/traffic_accounting.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late File ledger;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('onexray-traffic-');
    ledger = File(p.join(directory.path, 'traffic-totals.json'));
    addTearDown(() => directory.delete(recursive: true));
  });

  test('Go session JSON needs no device ledger', () {
    final snapshot = RuntimeSnapshot.fromJson({
      'version': 1,
      'session': {
        'id': _id('a'),
        'planId': _id('b'),
        'startedAtMs': 1,
        'endedAtMs': 0,
        'uplink': 10,
        'downlink': 20,
      },
      'available': true,
      'sampledAtMs': 2,
      'savedAtMs': 3,
      'error': '',
    });
    expect(snapshot.uplink, 10);
    expect(snapshot.totalUplink, 0);
    expect(
      snapshot.withTotals(uplink: 99, downlink: 100, resetGeneration: 2).uplink,
      10,
    );
  });

  test('saved and live counters deduplicate; reset preserves session watermarks', () async {
    var current = _snapshot('a', 10, 20);
    final accounting = TrafficAccounting(
      path: ledger.path,
      readRuntimeState: (_) async => RuntimeState(current: current),
    );
    expect((await accounting.read())!.totalUplink, 10);
    final live = _snapshot('a', 15, 30, time: 4);
    expect((await accounting.read(live: live))!.totalUplink, 15);
    // The host file can lag behind the foreground metrics without subtracting.
    expect((await accounting.read())!.uplink, 15);
    final reset = (await accounting.read(reset: true))!;
    expect(reset.totalUplink, 0);
    expect(reset.totalDownlink, 0);
    expect(reset.uplink, 15);
    expect(reset.downlink, 30);
    expect(reset.resetGeneration, 1);
    current = _snapshot('a', 12, 25);
    expect((await accounting.read())!.totalUplink, 0);
    final reopened = TrafficAccounting(
      path: ledger.path,
      readRuntimeState: (_) async => RuntimeState(current: current),
    );
    final next = (await reopened.read(live: _snapshot('a', 19, 33, time: 5)))!;
    expect(next.totalUplink, 4);
    expect(next.totalDownlink, 3);
    expect(next.uplink, 19);
    expect(next.resetGeneration, 1);
  });

  test(
    'archive deletion follows save, and failed deletion retains its watermark',
    () async {
      final current = _snapshot('c', 3, 6);
      var archives = [_snapshot('a', 10, 20), _snapshot('b', 4, 8)];
      var allowDelete = false;
      final accounting = TrafficAccounting(
        path: ledger.path,
        readRuntimeState: (remove) async {
          if (remove.isNotEmpty) {
            final saved = jsonDecode(await ledger.readAsString()) as Map;
            expect(saved['uplink'], 17);
            expect((saved['sessions'] as Map).keys, containsAll(remove));
            expect(remove, isNot(contains(current.sessionId)));
            if (allowDelete) {
              archives = archives
                  .where((s) => !remove.contains(s.sessionId))
                  .toList();
            }
          }
          return RuntimeState(current: current, archived: archives);
        },
      );
      expect((await accounting.read())!.totalUplink, 17);
      expect((await accounting.read())!.totalUplink, 17);
      expect(
        (jsonDecode(await ledger.readAsString())['sessions'] as Map),
        hasLength(3),
      );
      allowDelete = true;
      expect((await accounting.read())!.totalUplink, 17);
      expect(archives, isEmpty);
      expect(
        (jsonDecode(await ledger.readAsString())['sessions'] as Map).keys,
        [current.sessionId],
      );
      expect((await accounting.read())!.totalUplink, 17);
    },
  );

  test(
    'failed first save never deletes an archive and retry counts it once',
    () async {
      var archives = [_snapshot('a', 7, 9)];
      var removals = 0;
      var failWrite = true;
      final accounting = TrafficAccounting(
        path: ledger.path,
        readRuntimeState: (remove) async {
          if (remove.isNotEmpty) {
            removals++;
            archives = [];
          }
          return RuntimeState(
            current: _snapshot('b', 1, 2),
            archived: archives,
          );
        },
        write: (text) async {
          if (failWrite) {
            throw const FileSystemException('Injected save failure');
          }
          await ledger.writeAsString(text, flush: true);
        },
      );
      await expectLater(accounting.read(), throwsA(isA<FileSystemException>()));
      expect(removals, 0);
      expect(archives, hasLength(1));
      expect(await ledger.exists(), false);
      failWrite = false;
      expect((await accounting.read())!.totalUplink, 8);
      expect((await accounting.read())!.totalUplink, 8);
      expect(removals, 1);
    },
  );

  test(
    'failed watermark pruning leaves the first committed totals recoverable',
    () async {
      var archives = [_snapshot('a', 7, 9)];
      var saves = 0;
      final accounting = TrafficAccounting(
        path: ledger.path,
        readRuntimeState: (remove) async {
          if (remove.isNotEmpty) {
            archives = [];
          }
          return RuntimeState(
            current: _snapshot('b', 1, 2),
            archived: archives,
          );
        },
        write: (text) async {
          if (++saves == 2) {
            throw const FileSystemException('Injected pruning save failure');
          }
          await ledger.writeAsString(text, flush: true);
        },
      );
      expect((await accounting.read())!.totalUplink, 8);
      expect(archives, isEmpty);
      expect(
        (jsonDecode(await ledger.readAsString())['sessions'] as Map),
        hasLength(2),
      );
      expect((await accounting.read())!.totalUplink, 8);
    },
  );

  test(
    'instances share a path queue and read archives only after earlier cleanup',
    () async {
      var archives = [_snapshot('a', 7, 9)];
      final entered = Completer<void>();
      final release = Completer<void>();
      var reads = 0;
      Future<RuntimeState> read(List<String> remove) async {
        if (++reads == 1) {
          entered.complete();
          await release.future;
        }
        if (remove.isNotEmpty) {
          archives = [];
        }
        return RuntimeState(current: _snapshot('b', 1, 2), archived: archives);
      }

      final first = TrafficAccounting(
        path: ledger.path,
        readRuntimeState: read,
      );
      final second = TrafficAccounting(
        path: ledger.path,
        readRuntimeState: read,
      );
      final reading = first.read();
      await entered.future;
      final queued = second.read();
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      release.complete();
      expect((await reading)!.totalUplink, 8);
      expect((await queued)!.totalUplink, 8);
    },
  );

  test(
    'a delayed live sample from an archived session cannot re-enter totals',
    () async {
      final accounting = TrafficAccounting(
        path: ledger.path,
        readRuntimeState: (_) async =>
            RuntimeState(current: _snapshot('b', 1, 2)),
      );
      await expectLater(
        accounting.read(live: _snapshot('a', 100, 200)),
        throwsFormatException,
      );
      expect(await ledger.exists(), false);
      expect((await accounting.read())!.totalUplink, 1);
    },
  );

  test('reset can clear only App totals while the runtime HTTP endpoint is unavailable', () async {
    var readable = true;
    final accounting = TrafficAccounting(
      path: ledger.path,
      readRuntimeState: (_) async {
        if (!readable) {
          throw const FileSystemException('Provider unavailable');
        }
        return RuntimeState(current: _snapshot('a', 7, 9));
      },
    );
    await accounting.read();
    readable = false;
    final offline = (await accounting.read(reset: true))!;
    expect(offline.uplink, 7);
    expect(offline.totalUplink, 0);
    expect(offline.available, false);
    final saved = jsonDecode(await ledger.readAsString()) as Map;
    expect(saved['uplink'], 0);
    expect(saved['resetGeneration'], 1);
    expect((saved['sessions'] as Map)[_id('a')]['uplink'], 7);
    readable = true;
    final current = (await accounting.read())!;
    expect(current.uplink, 7);
    expect(current.totalUplink, 0);
  });

  test(
    'offline reopen retains last session and totals until HTTP returns',
    () async {
      var online = true;
      var current = _snapshot('a', 7, 9);
      var archives = <RuntimeSnapshot>[];
      Future<RuntimeState> read(List<String> remove) async {
        if (!online) throw const SocketException('Core stopped');
        archives.removeWhere((snapshot) => remove.contains(snapshot.sessionId));
        return RuntimeState(current: current, archived: archives);
      }

      final first = TrafficAccounting(
        path: ledger.path,
        readRuntimeState: read,
      );
      await first.read(live: _snapshot('a', 10, 15, time: 4));
      online = false;
      final reopened = TrafficAccounting(
        path: ledger.path,
        readRuntimeState: read,
      );
      final cached = (await reopened.read())!;
      expect(cached.sessionId, _id('a'));
      expect(cached.uplink, 10);
      expect(cached.totalUplink, 10);
      expect(cached.available, false);
      await expectLater(
        reopened.read(live: _snapshot('a', 100, 200)),
        throwsA(isA<SocketException>()),
      );
      expect((await reopened.read())!.totalUplink, 10);
      expect((await reopened.read(reset: true))!.totalUplink, 0);
      online = true;
      archives = [_snapshot('a', 12, 19, time: 5)];
      current = _snapshot('b', 3, 6, time: 6);
      final next = (await reopened.read())!;
      expect(next.sessionId, _id('b'));
      expect(next.uplink, 3);
      expect(next.totalUplink, 5);
      expect(next.totalDownlink, 10);
      expect(archives, isEmpty);
      expect((await reopened.read())!.totalUplink, 5);
    },
  );
}

RuntimeSnapshot _snapshot(String digit, int up, int down, {int time = 3}) =>
    RuntimeSnapshot(
      sessionId: _id(digit),
      planId: _id('f'),
      startedAtMs: 1,
      endedAtMs: 0,
      uplink: up,
      downlink: down,
      available: true,
      sampledAtMs: time,
      savedAtMs: time,
      error: '',
    );

String _id(String digit) => List.filled(32, digit).join();
