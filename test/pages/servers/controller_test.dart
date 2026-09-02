import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/settings.dart';
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
      controller.dispose();
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

  test('custom count uses empty outbounds; measured failure is not an untested candidate', () async {
    final one = await server('one');
    final two = await server('two');
    await db.customRoutingProfilesDao.insertRow(
      CustomRoutingProfilesCompanion.insert(
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
    controller.customRoutes = await db.customRoutingProfilesDao.allRows;
    controller.configuration = ConnectionConfiguration(
      connection: ConnectionSettings(
        trafficMode: TrafficMode.custom,
        customId: controller.customRoutes.single.id,
      ),
    );
    controller.servers = [
      one,
      two.copyWith(
        delay: PingDelayConstants.error,
        lastMeasuredAt: Value(DateTime(2026)),
      ),
    ];
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
