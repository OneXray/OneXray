import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/advanced/xray/data_update/state.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/servers/subscription/model.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/servers/subscription/failure.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/core/errors/failure.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
  });

  test('new subscriptions default to no HWID and opted-in sources get distinct IDs', () async {
    final inputs = <SubscriptionInput>[];
    final service = _service(database, (input) async {
      inputs.add(input);
      return SubscriptionLoadResult(
        status: SubscriptionUpdateResult.success,
        rows: [_node('Node')],
      );
    });
    for (final enabled in [false, true, true]) {
      final result = await service.insertSubscription(
        SubscriptionInput(
          name: 'Source ${inputs.length}',
          url: 'https://example.com/${inputs.length}',
          hwidEnabled: enabled,
        ),
      );
      expect(result.success, isTrue);
      final row = (await database.subscriptionDao.searchRow(result.subId))!;
      expect(row.hwidEnabled, enabled);
      expect(row.hwid, inputs.last.hwid);
      if (enabled) {
        expect(
          row.hwid,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
      } else {
        expect(row.hwid, isNull);
      }
    }
    expect(inputs[1].hwid, isNot(inputs[2].hwid));
  });

  test(
    'refresh, toggles and provider edits retain the original HWID',
    () async {
      final inputs = <SubscriptionInput>[];
      Future<SubscriptionLoadResult> load(SubscriptionInput input) async {
        inputs.add(input);
        return SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('Node')],
        );
      }

      final service = _service(database, load);
      final result = await service.insertSubscription(
        const SubscriptionInput(
          name: 'Provider',
          url: 'https://example.com/one',
          hwidEnabled: true,
          hwid: 'draft-device-identity',
        ),
      );
      final row = (await database.subscriptionDao.searchRow(result.subId))!;
      expect(row.hwid, 'draft-device-identity');

      // A fresh service reads identity/consent from storage, not an in-memory map.
      final restarted = _service(database, load);
      for (final enabled in [false, true]) {
        expect(
          await restarted.saveSubscriptionInput(
            row.id,
            SubscriptionInput(
              name: 'Renamed',
              url: 'https://example.com/two',
              hwidEnabled: enabled,
            ),
          ),
          SubscriptionUpdateResult.success,
        );
        expect(
          (await restarted.refreshSubscriptionResult(row)).success,
          isTrue,
        );
        expect(inputs.last.hwid, row.hwid);
        expect(inputs.last.hwidEnabled, enabled);
      }
      await restarted.saveSubscriptionInput(
        row.id,
        const SubscriptionInput(
          name: 'Another provider',
          url: 'https://another.example/one',
        ),
      );
      final changed = (await database.subscriptionDao.searchRow(row.id))!;
      expect(changed.hwidEnabled, isFalse);
      expect(changed.hwid, row.hwid);
      await restarted.saveSubscriptionInput(
        row.id,
        SubscriptionInput(
          name: changed.name,
          url: changed.url,
          hwidEnabled: true,
          hwid: 'must-not-replace-the-saved-identity',
        ),
      );
      expect(
        (await restarted.refreshSubscriptionResult(changed)).success,
        isTrue,
      );
      expect(inputs.last.hwid, row.hwid);
    },
  );

  for (final enabled in [false, true]) {
    test(
      'first edit saves the generated draft HWID (enabled: $enabled)',
      () async {
        final source = await _source(database);
        final service = _service(
          database,
          (_) async =>
              throw StateError('Saving must not download the subscription'),
        );
        await service.saveSubscriptionInput(
          source.id,
          SubscriptionInput(
            name: source.name,
            url: source.url,
            hwidEnabled: enabled,
            hwid: 'first-draft-identity',
          ),
        );
        final saved = (await database.subscriptionDao.searchRow(source.id))!;
        expect(saved.hwid, 'first-draft-identity');
        expect(saved.hwidEnabled, enabled);
      },
    );
  }

  for (final useService in [true, false]) {
    test(
      'changing HWID consent rejects in-flight content (service: $useService)',
      () async {
        final source = await _source(database);
        final keptId = await database.coreConfigDao.insertRow(
          _node('Keep', subId: source.id),
        );
        final started = Completer<void>();
        final pending = Completer<SubscriptionLoadResult>();
        final service = _service(database, (_) {
          started.complete();
          return pending.future;
        });
        final refresh = service.refreshSubscriptionResult(source);
        await started.future;
        if (useService) {
          await service.saveSubscriptionInput(
            source.id,
            SubscriptionInput(
              name: source.name,
              url: source.url,
              ageSecretKey: source.ageSecretKey,
              agePublicKey: source.agePublicKey,
              hwidEnabled: true,
            ),
          );
        } else {
          await database.subscriptionDao.updateRow(
            source.copyWith(
              hwidEnabled: true,
              hwid: const Value('new-identity'),
            ),
          );
        }
        pending.complete(
          SubscriptionLoadResult(
            status: SubscriptionUpdateResult.success,
            rows: [_node('Obsolete')],
          ),
        );
        expect((await refresh).superseded, isTrue);
        final nodes = await database.coreConfigDao
            .allOutboundRowsWithDataBySubId(source.id);
        expect(nodes.single.id, keptId);
        expect(
          (await database.subscriptionDao.searchRow(source.id))!.timestamp,
          source.timestamp,
        );
      },
    );
  }

  test(
    'manual refresh-all joins repeats and continues after a failed source',
    () async {
      final first = await _source(database);
      final secondId = await database.subscriptionDao.insertRow(
        SubscriptionCompanion.insert(
          name: 'Second',
          url: 'https://example.com/second',
          timestamp: DateTime.now(),
        ),
      );
      final existing = await database.coreConfigDao.insertRow(
        _node('Keep', subId: first.id),
      );
      final started = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final pings = <int>[];
      final service = _service(database, (input) async {
        expect(AppEventBus.instance.state.downloading, isTrue);
        calls++;
        if (input.name == first.name) {
          started.complete();
          await release.future;
          return const SubscriptionLoadResult(
            status: SubscriptionUpdateResult.invalidContent,
          );
        }
        return SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('New')],
        );
      }, pings: pings);
      final refreshing = service.refreshAll();
      await started.future;
      expect(identical(refreshing, service.refreshAll()), isTrue);
      release.complete();
      final results = await refreshing;
      expect(results.values.map((row) => row.success), [false, true]);
      expect(calls, 2);
      expect(pings, [secondId]);
      expect(await database.coreConfigDao.searchRow(existing), isNotNull);
      expect(AppEventBus.instance.state.downloading, isFalse);
      final message = subscriptionRefreshMessage(AppLocalizationsEn(), results);
      expect(message, contains('Source:'));
      expect(message, contains('Second:'));
      expect(message, contains(AppLocalizationsEn().prototypeUsableNodes(1)));
    },
  );

  test('clear-data stops the refresh-all batch and releases loading', () async {
    await _source(database);
    await database.subscriptionDao.insertRow(
      SubscriptionCompanion.insert(
        name: 'Later',
        url: 'https://example.com/later',
        timestamp: DateTime.now(),
      ),
    );
    final started = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    final service = _service(database, (_) async {
      calls++;
      started.complete();
      await release.future;
      return SubscriptionLoadResult(
        status: SubscriptionUpdateResult.success,
        rows: [_node('New')],
      );
    });
    final refreshing = service.refreshAll();
    final cancelled = expectLater(
      refreshing,
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'cancelled')),
    );
    await started.future;
    final paused = service.pauseForDataClear();
    release.complete();
    await cancelled;
    await paused;
    expect(calls, 1);
    expect(AppEventBus.instance.state.downloading, isFalse);
    service.resumeAfterDataClear();
  });

  test(
    'refresh before coordinator initialization protects persisted selections',
    () async {
      final source = await _source(database);
      final fixedId = await database.coreConfigDao.insertRow(
        _node('Fixed', subId: source.id),
      );
      final exitId = await database.coreConfigDao.insertRow(
        _node('Exit', subId: source.id),
      );
      await database.connectionConfigDao.commit(
        configurationJson: jsonEncode({
          'connection': {
            'selection': {'kind': 'server', 'id': fixedId},
            'smart': {'finalExitId': exitId},
          },
        }),
      );
      final service = SubscriptionService.forTesting(
        database: database,
        loadRows: (_) async => SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('Replacement')],
        ),
        schedulePing: (_) {},
      );

      final result = await service.refreshSubscriptionResult(source);
      expect(result.status, SubscriptionUpdateResult.success);
      expect(await database.coreConfigDao.searchRow(fixedId), isNotNull);
      expect(await database.coreConfigDao.searchRow(exitId), isNotNull);
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
        hasLength(3),
      );
    },
  );

  test('source edits do not download, and global automatic opt-out still allows manual refresh', () async {
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
    await service.refreshOutdatedSubscription(
      autoUpdateState: AutoUpdateState()..subscriptionEnabled = false,
    );
    expect(downloads, 0);
    expect(await database.subscriptionDao.searchRow(source.id), saved);
    final result = await service.refreshSubscriptionResult(saved);
    expect(result.success, isTrue);
    expect(downloads, 1);
  });

  test(
    'global automatic updates refresh all due sources and skip fresh sources',
    () async {
      final now = DateTime.now();
      for (final entry in {
        'Due A': const Duration(days: 2),
        'Due B': const Duration(hours: 25),
        'Fresh': const Duration(hours: 1),
      }.entries) {
        await database.subscriptionDao.insertRow(
          SubscriptionCompanion.insert(
            name: entry.key,
            url: 'https://example.com/${Uri.encodeComponent(entry.key)}',
            timestamp: now.subtract(entry.value),
          ),
        );
      }
      final downloads = <String>[];
      final service = _service(database, (input) async {
        downloads.add(input.name);
        return SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node(input.name)],
        );
      });
      final settings = AutoUpdateState()
        ..subscriptionEnabled = true
        ..subscriptionInterval = AutoUpdateInterval.oneDay;

      await service.refreshOutdatedSubscription(autoUpdateState: settings);
      expect(downloads, unorderedEquals(['Due A', 'Due B']));

      downloads.clear();
      await service.refreshOutdatedSubscription(autoUpdateState: settings);
      expect(downloads, isEmpty);
    },
  );

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
    final refresh = service.refreshSubscriptionResult(source);
    await started.future;
    expect(AppEventBus.instance.state.downloading, isTrue);
    expect(
      await service.saveSubscriptionInput(
        source.id,
        const SubscriptionInput(name: 'New', url: 'https://example.com/new'),
      ),
      SubscriptionUpdateResult.success,
    );
    release.complete();
    expect((await refresh).superseded, isTrue);
    expect(AppEventBus.instance.state.downloading, isFalse);
    expect((await database.subscriptionDao.searchRow(source.id))!.name, 'New');
    expect(
      await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
      isEmpty,
    );
  });

  test('nonempty import reports the number of saved nodes without persisting counts', () async {
    final imported = _node('Imported');
    final pings = <int>[];
    final service = _service(
      database,
      (_) async => SubscriptionLoadResult(
        status: SubscriptionUpdateResult.success,
        rows: [imported],
      ),
      pings: pings,
    );
    final result = await service.insertSubscription(
      const SubscriptionInput(name: 'Source', url: 'https://example.com/sub'),
    );

    expect(result.success, isTrue);
    expect(result.count, 1);
    final source = (await database.subscriptionDao.allRows).single;
    expect(source.toJson(), isNot(contains('count')));
    expect(source.toJson(), isNot(contains('expanded')));
    expect(source.toJson(), isNot(contains('parseFailureCount')));
    final row = (await database.coreConfigDao.allOutboundRowsWithDataBySubId(
      source.id,
    )).single;
    expect(row.data, imported.data.value);
    expect(jsonDecode(utf8.decode(base64Decode(row.data!)))['tag'], 'Imported');
    expect(pings, [source.id]);
  });

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
      final service = _service(
        database,
        (_) async => SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [_node('Run A'), _node('New')],
        ),
        readReferences: () => references,
      );

      final result = await service.refreshSubscriptionResult(source);
      expect(result.success, isTrue);
      expect(result.count, 2);
      for (final row in originals.take(5)) {
        expect(await database.coreConfigDao.searchRow(row.id), row);
      }
      expect(await database.coreConfigDao.searchRow(originals.last.id), isNull);
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(source.id),
        hasLength(7),
      );
      final updated = (await database.subscriptionDao.searchRow(source.id))!;
      expect(updated.timestamp.isAfter(source.timestamp), isTrue);
      expect(updated.ageSecretKey, source.ageSecretKey);
      expect(updated.agePublicKey, source.agePublicKey);

      // Disconnecting does not remove fixed, final-exit or favorite references.
      references = SubscriptionNodeReferences(
        fixedId: originals[2].id,
        finalExitId: originals[3].id,
      );
      expect(
        (await service.refreshSubscriptionResult(updated)).success,
        isTrue,
      );
      expect(await database.coreConfigDao.searchRow(originals[0].id), isNull);
      expect(await database.coreConfigDao.searchRow(originals[1].id), isNull);
      for (final row in originals.skip(2).take(3)) {
        expect(await database.coreConfigDao.searchRow(row.id), row);
      }

      references = const SubscriptionNodeReferences();
      await database.coreConfigDao.updateRow(
        originals[4].copyWith(favorite: false),
      );
      await service.refreshSubscriptionResult(updated);
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
    'empty or failed results leave nodes and source metadata intact',
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
      );
      expect(inserted.success, isFalse);
      expect(inserted.status, SubscriptionUpdateResult.invalidContent);
      expect(await database.subscriptionDao.allRows, hasLength(1));
      final empty = await service.refreshSubscriptionResult(source);
      expect(empty.success, isFalse);
      expect(empty.status, SubscriptionUpdateResult.invalidContent);
      loaded = const SubscriptionLoadResult(
        status: SubscriptionUpdateResult.downloadFailed,
      );
      final failed = await service.refreshSubscriptionResult(source);
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
        ),
      );
      final result = await service.refreshSubscriptionResult(source);
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
        );
      });
      final first = service.refreshSubscriptionResult(source);
      final duplicate = service.refreshSubscriptionResult(source);
      await started.future;
      expect(
        await service.saveSubscriptionInput(
          source.id,
          const SubscriptionInput(
            name: 'Edited source',
            url: 'https://example.com/new',
            ageSecretKey: 'new-secret',
            agePublicKey: 'new-public',
          ),
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
      // Editing the source no longer downloads; its next refresh uses the edit.
      expect(
        (await service.refreshSubscriptionResult(current)).success,
        isTrue,
      );
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
      final refresh = service.refreshSubscriptionResult(source);
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

  test(
    'clear-data waits for in-flight downloads before replacing their rows',
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
      final oldRequest = service.refreshSubscriptionResult(source);
      await started.future;
      var restoreStarted = false;
      final restoring = service.pauseForDataClear().then((_) async {
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
        service.refreshSubscriptionResult(source),
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
