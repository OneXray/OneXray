import 'dart:convert';
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/routing/custom_service.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';

void main() {
  late AppDatabase db;
  late ServersController controller;
  final l = AppLocalizationsEn();
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final coordinator = ConnectionCoordinator(database: db);
    controller = ServersController(database: db, coordinator: coordinator);
    addTearDown(() async {
      await controller.close();
      coordinator.dispose();
      await db.close();
    });
  });

  Future<CoreConfigData> server(
    String name, {
    int source = 0,
    String country = 'JP',
    bool favorite = false,
  }) async {
    final id = await db.coreConfigDao.insertAssetRow(
      outboundCompanion({
        'tag': name,
        'protocol': 'vless',
        'streamSettings': {'network': 'xhttp', 'security': 'tls'},
      }).copyWith(
        subId: Value(source),
        countryCode: Value(country),
        favorite: Value(favorite),
      ),
    );
    return (await db.coreConfigDao.searchRow(id))!;
  }

  testWidgets(
    'pending node work blocks its source but not another node or navigation',
    (tester) async {
      final one = await server('one', source: 4);
      final two = await server('two', source: 4);
      controller.servers = [one, two];
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Servers'))),
      );
      final context = tester.element(find.text('Servers'));
      final pending = Completer<void>();
      final operation = controller.perform(
        context,
        () => pending.future,
        ids: {one.id},
      );
      expect(controller.serverBusy(one), isTrue);
      expect(controller.serverBusy(two), isFalse);
      expect(controller.sourceBusy(4), isTrue);
      expect(controller.busy, isFalse);
      var writes = 0;
      await controller.perform(context, () async => writes++, ids: {one.id});
      await controller.perform(context, () async => writes++, sourceId: 4);
      expect(writes, 0);
      await controller.perform(context, () async => writes++, ids: {two.id});
      expect(writes, 1);
      pending.complete();
      await operation;
      expect(controller.sourceBusy(4), isFalse);
    },
  );

  test('location/source grouping shares rows; searching never changes connection settings', () async {
    final one = await server('Tokyo', source: 4, favorite: true);
    final two = await server('Osaka', source: 4);
    controller.servers = [one, two];
    final before = controller.configuration.encode();
    expect(controller.groups(l).single.rows, [one, two]);
    controller.search.text = 'Tokyo';
    expect(controller.groups(l).single.visibleRows, [one]);
    expect(controller.favorites(l), [one]);
    controller.groupBy(ServerGrouping.subscription);
    expect(controller.groups(l).single.rows, [one, two]);
    expect(controller.groups(l).single.selection.id, 4);
    expect(controller.configuration.encode(), before);
    expect(controller.protocol(one), 'VLESS | XHTTP | TLS');
  });

  test('subscription grouping omits sources without nodes', () async {
    final one = await server('Tokyo', source: 4);
    controller.servers = [one];
    controller.sources = [
      SubscriptionData(
        id: 4,
        name: 'Used source',
        url: 'https://example.test/used',
        timestamp: DateTime(2026, 9, 4),
        count: 1,
        expanded: true,
      ),
      SubscriptionData(
        id: 5,
        name: 'Empty source',
        url: 'https://example.test/empty',
        timestamp: DateTime(2026, 9, 4),
        count: 0,
        expanded: true,
      ),
    ];

    controller.groupBy(ServerGrouping.subscription);

    expect(controller.groups(l).map((group) => group.name), ['Used source']);
  });

  test(
    'group summary keeps availability shape before a successful probe',
    () async {
      final one = await server('one');
      final two = await server('two');
      controller.servers = [one, two];

      expect(
        controller.summary(l, controller.groups(l).single),
        l.prototypeGroupAvailability(2, 2, '—'),
      );
    },
  );

  test('source checked label uses relative copy only for the current day', () {
    final now = DateTime(2026, 9, 4, 12);
    expect(
      controller.sourceCheckedLabel(l, now, now: now),
      l.prototypeCheckedJustNow,
    );
    expect(
      controller.sourceCheckedLabel(l, DateTime(2026, 9, 4, 10), now: now),
      l.prototypeCheckedToday,
    );
    expect(
      controller.sourceCheckedLabel(l, DateTime(2026, 9, 3, 23, 59), now: now),
      isNull,
    );
  });

  test('Use N follows normal route and excludes final exit, not the current fixed selection', () async {
    final one = await server('one');
    final two = await server('two');
    final exit = await server('exit');
    controller.servers = [one, two, exit];
    controller.configuration = ConnectionConfiguration(
      connection: ConnectionSettings(
        expert: true,
        selection: ServerSelection.server(one.id),
        smart: SmartRoutingSettings(entryCount: 2, finalExitId: exit.id),
      ),
    );
    final group = controller.groups(l).single;
    expect(controller.entryCount(group.selection), 2);
    expect(
      controller.canUse(group),
      true,
    ); // Unmeasured candidates are eligible.
    expect(controller.canChoose(exit), false);
    controller.servers = [one, exit];
    expect(controller.canUse(controller.groups(l).single), false);
    controller.configuration = ConnectionConfiguration(
      connection: ConnectionSettings(
        trafficMode: TrafficMode.allVpn,
        smart: SmartRoutingSettings(entryCount: 3),
      ),
    );
    expect(controller.entryCount(group.selection), 1);
  });

  test('delay alone distinguishes untested, successful, failed and timed-out nodes', () async {
    final row = await server('one');
    for (final (delay, label, selectable) in [
      (PingDelayConstants.unknown, l.prototypeNotTested, true),
      (0, l.prototypeAvailableLatency(0), true),
      (-1, l.prototypeTemporarilyUnavailable, false),
      (320, l.prototypeSlowLatency(320), true),
      (PingDelayConstants.error, l.prototypeTemporarilyUnavailable, false),
      (PingDelayConstants.timeout, l.prototypeTemporarilyUnavailable, false),
    ]) {
      final candidate = row.copyWith(delay: delay);
      expect(controller.health(l, candidate), label);
      expect(controller.canChoose(candidate), selectable);
      controller.servers = [candidate];
      expect(
        controller.automaticResult(l),
        delay == 0 || delay == 320
            ? l.prototypeCurrentServerLatency('one', delay)
            : isNull,
      );
    }
  });

  test('custom count uses empty outbounds; measured failure is not an untested candidate', () async {
    final one = await server('one');
    final two = await server('two');
    await db.routingProfileDao.insertRow(
      RoutingProfileCompanion.insert(
        name: 'custom',
        data: base64Encode(
          utf8.encode(
            jsonEncode({
              'outbounds': [{}, {}],
              'routing': {'rules': []},
            }),
          ),
        ),
      ),
    );
    controller.customRoutes = (await db.routingProfileDao.allRows)
        .map(CustomRoutingService.read)
        .toList();
    controller.configuration = ConnectionConfiguration(
      connection: ConnectionSettings(
        trafficMode: TrafficMode.custom,
        customId: controller.customRoutes.single.id,
      ),
    );
    controller.servers = [one, two.copyWith(delay: PingDelayConstants.error)];
    final group = controller.groups(l).single;
    expect(controller.entryCount(group.selection), 2);
    expect(controller.canUse(group), false);
    expect(controller.health(l, one), l.prototypeNotTested);
    expect(
      controller.health(l, controller.servers.last),
      l.prototypeTemporarilyUnavailable,
    );
  });
}
