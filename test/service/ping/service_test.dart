import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/connection/resolver.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/ping/batch.dart';
import 'package:onexray/service/ping/service.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final bus = AppEventBus();
    addTearDown(bus.close);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('manual retest refreshes location per node and keeps delay on location failure', () async {
    final first = await db.coreConfigDao.insertRow(_node('First'));
    final second = await db.coreConfigDao.insertRow(_node('Second'));
    var run = 0;
    final service = PingService.forTesting(
      database: db,
      runBatch: (_, _) async {
        run++;
        return run == 1
            ? const [
                PingBatchResult(true, 0, '', countryCode: 'US'),
                PingBatchResult(true, 20, '', countryCode: 'JP'),
              ]
            : const [
                PingBatchResult(true, 12, '', locationError: 'unavailable'),
                PingBatchResult(true, 15, '', countryCode: 'SG'),
              ];
      },
    );
    await service.pingConfigIds([first, second]);
    expect((await db.coreConfigDao.searchRow(first))!.countryCode, 'US');
    expect((await db.coreConfigDao.searchRow(second))!.countryCode, 'JP');
    await service.pingConfigIds([first, second]);
    expect(run, 1);
    await service.pingConfigIds([first, second], force: true);
    final row = (await db.coreConfigDao.searchRow(first))!;
    expect(row.delay, 12);
    expect(row.countryCode, isNull);
    expect(row.locationSource, isNull);
    expect((await db.coreConfigDao.searchRow(second))!.countryCode, 'SG');
    expect(
      (await db.coreConfigDao.searchRow(second))!.locationSource,
      'pingBatch',
    );
  });

  test(
    'legacy auto=false cannot disable imported-node or subscription queues',
    () async {
      await PreferencesKey().savePingState({'autoPingNewConfigs': false});
      final local = await db.coreConfigDao.insertRow(_node('Local'));
      final remote = await db.coreConfigDao.insertRow(
        _node('Remote', subId: 9),
      );
      var batches = 0;
      final service = PingService.forTesting(
        database: db,
        runBatch: (sources, state) async {
          expect(state.autoPingNewConfigs, isFalse);
          batches++;
          return _successes(sources.length);
        },
      );

      service.schedulePingConfigIds([local, local]);
      service.schedulePingSubscriptions([9, 9]);
      await service.pingConfigIds([local, remote]);

      // The last queued selection sees both measurements and does not probe again.
      expect(batches, 2);
      for (final id in [local, remote]) {
        final row = (await db.coreConfigDao.searchRow(id))!;
        expect(row.delay, 20);
        expect(row.lastMeasuredAt, isNotNull);
      }
      expect(AppEventBus.instance.state.pinging, isFalse);
    },
  );

  test('five-node batch commits let selection finish while the remaining two continue', () async {
    final ids = <int>[];
    for (var index = 0; index < 7; index++) {
      ids.add(await db.coreConfigDao.insertRow(_node('Node $index')));
    }
    final secondStarted = Completer<void>();
    final releaseSecond = Completer<void>();
    final sizes = <int>[];
    Future<void>? probing;
    addTearDown(() async {
      if (!releaseSecond.isCompleted) releaseSecond.complete();
      await probing;
    });
    final service = PingService.forTesting(
      database: db,
      runBatch: (sources, _) async {
        sizes.add(sources.length);
        if (sizes.length == 2) {
          secondStarted.complete();
          await releaseSecond.future;
        }
        return _successes(sources.length);
      },
    );
    final resolver = ConnectionResolver(
      rows: () => db.select(db.coreConfig).watch(),
      probe: (ids) => probing = service.pingConfigIds(ids),
    );

    final resolving = resolver.resolve(
      ConnectionSettings(smart: SmartRoutingSettings(entryCount: 2)),
    );
    await secondStarted.future.timeout(const Duration(seconds: 5));
    final selected = await resolving.timeout(const Duration(seconds: 5));
    expect(sizes, [5, 2]);
    expect(releaseSecond.isCompleted, isFalse);
    expect(selected.map((node) => node.id), ids.take(2));
    expect(
      (await db.coreConfigDao.searchRow(ids.last))!.lastMeasuredAt,
      isNull,
    );
    releaseSecond.complete();
    await probing;
    expect(
      (await db.coreConfigDao.searchRow(ids.last))!.lastMeasuredAt,
      isNotNull,
    );
    expect(selected.map((node) => node.id), ids.take(2));
  });

  test('failed results cannot look healthy and delayed writes preserve edits and favorites', () async {
    final first = await db.coreConfigDao.insertRow(_node('Failure'));
    final second = await db.coreConfigDao.insertRow(_node('Edited'));
    final started = Completer<void>();
    final release = Completer<void>();
    final service = PingService.forTesting(
      database: db,
      runBatch: (_, _) async {
        started.complete();
        await release.future;
        return const [
          PingBatchResult(false, 7, 'failure'),
          PingBatchResult(true, 9, ''),
        ];
      },
    );
    final probing = service.pingConfigIds([first, second]);
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      await probing;
    });
    await started.future.timeout(const Duration(seconds: 5));
    await (db.update(db.coreConfig)..where((row) => row.id.equals(first)))
        .write(const CoreConfigCompanion(favorite: Value(true)));
    final edit = _node(
      'New content',
      subId: 9,
    ).copyWith(id: Value(second), favorite: const Value(true));
    await db.update(db.coreConfig).replace(edit);
    release.complete();
    await probing;

    final failed = (await db.coreConfigDao.searchRow(first))!;
    expect(failed.delay, PingDelayConstants.error);
    expect(failed.lastMeasuredAt, isNotNull);
    expect(failed.favorite, isTrue);
    final edited = (await db.coreConfigDao.searchRow(second))!;
    expect(edited.name, 'New content');
    expect(edited.subId, 9);
    expect(edited.delay, PingDelayConstants.unknown);
    expect(edited.lastMeasuredAt, isNull);
    expect(edited.favorite, isTrue);
  });

  test(
    'maintenance drains registered queued work before restoring the same IDs',
    () async {
      final first = await db.coreConfigDao.insertRow(_node('First'));
      final second = await db.coreConfigDao.insertRow(_node('Second'));
      final started = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      var restored = false;
      final service = PingService.forTesting(
        database: db,
        runBatch: (sources, _) async {
          calls++;
          started.complete();
          await release.future;
          return _successes(sources.length);
        },
      );
      final active = service.pingConfigIds([first]);
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await active;
      });
      await started.future.timeout(const Duration(seconds: 5));
      final queued = service.pingConfigIds([second]);
      final queuedRejected = expectLater(queued, throwsStateError);
      final restoring = DataMaintenance.exclusive(() async {
        expect(calls, 1);
        await db.transaction(() async {
          await db.delete(db.coreConfig).go();
          for (final id in [first, second]) {
            await db.coreConfigDao.insertRow(
              _node('Restored').copyWith(id: Value(id)),
            );
          }
        });
        restored = true;
      });
      expect(restored, isFalse);
      release.complete();
      await active;
      await queuedRejected;
      await restoring;

      expect(restored, isTrue);
      expect(calls, 1);
      for (final id in [first, second]) {
        final row = (await db.coreConfigDao.searchRow(id))!;
        expect(row.name, 'Restored');
        expect(row.delay, PingDelayConstants.unknown);
        expect(row.lastMeasuredAt, isNull);
      }
    },
  );
}

List<PingBatchResult> _successes(int count) =>
    List.generate(count, (_) => const PingBatchResult(true, 20, ''));

CoreConfigCompanion _node(String name, {int subId = 0}) =>
    CoreConfigCompanion.insert(
      name: name,
      type: 'outbound',
      tags: 'socks',
      delay: PingDelayConstants.unknown,
      subId: subId,
      data: Value(
        base64Encode(
          utf8.encode(
            jsonEncode({
              'outbounds': [
                {
                  'tag': name,
                  'protocol': 'socks',
                  'settings': {'address': '127.0.0.1', 'port': 1080},
                },
              ],
            }),
          ),
        ),
      ),
    );
