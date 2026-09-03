import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
  });

  test(
    'refresh preserves nodes until reference protection is installed',
    () async {
      final source = await _source(database);
      final id = await database.coreConfigDao.insertRow(
        _node('Protected until ready', subId: source.id),
      );
      final original = await database.coreConfigDao.searchRow(id);
      final service = SubscriptionService.forTesting(
        database: database,
        loadRows: (_) async => SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('Replacement')],
        ),
        schedulePing: (_) =>
            fail('Failed replacement must not schedule a ping'),
      );

      final result = await service.refreshSubscriptionResult(source, false);
      expect(result.status, SubscriptionUpdateResult.writeFailed);
      expect(await database.coreConfigDao.searchRow(id), original);
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
        hasLength(1),
      );
    },
  );

  test('source form edits and automatic switches persist without downloading or rewriting nodes', () async {
    final source = await _source(database);
    final nodeId = await database.coreConfigDao.insertRow(
      _node('Existing', subId: source.id),
    );
    final original = await database.coreConfigDao.searchRow(nodeId);
    var downloads = 0;
    final service = _service(database, (input) async {
      downloads++;
      expect(input.url, 'https://example.com/new');
      expect(input.ageSecretKey, 'new-secret');
      return SubscriptionLoadResult(
        status: SubscriptionUpdateResult.success,
        rows: [_node('Refreshed')],
      );
    });
    expect(
      await service.saveSubscriptionInput(
        source.id,
        const SubscriptionInput(
          name: 'Renamed',
          url: 'https://example.com/new',
          ageSecretKey: 'new-secret',
          agePublicKey: 'new-public',
        ),
      ),
      SubscriptionUpdateResult.success,
    );
    expect(downloads, 0);
    expect(await database.coreConfigDao.searchRow(nodeId), original);
    final saved = (await database.subscriptionDao.searchRow(source.id))!;
    expect(saved.timestamp, source.timestamp);
    expect(saved.autoUpdate, isTrue);
    await service.setAutomaticUpdates(source.id, false);
    await service.refreshOutdatedSubscription(
      autoUpdateState: AutoUpdateState(),
      updateDownloading: false,
    );
    expect(downloads, 0);
    expect(
      (await database.subscriptionDao.searchRow(source.id))!.autoUpdate,
      isFalse,
    );
    final result = await service.refreshSubscriptionResult(saved, false);
    expect(
      result.success,
      isTrue,
    ); // Manual refresh is independent of automatic opt-out.
    expect(downloads, 1);
    expect(
      (await database.subscriptionDao.searchRow(source.id))!.autoUpdate,
      isFalse,
    );
  });

  test('saving source form invalidates an earlier in-flight refresh', () async {
    final source = await _source(database);
    final started = Completer<void>();
    final release = Completer<void>();
    final service = _service(database, (_) async {
      started.complete();
      await release.future;
      return SubscriptionLoadResult(
        status: SubscriptionUpdateResult.success,
        rows: [_node('Obsolete')],
      );
    });
    final refresh = service.refreshSubscriptionResult(source, false);
    await started.future;
    expect(
      await service.saveSubscriptionInput(
        source.id,
        const SubscriptionInput(name: 'New', url: 'https://example.com/new'),
      ),
      SubscriptionUpdateResult.success,
    );
    release.complete();
    expect((await refresh).superseded, isTrue);
    expect((await database.subscriptionDao.searchRow(source.id))!.name, 'New');
    expect(
      await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
      isEmpty,
    );
  });

  test(
    'nonempty import reports recognition failures without persisting them',
    () async {
      final imported = _node('Imported');
      final pings = <int>[];
      final service = _service(
        database,
        (_) async => SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [imported],
          parseFailureCount: 4,
        ),
        pings: pings,
      );
      final result = await service.insertSubscription(
        const SubscriptionInput(name: 'Source', url: 'https://example.com/sub'),
        false,
      );

      expect(result.success, isTrue);
      expect(result.count, 1);
      expect(result.parseFailureCount, 4);
      final source = (await database.subscriptionDao.allRows).single;
      expect(source.count, 1);
      expect(source.toJson(), isNot(contains('parseFailureCount')));
      final row = (await database.coreConfigDao.allOutboundRowsWithDataBySubId(
        source.id,
      )).single;
      expect(row.data, imported.data.value);
      expect(
        jsonDecode(utf8.decode(base64Decode(row.data!)))['tag'],
        'Imported',
      );
      expect(pings, [source.id]);
    },
  );

  test(
    'refresh preserves all references and favorites, but counts only imports',
    () async {
      final source = await _source(database);
      final originals = <CoreConfigData>[];
      for (final name in [
        'Run A',
        'Run B',
        'Fixed',
        'Exit',
        'Favorite',
        'Replace',
      ]) {
        final id = await database.coreConfigDao.insertRow(
          _node(
            name,
            subId: source.id,
          ).copyWith(favorite: Value(name == 'Favorite')),
        );
        originals.add((await database.coreConfigDao.searchRow(id))!);
      }
      var references = SubscriptionNodeReferences(
        runningIds: {originals[0].id, originals[1].id},
        fixedId: originals[2].id,
        finalExitId: originals[3].id,
      );
      int? parseFailures = 7;
      final service = _service(
        database,
        (_) async => SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('Run A'), _node('New')],
          parseFailureCount: parseFailures,
        ),
        readReferences: () => references,
      );

      final result = await service.refreshSubscriptionResult(source, false);
      expect(result.success, isTrue);
      expect(result.count, 2);
      expect(result.parseFailureCount, 7);
      for (final row in originals.take(5)) {
        expect(await database.coreConfigDao.searchRow(row.id), row);
      }
      expect(await database.coreConfigDao.searchRow(originals.last.id), isNull);
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
        hasLength(7),
      );
      final updated = (await database.subscriptionDao.searchRow(source.id))!;
      expect(updated.count, 2);
      expect(updated.expanded, source.expanded);
      expect(updated.ageSecretKey, source.ageSecretKey);
      expect(updated.agePublicKey, source.agePublicKey);

      // Disconnecting does not remove fixed, final-exit or favorite references.
      references = SubscriptionNodeReferences(
        fixedId: originals[2].id,
        finalExitId: originals[3].id,
      );
      parseFailures = null;
      final nextResult = await service.refreshSubscriptionResult(
        updated,
        false,
      );
      expect(nextResult.parseFailureCount, isNull);
      expect(await database.coreConfigDao.searchRow(originals[0].id), isNull);
      expect(await database.coreConfigDao.searchRow(originals[1].id), isNull);
      for (final row in originals.skip(2).take(3)) {
        expect(await database.coreConfigDao.searchRow(row.id), row);
      }

      references = const SubscriptionNodeReferences();
      await database.coreConfigDao.updateRow(
        originals[4].copyWith(favorite: false),
      );
      await service.refreshSubscriptionResult(updated, false);
      for (final row in originals) {
        expect(await database.coreConfigDao.searchRow(row.id), isNull);
      }
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
        hasLength(2),
      );
    },
  );

  test(
    'empty or failed results leave nodes, source settings and counts intact',
    () async {
      final source = await _source(database);
      final nodeId = await database.coreConfigDao.insertRow(
        _node('Existing', subId: source.id),
      );
      final before = await database.coreConfigDao.searchRow(nodeId);
      var loaded = const SubscriptionLoadResult(
        status: SubscriptionUpdateResult.success,
      );
      final service = _service(database, (_) async => loaded);
      final inserted = await service.insertSubscription(
        const SubscriptionInput(
          name: 'Empty',
          url: 'https://example.com/empty',
        ),
        false,
      );
      expect(inserted.success, isFalse);
      expect(inserted.status, SubscriptionUpdateResult.invalidContent);
      expect(await database.subscriptionDao.allRows, hasLength(1));
      final empty = await service.refreshSubscriptionResult(source, false);
      expect(empty.success, isFalse);
      expect(empty.status, SubscriptionUpdateResult.invalidContent);
      expect(
        await service.updateSubscription(
          source.id,
          const SubscriptionInput(
            name: 'Changed',
            url: 'https://example.com/new',
          ),
          showLoading: false,
        ),
        SubscriptionUpdateResult.invalidContent,
      );
      loaded = const SubscriptionLoadResult(
        status: SubscriptionUpdateResult.downloadFailed,
      );
      final failed = await service.refreshSubscriptionResult(source, false);
      expect(failed.status, SubscriptionUpdateResult.downloadFailed);
      expect(await database.subscriptionDao.searchRow(source.id), source);
      expect(await database.coreConfigDao.searchRow(nodeId), before);
    },
  );

  test(
    'an insert failure rolls back deletion and source metadata together',
    () async {
      final localId = await database.coreConfigDao.insertRow(_node('Local'));
      final source = await _source(database);
      final oldId = await database.coreConfigDao.insertRow(
        _node('Existing', subId: source.id),
      );
      final before = await database.coreConfigDao.searchRow(oldId);
      final service = _service(
        database,
        (_) async => SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('Conflict').copyWith(id: Value(localId))],
          parseFailureCount: 6,
        ),
      );
      final result = await service.refreshSubscriptionResult(source, false);
      expect(result.status, SubscriptionUpdateResult.writeFailed);
      expect(await database.coreConfigDao.searchRow(oldId), before);
      expect(await database.subscriptionDao.searchRow(source.id), source);
      expect((await database.coreConfigDao.searchRow(localId))!.name, 'Local');
    },
  );

  test(
    'duplicate refresh shares work and an edit supersedes its old response',
    () async {
      final source = await _source(database);
      final oldResponse = Completer<SubscriptionLoadResult>();
      final started = Completer<void>();
      var oldLoads = 0;
      final service = _service(database, (input) async {
        if (input.url == source.url) {
          oldLoads += 1;
          started.complete();
          return oldResponse.future;
        }
        return SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('New URL')],
          parseFailureCount: 2,
        );
      });
      final first = service.refreshSubscriptionResult(source, false);
      final duplicate = service.refreshSubscriptionResult(source, false);
      await started.future;
      expect(
        await service.updateSubscription(
          source.id,
          const SubscriptionInput(
            name: 'Edited source',
            url: 'https://example.com/new',
            ageSecretKey: 'new-secret',
            agePublicKey: 'new-public',
          ),
          showLoading: false,
        ),
        SubscriptionUpdateResult.success,
      );
      oldResponse.complete(
        SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('Obsolete')],
        ),
      );
      final obsolete = await first;
      expect(await duplicate, same(obsolete));
      expect(obsolete.superseded, isTrue);
      expect(obsolete.success, isFalse);
      expect(obsolete.count, 0);
      expect(oldLoads, 1);
      final current = (await database.subscriptionDao.searchRow(source.id))!;
      expect(current.url, 'https://example.com/new');
      expect(current.ageSecretKey, 'new-secret');
      expect(
        (await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id))
            .single
            .name,
        'New URL',
      );
    },
  );

  test(
    'source URL and Age are rechecked before accepting a downloaded result',
    () async {
      final source = await _source(database);
      final response = Completer<SubscriptionLoadResult>();
      final started = Completer<void>();
      final service = _service(database, (_) {
        started.complete();
        return response.future;
      });
      final refresh = service.refreshSubscriptionResult(source, false);
      await started.future;
      final edited = source.copyWith(
        agePublicKey: const Value('changed-public'),
      );
      await database.subscriptionDao.updateRow(edited);
      response.complete(
        SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('Obsolete')],
        ),
      );
      expect((await refresh).superseded, isTrue);
      expect(await database.subscriptionDao.searchRow(source.id), edited);
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
        isEmpty,
      );
    },
  );

  test('background refresh cannot supersede an in-flight user edit', () async {
    final source = await _source(database);
    final response = Completer<SubscriptionLoadResult>();
    final started = Completer<void>();
    final service = _service(database, (_) {
      started.complete();
      return response.future;
    });
    final edit = service.updateSubscription(
      source.id,
      const SubscriptionInput(name: 'Edited', url: 'https://example.com/new'),
      showLoading: false,
    );
    await started.future;
    final background = await service.refreshSubscriptionResult(source, false);
    expect(background.superseded, isTrue);
    response.complete(
      SubscriptionLoadResult(
        status: SubscriptionUpdateResult.success,
        rows: [_node('Edited')],
      ),
    );
    expect(await edit, SubscriptionUpdateResult.success);
    expect(
      (await database.subscriptionDao.searchRow(source.id))!.url,
      'https://example.com/new',
    );
  });

  test(
    'exclusive restore waits for downloads before restoring the same IDs',
    () async {
      final source = await _source(database);
      final oldNodeId = await database.coreConfigDao.insertRow(
        _node('Before restore', subId: source.id),
      );
      final response = Completer<SubscriptionLoadResult>();
      final started = Completer<void>();
      final service = _service(database, (_) {
        started.complete();
        return response.future;
      });
      final oldRequest = service.refreshSubscriptionResult(source, false);
      await started.future;
      var restoreStarted = false;
      final restoring = DataMaintenance.exclusive(() async {
        restoreStarted = true;
        await database.transaction(() async {
          await database.coreConfigDao.clear();
          await database.subscriptionDao.clear();
          await database.subscriptionDao.insertRow(source.toCompanion(false));
          await database.coreConfigDao.insertRow(
            _node('Restored', subId: source.id).copyWith(id: Value(oldNodeId)),
          );
        });
      });
      addTearDown(() async {
        if (!response.isCompleted) {
          response.complete(
            const SubscriptionLoadResult(
              status: SubscriptionUpdateResult.downloadFailed,
            ),
          );
        }
        await oldRequest;
        await restoring;
      });
      expect(restoreStarted, isFalse);
      await expectLater(
        service.refreshSubscriptionResult(source, false),
        throwsStateError,
      );
      response.complete(
        SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('Old downloaded data')],
        ),
      );
      await oldRequest;
      await restoring;
      expect(restoreStarted, isTrue);
      final restoredRows = await database.coreConfigDao
          .allOutboundRowsWithDataBySubId(source.id);
      expect(restoredRows, hasLength(1));
      expect(restoredRows.single.id, oldNodeId);
      expect(restoredRows.single.name, 'Restored');
      expect(await database.subscriptionDao.searchRow(source.id), source);
    },
  );

  test(
    'explicit source deletion removes referenced rows without orphaning them',
    () async {
      final source = await _source(database);
      final rawId = await database.coreConfigDao.insertRow(
        _node(
          'Legacy Raw',
          subId: source.id,
        ).copyWith(type: const Value('raw')),
      );
      final originalRaw = await database.coreConfigDao.searchRow(rawId);
      await database.coreConfigDao.insertRow(
        _node(
          'Favorite',
          subId: source.id,
        ).copyWith(favorite: const Value(true)),
      );
      final localId = await database.coreConfigDao.insertRow(_node('Local'));
      final service = _service(
        database,
        (_) async => const SubscriptionLoadResult(
          status: SubscriptionUpdateResult.invalidContent,
        ),
      );
      expect(await database.subscriptionDao.deleteRow(0), 0);
      expect(
        await service.deleteSubscription(
          source.id,
          prepareDeletion: (_) async => false,
        ),
        0,
      );
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
        hasLength(1),
      );
      expect(
        await service.deleteSubscription(
          source.id,
          prepareDeletion: (_) async => true,
        ),
        1,
      );
      expect(await database.subscriptionDao.searchRow(source.id), isNull);
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
        isEmpty,
      );
      expect(await database.coreConfigDao.searchRow(localId), isNotNull);
      expect(await database.coreConfigDao.searchRow(rawId), originalRaw);
    },
  );
}

SubscriptionService _service(
  AppDatabase database,
  Future<SubscriptionLoadResult> Function(SubscriptionInput) loadRows, {
  SubscriptionReferenceReader? readReferences,
  List<int>? pings,
}) => SubscriptionService.forTesting(
  database: database,
  loadRows: loadRows,
  schedulePing: (id) {
    pings?.add(id);
  },
  readReferences: readReferences ?? () => const SubscriptionNodeReferences(),
);

Future<SubscriptionData> _source(AppDatabase database) async {
  final id = await database.subscriptionDao.insertRow(
    SubscriptionCompanion.insert(
      name: 'Source',
      url: 'https://example.com/sub',
      ageSecretKey: const Value('old-secret'),
      agePublicKey: const Value('old-public'),
      timestamp: DateTime.utc(2024),
      count: 1,
      expanded: false,
    ),
  );
  return (await database.subscriptionDao.searchRow(id))!;
}

CoreConfigCompanion _node(String name, {int subId = 0}) =>
    CoreConfigCompanion.insert(
      name: name,
      type: 'outbound',
      tags: 'socks',
      data: Value(
        base64Encode(
          utf8.encode(jsonEncode({'protocol': 'socks', 'tag': name})),
        ),
      ),
      delay: 0,
      subId: subId,
    );
