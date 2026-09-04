import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/routing/custom_service.dart';
import 'package:onexray/service/routing/state.dart';

void main() {
  test(
    'names use Unicode characters and trimmed case-insensitive uniqueness',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final service = CustomRoutingService(database);
      final id = await service.save(RoutingProfileState(name: ' Route '));
      expect((await database.routingProfileDao.searchRow(id))!.name, 'Route');
      await expectLater(
        service.save(RoutingProfileState(name: 'route')),
        throwsFormatException,
      );
      final name = List.filled(32, '🌐').join();
      await service.save(RoutingProfileState(id: id, name: name));
      expect((await database.routingProfileDao.searchRow(id))!.name, name);
    },
  );
  test(
    'custom saves share one strict limit/encoding boundary; edits stay allowed',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final service = CustomRoutingService(database);
      final state = RoutingProfileState(
        name: 'One',
        rules: [
          RoutingRuleState(
            ruleTag: 'Example',
            domain: const ['domain:example.com'],
            action: RoutingRuleAction.direct,
          ),
        ],
      );
      final id = await service.save(state);
      final row = (await database.routingProfileDao.searchRow(id))!;
      final stored = jsonDecode(utf8.decode(base64Decode(row.data))) as Map;
      expect(stored.containsKey('name'), false);
      expect(stored.containsKey('geodata'), false);
      final roundTrip = CustomRoutingService.read(row);
      expect(roundTrip.id, id);
      expect(roundTrip.name, 'One');
      expect(roundTrip.entryCount, 1);
      expect(roundTrip.rules.single.toJson(), state.rules.single.toJson());
      await service.save(RoutingProfileState(name: 'Two'));
      await service.save(RoutingProfileState(name: 'Three'));
      await expectLater(
        service.save(RoutingProfileState(name: 'Four')),
        throwsStateError,
      );
      await service.save(state.copyWith(id: id, name: 'Edited'));
      expect((await database.routingProfileDao.searchRow(id))!.name, 'Edited');
      await expectLater(
        service.save(state.copyWith(id: id, name: 'Hidden', entryCount: 4)),
        throwsFormatException,
      );
      expect((await database.routingProfileDao.searchRow(id))!.name, 'Edited');
    },
  );
}
