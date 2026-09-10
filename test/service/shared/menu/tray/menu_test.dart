import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/servers/catalog.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/menu/tray/menu.dart';
import 'package:onexray/service/shared/menu/tray/service.dart';
import 'package:tray_manager/tray_manager.dart';

Iterable<MenuItem> _descendants(List<MenuItem> items) sync* {
  for (final item in items) {
    yield item;
    if (item.submenu != null) yield* _descendants(item.submenu!.items ?? []);
  }
}

MenuItem _item(List<MenuItem> items, String key) =>
    _descendants(items).singleWhere((item) => item.key == key);

CoreConfigCompanion _node(String name, {int source = 0, int delay = 10}) =>
    CoreConfigCompanion.insert(
      name: name,
      type: 'outbound',
      tags: '',
      data: Value(
        base64Encode(
          utf8.encode(
            jsonEncode({
              'tag': name,
              'protocol': 'socks',
              'settings': {'address': '127.0.0.1', 'port': 1080},
            }),
          ),
        ),
      ),
      delay: delay,
      subId: source,
      countryCode: const Value('JP'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppEventBus();
  final l = AppLocalizationsEn();
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('desktop choices retain legacy Raw rows, normal selection and grouped updates', () async {
    final source = await db.subscriptionDao.insertRow(
      SubscriptionCompanion.insert(
        name: 'Source',
        url: 'https://example.com/sub',
        timestamp: DateTime.now(),
      ),
    );
    final local = await db.coreConfigDao.insertRow(_node('Local'));
    await db.coreConfigDao.insertRow(_node('Remote', source: source));
    for (var i = 1; i <= 4; i++) {
      await db.coreConfigDao.insertRow(
        CoreConfigCompanion.insert(
          name: 'Raw $i',
          type: 'raw',
          tags: '',
          delay: 0,
          subId: 0,
          data: Value(base64Encode(utf8.encode('{}'))),
        ),
      );
    }
    await db.routingProfileDao.insertRow(
      RoutingProfileCompanion.insert(
        name: 'Work',
        data: base64Encode(utf8.encode('{}')),
      ),
    );
    final data = TrayMenuData()
      ..catalog = ServerCatalog(
        servers: await db.coreConfigDao.watchOutbounds().first,
        sources: await db.subscriptionDao.allRows,
      )
      ..raws = await db.coreConfigDao.allRawRowsWithDataStream.first
      ..routes = await db.routingProfileDao.allRows
      ..configuration = ConnectionSettings(
        selection: ServerSelection.server(local),
      );
    var items = data.selectionItems(l, busy: false);
    expect(_item(items, 'server:$local').checked, isTrue);
    expect(_item(items, 'source:0').label, l.prototypeManualAdditions);
    expect(
      _descendants(items)
          .where((item) => item.key?.startsWith('raw:') ?? false),
      hasLength(4),
    );
    expect(items.last.disabled, isFalse);

    data.configuration = ConnectionSettings(
      expert: true,
      rawId: data.raws.last.id,
    );
    items = data.selectionItems(l, busy: false);
    expect(_item(items, 'server:$local').checked, isFalse);
    expect(_item(items, 'raw:${data.raws.last.id}').checked, isTrue);
    expect(items.last.disabled, isTrue);
    expect(items.first.disabled, isFalse);
    expect(
      data.selectionItems(l, busy: true).every((item) => item.disabled),
      isTrue,
    );

    final updates = data.updateItems(l, {'updateSubscriptions'});
    expect(_item(updates, 'updateSubscription:$source').disabled, isTrue);
    expect(_item(updates, 'updateGeodata').disabled, isFalse);
    expect(_item(updates, 'updateDefaultGeodata').disabled, isFalse);
    expect(
      _descendants(updates)
          .any((item) => item.key?.contains('geosite') ?? false),
      isFalse,
    );

    await db.coreConfigDao.deleteRow(
      (await db.coreConfigDao.searchRow(local))!,
    );
    data.catalog = ServerCatalog(
      servers: await db.coreConfigDao.watchOutbounds().first,
    );
    expect(
      _descendants(data.selectionItems(l, busy: false))
          .any((item) => item.key == 'source:0'),
      isFalse,
    );
  });

  test(
    'database changes update tray names, delay order and active configuration',
    () async {
      final snapshots =
          <({List<int> ids, String? firstName, bool expert, int? rawId})>[];
      final subscription = TrayMenuData.watch(db).listen((data) {
        snapshots.add((
          ids: data.catalog.servers.map((row) => row.id).toList(),
          firstName: data.catalog.servers.firstOrNull?.name,
          expert: data.configuration.expert,
          rawId: data.configuration.rawId,
        ));
      });
      addTearDown(subscription.cancel);
      final slow = await db.coreConfigDao.insertRow(_node('Slow', delay: 900));
      final fast = await db.coreConfigDao.insertRow(_node('Fast', delay: 50));
      await db.connectionConfigDao.commit(
        configurationJson: ConnectionConfiguration(
          connection: ConnectionSettings(expert: true, rawId: 99),
        ).encode(),
      );
      await pumpEventQueue();
      expect(snapshots.last.ids, [fast, slow]);
      expect(snapshots.last.firstName, 'Fast');
      expect((snapshots.last.expert, snapshots.last.rawId), (true, 99));
      await db.coreConfigDao.deleteRow(
        (await db.coreConfigDao.searchRow(fast))!,
      );
      await pumpEventQueue();
      expect(snapshots.last.ids, [slow]);
    },
  );

  test('tray dispatch shares configuration application and revalidates a deleted choice', () async {
    final id = await db.coreConfigDao.insertRow(_node('Local'));
    final notifications = <String>[];
    final choices = <Map<String, dynamic>>[];
    Future<void> Function()? validate;
    final tray =
        TrayService.forTesting(
            database: db,
            connect: () async => fail('Selection must not directly start VPN'),
            notify: (message) async => notifications.add(message),
            showMainWindow: () async =>
                fail('Disconnected selection needs no window'),
          )
          ..onConfigurationChange = (values, label, check) async {
            choices.add(values);
            validate = check;
            await check();
          };
    await tray.onTrayMenuItemClick(MenuItem(key: 'server:$id'));
    expect(choices.single, {
      'expert': false,
      'selection': {'kind': 'server', 'id': id},
    });
    await db.coreConfigDao.deleteRow((await db.coreConfigDao.searchRow(id))!);
    await expectLater(
      validate!(),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'notFound')),
    );
    await tray.onTrayMenuItemClick(MenuItem(key: 'server:$id'));
    expect(choices, hasLength(1));
    expect(notifications, hasLength(1));
    await tray.onTrayMenuItemClick(MenuItem(key: 'traffic:allVpn'));
    expect(choices.last, {'expert': false, 'trafficMode': 'allVpn'});
    await tray.onTrayMenuItemClick(MenuItem(key: 'region:JP', disabled: true));
    expect(choices, hasLength(2));
  });
}
