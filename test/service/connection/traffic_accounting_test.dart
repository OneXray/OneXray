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

  test('parses the current libXray session without a plan identity', () {
    final traffic = RuntimeSnapshot.fromJson({
      'version': 1,
      'session': {
        'id': _id('a'),
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

    expect(traffic.sessionId, _id('a'));
    expect(traffic.uplink, 10);
    expect(traffic.totalUplink, 0);
  });

  test(
    'deduplicates saved/live counters and reset keeps the watermark',
    () async {
      var current = _traffic('a', 10, 20);
      final accounting = TrafficAccounting(
        path: ledger.path,
        readRuntimeSnapshot: () async => current,
      );

      expect((await accounting.read())!.totalUplink, 10);
      expect(
        (await accounting.read(live: _traffic('a', 15, 30, time: 4)))!
            .totalUplink,
        15,
      );
      final reset = (await accounting.read(reset: true))!;
      expect(reset.totalUplink, 0);
      expect(reset.uplink, 15);

      current = _traffic('a', 19, 33, time: 5);
      final reopened = TrafficAccounting(
        path: ledger.path,
        readRuntimeSnapshot: () async => current,
      );
      final next = (await reopened.read())!;
      expect(next.totalUplink, 4);
      expect(next.totalDownlink, 3);
    },
  );

  test(
    'a new session adds only the counters still available from it',
    () async {
      var current = _traffic('a', 10, 20);
      final accounting = TrafficAccounting(
        path: ledger.path,
        readRuntimeSnapshot: () async => current,
      );
      await accounting.read();

      current = _traffic('b', 3, 6);
      final next = (await accounting.read())!;
      expect(next.totalUplink, 13);
      expect(next.totalDownlink, 26);
    },
  );

  test('offline reads and reset use the last App-owned value', () async {
    var online = true;
    final accounting = TrafficAccounting(
      path: ledger.path,
      readRuntimeSnapshot: () async {
        if (!online) throw const SocketException('Core stopped');
        return _traffic('a', 7, 9);
      },
    );
    await accounting.read();
    online = false;

    final cached = (await accounting.read())!;
    expect(cached.available, false);
    expect(cached.totalUplink, 7);
    final reset = (await accounting.read(reset: true))!;
    expect(reset.totalUplink, 0);
    expect(reset.uplink, 7);
  });

  test('invalid or unwritable totals never hide live counters', () async {
    await ledger.writeAsString(
      '{"version":1,"sessions":{},"resetGeneration":0}',
    );
    final repaired = TrafficAccounting(
      path: ledger.path,
      readRuntimeSnapshot: () async => _traffic('a', 7, 9),
    );
    final live = await repaired.read(live: _traffic('a', 8, 10, time: 4));
    expect(live?.available, true);
    expect(live?.uplink, 8);

    final unwritable = TrafficAccounting(
      path: p.join(directory.path, 'unwritable.json'),
      readRuntimeSnapshot: () async => _traffic('b', 3, 5),
      write: (_) async => throw const FileSystemException('read only'),
    );
    expect(
      (await unwritable.read(live: _traffic('b', 4, 6, time: 4)))?.uplink,
      4,
    );
  });
}

RuntimeSnapshot _traffic(String digit, int up, int down, {int time = 3}) =>
    RuntimeSnapshot(
      sessionId: _id(digit),
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
